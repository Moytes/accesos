import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class QueuedMutation {
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final String queuedAt;
  final String description;
  final String? dedupeKey;
  final List<String> invalidatePrefixes;
  int retryCount;

  QueuedMutation({
    required this.id,
    required this.method,
    required this.path,
    required this.body,
    required this.queuedAt,
    required this.description,
    this.dedupeKey,
    this.invalidatePrefixes = const [],
    this.retryCount = 0,
  });

  factory QueuedMutation.fromJson(Map<String, dynamic> json) {
    return QueuedMutation(
      id: json['id']?.toString() ?? '',
      method: json['method']?.toString() ?? 'POST',
      path: json['path']?.toString() ?? '',
      body: Map<String, dynamic>.from(json['body'] as Map? ?? const {}),
      queuedAt: json['queuedAt']?.toString() ?? '',
      description: json['description']?.toString() ?? 'Operación pendiente',
      dedupeKey: json['dedupeKey']?.toString(),
      invalidatePrefixes:
          List<String>.from(json['invalidatePrefixes'] ?? const []),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'body': body,
        'queuedAt': queuedAt,
        'description': description,
        if (dedupeKey != null) 'dedupeKey': dedupeKey,
        'invalidatePrefixes': invalidatePrefixes,
        'retryCount': retryCount,
      };
}

class SyncRunResult {
  final int processed;
  final int failedPermanent;
  final int remaining;
  final String? lastError;

  const SyncRunResult({
    required this.processed,
    required this.failedPermanent,
    required this.remaining,
    this.lastError,
  });
}

typedef QueuedRequestSender = Future<http.Response> Function(
  String method,
  String path,
  Map<String, dynamic> body,
);

/// Cola FIFO persistente (Outbox) por usuario para operaciones académicas idempotentes offline.
class OfflineSyncQueueService {
  static final OfflineSyncQueueService _instance =
      OfflineSyncQueueService._internal();
  factory OfflineSyncQueueService() => _instance;
  OfflineSyncQueueService._internal();

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastSyncError = ValueNotifier<String?>(null);

  String _activeUserId = 'anon';
  final Map<String, List<QueuedMutation>> _memoryQueues = {};
  Directory? _overrideRootDir;
  QueuedRequestSender? _sender;
  Future<void> Function(List<String> prefixes)? _onInvalidatePrefixes;
  Completer<SyncRunResult>? _activeSync;

  void registerHandlers({
    required QueuedRequestSender sender,
    Future<void> Function(List<String> prefixes)? onInvalidatePrefixes,
  }) {
    _sender = sender;
    _onInvalidatePrefixes = onInvalidatePrefixes;
  }

  @visibleForTesting
  void configureForTest({Directory? rootDir}) {
    _overrideRootDir = rootDir;
    _memoryQueues.clear();
    pendingCount.value = 0;
    isSyncing.value = false;
    lastSyncError.value = null;
  }

  String _sanitizeSegment(String input) =>
      input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');

  Future<void> setActiveUser(String? userId) async {
    final clean = (userId ?? '').trim();
    _activeUserId = clean.isEmpty ? 'anon' : _sanitizeSegment(clean);
    final items = await _loadQueue(_activeUserId);
    pendingCount.value = items.length;
  }

  Future<File?> _queueFile(String uid) async {
    try {
      final base = _overrideRootDir ?? await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/controlplus_queue');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return File('${dir.path}/queue_${_sanitizeSegment(uid)}.json');
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<QueuedMutation>> _loadQueue(String uid) async {
    if (_memoryQueues.containsKey(uid)) {
      return List<QueuedMutation>.from(_memoryQueues[uid]!);
    }

    final file = await _queueFile(uid);
    if (file != null && await file.exists()) {
      try {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = decoded
              .whereType<Map>()
              .map((e) => QueuedMutation.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _memoryQueues[uid] = parsed;
          return List<QueuedMutation>.from(parsed);
        }
      } catch (e) {
        debugPrint('OfflineSyncQueue load error: $e');
      }
    }

    _memoryQueues[uid] = [];
    return [];
  }

  Future<void> _saveQueue(String uid, List<QueuedMutation> items) async {
    _memoryQueues[uid] = List<QueuedMutation>.from(items);
    if (uid == _activeUserId) {
      pendingCount.value = items.length;
    }

    final file = await _queueFile(uid);
    if (file != null) {
      try {
        await file.writeAsString(
          jsonEncode(items.map((e) => e.toJson()).toList()),
          flush: true,
        );
      } catch (e) {
        debugPrint('OfflineSyncQueue save error: $e');
      }
    }
  }

  Future<void> enqueue({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    required String description,
    String? dedupeKey,
    List<String> invalidatePrefixes = const [],
  }) async {
    final uid = _activeUserId;
    final items = await _loadQueue(uid);

    if (dedupeKey != null && dedupeKey.isNotEmpty) {
      items.removeWhere((item) => item.dedupeKey == dedupeKey);
    }

    final entry = QueuedMutation(
      id: '${DateTime.now().microsecondsSinceEpoch}_${items.length}',
      method: method.toUpperCase(),
      path: path,
      body: body,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
      description: description,
      dedupeKey: dedupeKey,
      invalidatePrefixes: invalidatePrefixes,
    );

    items.add(entry);
    await _saveQueue(uid, items);
  }

  Future<List<QueuedMutation>> getPendingItems() => _loadQueue(_activeUserId);

  Future<SyncRunResult> processQueue() async {
    if (_activeSync != null) {
      return _activeSync!.future;
    }

    final sender = _sender;
    if (sender == null) {
      return SyncRunResult(
        processed: 0,
        failedPermanent: 0,
        remaining: pendingCount.value,
      );
    }

    final completer = Completer<SyncRunResult>();
    _activeSync = completer;
    isSyncing.value = true;

    int processed = 0;
    int failedPermanent = 0;
    String? errMessage;

    try {
      final uid = _activeUserId;
      final items = await _loadQueue(uid);
      final remaining = <QueuedMutation>[];
      final prefixesToInvalidate = <String>{};

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        try {
          final resp = await sender(item.method, item.path, item.body);
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            processed++;
            prefixesToInvalidate.addAll(item.invalidatePrefixes);
          } else if (resp.statusCode == 400 ||
              resp.statusCode == 403 ||
              resp.statusCode == 404 ||
              resp.statusCode == 409 ||
              resp.statusCode == 422) {
            // Rechazo definitivo de dominio/validación: sacar de cola para no bloquear la fila
            failedPermanent++;
            errMessage =
                '${item.description}: rechazado (${resp.statusCode})';
          } else {
            // Error transitorio (401, 5xx, rate-limit): conservar este y el resto en orden FIFO
            item.retryCount++;
            remaining.addAll(items.sublist(i));
            errMessage = 'Pendiente de reintento (HTTP ${resp.statusCode})';
            break;
          }
        } catch (e) {
          // Falla de red/timeout: detener ejecución FIFO sin perder elementos
          item.retryCount++;
          remaining.addAll(items.sublist(i));
          errMessage = 'Sin conexión al sincronizar';
          break;
        }
      }

      await _saveQueue(uid, remaining);

      if (prefixesToInvalidate.isNotEmpty && _onInvalidatePrefixes != null) {
        await _onInvalidatePrefixes!(prefixesToInvalidate.toList());
      }

      lastSyncError.value = failedPermanent > 0 ? errMessage : null;
      final result = SyncRunResult(
        processed: processed,
        failedPermanent: failedPermanent,
        remaining: remaining.length,
        lastError: errMessage,
      );
      completer.complete(result);
      return result;
    } finally {
      isSyncing.value = false;
      _activeSync = null;
    }
  }

  Future<void> clearUserQueue(String userId) async {
    final safeUid = _sanitizeSegment(userId.isEmpty ? 'anon' : userId);
    _memoryQueues.remove(safeUid);
    if (safeUid == _activeUserId) {
      pendingCount.value = 0;
    }
    final file = await _queueFile(safeUid);
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}

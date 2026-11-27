import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Almacenamiento local SWR en disco aislado por usuario para modo Offline-First.
/// Nunca persiste tokens QR dinámicos ni notas clínicas confidenciales de Psicología.
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  static const List<String> _sensitiveKeywords = [
    'qr/generate',
    'qr/clase',
    'qr_dynamic',
    'notas_clinicas',
    'citas_psicologicas_notas',
  ];

  String _activeUserId = 'anon';
  final Map<String, String> _memoryFallback = {};
  Directory? _overrideRootDir;

  String get activeUserId => _activeUserId;

  void setActiveUser(String? userId) {
    final clean = (userId ?? '').trim();
    _activeUserId = clean.isEmpty ? 'anon' : _sanitizeSegment(clean);
  }

  @visibleForTesting
  void configureForTest({Directory? rootDir}) {
    _overrideRootDir = rootDir;
    _memoryFallback.clear();
  }

  bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return _sensitiveKeywords.any(lower.contains);
  }

  String _sanitizeSegment(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
  }

  String _fileNameForKey(String key) {
    final encoded = base64Url.encode(utf8.encode(key));
    if (encoded.length <= 120) {
      return '$encoded.json';
    }
    return '${encoded.substring(0, 80)}_${key.hashCode.abs()}.json';
  }

  Future<Directory?> _resolveUserDir(String userId) async {
    final safeUid = _sanitizeSegment(userId.isEmpty ? 'anon' : userId);
    try {
      final baseDir =
          _overrideRootDir ?? await getApplicationSupportDirectory();
      final dir = Directory('${baseDir.path}/controlplus_cache/$safeUid');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveJson(String key, dynamic data, {String? userId}) async {
    if (_isSensitiveKey(key)) return;

    final uid = userId != null && userId.isNotEmpty
        ? _sanitizeSegment(userId)
        : _activeUserId;

    final payload = jsonEncode({
      'key': key,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    });

    final memKey = '$uid::$key';
    _memoryFallback[memKey] = payload;

    final dir = await _resolveUserDir(uid);
    if (dir != null) {
      try {
        final file = File('${dir.path}/${_fileNameForKey(key)}');
        await file.writeAsString(payload, flush: true);
      } catch (e) {
        debugPrint('OfflineCache write warning ($key): $e');
      }
    }
  }

  Future<T?> readJson<T>(
    String key, {
    Duration? maxAge,
    String? userId,
  }) async {
    if (_isSensitiveKey(key)) return null;

    final envelope = await _readEnvelope(key, userId: userId);
    if (envelope == null) return null;

    if (maxAge != null) {
      final savedAtStr = envelope['savedAt']?.toString();
      final savedAt =
          savedAtStr != null ? DateTime.tryParse(savedAtStr) : null;
      if (savedAt == null ||
          DateTime.now().toUtc().difference(savedAt) > maxAge) {
        return null;
      }
    }

    final rawData = envelope['data'];
    if (rawData is T) {
      return rawData;
    }
    return rawData as T?;
  }

  Future<DateTime?> readSavedAt(String key, {String? userId}) async {
    final envelope = await _readEnvelope(key, userId: userId);
    final str = envelope?['savedAt']?.toString();
    return str != null ? DateTime.tryParse(str)?.toLocal() : null;
  }

  Future<Map<String, dynamic>?> _readEnvelope(
    String key, {
    String? userId,
  }) async {
    final uid = userId != null && userId.isNotEmpty
        ? _sanitizeSegment(userId)
        : _activeUserId;
    final memKey = '$uid::$key';

    String? raw = _memoryFallback[memKey];
    if (raw == null) {
      final dir = await _resolveUserDir(uid);
      if (dir != null) {
        try {
          final file = File('${dir.path}/${_fileNameForKey(key)}');
          if (await file.exists()) {
            raw = await file.readAsString();
            _memoryFallback[memKey] = raw;
          }
        } catch (e) {
          debugPrint('OfflineCache read warning ($key): $e');
        }
      }
    }

    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<void> removeKey(String key, {String? userId}) async {
    final uid = userId != null && userId.isNotEmpty
        ? _sanitizeSegment(userId)
        : _activeUserId;
    _memoryFallback.remove('$uid::$key');

    final dir = await _resolveUserDir(uid);
    if (dir != null) {
      try {
        final file = File('${dir.path}/${_fileNameForKey(key)}');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> invalidatePrefix(String prefix, {String? userId}) async {
    final uid = userId != null && userId.isNotEmpty
        ? _sanitizeSegment(userId)
        : _activeUserId;

    _memoryFallback.removeWhere(
      (k, _) => k.startsWith('$uid::$prefix'),
    );

    final dir = await _resolveUserDir(uid);
    if (dir != null && await dir.exists()) {
      try {
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            try {
              final raw = await entity.readAsString();
              final decoded = jsonDecode(raw);
              if (decoded is Map &&
                  (decoded['key']?.toString() ?? '').startsWith(prefix)) {
                await entity.delete();
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

  Future<void> clearUserCache(String userId) async {
    final safeUid = _sanitizeSegment(userId.isEmpty ? 'anon' : userId);
    _memoryFallback.removeWhere((k, _) => k.startsWith('$safeUid::'));

    try {
      final baseDir =
          _overrideRootDir ?? await getApplicationSupportDirectory();
      final dir = Directory('${baseDir.path}/controlplus_cache/$safeUid');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on MissingPluginException {
      // Ignorar en entorno de test
    } catch (_) {}
  }
}

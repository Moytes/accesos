import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'offline_sync_queue_service.dart';

/// Monitorea el estado de red y conectividad real con el backend EC2,
/// disparando la sincronización automática de la cola offline al reconectar.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  final ValueNotifier<DateTime?> lastCheckedAt = ValueNotifier<DateTime?>(null);

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final results = await Connectivity().checkConnectivity();
      await _handleConnectivityResults(results);

      _subscription =
          Connectivity().onConnectivityChanged.listen((results) async {
        await _handleConnectivityResults(results);
      });
    } on MissingPluginException {
      // En pruebas unitarias o plataforma sin plugin mantener comportamiento seguro
      isOnline.value = true;
    } catch (e) {
      debugPrint('ConnectivityService init warning: $e');
    }
  }

  Future<void> _handleConnectivityResults(
      List<ConnectivityResult> results) async {
    final hasInterface =
        results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      isOnline.value = false;
      lastCheckedAt.value = DateTime.now();
      return;
    }

    await checkBackendReachability();
  }

  Future<bool> checkBackendReachability() async {
    try {
      final resp = await http
          .get(ApiConfig.healthUri)
          .timeout(ApiConfig.healthTimeout);
      final ok = resp.statusCode >= 200 && resp.statusCode < 500;
      _updateStatus(ok);
      return ok;
    } catch (_) {
      _updateStatus(false);
      return false;
    }
  }

  void reportNetworkSuccess() => _updateStatus(true);

  void reportNetworkFailure() => _updateStatus(false);

  void _updateStatus(bool online) {
    final wasOffline = !isOnline.value;
    isOnline.value = online;
    lastCheckedAt.value = DateTime.now();

    if (online &&
        (wasOffline || OfflineSyncQueueService().pendingCount.value > 0)) {
      OfflineSyncQueueService().processQueue();
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controla el bloqueo nativo de capturas y grabación de pantalla
/// (FLAG_SECURE en Android; detección + privacidad en iOS) mediante conteo de referencias.
class ScreenSecurityService {
  static final ScreenSecurityService _instance = ScreenSecurityService._internal();
  factory ScreenSecurityService() => _instance;

  ScreenSecurityService._internal() {
    _channel.setMethodCallHandler(_handlePlatformCall);
  }

  static const MethodChannel _channel = MethodChannel('com.controlplus/screen_security');

  int _activeLocks = 0;
  final ValueNotifier<bool> isCaptured = ValueNotifier<bool>(false);
  final StreamController<void> _screenshotController =
      StreamController<void>.broadcast();

  Stream<void> get onScreenshotAttempt => _screenshotController.stream;
  bool get isSecureModeActive => _activeLocks > 0;

  Future<dynamic> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'onCaptureChanged':
        final captured = call.arguments == true;
        isCaptured.value = captured;
        return null;
      case 'onScreenshotTaken':
        _screenshotController.add(null);
        return null;
      default:
        return null;
    }
  }

  Future<void> acquire() async {
    _activeLocks++;
    if (_activeLocks == 1) {
      await _enableNative();
    }
    await refreshCaptureStatus();
  }

  Future<void> release() async {
    if (_activeLocks > 0) {
      _activeLocks--;
    }
    if (_activeLocks == 0) {
      await _disableNative();
      isCaptured.value = false;
    }
  }

  Future<bool> refreshCaptureStatus() async {
    try {
      final result = await _channel.invokeMethod<bool>('isScreenCaptured');
      final captured = result ?? false;
      isCaptured.value = captured;
      return captured;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _enableNative() async {
    try {
      await _channel.invokeMethod('enableSecureMode');
    } on MissingPluginException {
      // Ignorar en entornos de prueba o escritorio sin canal nativo
    } on PlatformException {
      // Ignorar fallos no fatales de plataforma
    }
  }

  Future<void> _disableNative() async {
    try {
      await _channel.invokeMethod('disableSecureMode');
    } on MissingPluginException {
      // Ignorar en entornos de prueba o escritorio sin canal nativo
    } on PlatformException {
      // Ignorar fallos no fatales de plataforma
    }
  }

  @visibleForTesting
  void resetForTest() {
    _activeLocks = 0;
    isCaptured.value = false;
  }
}

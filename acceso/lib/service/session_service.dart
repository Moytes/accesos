import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'offline_cache_service.dart';
import 'offline_sync_queue_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;
  VoidCallback? _onSessionExpired;

  // Estado actual de sesión
  bool _isSessionActive = false;
  String? _userId;
  String? _nombre;
  String? _rol;
  List<String> _roles = [];
  String? _email;
  String? _matricula;
  String? _numeroEmpleado;
  String? _grupo;
  String? _imagenUrl;
  String? _sessionId;

  final ValueNotifier<String?> activeRoleNotifier = ValueNotifier<String?>(null);

  static const Duration _sessionTimeout = Duration(minutes: 60);
  static const String _keySessionActive = 'session_active';
  static const String _keyUserId = 'user_id';
  static const String _keyNombre = 'nombre';
  static const String _keyRol = 'rol';
  static const String _keyRoles = 'roles';
  static const String _keyEmail = 'email';
  static const String _keyMatricula = 'matricula';
  static const String _keyNumeroEmpleado = 'numero_empleado';
  static const String _keyGrupo = 'grupo';
  static const String _keyImagenUrl = 'imagen_url';
  static const String _keySessionId = 'session_id';
  static const String _keyLastActivity = 'last_activity';

  // ─── GETTERS ──────────────────────────────────────────────────────────
  bool get isSessionActive => _isSessionActive;
  String? get userId => _userId;
  String? get nombre => _nombre;
  String? get rol => _rol;
  List<String> get roles => List.unmodifiable(_roles);
  String? get email => _email;
  String? get matricula => _matricula;
  String? get numeroEmpleado => _numeroEmpleado;
  String? get grupo => _grupo;
  String? get imagenUrl => _imagenUrl;
  String? get sessionId => _sessionId;
  DateTime? get lastActivityTime => _lastActivityTime;

  bool hasRole(String code) {
    final target = code.trim().toLowerCase();
    return _roles.any((r) => r.trim().toLowerCase() == target) ||
        (_rol ?? '').trim().toLowerCase() == target;
  }

  // ─── INICIALIZAR ──────────────────────────────────────────────────────
  Future<void> initialize(VoidCallback onSessionExpired) async {
    _onSessionExpired = onSessionExpired;
    await _cargarSesionGuardada();
    _startInactivityTimer();
  }

  Future<bool> _cargarSesionGuardada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSessionActive = prefs.getBool(_keySessionActive) ?? false;

      if (_isSessionActive) {
        _userId = prefs.getString(_keyUserId);
        _nombre = prefs.getString(_keyNombre);
        _rol = prefs.getString(_keyRol);
        _roles = prefs.getStringList(_keyRoles) ??
            (_rol != null && _rol!.isNotEmpty ? [_rol!] : []);
        _email = prefs.getString(_keyEmail);
        _matricula = prefs.getString(_keyMatricula);
        _numeroEmpleado = prefs.getString(_keyNumeroEmpleado);
        _grupo = prefs.getString(_keyGrupo);
        _imagenUrl = prefs.getString(_keyImagenUrl);
        _sessionId = prefs.getString(_keySessionId);
        activeRoleNotifier.value = _rol;

        OfflineCacheService().setActiveUser(_userId);
        await OfflineSyncQueueService().setActiveUser(_userId);

        final lastActivityStr = prefs.getString(_keyLastActivity);
        if (lastActivityStr != null && lastActivityStr.isNotEmpty) {
          _lastActivityTime = DateTime.tryParse(lastActivityStr) ?? DateTime.now();
        } else {
          _lastActivityTime = DateTime.now();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error cargando sesión: $e');
      return false;
    }
  }

  /// Verifica si existe una sesión local con JWT válido almacenado de forma segura.
  Future<bool> restorePersistedSession() async {
    final loaded = await _cargarSesionGuardada();
    if (!loaded || _userId == null || _userId!.isEmpty || (_rol ?? '').isEmpty) {
      return false;
    }
    final token = await ApiClient().getToken();
    return token != null && token.isNotEmpty;
  }

  // ─── INICIAR SESIÓN ──────────────────────────────────────────────────
  Future<void> startSession({
    required String userId,
    required String nombre,
    required String rol,
    List<String>? roles,
    String? email,
    String? matricula,
    String? numeroEmpleado,
    String? grupo,
    String? imagenUrl,
    String? sessionId,
  }) async {
    _isSessionActive = true;
    _userId = userId;
    _nombre = nombre;
    _rol = rol;
    _roles = (roles != null && roles.isNotEmpty)
        ? List<String>.from(roles)
        : [rol];
    if (!_roles.any((r) => r.toLowerCase() == rol.toLowerCase())) {
      _roles.insert(0, rol);
    }
    _email = email;
    _matricula = matricula;
    _numeroEmpleado = numeroEmpleado;
    _grupo = grupo;
    _imagenUrl = imagenUrl;
    _sessionId = sessionId;
    _lastActivityTime = DateTime.now();
    activeRoleNotifier.value = _rol;

    OfflineCacheService().setActiveUser(userId);
    await OfflineSyncQueueService().setActiveUser(userId);

    await _guardarSesion();
    _startInactivityTimer();
  }

  Future<void> switchActiveRole(String newRole) async {
    if (!_isSessionActive) return;
    _rol = newRole;
    if (!_roles.any((r) => r.toLowerCase() == newRole.toLowerCase())) {
      _roles.add(newRole);
    }
    activeRoleNotifier.value = _rol;
    await _guardarSesion();
  }

  Future<void> _guardarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySessionActive, _isSessionActive);
      await prefs.setString(_keyUserId, _userId ?? '');
      await prefs.setString(_keyNombre, _nombre ?? '');
      await prefs.setString(_keyRol, _rol ?? '');
      await prefs.setStringList(_keyRoles, _roles);
      await prefs.setString(_keyEmail, _email ?? '');
      if (_matricula != null) {
        await prefs.setString(_keyMatricula, _matricula!);
      }
      if (_numeroEmpleado != null) {
        await prefs.setString(_keyNumeroEmpleado, _numeroEmpleado!);
      }
      if (_grupo != null) {
        await prefs.setString(_keyGrupo, _grupo!);
      }
      if (_imagenUrl != null) {
        await prefs.setString(_keyImagenUrl, _imagenUrl!);
      }
      if (_sessionId != null) {
        await prefs.setString(_keySessionId, _sessionId!);
      }
      await prefs.setString(
        _keyLastActivity,
        _lastActivityTime?.toIso8601String() ?? '',
      );
    } catch (e) {
      debugPrint('Error guardando sesión: $e');
    }
  }

  Future<void> actualizarSesion({
    String? nombre,
    String? email,
    String? matricula,
    String? numeroEmpleado,
    String? grupo,
    String? imagenUrl,
    List<String>? roles,
  }) async {
    if (!_isSessionActive) return;
    if (nombre != null) _nombre = nombre;
    if (email != null) _email = email;
    if (matricula != null) _matricula = matricula;
    if (numeroEmpleado != null) _numeroEmpleado = numeroEmpleado;
    if (grupo != null) _grupo = grupo;
    if (imagenUrl != null) _imagenUrl = imagenUrl;
    if (roles != null && roles.isNotEmpty) _roles = List<String>.from(roles);
    await _guardarSesion();
  }

  // ─── TIMER DE INACTIVIDAD ────────────────────────────────────────────
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_isSessionActive) return;

    _inactivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (_lastActivityTime != null) {
          final difference = DateTime.now().difference(_lastActivityTime!);
          if (difference >= _sessionTimeout) {
            await _expireSession();
          }
        }
      },
    );
  }

  Future<void> recordActivity() async {
    if (!_isSessionActive) return;
    _lastActivityTime = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyLastActivity,
        _lastActivityTime!.toIso8601String(),
      );
    } catch (_) {}
  }

  Future<void> _expireSession() async {
    _inactivityTimer?.cancel();
    _lastActivityTime = null;
    _isSessionActive = false;
    await _guardarSesion();
    _onSessionExpired?.call();
  }

  // ─── CERRAR SESIÓN ──────────────────────────────────────────────────
  Future<void> endSession() async {
    final previousUid = _userId;
    _inactivityTimer?.cancel();
    _lastActivityTime = null;
    _isSessionActive = false;
    _userId = null;
    _nombre = null;
    _rol = null;
    _roles = [];
    _email = null;
    _matricula = null;
    _numeroEmpleado = null;
    _grupo = null;
    _imagenUrl = null;
    _sessionId = null;
    activeRoleNotifier.value = null;

    await ApiClient().clearToken();
    if (previousUid != null && previousUid.isNotEmpty) {
      await OfflineCacheService().clearUserCache(previousUid);
      await OfflineSyncQueueService().clearUserQueue(previousUid);
    }
    OfflineCacheService().setActiveUser(null);
    await OfflineSyncQueueService().setActiveUser(null);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySessionActive);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyNombre);
      await prefs.remove(_keyRol);
      await prefs.remove(_keyRoles);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyMatricula);
      await prefs.remove(_keyNumeroEmpleado);
      await prefs.remove(_keyGrupo);
      await prefs.remove(_keyImagenUrl);
      await prefs.remove(_keySessionId);
      await prefs.remove(_keyLastActivity);
      await prefs.remove('auth_token');
    } catch (e) {
      debugPrint('Error eliminando sesión: $e');
    }
  }

  Future<bool> verificarSesion() async => _isSessionActive;

  Map<String, dynamic> getSessionData() {
    return {
      'isActive': _isSessionActive,
      'userId': _userId,
      'nombre': _nombre,
      'rol': _rol,
      'roles': _roles,
      'email': _email,
      'matricula': _matricula,
      'numeroEmpleado': _numeroEmpleado,
      'grupo': _grupo,
      'imagenUrl': _imagenUrl,
      'lastActivity': _lastActivityTime?.toIso8601String(),
    };
  }

  void dispose() {
    _inactivityTimer?.cancel();
    _lastActivityTime = null;
    _onSessionExpired = null;
  }

  Future<void> extenderSesion() async {
    if (_isSessionActive) {
      _lastActivityTime = DateTime.now();
      await _guardarSesion();
    }
  }

  void setSessionTimeout(Duration timeout) {}
}

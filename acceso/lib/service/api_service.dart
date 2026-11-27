import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'offline_cache_service.dart';
import 'offline_sync_queue_service.dart';

/// Capa unificada de acceso a datos de Control+ (.NET 10 App API v2).
/// Implementa estrategia Stale-While-Revalidate (caché persistente por usuario)
/// y cola Outbox FIFO para mutaciones académicas en modo offline.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    OfflineSyncQueueService().registerHandlers(
      sender: _sendQueuedRequest,
      onInvalidatePrefixes: (prefixes) async {
        for (final p in prefixes) {
          await _cache.invalidatePrefix(p);
        }
      },
    );
  }

  final ApiClient _client = ApiClient();
  final OfflineCacheService _cache = OfflineCacheService();
  final OfflineSyncQueueService _queue = OfflineSyncQueueService();

  String? lastError;
  bool lastDataFromCache = false;
  bool lastMutationQueuedOffline = false;

  Future<http.Response> _sendQueuedRequest(
    String method,
    String path,
    Map<String, dynamic> body,
  ) {
    return _client.sendDynamic(method, path, body: body, includeAuth: true);
  }

  /// Lectura tolerante a fallos de red (SWR): intenta red y guarda caché;
  /// ante error de conectividad/5xx devuelve datos cacheados del usuario.
  Future<T> _getWithOfflineCache<T>({
    required String cacheKey,
    required String path,
    required T Function(dynamic decoded) parser,
    required T fallback,
    Duration? maxAge,
  }) async {
    lastError = null;
    try {
      final response = await _client.get(path);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        await _cache.saveJson(cacheKey, decoded);
        lastDataFromCache = false;
        return parser(decoded);
      }
      lastError = ApiClient.extractErrorMessage(response);
      if (response.statusCode >= 500) {
        final cached = await _cache.readJson<dynamic>(cacheKey, maxAge: maxAge);
        if (cached != null) {
          lastDataFromCache = true;
          return parser(cached);
        }
      }
      return fallback;
    } catch (e) {
      debugPrint('ApiService GET fallback ($path): $e');
      if (ApiClient.isConnectivityError(e) || !ConnectivityService().isOnline.value) {
        lastError = 'Sin conexión al servidor';
        final cached = await _cache.readJson<dynamic>(cacheKey, maxAge: maxAge);
        if (cached != null) {
          lastDataFromCache = true;
          return parser(cached);
        }
      } else {
        lastError = e.toString();
      }
      return fallback;
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic decoded) {
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ─── AUTENTICACIÓN Y SESIÓN ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> login(
    String correo,
    String password, {
    String? deviceInfo,
  }) async {
    lastError = null;
    try {
      final response = await _client.post(
        '/auth/login',
        includeAuth: false,
        body: {
          'correo': correo,
          'password': password,
          if (deviceInfo != null && deviceInfo.isNotEmpty)
            'deviceInfo': deviceInfo,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload = jsonDecode(response.body);
        final token = payload['token'] as String?;
        final user = payload['user'] as Map<String, dynamic>?;
        if (token != null && token.isNotEmpty) {
          await _client.setToken(token);
        }
        if (user != null) {
          final uid = user['id']?.toString();
          if (uid != null && uid.isNotEmpty) {
            _cache.setActiveUser(uid);
            await _queue.setActiveUser(uid);
            await _cache.saveJson('user_$uid', user, userId: uid);
          }
          user['sessionId'] = payload['sessionId'];
        }
        return user;
      }

      lastError = ApiClient.extractErrorMessage(
        response,
        fallback: 'Correo o contraseña incorrectos.',
      );
      return null;
    } catch (e) {
      debugPrint('Error en login: $e');
      lastError = ApiClient.isConnectivityError(e)
          ? 'No se pudo conectar con el servidor. Verifica tu conexión a internet.'
          : 'Error al iniciar sesión: $e';
      return null;
    }
  }

  Future<bool> logout(String userId, {bool allDevices = false}) async {
    try {
      await _client.post(
        '/auth/logout',
        body: {
          'userId': userId,
          'allDevices': allDevices,
        },
      );
    } catch (e) {
      debugPrint('Error en logout: $e');
    } finally {
      await _client.clearToken();
    }
    return true;
  }

  Future<Map<String, dynamic>?> getMe() async {
    return _getWithOfflineCache<Map<String, dynamic>?>(
      cacheKey: 'auth_me',
      path: '/auth/me',
      parser: (d) => d is Map ? Map<String, dynamic>.from(d) : null,
      fallback: null,
    );
  }

  Future<List<Map<String, dynamic>>> getSesionesActivas() async {
    lastError = null;
    try {
      final response = await _client.get('/auth/sesiones');
      if (response.statusCode == 200) {
        return _asMapList(jsonDecode(response.body));
      }
      lastError = ApiClient.extractErrorMessage(response);
      return [];
    } catch (e) {
      lastError = 'No se pudieron cargar las sesiones activas.';
      return [];
    }
  }

  // ─── USUARIOS Y AVATAR R2 ─────────────────────────────────────────────────

  Future<String?> uploadAvatar(List<int> fileBytes, String fileName) async {
    lastError = null;
    try {
      final response = await _client.uploadFile(
        '/users/avatar',
        fileBytes: fileBytes,
        fileName: fileName,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _cache.invalidatePrefix('user_');
        await _cache.invalidatePrefix('auth_me');
        return data['url']?.toString();
      }
      lastError = ApiClient.extractErrorMessage(
        response,
        fallback: 'No se pudo subir la foto de perfil.',
      );
      return null;
    } catch (e) {
      lastError = ApiClient.isConnectivityError(e)
          ? 'Sin conexión para subir foto de perfil.'
          : 'Error al subir avatar: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    return _getWithOfflineCache<Map<String, dynamic>?>(
      cacheKey: 'user_$userId',
      path: '/users/$userId',
      parser: (d) => d is Map ? Map<String, dynamic>.from(d) : null,
      fallback: null,
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsers({
    String? rol,
    String? estatus,
  }) async {
    final params = <String>[];
    if (rol != null && rol.trim().isNotEmpty) {
      params.add('rol=${Uri.encodeQueryComponent(rol.trim())}');
    }
    if (estatus != null && estatus.trim().isNotEmpty) {
      params.add('estatus=${Uri.encodeQueryComponent(estatus.trim())}');
    }
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return _getWithOfflineCache<List<Map<String, dynamic>>>(
      cacheKey: 'users_list_$query',
      path: '/users$query',
      parser: _asMapList,
      fallback: const [],
    );
  }

  Future<Map<String, dynamic>?> createUser({
    required String nombre,
    required String correo,
    required String password,
    required String rol,
    List<String>? roles,
    String? matricula,
    String? numeroEmpleado,
    String? grupo,
    String? grupoId,
    required int activo,
    String? estatus,
  }) async {
    lastError = null;
    try {
      final response = await _client.post(
        '/users',
        body: {
          'nombre': nombre,
          'correo': correo,
          'password': password,
          'rol': rol,
          if (roles != null && roles.isNotEmpty) 'roles': roles,
          'matricula': (matricula != null && matricula.trim().isNotEmpty)
              ? matricula.trim()
              : null,
          'numeroEmpleado':
              (numeroEmpleado != null && numeroEmpleado.trim().isNotEmpty)
                  ? numeroEmpleado.trim()
                  : null,
          'grupo': grupo,
          if (grupoId != null && grupoId.isNotEmpty) 'grupoId': grupoId,
          'activo': activo,
          if (estatus != null && estatus.isNotEmpty) 'estatus': estatus,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        await _cache.invalidatePrefix('users_');
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(
        response,
        fallback: 'No se pudo crear el usuario.',
      );
      return null;
    } catch (e) {
      debugPrint('Error en createUser: $e');
      lastError = ApiClient.isConnectivityError(e)
          ? 'Se requiere conexión a internet para crear usuarios.'
          : 'Error al crear usuario: $e';
      return null;
    }
  }

  Future<bool> updateUser({
    required String userId,
    String? nombre,
    String? correo,
    String? password,
    String? rol,
    List<String>? roles,
    String? matricula,
    String? numeroEmpleado,
    String? grupo,
    String? grupoId,
    int? activo,
    String? estatus,
  }) async {
    lastError = null;
    try {
      final response = await _client.put(
        '/users/$userId',
        body: {
          if (nombre != null) 'nombre': nombre,
          if (correo != null) 'correo': correo,
          if (password != null && password.isNotEmpty) 'password': password,
          if (rol != null) 'rol': rol,
          if (roles != null && roles.isNotEmpty) 'roles': roles,
          if (matricula != null) 'matricula': matricula,
          if (numeroEmpleado != null) 'numeroEmpleado': numeroEmpleado,
          if (grupo != null) 'grupo': grupo,
          if (grupoId != null && grupoId.isNotEmpty) 'grupoId': grupoId,
          if (activo != null) 'activo': activo,
          if (estatus != null) 'estatus': estatus,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _cache.invalidatePrefix('users_');
        await _cache.removeKey('user_$userId');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(
        response,
        fallback: 'Error al actualizar el usuario.',
      );
      return false;
    } catch (e) {
      debugPrint('Error en updateUser: $e');
      lastError = ApiClient.isConnectivityError(e)
          ? 'Se requiere conexión a internet para actualizar usuarios.'
          : 'Error al actualizar: $e';
      return false;
    }
  }

  Future<bool> updateUserRoles(String userId, List<String> roles) async {
    lastError = null;
    try {
      final response = await _client.put(
        '/users/$userId/roles',
        body: {'roles': roles},
      );
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('users_');
        await _cache.removeKey('user_$userId');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      lastError = 'No se pudieron actualizar los roles: $e';
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    lastError = null;
    try {
      final response = await _client.delete('/users/$userId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _cache.invalidatePrefix('users_');
        await _cache.removeKey('user_$userId');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      debugPrint('Error en deleteUser: $e');
      lastError = ApiClient.isConnectivityError(e)
          ? 'Se requiere conexión a internet para eliminar/desactivar.'
          : 'Error al eliminar usuario: $e';
      return false;
    }
  }

  // ─── QR DINÁMICO (NUNCA SE CACHEA) ───────────────────────────────────────

  Future<Map<String, dynamic>?> generateNewQRUser(
    String userId, {
    int duracionMinutos = 3,
  }) async {
    lastError = null;
    try {
      final response = await _client.post(
        '/qr/generate',
        body: {'userId': userId, 'duracionMinutos': duracionMinutos},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(
        response,
        fallback: 'No se pudo generar el QR dinámico.',
      );
      return null;
    } catch (e) {
      debugPrint('Error en generateNewQRUser: $e');
      lastError = ApiClient.isConnectivityError(e)
          ? 'Se requiere conexión a internet para emitir tu código QR dinámico.'
          : 'Error al generar QR: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> generateClaseQr({
    required String claseId,
    String? reservacionId,
    int usosMaximos = 60,
    int duracionMinutos = 30,
  }) async {
    lastError = null;
    try {
      final response = await _client.post(
        '/qr/clase',
        body: {
          'claseId': claseId,
          if (reservacionId != null && reservacionId.isNotEmpty)
            'reservacionId': reservacionId,
          'usosMaximos': usosMaximos,
          'duracionMinutos': duracionMinutos,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(
        response,
        fallback: 'No se pudo generar el QR de clase.',
      );
      return null;
    } catch (e) {
      lastError = ApiClient.isConnectivityError(e)
          ? 'Se requiere conexión para generar el QR de asistencia de clase.'
          : 'Error generando QR de clase: $e';
      return null;
    }
  }

  Future<bool> marcarQRUserComoUsado(String qrCode) async {
    try {
      final response = await _client.post(
        '/qr/mark-used',
        body: {'codigo': qrCode},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error en marcarQRUserComoUsado: $e');
      return false;
    }
  }

  // ─── ACCESOS (ENTRADAS / SALIDAS / DENEGADOS) ────────────────────────────

  Future<List<Map<String, dynamic>>> getAccess({
    String? userId,
    String? zoneId,
    String? tipo,
    int limit = 200,
  }) async {
    final params = <String>['limit=$limit'];
    if (userId != null && userId.isNotEmpty) {
      params.add('userId=${Uri.encodeQueryComponent(userId)}');
    }
    if (zoneId != null && zoneId.isNotEmpty) {
      params.add('zoneId=${Uri.encodeQueryComponent(zoneId)}');
    }
    if (tipo != null && tipo.isNotEmpty) {
      params.add('tipo=${Uri.encodeQueryComponent(tipo)}');
    }
    final query = params.join('&');
    return _getWithOfflineCache<List<Map<String, dynamic>>>(
      cacheKey: 'access_$query',
      path: '/access?$query',
      parser: _asMapList,
      fallback: const [],
    );
  }

  Future<List<Map<String, dynamic>>> getAllAccess() => getAccess();

  Future<List<Map<String, dynamic>>> getAccessByUserId(String userId) =>
      getAccess(userId: userId);

  Future<List<Map<String, dynamic>>> getAccessByZoneId(String zoneId) =>
      getAccess(zoneId: zoneId);

  Future<List<Map<String, dynamic>>> getAccessByType(String tipo) =>
      getAccess(tipo: tipo);

  // ─── ACADÉMICO Y ASISTENCIAS ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGruposByTutor(String tutorId) =>
      _getWithOfflineCache(
        cacheKey: 'acad_tutor_grupos_$tutorId',
        path: '/academico/tutores/$tutorId/grupos',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getMateriasByGrupo(String grupo) =>
      getMateriasByGrupoConProfesor(grupo);

  Future<List<Map<String, dynamic>>> getMateriasByGrupoConProfesor(
          String grupo) =>
      _getWithOfflineCache(
        cacheKey: 'acad_grupo_materias_$grupo',
        path: '/academico/grupos/${Uri.encodeComponent(grupo)}/materias',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getMateriasByProfesor(
          String profesorId) =>
      _getWithOfflineCache(
        cacheKey: 'acad_prof_materias_$profesorId',
        path: '/academico/profesores/$profesorId/materias',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getGruposByMateria(String materiaId) =>
      _getWithOfflineCache(
        cacheKey: 'acad_mat_grupos_$materiaId',
        path: '/academico/materias/$materiaId/grupos',
        parser: _asMapList,
        fallback: const [],
      );

  Future<Map<String, dynamic>?> getDatosEstudiante(String userId) =>
      _getWithOfflineCache<Map<String, dynamic>?>(
        cacheKey: 'acad_est_datos_$userId',
        path: '/academico/estudiantes/$userId/datos',
        parser: (d) => d is Map ? Map<String, dynamic>.from(d) : null,
        fallback: null,
      );

  Future<Map<String, dynamic>> getAsistenciasTabla(String claseId) async {
    return _getWithOfflineCache<Map<String, dynamic>>(
      cacheKey: 'acad_tabla_$claseId',
      path: '/academico/clases/$claseId/asistencias-tabla',
      parser: (raw) {
        if (raw is! Map) {
          return {
            'alumnos': [],
            'fechas': <String>[],
            'asistencias': <String, Map<String, String>>{},
          };
        }
        final data = Map<String, dynamic>.from(raw);
        final rawAsistencias =
            (data['asistencias'] as Map?) ?? const <String, dynamic>{};
        final Map<String, Map<String, String>> typedAsistencias = {};
        rawAsistencias.forEach((uid, mapVal) {
          if (mapVal is Map) {
            typedAsistencias[uid.toString()] = mapVal.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
          }
        });
        return {
          'alumnos': List<Map<String, dynamic>>.from(
            (data['alumnos'] as List? ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map)),
          ),
          'fechas': List<String>.from(data['fechas'] ?? const []),
          'asistencias': typedAsistencias,
        };
      },
      fallback: {
        'alumnos': [],
        'fechas': <String>[],
        'asistencias': <String, Map<String, String>>{},
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAlumnosConAsistenciaByGrupoYMateria(
    String grupo,
    String materiaId,
  ) =>
      _getWithOfflineCache(
        cacheKey: 'acad_alumnos_${grupo}_$materiaId',
        path:
            '/academico/grupos/${Uri.encodeComponent(grupo)}/materias/$materiaId/alumnos-asistencia',
        parser: _asMapList,
        fallback: const [],
      );

  Future<Map<String, int>> getEstadisticasAsistencia(
      String userId, String claseId) {
    return _getWithOfflineCache<Map<String, int>>(
      cacheKey: 'acad_stats_${userId}_$claseId',
      path: '/academico/alumnos/$userId/clases/$claseId/estadisticas',
      parser: (d) {
        final data = d as Map;
        return {
          'total': (data['total'] as num?)?.toInt() ?? 0,
          'presentes': (data['presentes'] as num?)?.toInt() ?? 0,
          'faltas': (data['faltas'] as num?)?.toInt() ?? 0,
          'retardos': (data['retardos'] as num?)?.toInt() ?? 0,
          'justificados': (data['justificados'] as num?)?.toInt() ?? 0,
        };
      },
      fallback: const {
        'total': 0,
        'presentes': 0,
        'faltas': 0,
        'retardos': 0,
        'justificados': 0,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getInasistenciasByAlumnoYMateria(
          String userId, String claseId) =>
      _getWithOfflineCache(
        cacheKey: 'acad_inasist_${userId}_$claseId',
        path: '/academico/alumnos/$userId/clases/$claseId/inasistencias',
        parser: _asMapList,
        fallback: const [],
      );

  Future<Map<String, dynamic>> getDatosPrediccionAlumno(
      String userId, String claseId) {
    return _getWithOfflineCache<Map<String, dynamic>>(
      cacheKey: 'acad_pred_${userId}_$claseId',
      path: '/academico/alumnos/$userId/clases/$claseId/prediccion',
      parser: (raw) {
        final data = Map<String, dynamic>.from(raw as Map);
        if (data['success'] == true) {
          final rawEst =
              (data['estadisticas'] as Map<String, dynamic>?) ?? {};
          final rawPatron =
              (data['patronSemanal'] as Map<String, dynamic>?) ?? {};
          final Map<String, double> patronSemanal = {};
          rawPatron.forEach((k, v) {
            patronSemanal[k] = (v as num?)?.toDouble() ?? 0.0;
          });

          return {
            'success': true,
            'alumno': data['alumno'],
            'fechas': List<String>.from(data['fechas'] ?? const []),
            'asistencias': List<String>.from(data['asistencias'] ?? const []),
            'estadisticas': {
              'totalClases': (rawEst['totalClases'] as num?)?.toInt() ?? 0,
              'totalPresentes':
                  (rawEst['totalPresentes'] as num?)?.toInt() ?? 0,
              'totalFaltas': (rawEst['totalFaltas'] as num?)?.toInt() ?? 0,
              'porcentajeAsistencia':
                  (rawEst['porcentajeAsistencia'] as num?)?.toDouble() ?? 0.0,
              'rachaActual': (rawEst['rachaActual'] as num?)?.toInt() ?? 0,
              'mejorRacha': (rawEst['mejorRacha'] as num?)?.toInt() ?? 0,
              'tendencia':
                  rawEst['tendencia']?.toString() ?? 'Sin suficientes datos',
            },
            'patronSemanal': patronSemanal,
          };
        }
        return data;
      },
      fallback: const {
        'success': false,
        'message': 'Sin conexión para obtener predicción',
      },
    );
  }

  /// Actualiza asistencia manual; si no hay red la encola en el Outbox FIFO.
  Future<bool> updateAsistencia(
    String materiaId,
    String userId,
    String fecha,
    String nuevoEstado, {
    bool? primeraPasada,
    bool? segundaPasada,
  }) async {
    lastError = null;
    lastMutationQueuedOffline = false;
    final body = <String, dynamic>{
      'materiaId': materiaId,
      'userId': userId,
      'fecha': fecha,
      'nuevoEstado': nuevoEstado,
      if (primeraPasada != null) 'primeraPasada': primeraPasada,
      if (segundaPasada != null) 'segundaPasada': segundaPasada,
    };

    try {
      final response = await _client.patch('/academico/asistencias', body: body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _cache.invalidatePrefix('acad_');
        return true;
      }
      final msg = ApiClient.extractErrorMessage(
        response,
        fallback: 'Error al actualizar asistencia',
      );
      lastError = msg;
      throw Exception(msg);
    } catch (e) {
      if (ApiClient.isConnectivityError(e) ||
          !ConnectivityService().isOnline.value) {
        await _queue.enqueue(
          method: 'PATCH',
          path: '/academico/asistencias',
          body: body,
          description: 'Asistencia ($fecha: $nuevoEstado)',
          dedupeKey: 'asist_${materiaId}_${userId}_$fecha',
          invalidatePrefixes: const ['acad_'],
        );
        lastMutationQueuedOffline = true;
        return false;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> crearMateria({
    String? codigo,
    required String nombre,
    String? profesorTitularId,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/academico/materias',
        body: {
          if (codigo != null && codigo.trim().isNotEmpty) 'codigo': codigo.trim(),
          'nombre': nombre.trim(),
          if (profesorTitularId != null && profesorTitularId.isNotEmpty)
            'profesorTitularId': profesorTitularId,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('acad_');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'No se pudo crear la materia: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> crearClase({
    required String materiaId,
    required String grupoId,
    required String profesorId,
    String? periodoId,
    String? codigo,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/academico/clases',
        body: {
          'materiaId': materiaId,
          'grupoId': grupoId,
          'profesorId': profesorId,
          if (periodoId != null && periodoId.isNotEmpty) 'periodoId': periodoId,
          if (codigo != null && codigo.trim().isNotEmpty) 'codigo': codigo.trim(),
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('acad_');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'No se pudo crear la clase: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> crearHorarioClase({
    required String claseId,
    String? salonId,
    required int diaSemana,
    required String horaInicio,
    required String horaFin,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/academico/horarios',
        body: {
          'claseId': claseId,
          if (salonId != null && salonId.isNotEmpty) 'salonId': salonId,
          'diaSemana': diaSemana,
          'horaInicio': horaInicio,
          'horaFin': horaFin,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('acad_');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'No se pudo crear el horario: $e';
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getHorariosClase(String claseId) =>
      _getWithOfflineCache(
        cacheKey: 'acad_horarios_$claseId',
        path: '/academico/clases/$claseId/horarios',
        parser: _asMapList,
        fallback: const [],
      );

  Future<bool> inscribirAlumnoClase({
    required String alumnoId,
    required String claseId,
    String estatus = 'inscrito',
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/academico/inscripciones',
        body: {
          'alumnoId': alumnoId,
          'claseId': claseId,
          'estatus': estatus,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('acad_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return false;
    } catch (e) {
      lastError = 'No se pudo inscribir al alumno: $e';
      return false;
    }
  }

  Future<bool> asignarTutorGrupo({
    required String tutorId,
    required String grupoId,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/academico/tutores',
        body: {'tutorId': tutorId, 'grupoId': grupoId},
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('acad_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return false;
    } catch (e) {
      lastError = 'No se pudo asignar el tutor: $e';
      return false;
    }
  }

  // ─── JUSTIFICANTES (MAESTRO-DETALLE V2 + R2) ──────────────────────────────

  Future<String?> uploadJustificanteImage(
    List<int> fileBytes,
    String fileName,
    String userId,
  ) async {
    lastError = null;
    try {
      final response = await _client.uploadFile(
        '/justificantes/upload',
        fileBytes: fileBytes,
        fileName: fileName,
        fields: {'userId': userId},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['url'] as String?;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return null;
    } catch (e) {
      debugPrint('Error en uploadJustificanteImage: $e');
      lastError = 'Error al subir evidencia: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> crearJustificanteGeneral({
    required String userId,
    required String titulo,
    required String asunto,
    required List<String> fechasFaltas,
    required List<String> claseIds,
    List<String> imagenesUrls = const [],
  }) async {
    lastError = null;
    try {
      final response = await _client.post(
        '/justificantes/general',
        body: {
          'userId': userId,
          'titulo': titulo,
          'asunto': asunto,
          'fechasFaltas': fechasFaltas,
          'claseIds': claseIds,
          'imagenesUrls': imagenesUrls,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        await _cache.invalidatePrefix('just_');
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(response);
      return null;
    } catch (e) {
      debugPrint('Error en crearJustificanteGeneral: $e');
      lastError = ApiClient.isConnectivityError(e)
          ? 'Se requiere conexión para enviar evidencias y crear justificante.'
          : 'Error al enviar justificante: $e';
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getJustificantesByAlumno(String userId) =>
      _getWithOfflineCache(
        cacheKey: 'just_alumno_$userId',
        path: '/justificantes/alumno/$userId',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getJustificantesByTutor(String tutorId) =>
      _getWithOfflineCache(
        cacheKey: 'just_tutor_$tutorId',
        path: '/justificantes/tutor/$tutorId',
        parser: _asMapList,
        fallback: const [],
      );

  Future<int> contarJustificantesPendientesTutor(String tutorId) =>
      _getWithOfflineCache<int>(
        cacheKey: 'just_tutor_count_$tutorId',
        path: '/justificantes/tutor/$tutorId/pendientes-count',
        parser: (d) => (d['count'] as num?)?.toInt() ?? 0,
        fallback: 0,
      );

  Future<bool> revisarJustificante({
    required String justificanteId,
    required String tutorId,
    required String nuevoEstado,
    String? comentario,
  }) async {
    lastError = null;
    lastMutationQueuedOffline = false;
    final body = {
      'tutorId': tutorId,
      'nuevoEstado': nuevoEstado,
      'comentario': comentario ?? '',
    };
    final path = '/justificantes/$justificanteId/revisar';
    try {
      final response = await _client.patch(path, body: body);
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('just_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      if (ApiClient.isConnectivityError(e) ||
          !ConnectivityService().isOnline.value) {
        await _queue.enqueue(
          method: 'PATCH',
          path: path,
          body: body,
          description: 'Revisión de justificante ($nuevoEstado)',
          dedupeKey: 'just_rev_$justificanteId',
          invalidatePrefixes: const ['just_'],
        );
        lastMutationQueuedOffline = true;
        return true;
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getJustificantesAprobadosByProfesor(
          String profesorId) =>
      _getWithOfflineCache(
        cacheKey: 'just_prof_$profesorId',
        path: '/justificantes/profesor/$profesorId/aprobados',
        parser: _asMapList,
        fallback: const [],
      );

  Future<int> getClaseIdAndCount(String materiaId) =>
      _getWithOfflineCache<int>(
        cacheKey: 'just_mat_count_$materiaId',
        path: '/justificantes/materia/$materiaId/count',
        parser: (d) => (d['count'] as num?)?.toInt() ?? 0,
        fallback: 0,
      );

  Future<bool> aplicarJustificanteGeneral({
    required String justificanteId,
    required String userId,
    required List<String> claseIds,
    required List<String> fechas,
    required bool aceptado,
    String? comentario,
  }) async {
    lastError = null;
    lastMutationQueuedOffline = false;
    final body = {
      'userId': userId,
      'claseIds': claseIds,
      'fechas': fechas,
      'aceptado': aceptado,
      if (comentario != null && comentario.trim().isNotEmpty)
        'comentario': comentario.trim(),
    };
    final path = '/justificantes/$justificanteId/aplicar-general';
    try {
      final response = await _client.post(path, body: body);
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('just_');
        await _cache.invalidatePrefix('acad_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      if (ApiClient.isConnectivityError(e) ||
          !ConnectivityService().isOnline.value) {
        await _queue.enqueue(
          method: 'POST',
          path: path,
          body: body,
          description:
              'Dictamen docente (${aceptado ? "Aplicado" : "No aceptado"})',
          dedupeKey: 'just_prof_$justificanteId',
          invalidatePrefixes: const ['just_', 'acad_'],
        );
        lastMutationQueuedOffline = true;
        return true;
      }
      return false;
    }
  }

  Future<bool> dictaminarDetalleJustificante({
    required String detalleId,
    required String estadoProfesor, // 'aplicado' | 'rechazado'
    String? comentario,
  }) async {
    lastError = null;
    lastMutationQueuedOffline = false;
    final body = {
      'estadoProfesor': estadoProfesor,
      if (comentario != null && comentario.trim().isNotEmpty)
        'comentario': comentario.trim(),
    };
    final path = '/justificantes/detalles/$detalleId/dictaminar';
    try {
      final response = await _client.patch(path, body: body);
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('just_');
        await _cache.invalidatePrefix('acad_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      if (ApiClient.isConnectivityError(e) ||
          !ConnectivityService().isOnline.value) {
        await _queue.enqueue(
          method: 'PATCH',
          path: path,
          body: body,
          description: 'Dictamen detalle ($estadoProfesor)',
          dedupeKey: 'just_det_$detalleId',
          invalidatePrefixes: const ['just_', 'acad_'],
        );
        lastMutationQueuedOffline = true;
        return true;
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFaltasAgrupadasPorFecha(String userId) =>
      _getWithOfflineCache<List<Map<String, dynamic>>>(
        cacheKey: 'just_faltas_grp_$userId',
        path: '/justificantes/alumno/$userId/faltas-agrupadas',
        parser: (rawList) {
          if (rawList is! List) return [];
          return rawList.map<Map<String, dynamic>>((item) {
            final m = item as Map<String, dynamic>;
            return {
              'fecha': m['fecha'] as String? ?? '',
              'materias': List<String>.from(m['materias'] ?? const []),
              'claseIds': List<String>.from(m['claseIds'] ?? const []),
            };
          }).toList();
        },
        fallback: const [],
      );

  // ─── VISITAS ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registrarVisita({
    required String nombre,
    required String correo,
    required String empresa,
    required String cargo,
    required String motivo,
    required String contactoInterno,
    String? contactoInternoId,
    required DateTime fechaVisita,
    String? horaInicio,
    String? horaFin,
    required String registradoPor,
  }) async {
    lastError = null;
    try {
      final response = await _client.post(
        '/visitas',
        body: {
          'nombre': nombre,
          'correo': correo,
          'empresa': empresa,
          'cargo': cargo,
          'motivo': motivo,
          'contactoInterno': contactoInterno,
          if (contactoInternoId != null && contactoInternoId.isNotEmpty)
            'contactoInternoId': contactoInternoId,
          'fechaVisita': fechaVisita.toIso8601String(),
          if (horaInicio != null && horaInicio.isNotEmpty)
            'horaInicio': horaInicio,
          if (horaFin != null && horaFin.isNotEmpty) 'horaFin': horaFin,
          'registradoPor': registradoPor,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _cache.invalidatePrefix('visitas_');
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      final msg = ApiClient.extractErrorMessage(
        response,
        fallback: 'Error al registrar visita',
      );
      lastError = msg;
      return {'success': false, 'message': msg};
    } catch (e) {
      return {
        'success': false,
        'message': ApiClient.isConnectivityError(e)
            ? 'Se requiere conexión a internet para registrar visitas.'
            : 'Error de conexión: $e',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getTodasLasVisitas() =>
      _getWithOfflineCache(
        cacheKey: 'visitas_all',
        path: '/visitas',
        parser: _asMapList,
        fallback: const [],
      );

  Future<int> contarVisitasPendientes() => _getWithOfflineCache<int>(
        cacheKey: 'visitas_pend_count',
        path: '/visitas/pendientes-count',
        parser: (d) => (d['count'] as num?)?.toInt() ?? 0,
        fallback: 0,
      );

  Future<bool> cancelarVisita(String visitaId) async {
    lastError = null;
    try {
      final response = await _client.patch('/visitas/$visitaId/cancelar');
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('visitas_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      lastError = 'No se pudo cancelar la visita: $e';
      return false;
    }
  }

  // ─── SALONES ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSalonesConEstado() =>
      _getWithOfflineCache(
        cacheKey: 'salones_estado_all',
        path: '/salones/estado',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getSalonesLibres() =>
      _getWithOfflineCache(
        cacheKey: 'salones_estado_libres',
        path: '/salones/estado?soloLibres=true',
        parser: _asMapList,
        fallback: const [],
      );

  Future<Map<String, dynamic>?> crearSalon({
    required String numero,
    String? nombre,
    String? edificio,
    String? zoneId,
    int piso = 1,
    int capacidad = 30,
    String tipo = 'aula',
    double posX = 0,
    double posY = 0,
    double ancho = 15,
    double alto = 12,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/salones',
        body: {
          'numero': numero,
          if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
          if (edificio != null && edificio.isNotEmpty) 'edificio': edificio,
          if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
          'piso': piso,
          'capacidad': capacidad,
          'tipo': tipo,
          'posX': posX,
          'posY': posY,
          'ancho': ancho,
          'alto': alto,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('salones_');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'No se pudo crear el salón: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>> reservarSalon({
    required String salonId,
    required String profesorId,
    required String numeroEmpleado,
    required String nombreProfesor,
    required String materia,
    required String motivo,
    String? claseId,
    String tipoUso = 'asesoria',
    int duracionMinutos = 120,
    bool requierePaseLista = false,
  }) async {
    lastError = null;
    try {
      final response = await _client.post(
        '/salones/reservar',
        body: {
          'salonId': salonId,
          'profesorId': profesorId,
          'numeroEmpleado': numeroEmpleado,
          'nombreProfesor': nombreProfesor,
          'materia': materia,
          'motivo': motivo,
          if (claseId != null && claseId.isNotEmpty) 'claseId': claseId,
          'tipoUso': tipoUso,
          'duracionMinutos': duracionMinutos,
          'requierePaseLista': requierePaseLista,
        },
      );
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('salones_');
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      final msg = ApiClient.extractErrorMessage(
        response,
        fallback: 'Error al reservar salón',
      );
      lastError = msg;
      return {'success': false, 'message': msg};
    } catch (e) {
      return {
        'success': false,
        'message': ApiClient.isConnectivityError(e)
            ? 'Se requiere conexión a internet para reservar un salón.'
            : 'Error inesperado: $e',
      };
    }
  }

  Future<bool> checkInSalon(String reservacionId) async {
    lastError = null;
    try {
      final response =
          await _client.patch('/salones/reservaciones/$reservacionId/check-in');
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('salones_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      lastError = 'Error al registrar check-in: $e';
      return false;
    }
  }

  Future<bool> liberarSalon(String reservacionId) async {
    lastError = null;
    try {
      final response =
          await _client.patch('/salones/reservaciones/$reservacionId/liberar');
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('salones_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelarReservacionSalon(String reservacionId) async {
    lastError = null;
    try {
      final response =
          await _client.patch('/salones/reservaciones/$reservacionId/cancelar');
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('salones_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getReservacionesActivasProfesor(
          String profesorId) =>
      _getWithOfflineCache(
        cacheKey: 'salones_prof_$profesorId',
        path: '/salones/profesor/$profesorId/activas',
        parser: _asMapList,
        fallback: const [],
      );

  // ─── ANUNCIOS Y NOTIFICACIONES INTERNAS ───────────────────────────────────

  Future<Map<String, dynamic>?> crearAnuncio({
    required String profesorId,
    String? materiaId,
    String? claseId,
    String? grupo,
    required String titulo,
    required String mensaje,
    String tipo = 'aviso',
  }) async {
    lastError = null;
    try {
      final response = await _client.post(
        '/anuncios',
        body: {
          'profesorId': profesorId,
          if (materiaId != null && materiaId.isNotEmpty) 'materiaId': materiaId,
          if (claseId != null && claseId.isNotEmpty) 'claseId': claseId,
          if (grupo != null && grupo.isNotEmpty) 'grupo': grupo,
          'titulo': titulo,
          'mensaje': mensaje,
          'tipo': tipo,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        await _cache.invalidatePrefix('anuncios_');
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(response);
      return null;
    } catch (e) {
      lastError = 'No se pudo conectar con el servidor';
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAnunciosByProfesor(
    String profesorId, {
    String? materiaId,
    String? claseId,
    String? grupo,
    String? tipo,
  }) {
    final params = <String, String>{};
    if (materiaId != null && materiaId.isNotEmpty) {
      params['materiaId'] = materiaId;
    }
    if (claseId != null && claseId.isNotEmpty) {
      params['claseId'] = claseId;
    }
    if (grupo != null && grupo.isNotEmpty) {
      params['grupo'] = grupo;
    }
    if (tipo != null && tipo.isNotEmpty) {
      params['tipo'] = tipo;
    }
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    return _getWithOfflineCache(
      cacheKey:
          'anuncios_profesor_${profesorId}_${materiaId ?? ''}_${claseId ?? ''}_${grupo ?? ''}_${tipo ?? ''}',
      path: '/anuncios/profesor/$profesorId$query',
      parser: _asMapList,
      fallback: const [],
    );
  }

  Future<Map<String, dynamic>?> actualizarAnuncio({
    required String anuncioId,
    required String titulo,
    required String mensaje,
    required String tipo,
    String? materiaId,
    String? claseId,
    String? grupo,
  }) async {
    lastError = null;
    try {
      final response = await _client.put(
        '/anuncios/$anuncioId',
        body: {
          'titulo': titulo,
          'mensaje': mensaje,
          'tipo': tipo,
          if (materiaId != null) 'materiaId': materiaId,
          if (claseId != null) 'claseId': claseId,
          if (grupo != null) 'grupo': grupo,
        },
      );
      if (response.statusCode == 200) {
        await _cache.invalidatePrefix('anuncios_');
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(response);
      return null;
    } catch (e) {
      lastError = 'No se pudo conectar con el servidor';
      return null;
    }
  }

  Future<bool> eliminarAnuncio(String anuncioId) async {
    lastError = null;
    try {
      final response = await _client.delete('/anuncios/$anuncioId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _cache.invalidatePrefix('anuncios_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(response);
      return false;
    } catch (e) {
      lastError = 'No se pudo conectar con el servidor';
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAnunciosByAlumno(String userId) =>
      _getWithOfflineCache(
        cacheKey: 'anuncios_alumno_$userId',
        path: '/anuncios/alumno/$userId',
        parser: _asMapList,
        fallback: const [],
      );

  Future<int> contarAnunciosNoLeidos(String userId) =>
      _getWithOfflineCache<int>(
        cacheKey: 'anuncios_count_$userId',
        path: '/anuncios/alumno/$userId/no-leidos-count',
        parser: (d) => (d['count'] as num?)?.toInt() ?? 0,
        fallback: 0,
      );

  Future<void> marcarAnuncioLeido(String anuncioId, String userId) async {
    final path = '/anuncios/$anuncioId/leido';
    final body = {'userId': userId};
    try {
      await _client.post(path, body: body);
      await _cache.invalidatePrefix('anuncios_');
    } catch (e) {
      if (ApiClient.isConnectivityError(e) ||
          !ConnectivityService().isOnline.value) {
        await _queue.enqueue(
          method: 'POST',
          path: path,
          body: body,
          description: 'Marcar aviso leído',
          dedupeKey: 'anuncio_leido_${anuncioId}_$userId',
          invalidatePrefixes: const ['anuncios_'],
        );
      }
      debugPrint('Error en marcarAnuncioLeido: $e');
    }
  }

  Future<void> guardarFCMToken(String userId, String token) async {
    if (!ApiConfig.enablePushNotifications) return;
    try {
      await _client.post(
        '/anuncios/fcm-token',
        body: {'userId': userId, 'token': token},
      );
    } catch (e) {
      debugPrint('Error en guardarFCMToken: $e');
    }
  }

  Future<void> eliminarFCMToken(String userId) async {
    if (!ApiConfig.enablePushNotifications) return;
    try {
      await _client.delete('/anuncios/fcm-token/$userId');
    } catch (e) {
      debugPrint('Error en eliminarFCMToken: $e');
    }
  }

  Future<List<String>> obtenerTokensAlumnos({
    required String materiaId,
    String? grupo,
  }) async {
    if (!ApiConfig.enablePushNotifications) return [];
    try {
      var query = 'materiaId=${Uri.encodeQueryComponent(materiaId)}';
      if (grupo != null && grupo.isNotEmpty) {
        query += '&grupo=${Uri.encodeQueryComponent(grupo)}';
      }
      final response = await _client.get('/anuncios/tokens?$query');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<String>.from(data['tokens'] ?? const []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> enviarNotificacionPush({
    required String titulo,
    required String cuerpo,
    required List<String> tokens,
    Map<String, dynamic>? data,
  }) async {
    if (!ApiConfig.enablePushNotifications) return false;
    try {
      if (tokens.isEmpty) return false;
      final response = await _client.post(
        '/anuncios/enviar-push',
        body: {
          'titulo': titulo,
          'cuerpo': cuerpo,
          'tokens': tokens,
          'data': data?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ?? {},
        },
      );
      if (response.statusCode == 200) {
        final respData = jsonDecode(response.body) as Map<String, dynamic>;
        return respData['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─── NOTICIAS INSTITUCIONALES (MARKETING + FEED) ──────────────────────────

  Future<String?> uploadNoticiaImagen(
      List<int> fileBytes, String fileName) async {
    lastError = null;
    try {
      final resp = await _client.uploadFile(
        '/noticias/upload',
        fileBytes: fileBytes,
        fileName: fileName,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['url']?.toString();
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'Error al subir imagen de noticia: $e';
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getNoticias({
    String? categoria,
    bool incluirBorradores = false,
  }) {
    final params = <String>['incluirBorradores=$incluirBorradores'];
    if (categoria != null && categoria.trim().isNotEmpty) {
      params.add('categoria=${Uri.encodeQueryComponent(categoria.trim())}');
    }
    final q = params.join('&');
    return _getWithOfflineCache(
      cacheKey: 'noticias_$q',
      path: '/noticias?$q',
      parser: _asMapList,
      fallback: const [],
    );
  }

  Future<Map<String, dynamic>?> crearNoticia({
    required String titulo,
    required String contenido,
    String? imagenUrl,
    String categoria = 'General',
    bool activo = true,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/noticias',
        body: {
          'titulo': titulo,
          'contenido': contenido,
          if (imagenUrl != null && imagenUrl.isNotEmpty) 'imagenUrl': imagenUrl,
          'categoria': categoria,
          'activo': activo,
          if (activo) 'fechaPublicacion': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('noticias_');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'No se pudo publicar la noticia: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> actualizarNoticia({
    required String id,
    required String titulo,
    required String contenido,
    String? imagenUrl,
    String categoria = 'General',
    bool activo = true,
  }) async {
    lastError = null;
    try {
      final resp = await _client.put(
        '/noticias/$id',
        body: {
          'titulo': titulo,
          'contenido': contenido,
          if (imagenUrl != null && imagenUrl.isNotEmpty) 'imagenUrl': imagenUrl,
          'categoria': categoria,
          'activo': activo,
        },
      );
      if (resp.statusCode == 200) {
        await _cache.invalidatePrefix('noticias_');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'No se pudo actualizar la noticia: $e';
      return null;
    }
  }

  Future<bool> eliminarNoticia(String id) async {
    lastError = null;
    try {
      final resp = await _client.delete('/noticias/$id');
      if (resp.statusCode == 200) {
        await _cache.invalidatePrefix('noticias_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return false;
    } catch (e) {
      lastError = 'No se pudo eliminar la noticia: $e';
      return false;
    }
  }

  // ─── CATÁLOGOS E INFRAESTRUCTURA ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRolesCatalogo() => _getWithOfflineCache(
        cacheKey: 'cat_roles',
        path: '/catalogos/roles',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getPeriodos() => _getWithOfflineCache(
        cacheKey: 'cat_periodos',
        path: '/catalogos/periodos',
        parser: _asMapList,
        fallback: const [],
      );

  Future<Map<String, dynamic>?> crearPeriodo({
    required String codigo,
    required String nombre,
    required String fechaInicio, // yyyy-MM-dd
    required String fechaFin, // yyyy-MM-dd
    bool activo = false,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/catalogos/periodos',
        body: {
          'codigo': codigo,
          'nombre': nombre,
          'fechaInicio': fechaInicio,
          'fechaFin': fechaFin,
          'activo': activo,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('cat_');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'Error al crear periodo: $e';
      return null;
    }
  }

  Future<bool> activarPeriodo(String id) async {
    lastError = null;
    try {
      final resp = await _client.patch('/catalogos/periodos/$id/activar');
      if (resp.statusCode == 200) {
        await _cache.invalidatePrefix('cat_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getGruposCatalogo({String? periodoId}) {
    final q = periodoId != null && periodoId.isNotEmpty
        ? '?periodoId=${Uri.encodeQueryComponent(periodoId)}'
        : '';
    return _getWithOfflineCache(
      cacheKey: 'cat_grupos_$q',
      path: '/catalogos/grupos$q',
      parser: _asMapList,
      fallback: const [],
    );
  }

  Future<Map<String, dynamic>?> crearGrupoCatalogo({
    required String codigo,
    String? carrera,
    String? periodoId,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/catalogos/grupos',
        body: {
          'codigo': codigo,
          if (carrera != null && carrera.trim().isNotEmpty)
            'carrera': carrera.trim(),
          if (periodoId != null && periodoId.isNotEmpty) 'periodoId': periodoId,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('cat_grupos');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'Error al crear grupo: $e';
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getZonas() => _getWithOfflineCache(
        cacheKey: 'cat_zones',
        path: '/catalogos/zones',
        parser: _asMapList,
        fallback: const [],
      );

  Future<Map<String, dynamic>?> crearZona({
    required String codigo,
    required String nombre,
    String? descripcion,
    String tipo = 'acceso_general',
    bool permiteVisitas = false,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/catalogos/zones',
        body: {
          'codigo': codigo,
          'nombre': nombre,
          if (descripcion != null && descripcion.isNotEmpty)
            'descripcion': descripcion,
          'tipo': tipo,
          'permiteVisitas': permiteVisitas,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('cat_zones');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'Error al crear zona: $e';
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPermisosZona(String zoneId) =>
      _getWithOfflineCache(
        cacheKey: 'cat_zone_perm_$zoneId',
        path: '/catalogos/zones/$zoneId/permisos',
        parser: _asMapList,
        fallback: const [],
      );

  Future<bool> upsertPermisoZona({
    required String zoneId,
    required String rolCodigo,
    String? horaInicio,
    String? horaFin,
    bool activo = true,
  }) async {
    lastError = null;
    try {
      final resp = await _client.put(
        '/catalogos/zones/$zoneId/permisos',
        body: {
          'rolCodigo': rolCodigo,
          if (horaInicio != null && horaInicio.isNotEmpty)
            'horaInicio': horaInicio,
          if (horaFin != null && horaFin.isNotEmpty) 'horaFin': horaFin,
          'activo': activo,
        },
      );
      if (resp.statusCode == 200) {
        await _cache.invalidatePrefix('cat_zone_perm_$zoneId');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return false;
    } catch (e) {
      lastError = 'Error al actualizar permiso de zona: $e';
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDispositivosIot() =>
      _getWithOfflineCache(
        cacheKey: 'cat_iot_devices',
        path: '/catalogos/dispositivos-iot',
        parser: _asMapList,
        fallback: const [],
      );

  Future<Map<String, dynamic>?> crearDispositivoIot({
    required String codigoDispositivo,
    required String nombre,
    required String zoneId,
    String? salonId,
    String direccion = 'ambos',
    bool generarApiKeyIndividual = true,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/catalogos/dispositivos-iot',
        body: {
          'codigoDispositivo': codigoDispositivo,
          'nombre': nombre,
          'zoneId': zoneId,
          if (salonId != null && salonId.isNotEmpty) 'salonId': salonId,
          'direccion': direccion,
          'generarApiKeyIndividual': generarApiKeyIndividual,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('cat_iot_devices');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'Error al registrar lector IoT: $e';
      return null;
    }
  }

  // ─── CALIFICACIONES Y SINCRONIZACIÓN LIZARD ───────────────────────────────

  Future<bool> upsertCalificacion({
    required String alumnoId,
    required String claseId,
    required int parcial,
    double? calificacion,
    required String nivel, // NA | SA | DE | AU
    String? comentario,
  }) async {
    lastError = null;
    lastMutationQueuedOffline = false;
    final body = {
      'alumnoId': alumnoId,
      'claseId': claseId,
      'parcial': parcial,
      if (calificacion != null) 'calificacion': calificacion,
      'nivel': nivel,
      if (comentario != null && comentario.trim().isNotEmpty)
        'comentario': comentario.trim(),
    };
    try {
      final resp = await _client.post('/calificaciones', body: body);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await _cache.invalidatePrefix('calif_');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return false;
    } catch (e) {
      if (ApiClient.isConnectivityError(e) ||
          !ConnectivityService().isOnline.value) {
        await _queue.enqueue(
          method: 'POST',
          path: '/calificaciones',
          body: body,
          description: 'Calificación P$parcial ($nivel)',
          dedupeKey: 'calif_${alumnoId}_${claseId}_$parcial',
          invalidatePrefixes: const ['calif_'],
        );
        lastMutationQueuedOffline = true;
        return true;
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCalificacionesByClase(String claseId) =>
      _getWithOfflineCache(
        cacheKey: 'calif_clase_$claseId',
        path: '/calificaciones/clases/$claseId',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getKardexAlumno(String alumnoId) =>
      _getWithOfflineCache(
        cacheKey: 'calif_kardex_$alumnoId',
        path: '/calificaciones/kardex/$alumnoId',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getPendientesLizard() =>
      _getWithOfflineCache(
        cacheKey: 'calif_lizard_pendientes',
        path: '/calificaciones/lizard/pendientes',
        parser: _asMapList,
        fallback: const [],
      );

  Future<int> confirmarSincronizacionLizard(List<String> calificacionIds) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/calificaciones/lizard/confirmar',
        body: {'calificacionIds': calificacionIds},
      );
      if (resp.statusCode == 200) {
        await _cache.invalidatePrefix('calif_');
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['updated'] as num?)?.toInt() ?? 0;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return 0;
    } catch (e) {
      lastError = 'Error confirmando sincronización Lizard: $e';
      return 0;
    }
  }

  // ─── PSICOLOGÍA (AGENDA + EXPEDIENTE CONFIDENCIAL NO CACHEADO) ────────────

  Future<List<Map<String, dynamic>>> getDisponibilidadPsicologos() =>
      _getWithOfflineCache(
        cacheKey: 'psi_disponibilidad',
        path: '/psicologia/disponibilidad',
        parser: _asMapList,
        fallback: const [],
      );

  Future<Map<String, dynamic>?> crearDisponibilidadPsicologo({
    String? psicologoId,
    required int diaSemana,
    required String horaInicio,
    required String horaFin,
    bool activo = true,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/psicologia/disponibilidad',
        body: {
          if (psicologoId != null && psicologoId.isNotEmpty)
            'psicologoId': psicologoId,
          'diaSemana': diaSemana,
          'horaInicio': horaInicio,
          'horaFin': horaFin,
          'activo': activo,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('psi_disponibilidad');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'No se pudo agregar horario: $e';
      return null;
    }
  }

  Future<bool> eliminarDisponibilidadPsicologo(String id) async {
    lastError = null;
    try {
      final resp = await _client.delete('/psicologia/disponibilidad/$id');
      if (resp.statusCode == 200) {
        await _cache.invalidatePrefix('psi_disponibilidad');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> agendarCitaPsicologica({
    String? alumnoId,
    required String psicologoId,
    required String fecha, // yyyy-MM-dd
    required String horaInicio, // HH:mm
    required String horaFin, // HH:mm
    String? motivo,
    String? citaOrigenId,
    bool fueraHorarioAutorizado = false,
  }) async {
    lastError = null;
    try {
      final resp = await _client.post(
        '/psicologia/citas',
        body: {
          if (alumnoId != null && alumnoId.isNotEmpty) 'alumnoId': alumnoId,
          'psicologoId': psicologoId,
          'fecha': fecha,
          'horaInicio': horaInicio,
          'horaFin': horaFin,
          if (motivo != null && motivo.trim().isNotEmpty)
            'motivo': motivo.trim(),
          if (citaOrigenId != null && citaOrigenId.isNotEmpty)
            'citaOrigenId': citaOrigenId,
          'fueraHorarioAutorizado': fueraHorarioAutorizado,
        },
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        await _cache.invalidatePrefix('psi_citas');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = ApiClient.isConnectivityError(e)
          ? 'Se requiere conexión a internet para agendar una cita.'
          : 'Error al agendar cita: $e';
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCitasAlumno(String alumnoId) =>
      _getWithOfflineCache(
        cacheKey: 'psi_citas_alumno_$alumnoId',
        path: '/psicologia/citas/alumno/$alumnoId',
        parser: _asMapList,
        fallback: const [],
      );

  Future<List<Map<String, dynamic>>> getAgendaPsicologo(String psicologoId) =>
      _getWithOfflineCache(
        cacheKey: 'psi_citas_agenda_$psicologoId',
        path: '/psicologia/citas/psicologo/$psicologoId',
        parser: _asMapList,
        fallback: const [],
      );

  Future<bool> actualizarEstadoCita({
    required String citaId,
    required String estado, // agendada | completada | cancelada | no_asistio
    String? motivoCancelacion,
  }) async {
    lastError = null;
    try {
      final resp = await _client.patch(
        '/psicologia/citas/$citaId/estado',
        body: {
          'estado': estado,
          if (motivoCancelacion != null && motivoCancelacion.trim().isNotEmpty)
            'motivoCancelacion': motivoCancelacion.trim(),
        },
      );
      if (resp.statusCode == 200) {
        await _cache.invalidatePrefix('psi_citas');
        return true;
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return false;
    } catch (e) {
      lastError = 'Error al actualizar estado de cita: $e';
      return false;
    }
  }

  /// Notas clínicas confidenciales: NUNCA se guardan en caché offline.
  Future<Map<String, dynamic>?> getNotaClinica(String citaId) async {
    lastError = null;
    try {
      final resp = await _client.get('/psicologia/citas/$citaId/notas');
      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      if (resp.statusCode != 404) {
        lastError = ApiClient.extractErrorMessage(resp);
      }
      return null;
    } catch (e) {
      lastError = ApiClient.isConnectivityError(e)
          ? 'Se requiere conexión segura para consultar el expediente clínico.'
          : 'Error consultando nota clínica: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> upsertNotaClinica({
    required String citaId,
    required String notasClinicas,
    String? acuerdosSeguimiento,
    String nivelRiesgo = 'bajo',
  }) async {
    lastError = null;
    try {
      final resp = await _client.put(
        '/psicologia/citas/$citaId/notas',
        body: {
          'notasClinicas': notasClinicas,
          if (acuerdosSeguimiento != null &&
              acuerdosSeguimiento.trim().isNotEmpty)
            'acuerdosSeguimiento': acuerdosSeguimiento.trim(),
          'nivelRiesgo': nivelRiesgo,
        },
      );
      if (resp.statusCode == 200) {
        await _cache.invalidatePrefix('psi_citas_agenda');
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return null;
    } catch (e) {
      lastError = 'No se pudo guardar la nota clínica: $e';
      return null;
    }
  }

  // ─── REPORTES Y AUDITORÍA ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> exportarReporteAsistencias({
    String? periodo,
    String? grupo,
    String? desde,
    String? hasta,
  }) async {
    lastError = null;
    final params = <String>[];
    if (periodo != null && periodo.isNotEmpty) {
      params.add('periodo=${Uri.encodeQueryComponent(periodo)}');
    }
    if (grupo != null && grupo.isNotEmpty) {
      params.add('grupo=${Uri.encodeQueryComponent(grupo)}');
    }
    if (desde != null && desde.isNotEmpty) {
      params.add('desde=${Uri.encodeQueryComponent(desde)}');
    }
    if (hasta != null && hasta.isNotEmpty) {
      params.add('hasta=${Uri.encodeQueryComponent(hasta)}');
    }
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    try {
      final resp = await _client.get('/reportes/asistencias$q');
      if (resp.statusCode == 200) {
        return _asMapList(jsonDecode(resp.body));
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return [];
    } catch (e) {
      lastError = 'Error exportando reporte de asistencias: $e';
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> exportarReporteAccesos({
    String? desde,
    String? hasta,
    String? tipo,
  }) async {
    lastError = null;
    final params = <String>[];
    if (desde != null && desde.isNotEmpty) {
      params.add('desde=${Uri.encodeQueryComponent(desde)}');
    }
    if (hasta != null && hasta.isNotEmpty) {
      params.add('hasta=${Uri.encodeQueryComponent(hasta)}');
    }
    if (tipo != null && tipo.isNotEmpty) {
      params.add('tipo=${Uri.encodeQueryComponent(tipo)}');
    }
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    try {
      final resp = await _client.get('/reportes/accesos$q');
      if (resp.statusCode == 200) {
        return _asMapList(jsonDecode(resp.body));
      }
      lastError = ApiClient.extractErrorMessage(resp);
      return [];
    } catch (e) {
      lastError = 'Error exportando reporte de accesos: $e';
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBitacoraAuditoria() =>
      _getWithOfflineCache(
        cacheKey: 'rep_auditoria',
        path: '/reportes/auditoria',
        parser: _asMapList,
        fallback: const [],
      );
}

import 'dart:convert';
import 'dart:io';
import 'package:acceso/main.dart';
import 'package:acceso/navigation/role_router.dart';
import 'package:acceso/screens/admin_panel_screen.dart';
import 'package:acceso/screens/admin_screen.dart';
import 'package:acceso/screens/alumnos.dart';
import 'package:acceso/screens/homeprofesor.dart';
import 'package:acceso/screens/noticias_screen.dart';
import 'package:acceso/screens/psicologia_screens.dart';
import 'package:acceso/screens/seguridad_screen.dart';
import 'package:acceso/service/api_client.dart';
import 'package:acceso/service/offline_cache_service.dart';
import 'package:acceso/service/offline_sync_queue_service.dart';
import 'package:acceso/service/screen_security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MyApp renderiza LoginScreen con marca CONTROL+ y campos',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('CONTROL+'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
  });

  group('OfflineCacheService', () {
    late Directory tempDir;
    final cache = OfflineCacheService();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cp_cache_test_');
      cache.configureForTest(rootDir: tempDir);
    });

    tearDown(() async {
      cache.configureForTest(rootDir: null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('aísla datos entre usuarios y purga únicamente al usuario en logout',
        () async {
      await cache.saveJson(
        'perfil',
        {'nombre': 'Usuario A'},
        userId: 'user_a',
      );
      await cache.saveJson(
        'perfil',
        {'nombre': 'Usuario B'},
        userId: 'user_b',
      );

      final aBefore = await cache.readJson<Map<String, dynamic>>(
        'perfil',
        userId: 'user_a',
      );
      final bBefore = await cache.readJson<Map<String, dynamic>>(
        'perfil',
        userId: 'user_b',
      );

      expect(aBefore?['nombre'], 'Usuario A');
      expect(bBefore?['nombre'], 'Usuario B');

      await cache.clearUserCache('user_a');

      final aAfter = await cache.readJson<Map<String, dynamic>>(
        'perfil',
        userId: 'user_a',
      );
      final bAfter = await cache.readJson<Map<String, dynamic>>(
        'perfil',
        userId: 'user_b',
      );

      expect(aAfter, isNull);
      expect(bAfter?['nombre'], 'Usuario B');
    });

    test('bloquea persistencia de claves sensibles (QR dinámico y notas clínicas)',
        () async {
      await cache.saveJson('qr/generate', {'codigo': 'SECRET'}, userId: 'u1');
      await cache.saveJson('qr/clase', {'codigo': 'CLASS'}, userId: 'u1');
      await cache.saveJson(
        'notas_clinicas_c1',
        {'notas': 'Confidencial'},
        userId: 'u1',
      );

      expect(
        await cache.readJson<Map<String, dynamic>>('qr/generate', userId: 'u1'),
        isNull,
      );
      expect(
        await cache.readJson<Map<String, dynamic>>('qr/clase', userId: 'u1'),
        isNull,
      );
      expect(
        await cache.readJson<Map<String, dynamic>>(
          'notas_clinicas_c1',
          userId: 'u1',
        ),
        isNull,
      );
    });
  });

  group('OfflineSyncQueueService', () {
    late Directory tempDir;
    final queue = OfflineSyncQueueService();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cp_queue_test_');
      queue.configureForTest(rootDir: tempDir);
      await queue.setActiveUser('docente_1');
    });

    tearDown(() async {
      queue.configureForTest(rootDir: null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('encola en orden FIFO, deduplica por dedupeKey y sincroniza HTTP 200',
        () async {
      await queue.enqueue(
        method: 'PATCH',
        path: '/academico/asistencias',
        body: {'estado': 'falta'},
        description: 'Primera actualización',
        dedupeKey: 'asist_1',
      );
      await queue.enqueue(
        method: 'POST',
        path: '/calificaciones',
        body: {'parcial': 1, 'nivel': 'AU'},
        description: 'Calificación P1',
        dedupeKey: 'calif_1',
      );
      // Actualización con el mismo dedupeKey debe reemplazar la previa
      await queue.enqueue(
        method: 'PATCH',
        path: '/academico/asistencias',
        body: {'estado': 'justificado'},
        description: 'Actualización final',
        dedupeKey: 'asist_1',
      );

      final items = await queue.getPendingItems();
      expect(items.length, 2);
      expect(queue.pendingCount.value, 2);
      expect(items[0].path, '/calificaciones');
      expect(items[1].body['estado'], 'justificado');

      final dispatchedPaths = <String>[];
      queue.registerHandlers(
        sender: (method, path, body) async {
          dispatchedPaths.add('$method:$path');
          return http.Response('{"ok":true}', 200);
        },
      );

      final result = await queue.processQueue();
      expect(result.processed, 2);
      expect(result.remaining, 0);
      expect(queue.pendingCount.value, 0);
      expect(
        dispatchedPaths,
        ['POST:/calificaciones', 'PATCH:/academico/asistencias'],
      );
    });
  });

  group('ScreenSecurityService', () {
    const channel = MethodChannel('com.controlplus/screen_security');
    final calls = <String>[];

    setUp(() {
      calls.clear();
      ScreenSecurityService().resetForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'isScreenCaptured') return false;
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      ScreenSecurityService().resetForTest();
    });

    test('usa conteo de referencias entre acquire() y release()', () async {
      final sec = ScreenSecurityService();

      await sec.acquire();
      await sec.acquire();

      expect(
        calls.where((m) => m == 'enableSecureMode').length,
        1,
      );
      expect(sec.isSecureModeActive, isTrue);

      await sec.release();
      expect(
        calls.where((m) => m == 'disableSecureMode').length,
        0,
      );
      expect(sec.isSecureModeActive, isTrue);

      await sec.release();
      expect(
        calls.where((m) => m == 'disableSecureMode').length,
        1,
      );
      expect(sec.isSecureModeActive, isFalse);
    });
  });

  test('ApiClient.extractErrorMessage extrae mensaje estructurado .NET 10', () {
    final respMsg = http.Response(
      jsonEncode({'success': false, 'message': 'El horario ya está ocupado'}),
      409,
    );
    expect(
      ApiClient.extractErrorMessage(respMsg),
      'El horario ya está ocupado',
    );

    final respValidation = http.Response(
      jsonEncode({
        'title': 'Validation Error',
        'errors': {
          'Correo': ['El correo es obligatorio']
        }
      }),
      400,
    );
    expect(
      ApiClient.extractErrorMessage(respValidation),
      'El correo es obligatorio',
    );
  });

  test('RoleRouter mapea correctamente los 8 roles del Backend v2', () {
    expect(
      RoleRouter.buildHomeForRole(rol: 'alumno', userId: 'u1'),
      isA<AsistenciasScreen>(),
    );
    expect(
      RoleRouter.buildHomeForRole(rol: 'profesor', userId: 'u2'),
      isA<ProfessorDashboard>(),
    );
    expect(
      RoleRouter.buildHomeForRole(rol: 'tutor', userId: 'u3'),
      isA<ProfessorDashboard>(),
    );
    expect(
      RoleRouter.buildHomeForRole(rol: 'admin', userId: 'u4'),
      isA<AdminScreen>(),
    );
    expect(
      RoleRouter.buildHomeForRole(rol: 'administrativo', userId: 'u5'),
      isA<AdminPanelScreen>(),
    );
    expect(
      RoleRouter.buildHomeForRole(rol: 'seguridad', userId: 'u6'),
      isA<SeguridadScreen>(),
    );
    expect(
      RoleRouter.buildHomeForRole(rol: 'psicologo', userId: 'u7'),
      isA<PsicologoDashboardScreen>(),
    );
    expect(
      RoleRouter.buildHomeForRole(rol: 'marketing', userId: 'u8'),
      isA<MarketingDashboardScreen>(),
    );
  });
}

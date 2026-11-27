import 'dart:convert';
import 'dart:io';
import 'package:acceso/main.dart';
import 'package:acceso/navigation/role_router.dart';
import 'package:acceso/screens/admin_panel_screen.dart';
import 'package:acceso/screens/admin_screen.dart';
import 'package:acceso/screens/alumnos.dart';
import 'package:acceso/screens/avisos_profesor_screen.dart';
import 'package:acceso/screens/crear_anuncio_screen.dart';
import 'package:acceso/screens/homeprofesor.dart';
import 'package:acceso/screens/noticias_screen.dart';
import 'package:acceso/screens/notificaciones_screen.dart';
import 'package:acceso/screens/psicologia_screens.dart';
import 'package:acceso/screens/seguridad_screen.dart';
import 'package:acceso/service/api_client.dart';
import 'package:acceso/service/offline_cache_service.dart';
import 'package:acceso/service/offline_sync_queue_service.dart';
import 'package:acceso/service/screen_security_service.dart';
import 'package:acceso/service/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('Responsividad Admin y Administrativo sin overflows', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cp_admin_ui_test_');
      OfflineCacheService().configureForTest(rootDir: tempDir);
      OfflineSyncQueueService().configureForTest(rootDir: tempDir);
      ApiClient().configureForTest(
        httpClient: MockClient((request) async {
          if (request.url.path.contains('pendientes-count')) {
            return http.Response('{"count": 3}', 200);
          }
          return http.Response('[]', 200);
        }),
      );
    });

    tearDown(() async {
      ApiClient().configureForTest(httpClient: null);
      SessionService().dispose();
      OfflineCacheService().configureForTest(rootDir: null);
      OfflineSyncQueueService().configureForTest(rootDir: null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    for (final size in const [
      Size(320, 640),
      Size(360, 780),
      Size(800, 1200),
    ]) {
      testWidgets(
        'AdminScreen renderiza correctamente en ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            const MaterialApp(
              home: AdminScreen(
                userId: 'admin-1',
                nombre: 'Administrador General',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('CONTROL'), findsOneWidget);
          expect(find.text('+'), findsOneWidget);
          expect(find.text('ADMINISTRADOR'), findsOneWidget);
          expect(find.text('Resumen Operativo'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'AdminPanelScreen renderiza correctamente en ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            const MaterialApp(
              home: AdminPanelScreen(
                userId: 'advo-1',
                nombre: 'María López',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('CONTROL+'), findsOneWidget);
          expect(find.text('ADMINISTRATIVO'), findsOneWidget);
          expect(find.text('Estado Operativo'), findsOneWidget);
          expect(find.text('Código QR'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Responsividad y flujo de Avisos (Profesor y Alumno)', () {
    final sampleAnuncios = [
      {
        'id': 'an-1',
        'profesor_id': 'prof-1',
        'materia_id': 'mat-1',
        'clase_id': 'cls-1',
        'grupo': 'TI-401',
        'materia_nombre': 'Programación Móvil',
        'profesor_nombre': 'Ana Estrada',
        'titulo': 'Examen parcial unidad 2 el próximo viernes',
        'mensaje':
            'Repasen arquitectura Flutter, manejo de estado y consumo REST.',
        'tipo': 'examen',
        'total_leidos': 14,
        'leido': false,
        'fecha_creacion': '2026-11-26T10:00:00Z',
        'updated_at': '2026-11-26T10:00:00Z',
      },
      {
        'id': 'an-2',
        'profesor_id': 'prof-1',
        'materia_id': 'mat-1',
        'clase_id': 'cls-1',
        'grupo': 'TI-401',
        'materia_nombre': 'Programación Móvil',
        'profesor_nombre': 'Ana Estrada',
        'titulo': 'Entrega de práctica con captura',
        'mensaje': 'Subir repositorio antes de las 23:59.',
        'tipo': 'tarea',
        'total_leidos': 8,
        'leido': true,
        'fecha_creacion': '2026-11-25T10:00:00Z',
        'updated_at': '2026-11-25T12:30:00Z',
      },
    ];

    setUp(() {
      OfflineCacheService().configureForTest(memoryOnly: true);
      OfflineSyncQueueService().configureForTest(rootDir: null);
      ApiClient().configureForTest(
        token: 'test-jwt',
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/anuncios/profesor/') ||
              request.url.path.contains('/anuncios/alumno/')) {
            return http.Response(jsonEncode(sampleAnuncios), 200);
          }
          if (request.url.path.contains('/grupos')) {
            return http.Response(
              jsonEncode([
                {'clase_id': 'cls-1', 'grupo': 'TI-401'},
              ]),
              200,
            );
          }
          if (request.method == 'DELETE') {
            return http.Response(jsonEncode({'success': true}), 200);
          }
          return http.Response('[]', 200);
        }),
      );
    });

    tearDown(() {
      ApiClient().configureForTest(httpClient: null);
      SessionService().dispose();
      OfflineCacheService().configureForTest(rootDir: null, memoryOnly: false);
      OfflineSyncQueueService().configureForTest(rootDir: null);
    });

    for (final size in const [
      Size(320, 640),
      Size(360, 780),
      Size(800, 1200),
    ]) {
      testWidgets(
        'AvisosProfesorScreen contextual renderiza sin overflows en ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            const MaterialApp(
              home: AvisosProfesorScreen(
                profesorId: 'prof-1',
                nombreProfesor: 'Ana Estrada',
                materiaId: 'mat-1',
                claseId: 'cls-1',
                materiaNombre: 'Programación Móvil',
                grupo: 'TI-401',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Avisos del grupo'), findsOneWidget);
          expect(find.text('Examen parcial unidad 2 el próximo viernes'),
              findsOneWidget);
          expect(find.text('Editar'), findsAtLeastNWidgets(1));
          expect(find.text('Eliminar'), findsAtLeastNWidgets(1));

          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pumpAndSettle();

          expect(find.text('Editado'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'NotificacionesScreen alumno renderiza sin overflows en ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            const MaterialApp(
              home: NotificacionesScreen(userId: 'alum-1'),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Avisos y notificaciones'), findsOneWidget);
          expect(find.text('Examen parcial unidad 2 el próximo viernes'),
              findsOneWidget);
          expect(find.text('Nuevo'), findsOneWidget);
          expect(find.text('Editado'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'CrearAnuncioScreen modo edición renderiza sin overflows en ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: CrearAnuncioScreen(
                profesorId: 'prof-1',
                nombreProfesor: 'Ana Estrada',
                materias: const [
                  {'id': 'mat-1', 'nombre': 'Programación Móvil'},
                ],
                anuncioExistente: sampleAnuncios.first,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Editar aviso'), findsOneWidget);
          expect(find.text('Guardar cambios'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('AvisosProfesorScreen filtra por tipo y elimina con confirmación',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: AvisosProfesorScreen(
            profesorId: 'prof-1',
            nombreProfesor: 'Ana Estrada',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis avisos'), findsOneWidget);
      expect(find.text('Examen parcial unidad 2 el próximo viernes'),
          findsOneWidget);
      expect(find.text('Entrega de práctica con captura'), findsOneWidget);

      await tester.ensureVisible(find.text('Tarea (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarea (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Examen parcial unidad 2 el próximo viernes'),
          findsNothing);
      expect(find.text('Entrega de práctica con captura'), findsOneWidget);

      await tester.ensureVisible(find.text('Eliminar'));
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar aviso'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Entrega de práctica con captura'), findsNothing);
      expect(find.text('Aviso eliminado correctamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

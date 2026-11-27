import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'screens/login_screen.dart';
import 'screens/notificaciones_screen.dart';
import 'service/api_client.dart';
import 'service/api_service.dart';
import 'service/connectivity_service.dart';
import 'service/session_service.dart';
import 'theme/app_colors.dart';

// ─── HANDLER PARA NOTIFICACIONES EN BACKGROUND (solo cuando ENABLE_PUSH=true) ─
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!ApiConfig.enablePushNotifications) return;
  try {
    await Firebase.initializeApp();
    await showLocalNotification(
      title: message.notification?.title ?? 'Nueva notificación',
      body: message.notification?.body ?? '',
      payload: message.data['screen']?.toString() ?? '',
    );
  } catch (e) {
    debugPrint('Error en background handler: $e');
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _setupLocalNotifications() async {
  try {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response);
      },
    );
  } catch (e) {
    debugPrint('Error inicializando notificaciones locales: $e');
  }
}

Future<void> _handleNotificationTap(NotificationResponse response) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id') ?? '';
  final context = _navigatorKey.currentContext;
  if (context != null && userId.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificacionesScreen(userId: userId),
      ),
    );
  }
}

Future<void> showLocalNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  try {
    const androidDetails = AndroidNotificationDetails(
      'control_plus_channel',
      'Control+ Notificaciones',
      channelDescription: 'Canal para notificaciones de Control+',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: AppColors.primary,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosSettings = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
      payload: payload ?? '',
    );
  } catch (e) {
    debugPrint('Error mostrando notificación local: $e');
  }
}

Future<void> _setupFCM() async {
  try {
    if (Firebase.apps.isEmpty) return;

    final fcm = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await fcm
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        )
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => const NotificationSettings(
            authorizationStatus: AuthorizationStatus.notDetermined,
            alert: AppleNotificationSetting.notSupported,
            announcement: AppleNotificationSetting.notSupported,
            badge: AppleNotificationSetting.notSupported,
            carPlay: AppleNotificationSetting.notSupported,
            criticalAlert: AppleNotificationSetting.notSupported,
            lockScreen: AppleNotificationSetting.notSupported,
            notificationCenter: AppleNotificationSetting.notSupported,
            showPreviews: AppleShowPreviewSetting.notSupported,
            sound: AppleNotificationSetting.notSupported,
            timeSensitive: AppleNotificationSetting.notSupported,
          ),
        );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      String? token;
      try {
        token = await fcm.getToken().timeout(
              const Duration(seconds: 4),
              onTimeout: () => null,
            );
      } catch (_) {}

      if (token != null && token.isNotEmpty) {
        await _guardarTokenEnServidor(token);
      }

      fcm.onTokenRefresh.listen((newToken) {
        _guardarTokenEnServidor(newToken);
      });
    }
  } catch (e) {
    debugPrint('Error configurando FCM: $e');
  }
}

Future<void> _guardarTokenEnServidor(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null && userId.isNotEmpty) {
      await ApiService()
          .guardarFCMToken(userId, token)
          .timeout(const Duration(seconds: 5));
    }
  } catch (e) {
    debugPrint('Error guardando FCM Token: $e');
  }
}

Future<void> _initServicesAsync() async {
  // Inicializa puente de sincronización offline antes de revisar conectividad
  ApiService();
  await ConnectivityService().initialize();

  // Notificaciones push quedan desacopladas hasta habilitar ENABLE_PUSH=true
  if (!ApiConfig.enablePushNotifications) return;

  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 4),
      onTimeout: () => Firebase.app(),
    );
  } catch (e) {
    debugPrint('Advertencia al inicializar Firebase: $e');
  }

  await _setupLocalNotifications();
  await _setupFCM();
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  _initServicesAsync();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _configureAuthHandler();
    if (ApiConfig.enablePushNotifications) {
      _initForegroundNotifications();
    }
  }

  void _configureAuthHandler() {
    ApiClient().onUnauthorized = () async {
      await SessionService().endSession();
      final nav = _navigatorKey.currentState;
      final ctx = _navigatorKey.currentContext;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu sesión fue cerrada o expiró en el servidor. Inicia sesión nuevamente.',
            ),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 4),
          ),
        );
      }
    };
  }

  Future<void> _initForegroundNotifications() async {
    for (int i = 0; i < 20; i++) {
      if (Firebase.apps.isNotEmpty) {
        _setupForegroundListeners();
        break;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  void _setupForegroundListeners() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        showLocalNotification(
          title: message.notification?.title ?? 'Nueva notificación',
          body: message.notification?.body ?? '',
          payload: message.data['screen']?.toString() ?? '',
        );
        _showNotificationSnackBar(
          message.notification?.title ?? 'Nueva notificación',
          message.notification?.body ?? '',
        );
      });

      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          _handleNavigationFromNotification(message.data);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNavigationFromNotification(message.data);
      });
    } catch (e) {
      debugPrint('Error configurando listeners en foreground: $e');
    }
  }

  void _showNotificationSnackBar(String title, String body) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(body),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Ver',
            textColor: Colors.white,
            onPressed: () {
              _navigatorKey.currentState?.pushNamed('/notificaciones');
            },
          ),
        ),
      );
    }
  }

  void _handleNavigationFromNotification(Map<String, dynamic> data) {
    final screen = data['screen'] as String?;
    final anuncioId = data['anuncio_id'] as String?;
    if (screen == 'notificaciones' ||
        (screen == 'anuncio' && anuncioId != null)) {
      _navigatorKey.currentState?.pushNamed('/notificaciones');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control+',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primaryDark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routes: {
        '/notificaciones': (context) => FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snapshot) {
                final uid = snapshot.data?.getString('user_id') ?? '';
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return NotificacionesScreen(userId: uid);
              },
            ),
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('en', 'US'),
      ],
      home: const LoginScreen(),
    );
  }
}

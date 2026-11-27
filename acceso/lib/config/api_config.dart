class ApiConfig {
  /// URL base del backend de la aplicación (.NET 10 App API en AWS EC2).
  /// Puede sobreescribirse en compilación o ejecución con:
  ///   flutter run --dart-define=API_BASE_URL=https://tu-dominio/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://3.232.18.95:6501/api',
  );

  /// Bandera para habilitar Firebase Cloud Messaging cuando se reactive en el proyecto.
  /// Por defecto deshabilitada mientras las notificaciones push están pospuestas.
  static const bool enablePushNotifications = bool.fromEnvironment(
    'ENABLE_PUSH',
    defaultValue: false,
  );

  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration uploadTimeout = Duration(seconds: 45);
  static const Duration healthTimeout = Duration(seconds: 4);

  static Uri get healthUri {
    final trimmed = baseUrl.trim();
    String root;
    if (trimmed.endsWith('/api/')) {
      root = trimmed.substring(0, trimmed.length - 5);
    } else if (trimmed.endsWith('/api')) {
      root = trimmed.substring(0, trimmed.length - 4);
    } else if (trimmed.endsWith('/')) {
      root = trimmed.substring(0, trimmed.length - 1);
    } else {
      root = trimmed;
    }
    return Uri.parse('$root/health');
  }
}

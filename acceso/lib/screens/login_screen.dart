import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../navigation/role_router.dart';
import '../service/api_service.dart';
import '../service/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _verificarSesionExistente();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── VERIFICAR SESIÓN GUARDADA (ONLINE U OFFLINE) ───────────────────
  Future<void> _verificarSesionExistente() async {
    try {
      final restored = await SessionService().restorePersistedSession();
      final session = SessionService();
      final userId = session.userId;
      final rol = session.rol;

      if (restored &&
          userId != null &&
          userId.isNotEmpty &&
          rol != null &&
          rol.isNotEmpty &&
          mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _navegarSegunRol(userId, session.nombre, rol);
          }
        });
      } else if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    } catch (e) {
      debugPrint('Error verificando sesión: $e');
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  // ─── NAVEGACIÓN SEGÚN ROL (8 ROLES V2) ──────────────────────────────
  void _navegarSegunRol(String userId, String? nombre, String rol) {
    if (!mounted) return;
    RoleRouter.navigateToRoleHome(
      context,
      rol: rol,
      userId: userId,
      nombre: nombre,
    );
  }

  // ─── REGISTRAR FCM TOKEN (SOLO SI PUSH ESTÁ HABILITADO) ──────────────
  Future<void> _registrarFCMToken(String userId) async {
    if (!ApiConfig.enablePushNotifications) return;
    try {
      final fcm = FirebaseMessaging.instance;
      final token = await fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _apiService.guardarFCMToken(userId, token);
      }
    } catch (e) {
      debugPrint('FCM omitido o no disponible: $e');
    }
  }

  // ─── HANDLE LOGIN ───────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    final correo = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      _showMessage('Por favor, completa todos los campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceInfo = kIsWeb
          ? 'Control+ Web'
          : 'Control+ ${Platform.operatingSystem}';
      final user = await _apiService.login(
        correo,
        password,
        deviceInfo: deviceInfo,
      );

      if (user != null) {
        final rol = (user['rol'] ?? 'alumno').toString();
        final userId = user['id'].toString();
        final nombre = (user['nombre'] ?? 'Usuario').toString();
        final rawRoles = user['roles'];
        final roles = rawRoles is List && rawRoles.isNotEmpty
            ? rawRoles.map((e) => e.toString()).toList()
            : <String>[rol];

        await SessionService().startSession(
          userId: userId,
          nombre: nombre,
          rol: rol,
          roles: roles,
          email: user['correo']?.toString() ?? correo,
          matricula: user['matricula']?.toString(),
          numeroEmpleado:
              (user['numero_empleado'] ?? user['numeroEmpleado'])?.toString(),
          grupo: user['grupo']?.toString(),
          imagenUrl:
              (user['imagen_url'] ?? user['imagenUrl'])?.toString(),
          sessionId: user['sessionId']?.toString(),
        );

        await _registrarFCMToken(userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inicio de sesión exitoso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          _navegarSegunRol(userId, nombre, rol);
        }
      } else {
        _showMessage(
          _apiService.lastError ?? 'Correo o contraseña incorrectos',
        );
      }
    } catch (e) {
      _showMessage('Error al iniciar sesión: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── SHOW MESSAGE ─────────────────────────────────────────────────────
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Si está verificando sesión, mostrar loading
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8E8E8),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF1B4F72),
              ),
              SizedBox(height: 20),
              Text(
                'Verificando sesión...',
                style: TextStyle(
                  color: Color(0xFF1B4F72),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: Stack(
        children: [
          // ── Círculos decorativos ──
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF5B9DB8).withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: 80,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF8FC4DC).withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF5B9DB8).withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 100,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF8FC4DC).withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // ── Contenido principal ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Logo / Título
                    const Text(
                      'CONTROL+',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4F72),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sistema de Control Escolar',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1B4F72),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 60),
                    
                    // ── Campo Email ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          hintText: 'Correo electrónico',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 18,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Color(0xFF1B4F72),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // ── Campo Password ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 18,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF1B4F72),
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: IconButton(
                              icon: Icon(
                                _obscurePassword 
                                  ? Icons.visibility_off 
                                  : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    
                    // ── Botón Login ──
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A95B8),
                          disabledBackgroundColor: 
                              const Color(0xFF4A95B8).withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // ── Versión ──
                    const Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
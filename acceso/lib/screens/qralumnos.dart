import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../service/api_service.dart';
import '../service/connectivity_service.dart';
import '../service/screen_security_service.dart';
import '../service/session_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';

/// Convierte un código de rol del backend a etiqueta legible en español.
String formatRoleLabel(String? rawRole) {
  switch ((rawRole ?? '').trim().toLowerCase()) {
    case 'admin':
      return 'Administrador';
    case 'administrativo':
      return 'Administrativo';
    case 'profesor':
      return 'Profesor / Docente';
    case 'tutor':
      return 'Tutor de Grupo';
    case 'alumno':
      return 'Estudiante';
    case 'seguridad':
      return 'Seguridad Campus';
    case 'psicologo':
      return 'Psicología';
    case 'marketing':
      return 'Marketing y Comunicación';
    default:
      if (rawRole == null || rawRole.trim().isEmpty) return 'Usuario';
      final clean = rawRole.trim();
      return '${clean[0].toUpperCase()}${clean.substring(1)}';
  }
}

class QRScreen extends StatefulWidget {
  final String userId;

  const QRScreen({super.key, required this.userId});

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final ScreenSecurityService _screenSecurity = ScreenSecurityService();
  final ConnectivityService _connectivity = ConnectivityService();

  Map<String, dynamic>? _userData;
  String? _qrCodeData;
  DateTime? _expiresAt;
  bool _isLoading = true;
  bool _isRegenerating = false;
  bool _qrExpirado = false;
  bool _isPaused = false;
  String? _errorMessage;
  int _remainingSeconds = 180;

  Timer? _countdownTimer;
  StreamSubscription<void>? _screenshotSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenSecurity.acquire();
    _screenshotSub = _screenSecurity.onScreenshotAttempt.listen((_) {
      _onScreenshotDetected();
    });
    _connectivity.isOnline.addListener(_onConnectivityChanged);
    _cargarTodo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _screenshotSub?.cancel();
    _connectivity.isOnline.removeListener(_onConnectivityChanged);
    _screenSecurity.release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (mounted) {
        setState(() => _isPaused = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() => _isPaused = false);
      }
      _screenSecurity.refreshCaptureStatus();
      if (_qrCodeData == null ||
          _qrExpirado ||
          (_expiresAt != null && DateTime.now().isAfter(_expiresAt!))) {
        _regenerarQR();
      }
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline.value &&
        _qrCodeData == null &&
        !_isRegenerating) {
      _regenerarQR();
    }
  }

  Future<void> _onScreenshotDetected() async {
    final oldCode = _qrCodeData;
    if (mounted) {
      setState(() {
        _qrCodeData = null;
        _qrExpirado = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Captura de pantalla detectada. Por seguridad tu QR anterior fue revocado y se emitirá uno nuevo.',
          ),
          backgroundColor: AppColors.dangerRed,
          duration: Duration(seconds: 4),
        ),
      );
    }
    if (oldCode != null && oldCode.isNotEmpty) {
      unawaited(_apiService.marcarQRUserComoUsado(oldCode));
    }
    await _regenerarQR();
  }

  Future<void> _cargarTodo() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = await _apiService.getUserById(widget.userId);
    if (mounted) {
      final session = SessionService();
      setState(() {
        _userData = user ??
            {
              'id': widget.userId,
              'nombre': session.nombre ?? 'Usuario',
              'rol': session.rol ?? 'alumno',
              'roles': session.roles,
              'matricula': session.matricula,
              'numero_empleado': session.numeroEmpleado,
              'grupo': session.grupo,
              'imagen_url': session.imagenUrl,
            };
      });
    }

    await _generarNuevoQr(silentLoader: true);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generarNuevoQr({bool silentLoader = false}) async {
    if (!silentLoader && mounted) {
      setState(() {
        _isRegenerating = true;
        _errorMessage = null;
      });
    }

    final result = await _apiService.generateNewQRUser(widget.userId);
    if (!mounted) return;

    if (result != null) {
      final code =
          (result['codigo'] ?? result['qr_codigo'] ?? result['id'])?.toString();
      DateTime? expiresAt;
      final rawExp = result['expira_at'] ?? result['expiraAt'];
      if (rawExp != null) {
        expiresAt = DateTime.tryParse(rawExp.toString())?.toLocal();
      }
      final diff = expiresAt != null
          ? expiresAt.difference(DateTime.now()).inSeconds
          : 180;
      final safeSeconds = diff > 0 ? diff : 180;

      if (code != null && code.isNotEmpty) {
        setState(() {
          _qrCodeData = code;
          _expiresAt = expiresAt ?? DateTime.now().add(Duration(seconds: safeSeconds));
          _remainingSeconds = safeSeconds;
          _qrExpirado = false;
          _errorMessage = null;
          _isRegenerating = false;
        });
        _iniciarTimer();
        return;
      }
    }

    _countdownTimer?.cancel();
    setState(() {
      _isRegenerating = false;
      _qrCodeData = null;
      _qrExpirado = true;
      _errorMessage = _apiService.lastError ??
          'No fue posible generar tu QR dinámico en este momento.';
    });
  }

  Future<void> _regenerarQR() async {
    if (_isRegenerating) return;
    await _generarNuevoQr();
  }

  void _iniciarTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final nextSeconds = _expiresAt != null
          ? _expiresAt!.difference(DateTime.now()).inSeconds
          : _remainingSeconds - 1;

      if (nextSeconds <= 0) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _qrExpirado = true;
        });
        if (_connectivity.isOnline.value) {
          _regenerarQR();
        }
      } else {
        setState(() => _remainingSeconds = nextSeconds);
      }
    });
  }

  void _onExitScreen() {
    final code = _qrCodeData;
    if (code != null && code.isNotEmpty && _connectivity.isOnline.value) {
      unawaited(_apiService.marcarQRUserComoUsado(code));
    }
  }

  String _formatDuration(int totalSeconds) {
    final clamped = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = (clamped ~/ 60).toString().padLeft(2, '0');
    final secs = (clamped % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _userData?['nombre']?.toString() ??
        SessionService().nombre ??
        'Usuario';
    final rolPrincipal = _userData?['rol']?.toString() ??
        SessionService().rol ??
        'alumno';
    final matricula = _userData?['matricula']?.toString();
    final numeroEmpleado = _userData?['numero_empleado']?.toString() ??
        _userData?['numeroEmpleado']?.toString();
    final grupo = _userData?['grupo']?.toString();
    final imagenUrl = _userData?['imagen_url']?.toString() ??
        SessionService().imagenUrl;

    return SessionWrapper(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _onExitScreen();
          }
        },
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary,
                  AppColors.accentBlue,
                  AppColors.qrGradientBottom,
                ],
              ),
            ),
            child: SafeArea(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'CONTROL+',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  tooltip: 'Renovar QR',
                                  icon: _isRegenerating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh,
                                          color: Colors.white,
                                        ),
                                  onPressed:
                                      _isRegenerating ? null : _regenerarQR,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Tarjeta blanca principal del pase QR
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Sello de protección contra capturas
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoftBlue,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_user,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Pantalla protegida contra capturas',
                                        style: TextStyle(
                                          color: AppColors.primaryDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Perfil breve
                                Row(
                                  children: [
                                    ClipOval(
                                      child: SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: SafeNetworkImage(
                                          url: imagenUrl,
                                          width: 56,
                                          height: 56,
                                          fallback: CircleAvatar(
                                            radius: 28,
                                            backgroundColor:
                                                AppColors.primaryDark,
                                            child: Text(
                                              nombre.isNotEmpty
                                                  ? nombre[0].toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nombre,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _badgeChip(
                                                formatRoleLabel(rolPrincipal),
                                                AppColors.primary,
                                              ),
                                              if (grupo != null &&
                                                  grupo.trim().isNotEmpty)
                                                _badgeChip(
                                                  'Grupo $grupo',
                                                  AppColors.accentBlue,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (matricula != null &&
                                              matricula.trim().isNotEmpty)
                                            Text(
                                              'Matrícula: $matricula',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            )
                                          else if (numeroEmpleado != null &&
                                              numeroEmpleado.trim().isNotEmpty)
                                            Text(
                                              'No. Empleado: $numeroEmpleado',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Área protegida del QR
                                ValueListenableBuilder<bool>(
                                  valueListenable: _screenSecurity.isCaptured,
                                  builder: (context, isCaptured, _) {
                                    if (isCaptured || _isPaused) {
                                      return _buildSecurityShieldBox();
                                    }
                                    if (_errorMessage != null ||
                                        _qrCodeData == null) {
                                      return _buildErrorOrOfflineBox();
                                    }
                                    return Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _qrExpirado
                                                  ? AppColors.dangerRed
                                                  : AppColors.primary
                                                      .withOpacity(0.25),
                                              width: 2,
                                            ),
                                          ),
                                          child: _qrExpirado
                                              ? SizedBox(
                                                  width: 220,
                                                  height: 220,
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.timer_off,
                                                          color: AppColors
                                                              .dangerRed,
                                                          size: 46,
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        const Text(
                                                          'QR Expirado',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: AppColors
                                                                .dangerRed,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        ElevatedButton(
                                                          onPressed:
                                                              _regenerarQR,
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                AppColors
                                                                    .primary,
                                                            foregroundColor:
                                                                Colors.white,
                                                          ),
                                                          child: const Text(
                                                            'Generar nuevo',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              : QrImageView(
                                                  data: _qrCodeData!,
                                                  version: QrVersions.auto,
                                                  size: 228,
                                                  eyeStyle: const QrEyeStyle(
                                                    eyeShape:
                                                        QrEyeShape.square,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                  dataModuleStyle:
                                                      const QrDataModuleStyle(
                                                    dataModuleShape:
                                                        QrDataModuleShape
                                                            .square,
                                                    color: Color(0xFF0A1F38),
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _remainingSeconds <= 30
                                                ? const Color(0xFFFFEBEE)
                                                : AppColors.surfaceSoftBlue,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.schedule,
                                                size: 18,
                                                color: _remainingSeconds <= 30
                                                    ? AppColors.dangerRed
                                                    : AppColors.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Vigencia: ${_formatDuration(_remainingSeconds)}',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: _remainingSeconds <= 30
                                                      ? AppColors.dangerRed
                                                      : AppColors.primaryDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Presenta este código en el lector de entrada o salida. Caduca automáticamente y nunca se almacena localmente.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isRegenerating ? null : _regenerarQR,
                                    icon: const Icon(Icons.qr_code_2),
                                    label: Text(
                                      _isRegenerating
                                          ? 'Generando QR...'
                                          : 'Generar nuevo QR',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryDark,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSecurityShieldBox() {
    return Container(
      width: 240,
      height: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.visibility_off,
            color: AppColors.warning,
            size: 52,
          ),
          const SizedBox(height: 12),
          const Text(
            'QR oculto por seguridad',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isPaused
                ? 'La vista se protegió al cambiar de aplicación.'
                : 'Se detectó grabación o transmisión de pantalla activa. Deténla para ver tu QR.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOrOfflineBox() {
    final isOffline = !_connectivity.isOnline.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOffline ? const Color(0xFFFFF8E1) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOffline ? AppColors.warning : AppColors.dangerRed,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
            color: isOffline ? AppColors.warning : AppColors.dangerRed,
            size: 46,
          ),
          const SizedBox(height: 10),
          Text(
            isOffline
                ? 'Sin conexión para emitir QR dinámico'
                : 'No se pudo emitir el QR',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                'Por seguridad, los códigos QR dinámicos no se guardan en caché offline. Tus asistencias, kárdex y citas guardadas siguen disponibles.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isRegenerating ? null : _regenerarQR,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

/// Pantalla para emitir y proyectar el QR dinámico de pase de lista por clase o reservación de salón.
class ClaseQrScreen extends StatefulWidget {
  final String claseId;
  final String nombreMateria;
  final String grupo;
  final String? reservacionId;

  const ClaseQrScreen({
    super.key,
    required this.claseId,
    required this.nombreMateria,
    required this.grupo,
    this.reservacionId,
  });

  @override
  State<ClaseQrScreen> createState() => _ClaseQrScreenState();
}

class _ClaseQrScreenState extends State<ClaseQrScreen> {
  final ApiService _apiService = ApiService();
  final ScreenSecurityService _screenSecurity = ScreenSecurityService();

  int _duracionMinutos = 30;
  int _usosMaximos = 60;
  bool _isGenerating = false;
  String? _qrCode;
  DateTime? _expiresAt;
  int _remainingSeconds = 0;
  String? _error;
  Timer? _timer;
  StreamSubscription<void>? _screenshotSub;

  @override
  void initState() {
    super.initState();
    _screenSecurity.acquire();
    _screenshotSub = _screenSecurity.onScreenshotAttempt.listen((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Captura detectada: se regenerará el QR de clase por seguridad.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      _generarQrClase();
    });
    _generarQrClase();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _screenshotSub?.cancel();
    _screenSecurity.release();
    super.dispose();
  }

  Future<void> _generarQrClase() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    final res = await _apiService.generateClaseQr(
      claseId: widget.claseId,
      reservacionId: widget.reservacionId,
      usosMaximos: _usosMaximos,
      duracionMinutos: _duracionMinutos,
    );

    if (!mounted) return;

    if (res != null) {
      final code =
          (res['codigo'] ?? res['qr_codigo'] ?? res['id'])?.toString();
      final rawExp = res['expira_at'] ?? res['expiraAt'];
      final exp = rawExp != null
          ? DateTime.tryParse(rawExp.toString())?.toLocal()
          : null;
      final secs = exp != null
          ? exp.difference(DateTime.now()).inSeconds
          : _duracionMinutos * 60;

      if (code != null && code.isNotEmpty) {
        setState(() {
          _qrCode = code;
          _expiresAt = exp ?? DateTime.now().add(Duration(seconds: secs));
          _remainingSeconds = secs > 0 ? secs : _duracionMinutos * 60;
          _isGenerating = false;
        });
        _startTimer();
        return;
      }
    }

    setState(() {
      _isGenerating = false;
      _error =
          _apiService.lastError ?? 'No se pudo generar el QR de asistencia.';
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = _expiresAt != null
          ? _expiresAt!.difference(DateTime.now()).inSeconds
          : _remainingSeconds - 1;
      if (left <= 0) {
        t.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds = left);
      }
    });
  }

  String _fmt(int s) {
    final c = s < 0 ? 0 : s;
    return '${(c ~/ 60).toString().padLeft(2, '0')}:${(c % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('QR de Asistencia de Clase'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Text(
                  widget.nombreMateria,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grupo ${widget.grupo}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _duracionMinutos,
                        decoration: const InputDecoration(
                          labelText: 'Duración',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [10, 15, 30, 60]
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text('$m min'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _duracionMinutos = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _usosMaximos,
                        decoration: const InputDecoration(
                          labelText: 'Cupo máximo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [30, 45, 60, 100]
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text('$u alumnos'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _usosMaximos = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<bool>(
                  valueListenable: _screenSecurity.isCaptured,
                  builder: (context, captured, _) {
                    if (captured) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.security,
                              color: AppColors.warning,
                              size: 46,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Grabación de pantalla detectada. QR oculto.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }
                    if (_isGenerating) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (_error != null || _qrCode == null) {
                      return Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.dangerRed,
                            size: 42,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error ?? 'No fue posible generar el QR',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        QrImageView(
                          data: _qrCode!,
                          version: QrVersions.auto,
                          size: 230,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _remainingSeconds > 0
                              ? 'Tiempo restante: ${_fmt(_remainingSeconds)}'
                              : 'QR expirado',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _remainingSeconds > 0
                                ? AppColors.primaryDark
                                : AppColors.dangerRed,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generarQrClase,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerar QR de Clase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

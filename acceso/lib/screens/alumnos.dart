import 'package:flutter/material.dart';
import '../navigation/role_router.dart';
import '../service/api_service.dart';
import '../service/session_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'asistencia_materia.dart';
import 'calificaciones_screens.dart';
import 'entradas_salidas.dart';
import 'justificantes_alumno_screen.dart';
import 'noticias_screen.dart';
import 'notificaciones_screen.dart';
import 'profile_screen.dart';
import 'psicologia_screens.dart';
import 'qralumnos.dart';

class AsistenciasScreen extends StatefulWidget {
  final String userId;
  final String? nombre;

  const AsistenciasScreen({
    Key? key,
    required this.userId,
    this.nombre,
  }) : super(key: key);

  @override
  State<AsistenciasScreen> createState() => _AsistenciasScreenState();
}

class _AsistenciasScreenState extends State<AsistenciasScreen> {
  final SessionService _sessionService = SessionService();
  final ApiService _apiService = ApiService();
  bool _isLoggingOut = false;
  bool _isLoading = true;

  int _notificacionesNoLeidas = 0;

  String? _grupo;
  List<Map<String, dynamic>> _materias = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosEstudiante();
    _cargarNotificaciones();
    
    // Registrar actividad al iniciar
    _sessionService.recordActivity();
  }

  @override
  void dispose() {
    // Solo cerrar sesión si no está activa
    if (!_sessionService.isSessionActive) {
      _sessionService.endSession();
    }
    super.dispose();
  }

  // ─── CARGAR NOTIFICACIONES ────────────────────────────────────────
  Future<void> _cargarNotificaciones() async {
    try {
      final count = await _apiService.contarAnunciosNoLeidos(widget.userId);
      if (mounted) {
        setState(() {
          _notificacionesNoLeidas = count;
        });
      }
    } catch (e) {
      print('❌ Error cargando notificaciones: $e');
    }
  }

  // ─── NAVEGAR A NOTIFICACIONES ─────────────────────────────────────
  void _irANotificaciones() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificacionesScreen(
          userId: widget.userId,
        ),
      ),
    ).then((_) {
      // Al regresar, refrescar contador
      _cargarNotificaciones();
    });
  }

  // ─── NAVEGAR A JUSTIFICANTES ─────────────────────────────────────
  void _irAJustificantes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JustificantesAlumnoScreen(
          userId: widget.userId,
        ),
      ),
    );
  }

  // ─── CARGAR DATOS DEL ESTUDIANTE ─────────────────────────────────
  Future<void> _cargarDatosEstudiante() async {
    // Registrar actividad
    await _sessionService.recordActivity();

    setState(() {
      _isLoading = true;
    });

    try {
      print("========== INICIANDO CARGA DE DATOS ==========");
      print("User ID: ${widget.userId}");

      final datos = await _apiService.getDatosEstudiante(widget.userId);

      print("Datos recibidos: $datos");

      if (datos != null && mounted) {
        print("Grupo: ${datos['grupo']}");
        print("Materias: ${datos['materias']}");
        print("Número de materias: ${(datos['materias'] as List).length}");

        setState(() {
          _grupo = datos['grupo'] as String?;
          _materias = (datos['materias'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          _isLoading = false;
        });

        print("✓ Datos cargados: Grupo $_grupo, ${_materias.length} materias");
      } else {
        setState(() {
          _isLoading = false;
        });
        print("✗ No se pudieron cargar los datos del estudiante");
      }
    } catch (e) {
      print("✗ Error al cargar datos: $e");
      print("✗ Stack trace: ${StackTrace.current}");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ─── HANDLE LOGOUT ─────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            '¿Cerrar sesión?',
            style: TextStyle(
              color: Color(0xFF003366),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '¿Estás seguro de que deseas cerrar sesión?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      setState(() {
        _isLoggingOut = true;
      });

      // ── Cerrar sesión en API ──
      await _apiService.logout(widget.userId);

      // ── Cerrar sesión local ──
      await _sessionService.endSession();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // ── Navegar al login ──
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/', 
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  // ─── GET CURRENT DATE ──────────────────────────────────────────────
  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${now.day} de ${months[now.month - 1]} ${now.year}';
  }

  // ─── GET PRIMER NOMBRE ─────────────────────────────────────────────
  String _getPrimerNombre(String? nombreCompleto) {
    if (nombreCompleto == null || nombreCompleto.isEmpty) {
      return 'Usuario';
    }
    return nombreCompleto.split(' ').first;
  }

  // ─── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF003366),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarDatosEstudiante,
                      color: const Color(0xFF003366),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildJustificantesButton(),
                              const SizedBox(height: 12),
                              _buildAvisosBannerButton(),
                              const SizedBox(height: 12),
                              _buildAccesosRapidosAlumno(),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Registro de asistencias',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF003366),
                                    ),
                                  ),
                                  if (_grupo != null)
                                    Text(
                                      'Grupo $_grupo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _getCurrentDate(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_materias.isEmpty)
                                        _buildEmptyState()
                                      else
                                        ..._materias
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final materia = entry.value;
                                          final isLast = index ==
                                              _materias.length - 1;

                                          return AsistenciaItem(
                                            userId: widget.userId,
                                            materia: materia['nombre'] ??
                                                'Sin nombre',
                                            claseId: materia['id'] ?? '',
                                            porcentaje:
                                                '${materia['porcentaje']}%',
                                            isLast: isLast,
                                            grupo: _grupo ?? 'Sin grupo',
                                            docente: materia['docente'],
                                          );
                                        }).toList(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BUILD JUSTIFICANTES BUTTON ──────────────────────────────────
  Widget _buildJustificantesButton() {
    return GestureDetector(
      onTap: _irAJustificantes,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF003366), Color(0xFF0055A0)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF003366).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 22,
            ),
            SizedBox(width: 12),
            Text(
              'Ver mis justificantes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ─── BUILD AVISOS BANNER BUTTON ───────────────────────────────────
  Widget _buildAvisosBannerButton() {
    final hasUnread = _notificacionesNoLeidas > 0;
    return GestureDetector(
      onTap: _irANotificaciones,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasUnread
                ? AppColors.warning
                : AppColors.primary.withValues(alpha: 0.25),
            width: hasUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (hasUnread ? AppColors.warning : AppColors.primary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.campaign_outlined,
                color: hasUnread ? AppColors.warning : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avisos de profesores',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    hasUnread
                        ? 'Tienes $_notificacionesNoLeidas ${_notificacionesNoLeidas == 1 ? 'aviso nuevo' : 'avisos nuevos'}'
                        : 'Consulta avisos, tareas y exámenes de tus clases',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _notificacionesNoLeidas > 99
                      ? '99+'
                      : '$_notificacionesNoLeidas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primaryDark,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  // ─── BUILD EMPTY STATE ─────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.school_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay materias registradas',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contacta con tu tutor',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccesosRapidosAlumno() {
    return Row(
      children: [
        Expanded(
          child: _miniModuleTile(
            icon: Icons.school_outlined,
            label: 'Kárdex',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KardexAlumnoScreen(
                  alumnoId: widget.userId,
                  nombreAlumno: widget.nombre,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniModuleTile(
            icon: Icons.psychology_outlined,
            label: 'Psicología',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CitasAlumnoScreen(
                  alumnoId: widget.userId,
                  nombreAlumno: widget.nombre,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniModuleTile(
            icon: Icons.newspaper_outlined,
            label: 'Noticias',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NoticiasFeedScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniModuleTile(
            icon: Icons.door_sliding_outlined,
            label: 'Accesos',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntradasSalidasScreen(
                  userIdFilter: widget.userId,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniModuleTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BUILD HEADER ──────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        const SafeHeaderBanner(
          height: 280,
          gradientColors: [
            Color(0xCC003366),
            Color(0x66003366),
          ],
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONTROL+',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Row(
                      children: [
                        RoleSwitcherButton(
                          currentRole: 'alumno',
                          userId: widget.userId,
                          nombre: widget.nombre,
                        ),
                        // ── Botón Perfil ──
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: widget.userId,
                                  nombre: widget.nombre,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.account_circle,
                            color: Colors.white,
                            size: 30,
                          ),
                          tooltip: 'Perfil',
                        ),

                        // ── Campana con badge ──
                        Stack(
                          children: [
                            IconButton(
                              onPressed: _irANotificaciones,
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 30,
                              ),
                              tooltip: 'Notificaciones',
                            ),
                            if (_notificacionesNoLeidas > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF3D00),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    _notificacionesNoLeidas > 99
                                        ? '99+'
                                        : '$_notificacionesNoLeidas',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // ── Botón Cerrar sesión ──
                        IconButton(
                          onPressed:
                              _isLoggingOut ? null : _handleLogout,
                          icon: _isLoggingOut
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                  size: 30,
                                ),
                          tooltip: 'Cerrar sesión',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: const Color(0xFFFFC107),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ESTUDIANTE',
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '¡Bienvenid@ ${_getPrimerNombre(widget.nombre)}!',
                        style: const TextStyle(
                          color: Color(0xFF003366),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Escanea tu QR para acceder al campus',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  QRScreen(userId: widget.userId),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.qr_code,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Código QR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── ASISTENCIA ITEM ──────────────────────────────────────────────────
class AsistenciaItem extends StatelessWidget {
  final String userId;
  final String materia;
  final String claseId;
  final String porcentaje;
  final bool isLast;
  final String grupo;
  final String? docente;

  const AsistenciaItem({
    Key? key,
    required this.userId,
    required this.materia,
    required this.claseId,
    required this.porcentaje,
    this.isLast = false,
    required this.grupo,
    this.docente,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final porcentajeNum =
        int.tryParse(porcentaje.replaceAll('%', '')) ?? 0;

    return Column(
      children: [
        InkWell(
          onTap: () {
            // Registrar actividad al navegar
            SessionService().recordActivity();
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AsistenciaMateriaScreen(
                  userId: userId,
                  claseId: claseId,
                  materiaNombre: materia,
                  porcentaje: porcentajeNum,
                  grupo: grupo,
                  docente: docente,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    materia,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Asistencias',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      porcentaje,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            color: Colors.grey[300],
            thickness: 1,
            height: 1,
          ),
      ],
    );
  }
}
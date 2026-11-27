import 'package:flutter/material.dart';
import '../navigation/role_router.dart';
import '../service/api_service.dart';
import '../service/session_service.dart';
import '../service/session_wrapper.dart';
import '../widgets/common_widgets.dart';
import 'crear_anuncio_screen.dart';
import 'grupos_screen.dart';
import 'justificantes_profesor_screen.dart';
import 'noticias_screen.dart';
import 'notificaciones_screen.dart';
import 'pedir_salon_screen.dart';
import 'profile_screen.dart';
import 'qralumnos.dart';
import 'tutor_screen.dart';

class ProfessorDashboard extends StatefulWidget {
  final String userId;
  final String? nombre;
  final String? rol;

  const ProfessorDashboard({
    Key? key,
    required this.userId,
    this.nombre,
    this.rol,
  }) : super(key: key);

  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> {
  final SessionService _sessionService = SessionService();
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _materias = [];
  bool _isLoading = true;
  bool _isLoggingOut = false;
  int _notificacionesNoLeidas = 0;

  @override
  void initState() {
    super.initState();
    _cargarMaterias();
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

  // ─── CARGAR MATERIAS ──────────────────────────────────────────────
  Future<void> _cargarMaterias() async {
    // Registrar actividad
    await _sessionService.recordActivity();

    setState(() {
      _isLoading = true;
    });

    try {
      print("=== CARGANDO MATERIAS DEL PROFESOR ===");
      print("Profesor ID: ${widget.userId}");

      final materias = await _apiService.getMateriasByProfesor(widget.userId);

      print("✓ ${materias.length} materias obtenidas de la tabla materias");

      for (var materia in materias) {
        print("Materia ID: ${materia['id']} - Nombre: ${materia['nom_mat']}");
      }

      List<Map<String, dynamic>> materiasSimplificadas = [];

      for (var materia in materias) {
        materiasSimplificadas.add({
          'id': materia['id'],
          'nombre': materia['nom_mat'] ?? 'Sin nombre',
        });
      }

      setState(() {
        _materias = materiasSimplificadas;
        _isLoading = false;
      });

      print("✓ ${_materias.length} materias cargadas y listas para mostrar");
    } catch (e) {
      print("✗ Error al cargar materias: $e");
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
              color: Color(0xFF004C8C),
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
                backgroundColor: const Color(0xFF004C8C),
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

  // ─── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFE8E8E8),
        drawer: widget.rol == 'Tutor' ? _buildDrawer(context) : null,
        body: RefreshIndicator(
          onRefresh: _cargarMaterias,
          color: const Color(0xFF004C8C),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Botón solicitar salón ──────────────────────────
                      _buildBotonSalon(),
                      const SizedBox(height: 12),

                      // ── Botón crear aviso ───────────────────────────────
                      _buildBotonAviso(),
                      const SizedBox(height: 20),

                      // ── Título materias ────────────────────────────────
                      const Text(
                        'Materias que impartes',
                        style: TextStyle(
                          color: Color(0xFF004C8C),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getCurrentDate(),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF004C8C),
                            ),
                          ),
                        )
                      else if (_materias.isEmpty)
                        _buildEmptyState()
                      else
                        _buildMateriasList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Botón solicitar salón ──────────────────────────────────────────────
  Widget _buildBotonSalon() {
    return GestureDetector(
      onTap: () {
        // Registrar actividad
        _sessionService.recordActivity();
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PedirSalonScreen(
              profesorId: widget.userId,
              nombreProfesor: widget.nombre ?? 'Profesor',
              numeroEmpleado: _sessionService.numeroEmpleado,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF004C8C), Color(0xFF1976D2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF004C8C).withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.meeting_room_outlined,
                color: Colors.white, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solicitar salón',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Ver salones disponibles y hacer una reservación',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Botón crear aviso ────────────────────────────────────────────────────
  Widget _buildBotonAviso() {
    return GestureDetector(
      onTap: () {
        // Registrar actividad
        _sessionService.recordActivity();
        
        // Si no hay materias cargadas aún, esperar
        if (_materias.isEmpty && !_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No tienes materias asignadas para enviar avisos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CrearAnuncioScreen(
              profesorId: widget.userId,
              nombreProfesor: widget.nombre ?? 'Profesor',
              materias: _materias,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF004C8C).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF004C8C).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: Color(0xFF004C8C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crear aviso',
                    style: TextStyle(
                      color: Color(0xFF004C8C),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Envía un aviso a tus grupos o a toda la clase',
                    style: TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF004C8C),
              size: 16,
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
          height: 245,
          gradientColors: [
            Color(0xCC004C8C),
            Color(0x66004C8C),
          ],
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (widget.rol == 'Tutor')
                      Builder(
                        builder: (context) => IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                      ),
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CONTROL+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RoleSwitcherButton(
                          currentRole: widget.rol ?? 'profesor',
                          userId: widget.userId,
                          nombre: widget.nombre,
                        ),
                        IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NoticiasFeedScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.newspaper_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: 'Noticias',
                        ),
                        // ── Botón Perfil ──
                        IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
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
                            size: 25,
                          ),
                          tooltip: 'Perfil',
                        ),

                        // ── Campana con badge ──
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: _irANotificaciones,
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 25,
                              ),
                              tooltip: 'Notificaciones',
                            ),
                            if (_notificacionesNoLeidas > 0)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF3D00),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    _notificacionesNoLeidas > 99
                                        ? '99+'
                                        : '$_notificacionesNoLeidas',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
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
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: _isLoggingOut ? null : _handleLogout,
                          icon: _isLoggingOut
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                  size: 24,
                                ),
                          tooltip: 'Cerrar sesión',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: const Color(0xFFFFB800),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.rol == 'Tutor' ? 'TUTOR' : 'PROFESOR',
                  style: const TextStyle(
                    color: Color(0xFFFFB800),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
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
                        '¡Bienvenid@ ${widget.nombre ?? 'Profesor'}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF004C8C),
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Escanea tu QR para acceder al campus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
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
                            color: const Color(0xFF4A9FD8),
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

  // ─── BUILD MATERIAS LIST ──────────────────────────────────────────
  Widget _buildMateriasList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _materias.length,
      itemBuilder: (context, index) {
        final materia = _materias[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildMateriaCard(materia),
        );
      },
    );
  }

  // ─── BUILD MATERIA CARD ───────────────────────────────────────────
  Widget _buildMateriaCard(Map<String, dynamic> materia) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la materia
          InkWell(
            onTap: () {
              // Registrar actividad
              _sessionService.recordActivity();
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GruposScreen(
                    materiaId: materia['id'],
                    materiaNombre: materia['nombre'],
                  ),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    materia['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(
                      color: Color(0xFF004C8C),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF004C8C),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Botón justificantes con contador
          FutureBuilder<int>(
            future: _apiService.getClaseIdAndCount(materia['id']),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              final hasCount = count > 0;

              return GestureDetector(
                onTap: () {
                  // Registrar actividad
                  _sessionService.recordActivity();
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JustificantesProfesorScreen(
                        profesorId: widget.userId,
                        claseId: materia['id'],
                        materiaNombre: materia['nombre'] ?? 'Sin nombre',
                        grupo: '',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: hasCount
                        ? const Color(0xFFFF9800).withOpacity(0.08)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasCount
                          ? const Color(0xFFFF9800)
                          : const Color(0xFF004C8C).withOpacity(0.3),
                      width: hasCount ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: hasCount
                            ? const Color(0xFFFF9800)
                            : const Color(0xFF004C8C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Justificantes',
                        style: TextStyle(
                          color: hasCount
                              ? const Color(0xFFFF9800)
                              : const Color(0xFF004C8C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasCount) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF004C8C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── BUILD EMPTY STATE ────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_outlined,
            size: 62,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No hay materias asignadas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Contacta con el administrador',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BUILD DRAWER ──────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF004C8C),
                    Color(0xFF4A9FD8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.nombre ?? 'Tutor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Menú de Tutor',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.groups,
                color: Color(0xFF004C8C),
              ),
              title: const Text(
                'Grupos Tutorados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TutorScreen(
                      userId: widget.userId,
                      nombre: widget.nombre,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.home,
                color: Color(0xFF004C8C),
              ),
              title: const Text(
                'Inicio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
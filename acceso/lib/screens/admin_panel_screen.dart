import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui_components.dart';
import 'entradas_salidas.dart';
import 'gestion_institucional_screen.dart';
import 'noticias_screen.dart';
import 'profile_screen.dart';
import 'qralumnos.dart';
import 'registrar_visita_screen.dart';
import 'visitas_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  final String userId;
  final String? nombre;

  const AdminPanelScreen({
    super.key,
    required this.userId,
    this.nombre,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final SessionService _sessionService = SessionService();
  final ApiService _apiService = ApiService();

  bool _isLoggingOut = false;
  bool _isLoadingKpis = true;
  int _visitasPendientes = 0;
  int _salonesLibres = 0;
  int _salonesTotal = 0;
  int _accesosRecientes = 0;
  int _totalZonas = 0;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    if (mounted) setState(() => _isLoadingKpis = true);
    try {
      final results = await Future.wait([
        _apiService.contarVisitasPendientes(),
        _apiService.getSalonesConEstado(),
        _apiService.getAccess(limit: 50),
        _apiService.getZonas(),
      ]);

      if (!mounted) return;
      final visitasPend = results[0] as int;
      final salones = results[1] as List<Map<String, dynamic>>;
      final accesos = results[2] as List<Map<String, dynamic>>;
      final zonas = results[3] as List<Map<String, dynamic>>;
      final libres = salones.where((s) => s['disponible'] == true).length;

      setState(() {
        _visitasPendientes = visitasPend;
        _salonesLibres = libres;
        _salonesTotal = salones.length;
        _accesosRecientes = accesos.length;
        _totalZonas = zonas.length;
        _isLoadingKpis = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingKpis = false);
    }
  }

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
              color: AppColors.primaryDark,
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
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
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
      setState(() => _isLoggingOut = true);
      await _apiService.logout(widget.userId);
      await _sessionService.endSession();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada exitosamente'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  String _primerNombre(String? raw) {
    final clean = (raw ?? _sessionService.nombre ?? '').trim();
    if (clean.isEmpty) return 'Administrativo';
    return clean.split(' ').first;
  }

  String _fechaActual() {
    final now = DateTime.now();
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${now.day} de ${months[now.month - 1]} ${now.year}';
  }

  Future<void> _pushAndRefresh(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _cargarResumen();
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        body: RefreshIndicator(
          onRefresh: _cargarResumen,
          color: AppColors.primaryDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExecutiveHeaderBar(
                  roleBadge: 'ADMINISTRATIVO',
                  roleBadgeColor: AppColors.badgeGold,
                  orangePlusAccent: false,
                  gradientColors: const [
                    Color(0xE0003366),
                    Color(0xB3004C8C),
                  ],
                  greeting: '¡Bienvenid@ ${_primerNombre(widget.nombre)}!',
                  subtitle: _fechaActual(),
                  currentRole: 'administrativo',
                  userId: widget.userId,
                  nombre: widget.nombre,
                  isLoggingOut: _isLoggingOut,
                  onProfileTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        userId: widget.userId,
                        nombre: widget.nombre,
                      ),
                    ),
                  ),
                  onLogoutTap: _handleLogout,
                  bottomCard: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 460;
                        final qrBtn = ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QRScreen(userId: widget.userId),
                            ),
                          ),
                          icon: const Icon(Icons.qr_code, size: 19),
                          label: const Text(
                            'Código QR',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brightBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pase de Acceso Personal',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Escanea tu QR para acceder al campus',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              qrBtn,
                            ],
                          );
                        }

                        return Column(
                          children: [
                            const Text(
                              'Escanea tu QR para acceder al campus',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            qrBtn,
                          ],
                        );
                      },
                    ),
                  ),
                ),
                ResponsiveContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      const SectionHeaderTitle(
                        icon: Icons.dashboard_outlined,
                        title: 'Estado Operativo',
                        subtitle: 'Indicadores en tiempo real del campus',
                      ),
                      const SizedBox(height: 12),
                      KpiMetricGrid(
                        isLoading: _isLoadingKpis,
                        items: [
                          KpiMetricItem(
                            label: 'Visitas Pend.',
                            value: '$_visitasPendientes',
                            icon: Icons.badge_outlined,
                            color: _visitasPendientes > 0
                                ? AppColors.warning
                                : AppColors.successDark,
                            helperText: _visitasPendientes > 0
                                ? 'En recepción'
                                : 'Sin pendientes',
                            onTap: () => _pushAndRefresh(
                              VisitasScreen(adminId: widget.userId),
                            ),
                          ),
                          KpiMetricItem(
                            label: 'Salones Libres',
                            value: _salonesTotal > 0
                                ? '$_salonesLibres/$_salonesTotal'
                                : '0',
                            icon: Icons.meeting_room_outlined,
                            color: AppColors.successDark,
                            helperText: 'Disponibles hoy',
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 1),
                            ),
                          ),
                          KpiMetricItem(
                            label: 'Accesos Rec.',
                            value: '$_accesosRecientes',
                            icon: Icons.swap_vert_circle_outlined,
                            color: AppColors.accentBlue,
                            onTap: () => _pushAndRefresh(
                              const EntradasSalidasScreen(),
                            ),
                          ),
                          KpiMetricItem(
                            label: 'Zonas Activas',
                            value: '$_totalZonas',
                            icon: Icons.security_outlined,
                            color: AppColors.primaryDark,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const SectionHeaderTitle(
                        icon: Icons.flash_on_outlined,
                        title: 'Recepción y Control',
                      ),
                      const SizedBox(height: 12),
                      ExecutiveActionGrid(
                        items: [
                          QuickActionItem(
                            label: 'Registrar\nVisita',
                            icon: Icons.person_add_outlined,
                            color: AppColors.primaryAction,
                            onTap: () => _pushAndRefresh(
                              RegistrarVisitaScreen(adminId: widget.userId),
                            ),
                          ),
                          QuickActionItem(
                            label: 'Ver\nVisitas',
                            icon: Icons.list_alt_outlined,
                            color: AppColors.successDark,
                            badge: _visitasPendientes > 0
                                ? _visitasPendientes
                                : null,
                            onTap: () => _pushAndRefresh(
                              VisitasScreen(adminId: widget.userId),
                            ),
                          ),
                          QuickActionItem(
                            label: 'Gestión\nInstitucional',
                            icon: Icons.account_balance_outlined,
                            color: AppColors.primaryDark,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(),
                            ),
                          ),
                          QuickActionItem(
                            label: 'Entradas\ny Salidas',
                            icon: Icons.swap_vert_circle_outlined,
                            color: AppColors.accentBlue,
                            onTap: () => _pushAndRefresh(
                              const EntradasSalidasScreen(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeaderTitle(
                        icon: Icons.apps_outlined,
                        title: 'Módulos Institucionales',
                      ),
                      const SizedBox(height: 10),
                      ResponsiveModuleGrid(
                        children: [
                          ExecutiveModuleCard(
                            icon: Icons.calendar_today_outlined,
                            title: 'Catálogos y Grupos',
                            description:
                                'Periodos escolares y altas de grupos académicos',
                            color: AppColors.primaryDark,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 0),
                            ),
                          ),
                          ExecutiveModuleCard(
                            icon: Icons.menu_book_outlined,
                            title: 'Oferta Académica y Salones',
                            description:
                                'Materias, clases, horarios, inscripciones y aulas',
                            color: AppColors.primaryAction,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 1),
                            ),
                          ),
                          ExecutiveModuleCard(
                            icon: Icons.assessment_outlined,
                            title: 'Reportes, Lizard y Auditoría',
                            description:
                                'Exportación Excel global y trazabilidad de acciones',
                            color: AppColors.accentBlue,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 3),
                            ),
                          ),
                          ExecutiveModuleCard(
                            icon: Icons.newspaper_outlined,
                            title: 'Noticias Institucionales',
                            description:
                                'Consulta de comunicados y avisos vigentes',
                            color: AppColors.primary,
                            onTap: () => _pushAndRefresh(
                              const NoticiasFeedScreen(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildInfoCard(),
                      const SizedBox(height: 30),
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoftBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: AppColors.primaryDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flujo de Pases de Visitantes',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Al registrar un visitante se genera su código QR de acceso inmediato que puedes compartir desde la app para control de entrada y salida en campus.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

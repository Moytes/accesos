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
import 'users_screen.dart';
import 'visitas_screen.dart';

class AdminScreen extends StatefulWidget {
  final String userId;
  final String? nombre;

  const AdminScreen({
    super.key,
    required this.userId,
    this.nombre,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final SessionService _sessionService = SessionService();
  final ApiService _apiService = ApiService();

  bool _isLoggingOut = false;
  bool _isLoadingKpis = true;
  int _totalUsuarios = 0;
  int _visitasPendientes = 0;
  int _accesosRecientes = 0;
  int _accesosDenegados = 0;
  int _lizardPendientes = 0;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    if (mounted) setState(() => _isLoadingKpis = true);
    try {
      final results = await Future.wait([
        _apiService.getAllUsers(),
        _apiService.contarVisitasPendientes(),
        _apiService.getAccess(limit: 50),
        _apiService.getPendientesLizard(),
      ]);

      if (!mounted) return;
      final users = results[0] as List<Map<String, dynamic>>;
      final visitasPend = results[1] as int;
      final accesos = results[2] as List<Map<String, dynamic>>;
      final lizard = results[3] as List<Map<String, dynamic>>;
      final denegados = accesos
          .where((a) => (a['tipo'] ?? '').toString().toLowerCase() == 'denegado')
          .length;

      setState(() {
        _totalUsuarios = users.length;
        _visitasPendientes = visitasPend;
        _accesosRecientes = accesos.length;
        _accesosDenegados = denegados;
        _lizardPendientes = lizard.length;
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
    if (clean.isEmpty) return 'Administrador';
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
                  roleBadge: 'ADMINISTRADOR',
                  roleBadgeColor: AppColors.badgeOrange,
                  orangePlusAccent: true,
                  gradientColors: const [
                    AppColors.primaryDark,
                    AppColors.primaryMid,
                  ],
                  greeting: 'Hola, ${_primerNombre(widget.nombre)}',
                  subtitle: 'Panel de Control · ${_fechaActual()}',
                  currentRole: 'admin',
                  userId: widget.userId,
                  nombre: widget.nombre,
                  isLoggingOut: _isLoggingOut,
                  onQrTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QRScreen(userId: widget.userId),
                    ),
                  ),
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
                ),
                ResponsiveContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      const SectionHeaderTitle(
                        icon: Icons.analytics_outlined,
                        title: 'Resumen Operativo',
                        subtitle: 'Desliza hacia abajo para actualizar métricas',
                      ),
                      const SizedBox(height: 12),
                      KpiMetricGrid(
                        isLoading: _isLoadingKpis,
                        items: [
                          KpiMetricItem(
                            label: 'Usuarios',
                            value: '$_totalUsuarios',
                            icon: Icons.people_alt_outlined,
                            color: AppColors.primaryDark,
                            onTap: () => _pushAndRefresh(const UsersScreen()),
                          ),
                          KpiMetricItem(
                            label: 'Visitas Pend.',
                            value: '$_visitasPendientes',
                            icon: Icons.badge_outlined,
                            color: _visitasPendientes > 0
                                ? AppColors.warning
                                : AppColors.successDark,
                            helperText: _visitasPendientes > 0
                                ? 'Por atender'
                                : 'Al día',
                            onTap: () => _pushAndRefresh(
                              VisitasScreen(adminId: widget.userId),
                            ),
                          ),
                          KpiMetricItem(
                            label: 'Accesos Rec.',
                            value: '$_accesosRecientes',
                            icon: Icons.swap_vert_circle_outlined,
                            color: AppColors.accentBlue,
                            helperText: _accesosDenegados > 0
                                ? '$_accesosDenegados denegados'
                                : 'Sin alertas',
                            onTap: () => _pushAndRefresh(
                              const EntradasSalidasScreen(),
                            ),
                          ),
                          KpiMetricItem(
                            label: 'Sync Lizard',
                            value: '$_lizardPendientes',
                            icon: Icons.sync_outlined,
                            color: _lizardPendientes > 0
                                ? AppColors.dangerRed
                                : AppColors.success,
                            helperText: _lizardPendientes > 0
                                ? 'Pendientes'
                                : 'Sincronizado',
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const SectionHeaderTitle(
                        icon: Icons.bolt_rounded,
                        title: 'Acciones Rápidas',
                      ),
                      const SizedBox(height: 12),
                      ExecutiveActionGrid(
                        items: [
                          QuickActionItem(
                            label: 'Gestionar\nUsuarios',
                            icon: Icons.person_add_alt_1_outlined,
                            color: AppColors.primaryDark,
                            onTap: () => _pushAndRefresh(const UsersScreen()),
                          ),
                          QuickActionItem(
                            label: 'Entradas\ny Salidas',
                            icon: Icons.fact_check_outlined,
                            color: AppColors.primaryAction,
                            onTap: () => _pushAndRefresh(
                              const EntradasSalidasScreen(),
                            ),
                          ),
                          QuickActionItem(
                            label: 'Registrar\nVisita',
                            icon: Icons.qr_code_scanner,
                            color: AppColors.successDark,
                            badge: _visitasPendientes > 0
                                ? _visitasPendientes
                                : null,
                            onTap: () => _pushAndRefresh(
                              RegistrarVisitaScreen(adminId: widget.userId),
                            ),
                          ),
                          QuickActionItem(
                            label: 'Gestión\nAcadémica',
                            icon: Icons.school_outlined,
                            color: AppColors.accentBlue,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeaderTitle(
                        icon: Icons.security_outlined,
                        title: 'Operación y Control de Accesos',
                      ),
                      const SizedBox(height: 10),
                      ResponsiveModuleGrid(
                        children: [
                          ExecutiveModuleCard(
                            icon: Icons.people_outline,
                            title: 'Usuarios y Multi-Rol',
                            description:
                                'Altas, roles institucionales, matrículas y estatus',
                            color: AppColors.primaryDark,
                            onTap: () => _pushAndRefresh(const UsersScreen()),
                          ),
                          ExecutiveModuleCard(
                            icon: Icons.door_sliding_outlined,
                            title: 'Entradas, Salidas y Denegaciones',
                            description:
                                'Bitácora por zona, motivos de rechazo y Excel',
                            color: AppColors.primary,
                            onTap: () => _pushAndRefresh(
                              const EntradasSalidasScreen(),
                            ),
                          ),
                          ExecutiveModuleCard(
                            icon: Icons.badge_outlined,
                            title: 'Control de Visitas',
                            description:
                                'Pases QR vigentes, seguimiento y cancelaciones',
                            color: AppColors.successDark,
                            badgeCount: _visitasPendientes,
                            onTap: () => _pushAndRefresh(
                              VisitasScreen(adminId: widget.userId),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const SectionHeaderTitle(
                        icon: Icons.account_balance_outlined,
                        title: 'Institución, Infraestructura y Cumplimiento',
                      ),
                      const SizedBox(height: 10),
                      ResponsiveModuleGrid(
                        children: [
                          ExecutiveModuleCard(
                            icon: Icons.calendar_today_outlined,
                            title: 'Catálogos: Periodos y Grupos',
                            description:
                                'Ciclos escolares activos y grupos académicos',
                            color: AppColors.primaryDark,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 0),
                            ),
                          ),
                          ExecutiveModuleCard(
                            icon: Icons.menu_book_outlined,
                            title: 'Oferta Académica y Salones',
                            description:
                                'Materias, clases, horarios, tutores y aulas',
                            color: AppColors.primaryAction,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 1),
                            ),
                          ),
                          ExecutiveModuleCard(
                            icon: Icons.sensors_outlined,
                            title: 'Zonas y Lectores IoT',
                            description:
                                'Reglas de acceso por rol y claves X-Device-Key',
                            color: AppColors.accentBlue,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 2),
                            ),
                          ),
                          ExecutiveModuleCard(
                            icon: Icons.history_edu_outlined,
                            title: 'Lizard Sync y Auditoría',
                            description:
                                'Calificaciones pendientes, reporte global y bitácora',
                            color: AppColors.warning,
                            badgeCount: _lizardPendientes,
                            onTap: () => _pushAndRefresh(
                              const GestionInstitucionalScreen(initialTab: 3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const SectionHeaderTitle(
                        icon: Icons.campaign_outlined,
                        title: 'Comunicación Institucional',
                      ),
                      const SizedBox(height: 10),
                      ResponsiveModuleGrid(
                        children: [
                          ExecutiveModuleCard(
                            icon: Icons.newspaper_outlined,
                            title: 'Noticias y Marketing',
                            description:
                                'Publicar comunicados, avisos y portadas oficiales',
                            color: AppColors.primary,
                            onTap: () => _pushAndRefresh(
                              MarketingDashboardScreen(
                                userId: widget.userId,
                                nombre: widget.nombre,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

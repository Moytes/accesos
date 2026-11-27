import 'package:flutter/material.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/alumnos.dart';
import '../screens/homeprofesor.dart';
import '../screens/noticias_screen.dart';
import '../screens/psicologia_screens.dart';
import '../screens/qralumnos.dart';
import '../screens/seguridad_screen.dart';
import '../service/session_service.dart';
import '../theme/app_colors.dart';

/// Enrutador centralizado para los 8 roles oficiales del Backend v2.
class RoleRouter {
  RoleRouter._();

  static Widget buildHomeForRole({
    required String rol,
    required String userId,
    String? nombre,
  }) {
    switch (rol.trim().toLowerCase()) {
      case 'alumno':
        return AsistenciasScreen(userId: userId, nombre: nombre);
      case 'profesor':
        return ProfessorDashboard(
          userId: userId,
          nombre: nombre,
          rol: 'Profesor',
        );
      case 'tutor':
        return ProfessorDashboard(
          userId: userId,
          nombre: nombre,
          rol: 'Tutor',
        );
      case 'admin':
        return AdminScreen(userId: userId, nombre: nombre);
      case 'administrativo':
        return AdminPanelScreen(userId: userId, nombre: nombre);
      case 'seguridad':
        return SeguridadScreen(userId: userId, nombre: nombre);
      case 'psicologo':
        return PsicologoDashboardScreen(userId: userId, nombre: nombre);
      case 'marketing':
        return MarketingDashboardScreen(userId: userId, nombre: nombre);
      default:
        return AsistenciasScreen(userId: userId, nombre: nombre);
    }
  }

  static void navigateToRoleHome(
    BuildContext context, {
    required String rol,
    required String userId,
    String? nombre,
    bool replaceAll = true,
  }) {
    final destino = buildHomeForRole(rol: rol, userId: userId, nombre: nombre);
    if (replaceAll) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destino),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destino),
      );
    }
  }
}

/// Selector rápido en AppBar cuando un usuario tiene múltiples roles asignados.
class RoleSwitcherButton extends StatelessWidget {
  final String currentRole;
  final String userId;
  final String? nombre;
  final Color iconColor;

  const RoleSwitcherButton({
    super.key,
    required this.currentRole,
    required this.userId,
    this.nombre,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final roles = SessionService().roles;
    if (roles.length <= 1) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Cambiar de rol activo',
      icon: Icon(Icons.swap_horiz_rounded, color: iconColor),
      onSelected: (nuevoRol) async {
        if (nuevoRol.toLowerCase() == currentRole.toLowerCase()) return;
        await SessionService().switchActiveRole(nuevoRol);
        if (!context.mounted) return;
        RoleRouter.navigateToRoleHome(
          context,
          rol: nuevoRol,
          userId: userId,
          nombre: nombre ?? SessionService().nombre,
        );
      },
      itemBuilder: (ctx) => roles.map((r) {
        final selected = r.toLowerCase() == currentRole.toLowerCase();
        return PopupMenuItem<String>(
          value: r,
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                formatRoleLabel(r),
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import '../navigation/role_router.dart';
import '../service/connectivity_service.dart';
import '../theme/app_colors.dart';
import 'common_widgets.dart';

/// Contenedor responsivo que centra contenido en tablets/paisaje y ajusta márgenes en móviles.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.padding,
  });

  static double horizontalPaddingForWidth(double width) {
    if (width < 360) return 12;
    if (width >= 600) return 24;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = horizontalPaddingForWidth(constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding ?? EdgeInsets.symmetric(horizontal: hPad),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Barra de encabezado ejecutiva y responsiva (cero overflows desde 320dp hasta tablet).
class ExecutiveHeaderBar extends StatelessWidget {
  final String roleBadge;
  final Color roleBadgeColor;
  final String greeting;
  final String subtitle;
  final bool orangePlusAccent;
  final List<Color> gradientColors;
  final String currentRole;
  final String userId;
  final String? nombre;
  final VoidCallback onProfileTap;
  final VoidCallback? onQrTap;
  final VoidCallback onLogoutTap;
  final bool isLoggingOut;
  final Widget? bottomCard;

  const ExecutiveHeaderBar({
    super.key,
    required this.roleBadge,
    this.roleBadgeColor = AppColors.badgeOrange,
    required this.greeting,
    required this.subtitle,
    this.orangePlusAccent = false,
    this.gradientColors = const [AppColors.primaryDark, AppColors.primaryMid],
    required this.currentRole,
    required this.userId,
    this.nombre,
    required this.onProfileTap,
    this.onQrTap,
    required this.onLogoutTap,
    this.isLoggingOut = false,
    this.bottomCard,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final hPad = ResponsiveContainer.horizontalPaddingForWidth(
          constraints.maxWidth,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: orangePlusAccent
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradientColors,
                        ),
                      ),
                    )
                  : SafeHeaderBanner(
                      height: bottomCard != null ? 300 : 210,
                      gradientColors: gradientColors,
                    ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: orangePlusAccent
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'CONTROL',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.4,
                                            ),
                                          ),
                                          Text(
                                            '+',
                                            style: TextStyle(
                                              color: AppColors.badgeOrange,
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'CONTROL+',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 23,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.6,
                                        ),
                                      ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ConnectivityPill(compact: compact),
                                RoleSwitcherButton(
                                  currentRole: currentRole,
                                  userId: userId,
                                  nombre: nombre,
                                ),
                                if (onQrTap != null)
                                  _CompactHeaderIcon(
                                    icon: Icons.qr_code_2,
                                    tooltip: 'Mi Código QR',
                                    onPressed: onQrTap!,
                                  ),
                                _CompactHeaderIcon(
                                  icon: Icons.account_circle_outlined,
                                  tooltip: 'Mi Perfil',
                                  onPressed: onProfileTap,
                                ),
                                _CompactHeaderIcon(
                                  icon: Icons.logout_rounded,
                                  tooltip: 'Cerrar sesión',
                                  isLoading: isLoggingOut,
                                  onPressed: isLoggingOut ? null : onLogoutTap,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: roleBadgeColor.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: roleBadgeColor.withOpacity(0.85),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      roleBadge,
                                      style: TextStyle(
                                        color: roleBadgeColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    greeting,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: compact ? 18 : 21,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.82),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (bottomCard != null) ...[
                          const SizedBox(height: 14),
                          bottomCard!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompactHeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _CompactHeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(icon, color: Colors.white, size: 23),
    );
  }
}

class _ConnectivityPill extends StatelessWidget {
  final bool compact;

  const _ConnectivityPill({required this.compact});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService().isOnline,
      builder: (context, isOnline, _) {
        final color = isOnline ? AppColors.success : AppColors.warning;
        return Container(
          margin: const EdgeInsets.only(right: 4),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 9,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.75)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: Colors.white,
                size: 13,
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'En línea' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class KpiMetricItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? helperText;
  final VoidCallback? onTap;

  const KpiMetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.helperText,
    this.onTap,
  });
}

/// Cuadrícula responsiva de indicadores KPI (2 cols móvil, 4 cols tablet/paisaje).
class KpiMetricGrid extends StatelessWidget {
  final List<KpiMetricItem> items;
  final bool isLoading;

  const KpiMetricGrid({
    super.key,
    required this.items,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 600 ? 4 : 2;
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (cols - 1))) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 0,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primaryDark.withOpacity(0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: item.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                item.icon,
                                size: 18,
                                color: item.color,
                              ),
                            ),
                            const Spacer(),
                            if (item.onTap != null)
                              Icon(
                                Icons.arrow_outward_rounded,
                                size: 15,
                                color: Colors.grey[400],
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isLoading ? '...' : item.value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (item.helperText != null &&
                            item.helperText!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.helperText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: item.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class QuickActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const QuickActionItem({
    required this.label,
    required this.icon,
    required this.color,
    this.badge,
    required this.onTap,
  });
}

/// Botones de acceso rápido con degradado institucional (2 cols móvil, 4 cols tablet).
class ExecutiveActionGrid extends StatelessWidget {
  final List<QuickActionItem> items;

  const ExecutiveActionGrid({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 600 ? 4 : 2;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (cols - 1))) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [item.color, item.color.withOpacity(0.84)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withOpacity(0.26),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                item.icon,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (item.badge != null && item.badge! > 0)
                          Positioned(
                            top: -4,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.badgeOrange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.badge! > 99 ? '99+' : '${item.badge}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class SectionHeaderTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  const SectionHeaderTitle({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ExecutiveModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final int? badgeCount;
  final VoidCallback onTap;

  const ExecutiveModuleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.color = AppColors.primaryDark,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryDark.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        if (badgeCount != null && badgeCount! > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.badgeOrange.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB26A00),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Organiza ExecutiveModuleCard en 1 columna en móvil y 2 columnas en tablet/horizontal.
class ResponsiveModuleGrid extends StatelessWidget {
  final List<ExecutiveModuleCard> children;

  const ResponsiveModuleGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 600 ? 2 : 1;
        if (cols == 1) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((c) => SizedBox(width: width, child: c))
              .toList(),
        );
      },
    );
  }
}

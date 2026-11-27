import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/app_permissions_service.dart';
import '../service/connectivity_service.dart';
import '../service/session_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';
import 'qralumnos.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String? nombre;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.nombre,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivity = ConnectivityService();

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _sesiones = [];
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _isLoading = true);

    Map<String, dynamic>? profile = await _apiService.getMe();
    profile ??= await _apiService.getUserById(widget.userId);

    List<Map<String, dynamic>> sesiones = [];
    if (_connectivity.isOnline.value) {
      sesiones = await _apiService.getSesionesActivas();
    }

    if (!mounted) return;
    final session = SessionService();
    setState(() {
      _userData = profile ??
          {
            'id': widget.userId,
            'nombre': widget.nombre ?? session.nombre ?? 'Usuario',
            'rol': session.rol ?? 'alumno',
            'roles': session.roles,
            'matricula': session.matricula,
            'numero_empleado': session.numeroEmpleado,
            'grupo': session.grupo,
            'imagen_url': session.imagenUrl,
          };
      _sesiones = sesiones;
      _isLoading = false;
    });
  }

  Future<void> _cambiarAvatar() async {
    if (!_connectivity.isOnline.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas conexión a internet para subir tu foto de perfil.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final picked = await AppPermissionsService.showAttachmentPickerSheet(
      context,
      allowPdf: false,
      allowMultiple: false,
      maxBytes: AppPermissionsService.maxAvatarBytes,
      title: 'Actualizar foto de perfil',
    );
    if (picked.isEmpty || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    final file = picked.first;
    final newUrl = await _apiService.uploadAvatar(file.bytes, file.fileName);

    if (!mounted) return;
    setState(() => _isUploadingAvatar = false);

    if (newUrl != null && newUrl.isNotEmpty) {
      await SessionService().actualizarSesion(imagenUrl: newUrl);
      await _cargarPerfil();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto de perfil actualizada correctamente.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiService.lastError ?? 'No se pudo actualizar la foto de perfil.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  Future<void> _cerrarSesion({required bool allDevices}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          allDevices
              ? '¿Cerrar todas las sesiones?'
              : '¿Cerrar sesión?',
        ),
        content: Text(
          allDevices
              ? 'Se invalidarán todas tus sesiones activas en otros teléfonos o tabletas.'
              : 'Se cerrará tu sesión en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: Text(allDevices ? 'Cerrar todas' : 'Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    await _apiService.logout(widget.userId, allDevices: allDevices);
    await SessionService().endSession();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  List<String> _extractRoles() {
    final raw = _userData?['roles'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    if (SessionService().roles.isNotEmpty) {
      return SessionService().roles;
    }
    final rol = _userData?['rol']?.toString() ?? SessionService().rol;
    return rol != null && rol.isNotEmpty ? [rol] : const [];
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'N/D';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return raw.toString();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _userData?['nombre']?.toString() ??
        widget.nombre ??
        SessionService().nombre ??
        'Usuario';
    final correo = _userData?['correo']?.toString() ?? 'No disponible';
    final rolPrincipal = _userData?['rol']?.toString() ??
        SessionService().rol ??
        'alumno';
    final matricula = _userData?['matricula']?.toString();
    final numeroEmpleado = (_userData?['numero_empleado'] ??
            _userData?['numeroEmpleado'] ??
            SessionService().numeroEmpleado)
        ?.toString();
    final grupo = _userData?['grupo']?.toString() ?? SessionService().grupo;
    final estatus = _userData?['estatus']?.toString() ?? 'activo';
    final imagenUrl =
        _userData?['imagen_url']?.toString() ?? SessionService().imagenUrl;
    final roles = _extractRoles();

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        body: RefreshIndicator(
          onRefresh: _cargarPerfil,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 265,
                  child: Stack(
                    children: [
                      SafeHeaderBanner(
                        imageUrl: imagenUrl,
                        height: 235,
                        gradientColors: const [
                          Color(0xD9003366),
                          Color(0x99004C8C),
                        ],
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Mi Perfil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'CONTROL+',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 106,
                                height: 106,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: SafeNetworkImage(
                                    url: imagenUrl,
                                    width: 98,
                                    height: 98,
                                    fallback: Container(
                                      color: AppColors.primaryDark,
                                      alignment: Alignment.center,
                                      child: Text(
                                        nombre.isNotEmpty
                                            ? nombre[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 38,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploadingAvatar
                                      ? null
                                      : _cambiarAvatar,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.badgeGold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isUploadingAvatar
                                        ? const Padding(
                                            padding: EdgeInsets.all(7),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primaryDark,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt,
                                            size: 18,
                                            color: AppColors.primaryDark,
                                          ),
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
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Center(
                        child: Text(
                          nombre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: roles
                              .map(
                                (r) => Chip(
                                  label: Text(
                                    formatRoleLabel(r),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  backgroundColor:
                                      r.toLowerCase() ==
                                              rolPrincipal.toLowerCase()
                                          ? AppColors.badgeGold.withOpacity(0.35)
                                          : AppColors.surfaceSoftBlue,
                                  side: BorderSide(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Card de Información Institucional
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Información de Cuenta',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const Divider(height: 20),
                            _infoRow(Icons.email_outlined, 'Correo', correo),
                            if (matricula != null && matricula.trim().isNotEmpty)
                              _infoRow(
                                Icons.badge_outlined,
                                'Matrícula',
                                matricula,
                              ),
                            if (numeroEmpleado != null &&
                                numeroEmpleado.trim().isNotEmpty)
                              _infoRow(
                                Icons.work_outline,
                                'No. Empleado',
                                numeroEmpleado,
                              ),
                            if (grupo != null && grupo.trim().isNotEmpty)
                              _infoRow(
                                Icons.groups_outlined,
                                'Grupo',
                                grupo,
                              ),
                            _infoRow(
                              Icons.verified_outlined,
                              'Estatus',
                              estatus.toUpperCase(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Card de Sesiones Activas
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.devices,
                                  size: 20,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sesiones Activas',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_sesiones.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            if (!_connectivity.isOnline.value)
                              Text(
                                'Modo sin conexión: las sesiones activas se consultan al reconectarte.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              )
                            else if (_sesiones.isEmpty)
                              Text(
                                'Solo esta sesión activa registrada.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              )
                            else
                              ..._sesiones.map((s) {
                                final isCurrent =
                                    s['id']?.toString() ==
                                        SessionService().sessionId ||
                                    s['actual'] == true;
                                final device = (s['device_info'] ??
                                        s['deviceInfo'] ??
                                        'Dispositivo móvil')
                                    .toString();
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCurrent
                                            ? Icons.phone_android
                                            : Icons.devices_other,
                                        size: 20,
                                        color: isCurrent
                                            ? AppColors.success
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              device,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            Text(
                                              'Inicio: ${_formatDate(s['created_at'] ?? s['createdAt'])}',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.success
                                                .withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'Actual',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.successDark,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoggingOut
                              ? null
                              : () => _cerrarSesion(allDevices: false),
                          icon: const Icon(Icons.logout),
                          label: Text(
                            _isLoggingOut
                                ? 'Cerrando sesión...'
                                : 'Cerrar sesión',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dangerRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isLoggingOut || !_connectivity.isOnline.value
                              ? null
                              : () => _cerrarSesion(allDevices: true),
                          icon: const Icon(Icons.phonelink_erase),
                          label: const Text(
                            'Cerrar sesión en todos los dispositivos',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.primaryDark),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/connectivity_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import 'qralumnos.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> allRoles = [
    'alumno',
    'profesor',
    'tutor',
    'admin',
    'administrativo',
    'seguridad',
    'psicologo',
    'marketing',
  ];

  static const List<String> allStatuses = [
    'activo',
    'suspendido',
    'egresado',
    'baja',
  ];

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _grupos = [];
  bool _isLoading = true;
  String _search = '';
  String _roleFilter = 'todos';
  String _statusFilter = 'todos';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getAllUsers(),
      _apiService.getGruposCatalogo(),
    ]);
    if (!mounted) return;
    setState(() {
      _users = results[0];
      _grupos = results[1];
      _isLoading = false;
    });
  }

  List<String> _extractUserRoles(Map<String, dynamic> u) {
    final raw = u['roles'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString().toLowerCase()).toList();
    }
    final r = (u['rol'] ?? 'alumno').toString().toLowerCase();
    return [r];
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _search.trim().toLowerCase();
    return _users.where((u) {
      final roles = _extractUserRoles(u);
      final estatus = (u['estatus'] ?? 'activo').toString().toLowerCase();
      if (_roleFilter != 'todos' && !roles.contains(_roleFilter)) return false;
      if (_statusFilter != 'todos' && estatus != _statusFilter) return false;
      if (q.isEmpty) return true;
      final nom = (u['nombre'] ?? '').toString().toLowerCase();
      final cor = (u['correo'] ?? '').toString().toLowerCase();
      final mat = (u['matricula'] ?? '').toString().toLowerCase();
      final emp = (u['numero_empleado'] ?? u['numeroEmpleado'] ?? '')
          .toString()
          .toLowerCase();
      return nom.contains(q) ||
          cor.contains(q) ||
          mat.contains(q) ||
          emp.contains(q);
    }).toList();
  }

  Future<void> _openUserModal([Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final nombreCtrl = TextEditingController(
      text: existing?['nombre']?.toString() ?? '',
    );
    final correoCtrl = TextEditingController(
      text: existing?['correo']?.toString() ?? '',
    );
    final passCtrl = TextEditingController();
    final matriculaCtrl = TextEditingController(
      text: existing?['matricula']?.toString() ?? '',
    );
    final empleadoCtrl = TextEditingController(
      text: (existing?['numero_empleado'] ?? existing?['numeroEmpleado'] ?? '')
          .toString(),
    );
    final grupoManualCtrl = TextEditingController(
      text: existing?['grupo']?.toString() ?? '',
    );

    String primaryRole =
        (existing?['rol'] ?? 'alumno').toString().toLowerCase();
    if (!allRoles.contains(primaryRole)) primaryRole = 'alumno';

    final selectedRoles = existing != null
        ? _extractUserRoles(existing).toSet()
        : <String>{primaryRole};
    selectedRoles.add(primaryRole);

    String? selectedGrupoId =
        (existing?['grupo_id'] ?? existing?['grupoId'])?.toString();
    String estatus =
        (existing?['estatus'] ?? 'activo').toString().toLowerCase();
    if (!allStatuses.contains(estatus)) estatus = 'activo';
    bool activo = (existing?['activo'] ?? 1) != 0;

    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isStudent = selectedRoles.contains('alumno');
          final isStaff = selectedRoles.any((r) => r != 'alumno');

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Editar Usuario' : 'Nuevo Usuario',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nombre requerido'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo institucional',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final email = (v ?? '').trim();
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Ingresa un correo electrónico válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEdit
                            ? 'Nueva contraseña (opcional)'
                            : 'Contraseña inicial',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (!isEdit && (v == null || v.length < 6)) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: primaryRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol principal',
                        border: OutlineInputBorder(),
                      ),
                      items: allRoles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(formatRoleLabel(r)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() {
                            primaryRole = v;
                            selectedRoles.add(v);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Roles asignados (multi-rol):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: allRoles.map((r) {
                        final checked = selectedRoles.contains(r);
                        return FilterChip(
                          label: Text(
                            formatRoleLabel(r),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          selected: checked,
                          selectedColor: AppColors.primary.withOpacity(0.18),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedRoles.add(r);
                              } else if (selectedRoles.length > 1) {
                                selectedRoles.remove(r);
                                if (primaryRole == r) {
                                  primaryRole = selectedRoles.first;
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (isStudent) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: matriculaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Matrícula',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_grupos.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: _grupos.any(
                            (g) => g['id']?.toString() == selectedGrupoId,
                          )
                              ? selectedGrupoId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Grupo catálogo',
                            border: OutlineInputBorder(),
                          ),
                          items: _grupos
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g['id']?.toString() ?? '',
                                  child: Text(
                                    '${g['codigo'] ?? ''} ${g['carrera'] ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setModalState(() {
                              selectedGrupoId = v;
                              final found = _grupos.firstWhere(
                                (g) => g['id']?.toString() == v,
                                orElse: () => {},
                              );
                              if (found['codigo'] != null) {
                                grupoManualCtrl.text =
                                    found['codigo'].toString();
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: grupoManualCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Código de grupo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (isStaff) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: empleadoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Número de empleado',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: estatus,
                            decoration: const InputDecoration(
                              labelText: 'Estatus',
                              border: OutlineInputBorder(),
                            ),
                            items: allStatuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.toUpperCase()),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() {
                                  estatus = v;
                                  activo = v == 'activo';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            const Text('Activo', style: TextStyle(fontSize: 12)),
                            Switch(
                              value: activo,
                              onChanged: (v) =>
                                  setModalState(() => activo = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                if (!ConnectivityService().isOnline.value) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Se requiere conexión a internet para guardar usuarios.',
                                      ),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                bool ok = false;
                                if (isEdit) {
                                  final uid = existing['id'].toString();
                                  ok = await _apiService.updateUser(
                                    userId: uid,
                                    nombre: nombreCtrl.text.trim(),
                                    correo: correoCtrl.text.trim(),
                                    password: passCtrl.text.isNotEmpty
                                        ? passCtrl.text
                                        : null,
                                    rol: primaryRole,
                                    roles: selectedRoles.toList(),
                                    matricula: matriculaCtrl.text.trim(),
                                    numeroEmpleado: empleadoCtrl.text.trim(),
                                    grupo: grupoManualCtrl.text.trim(),
                                    grupoId: selectedGrupoId,
                                    activo: activo ? 1 : 0,
                                    estatus: estatus,
                                  );
                                  if (ok) {
                                    await _apiService.updateUserRoles(
                                      uid,
                                      selectedRoles.toList(),
                                    );
                                  }
                                } else {
                                  final created = await _apiService.createUser(
                                    nombre: nombreCtrl.text.trim(),
                                    correo: correoCtrl.text.trim(),
                                    password: passCtrl.text,
                                    rol: primaryRole,
                                    roles: selectedRoles.toList(),
                                    matricula: matriculaCtrl.text.trim(),
                                    numeroEmpleado: empleadoCtrl.text.trim(),
                                    grupo: grupoManualCtrl.text.trim(),
                                    grupoId: selectedGrupoId,
                                    activo: activo ? 1 : 0,
                                    estatus: estatus,
                                  );
                                  ok = created != null;
                                }

                                if (!ctx.mounted) return;
                                setModalState(() => saving = false);

                                if (ok) {
                                  Navigator.pop(ctx);
                                  await _cargar();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEdit
                                            ? 'Usuario actualizado.'
                                            : 'Usuario creado correctamente.',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _apiService.lastError ??
                                            'Error guardando usuario.',
                                      ),
                                      backgroundColor: AppColors.dangerRed,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(saving ? 'Guardando...' : 'Guardar Usuario'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _eliminar(Map<String, dynamic> u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar / Eliminar usuario'),
        content: Text(
          '¿Confirmas desactivar a ${u['nombre']} (${u['correo']})?',
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
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok = await _apiService.deleteUser(u['id'].toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Usuario eliminado / desactivado.'
              : (_apiService.lastError ?? 'No se pudo eliminar.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.dangerRed,
      ),
    );
    if (ok) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredUsers;
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: Text('Usuarios (${_users.length})'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openUserModal(),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Nuevo'),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, correo, matrícula...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _roleChip('todos', 'Todos'),
                        ...allRoles.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _roleChip(r, formatRoleLabel(r)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _statusChip('todos', 'Todos estatus'),
                        ...allStatuses.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _statusChip(s, s.toUpperCase()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final u = items[i];
                          final roles = _extractUserRoles(u);
                          final mat = u['matricula']?.toString();
                          final emp = (u['numero_empleado'] ??
                                  u['numeroEmpleado'])
                              ?.toString();
                          final est =
                              (u['estatus'] ?? 'activo').toString().toLowerCase();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              onTap: () => _openUserModal(u),
                              leading: CircleAvatar(
                                backgroundColor: est == 'activo'
                                    ? AppColors.primaryDark
                                    : Colors.grey,
                                child: Text(
                                  (u['nombre']?.toString() ?? 'U')
                                          .isNotEmpty
                                      ? u['nombre']
                                          .toString()[0]
                                          .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                (u['nombre'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (u['correo'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  if (mat != null && mat.isNotEmpty)
                                    Text(
                                      'Matrícula: $mat · Grupo ${u['grupo'] ?? ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  if (emp != null && emp.isNotEmpty)
                                    Text(
                                      'No. Empleado: $emp',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: roles
                                        .map(
                                          (r) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceSoftBlue,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              formatRoleLabel(r),
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.dangerRed,
                                ),
                                onPressed: () => _eliminar(u),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String value, String label) {
    final selected = _roleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primaryDark,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _roleFilter = value),
    );
  }

  Widget _statusChip(String value, String label) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primaryDark,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }
}

import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui_components.dart';
import 'qralumnos.dart';

class GestionInstitucionalScreen extends StatefulWidget {
  final int initialTab;

  const GestionInstitucionalScreen({super.key, this.initialTab = 0});

  @override
  State<GestionInstitucionalScreen> createState() =>
      _GestionInstitucionalScreenState();
}

class _GestionInstitucionalScreenState
    extends State<GestionInstitucionalScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _periodos = [];
  List<Map<String, dynamic>> _grupos = [];
  List<Map<String, dynamic>> _zonas = [];
  List<Map<String, dynamic>> _dispositivos = [];
  List<Map<String, dynamic>> _lizardPendientes = [];
  List<Map<String, dynamic>> _auditoria = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _salones = [];
  List<Map<String, dynamic>> _materiasCatalogo = [];

  final Set<String> _selectedLizardIds = {};

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _isLoading = true);
    final res = await Future.wait([
      _api.getPeriodos(),
      _api.getGruposCatalogo(),
      _api.getZonas(),
      _api.getDispositivosIot(),
      _api.getPendientesLizard(),
      _api.getBitacoraAuditoria(),
      _api.getAllUsers(),
      _api.getSalonesConEstado(),
    ]);

    final users = res[6];
    final materias = await _cargarCatalogoMaterias(users);

    if (!mounted) return;
    setState(() {
      _periodos = res[0];
      _grupos = res[1];
      _zonas = res[2];
      _dispositivos = res[3];
      _lizardPendientes = res[4];
      _auditoria = res[5];
      _users = users;
      _salones = res[7];
      _materiasCatalogo = materias;
      _selectedLizardIds.clear();
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _cargarCatalogoMaterias(
    List<Map<String, dynamic>> users,
  ) async {
    final profIds = <String>{};
    for (final u in users) {
      final rol = (u['rol'] ?? '').toString().toLowerCase();
      final rolesList = u['roles'] is List
          ? (u['roles'] as List).map((e) => e.toString().toLowerCase()).toList()
          : <String>[];
      if (rol == 'profesor' ||
          rol == 'tutor' ||
          rolesList.contains('profesor') ||
          rolesList.contains('tutor')) {
        final id = u['id']?.toString() ?? '';
        if (id.isNotEmpty) profIds.add(id);
      }
    }
    if (profIds.isEmpty) return [];

    final batches = await Future.wait(
      profIds.map((pid) => _api.getMateriasByProfesor(pid)),
    );
    final porId = <String, Map<String, dynamic>>{};
    for (final list in batches) {
      for (final m in list) {
        final id = (m['id'] ?? '').toString();
        if (id.isNotEmpty) porId[id] = m;
      }
    }
    final result = porId.values.toList()
      ..sort(
        (a, b) => (a['nombre'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['nombre'] ?? '').toString().toLowerCase()),
      );
    return result;
  }

  List<Map<String, dynamic>> _filtrarUsuariosPorRol(Set<String> targetRoles) {
    return _users.where((u) {
      final rol = (u['rol'] ?? '').toString().toLowerCase();
      if (targetRoles.contains(rol)) return true;
      if (u['roles'] is List) {
        for (final r in u['roles'] as List) {
          if (targetRoles.contains(r.toString().toLowerCase())) return true;
        }
      }
      return false;
    }).toList();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.dangerRed : AppColors.success,
      ),
    );
  }

  Future<bool?> _showFormSheet({
    required String title,
    String? subtitle,
    required String submitLabel,
    required Widget Function(BuildContext ctx, StateSetter setModalState) builder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  builder(ctx, setModalState),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(submitLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── ACCIONES CATÁLOGOS ─────────────────────────────────────────────────

  Future<void> _nuevoPeriodoDialog() async {
    final codCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final iniCtrl = TextEditingController(text: '2026-09-01');
    final finCtrl = TextEditingController(text: '2026-12-18');
    bool activo = true;

    final ok = await _showFormSheet(
      title: 'Nuevo Periodo Escolar',
      submitLabel: 'Crear Periodo',
      builder: (ctx, setDlg) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codCtrl,
            decoration: const InputDecoration(
              labelText: 'Código (ej. 2026-3)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nomCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre (ej. Sep-Dic 2026)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: iniCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Inicio (yyyy-MM-dd)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: finCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fin (yyyy-MM-dd)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activar al crear'),
            value: activo,
            onChanged: (v) => setDlg(() => activo = v),
          ),
        ],
      ),
    );
    if (ok == true) {
      final created = await _api.crearPeriodo(
        codigo: codCtrl.text.trim(),
        nombre: nomCtrl.text.trim(),
        fechaInicio: iniCtrl.text.trim(),
        fechaFin: finCtrl.text.trim(),
        activo: activo,
      );
      if (created != null) {
        _snack('Periodo creado.');
        _cargarTodo();
      } else {
        _snack(_api.lastError ?? 'No se pudo crear periodo.', error: true);
      }
    }
  }

  Future<void> _nuevoGrupoDialog() async {
    final codCtrl = TextEditingController();
    final carCtrl = TextEditingController();
    String? periodoId =
        _periodos.isNotEmpty ? _periodos.first['id']?.toString() : null;

    final ok = await _showFormSheet(
      title: 'Nuevo Grupo Académico',
      submitLabel: 'Crear Grupo',
      builder: (ctx, setDlg) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codCtrl,
            decoration: const InputDecoration(
              labelText: 'Código (ej. IDGS101)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: carCtrl,
            decoration: const InputDecoration(
              labelText: 'Carrera',
              border: OutlineInputBorder(),
            ),
          ),
          if (_periodos.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: periodoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Periodo',
                border: OutlineInputBorder(),
              ),
              items: _periodos
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id'].toString(),
                      child: Text(
                        p['nombre']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setDlg(() => periodoId = v),
            ),
          ],
        ],
      ),
    );
    if (ok == true) {
      final created = await _api.crearGrupoCatalogo(
        codigo: codCtrl.text.trim(),
        carrera: carCtrl.text.trim(),
        periodoId: periodoId,
      );
      if (created != null) {
        _snack('Grupo creado.');
        _cargarTodo();
      } else {
        _snack(_api.lastError ?? 'Error al crear grupo.', error: true);
      }
    }
  }

  // ─── ACCIONES ACADÉMICO (CON FILTROS Y SELECTORES SIN UUID MANUAL) ───────

  Future<void> _crearMateriaDialog() async {
    final codCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final profes = _filtrarUsuariosPorRol({'profesor', 'tutor'});
    String? profId = profes.isNotEmpty ? profes.first['id']?.toString() : null;

    final ok = await _showFormSheet(
      title: 'Crear Materia',
      subtitle: 'Asigna la asignatura a un profesor titular',
      submitLabel: 'Crear Materia',
      builder: (ctx, setDlg) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codCtrl,
            decoration: const InputDecoration(
              labelText: 'Código (ej. MAT-101)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nomCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre de materia',
              border: OutlineInputBorder(),
            ),
          ),
          if (profes.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: profId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Profesor titular',
                border: OutlineInputBorder(),
              ),
              items: profes
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id'].toString(),
                      child: Text(
                        p['nombre']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setDlg(() => profId = v),
            ),
          ],
        ],
      ),
    );
    if (ok == true) {
      final res = await _api.crearMateria(
        codigo: codCtrl.text.trim(),
        nombre: nomCtrl.text.trim(),
        profesorTitularId: profId,
      );
      if (res != null) {
        final createdId = res['id']?.toString() ?? '';
        if (createdId.isNotEmpty && mounted) {
          setState(() {
            _materiasCatalogo.removeWhere(
              (m) => m['id']?.toString() == createdId,
            );
            _materiasCatalogo.add({
              'id': createdId,
              'codigo': codCtrl.text.trim(),
              'nombre': nomCtrl.text.trim(),
            });
            _materiasCatalogo.sort(
              (a, b) => (a['nombre'] ?? '')
                  .toString()
                  .toLowerCase()
                  .compareTo((b['nombre'] ?? '').toString().toLowerCase()),
            );
          });
        }
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Materia Creada',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Se creó "${nomCtrl.text.trim()}". Para que el docente pase lista y capture calificaciones, vincúlala ahora a un grupo creando una Clase.',
              style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (createdId.isNotEmpty) {
                    _crearClaseDialog(prefillMateriaId: createdId);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Crear Clase ahora'),
              ),
            ],
          ),
        );
      } else {
        _snack(_api.lastError ?? 'Error creando materia.', error: true);
      }
    }
  }

  Future<void> _crearClaseDialog({String? prefillMateriaId}) async {
    if (_materiasCatalogo.isEmpty) {
      _snack(
        'Primero crea al menos una materia para poder asignarla a una clase.',
        error: true,
      );
      return;
    }

    final codCtrl = TextEditingController();
    final profes = _filtrarUsuariosPorRol({'profesor', 'tutor'});
    String filtroMateria = '';
    String? materiaId = (prefillMateriaId != null &&
            _materiasCatalogo.any(
              (m) => m['id']?.toString() == prefillMateriaId,
            ))
        ? prefillMateriaId
        : _materiasCatalogo.first['id']?.toString();
    String? grupoId = _grupos.isNotEmpty ? _grupos.first['id']?.toString() : null;
    String? profId = profes.isNotEmpty ? profes.first['id']?.toString() : null;
    String? periodoId =
        _periodos.isNotEmpty ? _periodos.first['id']?.toString() : null;

    final ok = await _showFormSheet(
      title: 'Crear Clase',
      subtitle: 'Selecciona materia, grupo, profesor y periodo',
      submitLabel: 'Crear Clase',
      builder: (ctx, setDlg) {
        final q = filtroMateria.trim().toLowerCase();
        final materiasFiltradas = _materiasCatalogo.where((m) {
          if (q.isEmpty) return true;
          final nom = (m['nombre'] ?? '').toString().toLowerCase();
          final cod = (m['codigo'] ?? '').toString().toLowerCase();
          return nom.contains(q) || cod.contains(q);
        }).toList();

        if (!materiasFiltradas.any((m) => m['id']?.toString() == materiaId)) {
          materiaId = materiasFiltradas.isNotEmpty
              ? materiasFiltradas.first['id']?.toString()
              : null;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Filtrar materia por nombre o código...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setDlg(() => filtroMateria = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: materiaId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Materia',
                border: OutlineInputBorder(),
              ),
              items: materiasFiltradas.map((m) {
                final cod = (m['codigo'] ?? '').toString();
                final nom = (m['nombre'] ?? 'Materia').toString();
                final label = cod.isNotEmpty ? '$cod · $nom' : nom;
                return DropdownMenuItem(
                  value: m['id'].toString(),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setDlg(() => materiaId = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codCtrl,
              decoration: const InputDecoration(
                labelText: 'Código de clase (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_grupos.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: grupoId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Grupo',
                  border: OutlineInputBorder(),
                ),
                items: _grupos
                    .map(
                      (g) => DropdownMenuItem(
                        value: g['id'].toString(),
                        child: Text(
                          '${g['codigo'] ?? ''}${(g['carrera'] ?? '').toString().isNotEmpty ? " · ${g['carrera']}" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDlg(() => grupoId = v),
              ),
            ],
            if (profes.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: profId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Profesor',
                  border: OutlineInputBorder(),
                ),
                items: profes
                    .map(
                      (p) => DropdownMenuItem(
                        value: p['id'].toString(),
                        child: Text(
                          p['nombre']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDlg(() => profId = v),
              ),
            ],
            if (_periodos.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: periodoId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Periodo',
                  border: OutlineInputBorder(),
                ),
                items: _periodos
                    .map(
                      (p) => DropdownMenuItem(
                        value: p['id'].toString(),
                        child: Text(
                          p['nombre']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDlg(() => periodoId = v),
              ),
            ],
          ],
        );
      },
    );
    final mId = materiaId;
    final gId = grupoId;
    final pId = profId;
    if (ok == true && mId != null && gId != null && pId != null) {
      final res = await _api.crearClase(
        materiaId: mId,
        grupoId: gId,
        profesorId: pId,
        periodoId: periodoId,
        codigo: codCtrl.text.trim(),
      );
      if (res != null) {
        _snack('Clase creada correctamente.');
      } else {
        _snack(_api.lastError ?? 'No se pudo crear la clase.', error: true);
      }
    }
  }

  Future<void> _crearHorarioDialog() async {
    if (_grupos.isEmpty) {
      _snack('No hay grupos registrados para asignar horarios.', error: true);
      return;
    }

    String grupoCodigo = (_grupos.first['codigo'] ?? '').toString();
    List<Map<String, dynamic>> clasesGrupo = [];
    String? claseId;
    bool cargandoClases = true;
    bool cargaIniciada = false;

    int dia = 1;
    TimeOfDay horaInicio = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay horaFin = const TimeOfDay(hour: 10, minute: 0);
    String? salonId = _salones.isNotEmpty ? _salones.first['id']?.toString() : null;

    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    Future<void> cargarClasesGrupo(
      String codigo,
      StateSetter setDlg,
    ) async {
      setDlg(() => cargandoClases = true);
      final list = await _api.getMateriasByGrupoConProfesor(codigo);
      if (!mounted) return;
      setDlg(() {
        clasesGrupo = list;
        claseId = list.isNotEmpty
            ? (list.first['clase_id'] ?? list.first['id'])?.toString()
            : null;
        cargandoClases = false;
      });
    }

    final ok = await _showFormSheet(
      title: 'Asignar Horario de Clase',
      subtitle: 'Elige el grupo y selecciona la clase sin escribir IDs',
      submitLabel: 'Guardar Horario',
      builder: (ctx, setDlg) {
        if (!cargaIniciada) {
          cargaIniciada = true;
          Future.microtask(() => cargarClasesGrupo(grupoCodigo, setDlg));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: grupoCodigo,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Grupo',
                border: OutlineInputBorder(),
              ),
              items: _grupos.map((g) {
                final cod = (g['codigo'] ?? '').toString();
                final car = (g['carrera'] ?? '').toString();
                return DropdownMenuItem(
                  value: cod,
                  child: Text(
                    car.isNotEmpty ? '$cod · $car' : cod,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  grupoCodigo = v;
                  cargarClasesGrupo(v, setDlg);
                }
              },
            ),
            const SizedBox(height: 10),
            if (cargandoClases)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (clasesGrupo.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Text(
                  'El grupo $grupoCodigo aún no tiene clases asignadas.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.primaryDark,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: claseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Clase / Materia',
                  border: OutlineInputBorder(),
                ),
                items: clasesGrupo.map((c) {
                  final cid = (c['clase_id'] ?? c['id'] ?? '').toString();
                  final mat = (c['nombre'] ?? 'Clase').toString();
                  final prof = (c['profesor_nombre'] ?? '').toString();
                  return DropdownMenuItem(
                    value: cid,
                    child: Text(
                      prof.isNotEmpty ? '$mat · $prof' : mat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setDlg(() => claseId = v),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: dia,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Día',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Lunes')),
                DropdownMenuItem(value: 2, child: Text('Martes')),
                DropdownMenuItem(value: 3, child: Text('Miércoles')),
                DropdownMenuItem(value: 4, child: Text('Jueves')),
                DropdownMenuItem(value: 5, child: Text('Viernes')),
                DropdownMenuItem(value: 6, child: Text('Sábado')),
              ],
              onChanged: (v) {
                if (v != null) setDlg(() => dia = v);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: horaInicio,
                      );
                      if (picked != null) setDlg(() => horaInicio = picked);
                    },
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text('Inicio: ${fmtTime(horaInicio)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: horaFin,
                      );
                      if (picked != null) setDlg(() => horaFin = picked);
                    },
                    icon: const Icon(Icons.access_time_filled, size: 18),
                    label: Text('Fin: ${fmtTime(horaFin)}'),
                  ),
                ),
              ],
            ),
            if (_salones.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: salonId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Salón',
                  border: OutlineInputBorder(),
                ),
                items: _salones
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text(
                          '${s['numero'] ?? ''}${(s['nombre'] ?? '').toString().isNotEmpty ? " · ${s['nombre']}" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDlg(() => salonId = v),
              ),
            ],
          ],
        );
      },
    );
    final cId = claseId;
    if (ok == true) {
      if (cId == null || cId.isEmpty) {
        _snack('Selecciona un grupo que tenga al menos una clase.', error: true);
        return;
      }
      final res = await _api.crearHorarioClase(
        claseId: cId,
        salonId: salonId,
        diaSemana: dia,
        horaInicio: fmtTime(horaInicio),
        horaFin: fmtTime(horaFin),
      );
      if (res != null) {
        _snack('Horario asignado correctamente.');
      } else {
        _snack(_api.lastError ?? 'No se pudo asignar horario.', error: true);
      }
    }
  }

  Future<void> _inscribirAlumnoDialog() async {
    final alumnos = _filtrarUsuariosPorRol({'alumno'});
    if (alumnos.isEmpty) {
      _snack('No hay alumnos registrados.', error: true);
      return;
    }
    if (_grupos.isEmpty) {
      _snack('No hay grupos registrados para inscribir alumnos.', error: true);
      return;
    }

    String filtroAlumno = '';
    String? alumnoId = alumnos.first['id']?.toString();
    String grupoCodigo = (_grupos.first['codigo'] ?? '').toString();
    List<Map<String, dynamic>> clasesGrupo = [];
    String? claseId;
    bool cargandoClases = true;
    bool cargaIniciada = false;

    Future<void> cargarClasesGrupo(
      String codigo,
      StateSetter setDlg,
    ) async {
      setDlg(() => cargandoClases = true);
      final list = await _api.getMateriasByGrupoConProfesor(codigo);
      if (!mounted) return;
      setDlg(() {
        clasesGrupo = list;
        claseId = list.isNotEmpty
            ? (list.first['clase_id'] ?? list.first['id'])?.toString()
            : null;
        cargandoClases = false;
      });
    }

    final ok = await _showFormSheet(
      title: 'Inscribir Alumno en Clase',
      subtitle: 'Filtra al alumno y selecciona el grupo y la materia',
      submitLabel: 'Inscribir Alumno',
      builder: (ctx, setDlg) {
        if (!cargaIniciada) {
          cargaIniciada = true;
          Future.microtask(() => cargarClasesGrupo(grupoCodigo, setDlg));
        }

        final q = filtroAlumno.trim().toLowerCase();
        final alumnosFiltrados = alumnos.where((a) {
          if (q.isEmpty) return true;
          final nom = (a['nombre'] ?? '').toString().toLowerCase();
          final mat = (a['matricula'] ?? '').toString().toLowerCase();
          final grp = (a['grupo'] ?? '').toString().toLowerCase();
          return nom.contains(q) || mat.contains(q) || grp.contains(q);
        }).toList();

        if (!alumnosFiltrados.any((a) => a['id']?.toString() == alumnoId)) {
          alumnoId = alumnosFiltrados.isNotEmpty
              ? alumnosFiltrados.first['id']?.toString()
              : null;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar alumno por nombre o matrícula...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setDlg(() => filtroAlumno = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: alumnoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Alumno',
                border: OutlineInputBorder(),
              ),
              items: alumnosFiltrados.map((a) {
                final mat = (a['matricula'] ?? '').toString();
                final nom = (a['nombre'] ?? 'Alumno').toString();
                return DropdownMenuItem(
                  value: a['id'].toString(),
                  child: Text(
                    mat.isNotEmpty ? '$nom ($mat)' : nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setDlg(() => alumnoId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: grupoCodigo,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Grupo',
                border: OutlineInputBorder(),
              ),
              items: _grupos.map((g) {
                final cod = (g['codigo'] ?? '').toString();
                final car = (g['carrera'] ?? '').toString();
                return DropdownMenuItem(
                  value: cod,
                  child: Text(
                    car.isNotEmpty ? '$cod · $car' : cod,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  grupoCodigo = v;
                  cargarClasesGrupo(v, setDlg);
                }
              },
            ),
            const SizedBox(height: 10),
            if (cargandoClases)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (clasesGrupo.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Text(
                  'El grupo $grupoCodigo aún no tiene clases creadas.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.primaryDark,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: claseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Clase / Materia',
                  border: OutlineInputBorder(),
                ),
                items: clasesGrupo.map((c) {
                  final cid = (c['clase_id'] ?? c['id'] ?? '').toString();
                  final mat = (c['nombre'] ?? 'Clase').toString();
                  final prof = (c['profesor_nombre'] ?? '').toString();
                  return DropdownMenuItem(
                    value: cid,
                    child: Text(
                      prof.isNotEmpty ? '$mat · $prof' : mat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setDlg(() => claseId = v),
              ),
          ],
        );
      },
    );
    final aId = alumnoId;
    final cId = claseId;
    if (ok == true) {
      if (aId == null || cId == null || cId.isEmpty) {
        _snack('Selecciona un alumno y una clase válida.', error: true);
        return;
      }
      final done = await _api.inscribirAlumnoClase(
        alumnoId: aId,
        claseId: cId,
      );
      if (done) {
        _snack('Alumno inscrito correctamente.');
      } else {
        _snack(_api.lastError ?? 'Error al inscribir alumno.', error: true);
      }
    }
  }

  Future<void> _asignarTutorDialog() async {
    final tutores = _filtrarUsuariosPorRol({'tutor', 'profesor'});
    String? tutorId = tutores.isNotEmpty ? tutores.first['id']?.toString() : null;
    String? grupoId = _grupos.isNotEmpty ? _grupos.first['id']?.toString() : null;

    final ok = await _showFormSheet(
      title: 'Asignar Tutor a Grupo',
      submitLabel: 'Asignar Tutor',
      builder: (ctx, setDlg) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tutores.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: tutorId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tutor / Docente',
                border: OutlineInputBorder(),
              ),
              items: tutores
                  .map(
                    (t) => DropdownMenuItem(
                      value: t['id'].toString(),
                      child: Text(
                        t['nombre']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setDlg(() => tutorId = v),
            ),
            const SizedBox(height: 10),
          ],
          if (_grupos.isNotEmpty)
            DropdownButtonFormField<String>(
              value: grupoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Grupo',
                border: OutlineInputBorder(),
              ),
              items: _grupos
                  .map(
                    (g) => DropdownMenuItem(
                      value: g['id'].toString(),
                      child: Text(
                        '${g['codigo'] ?? ''}${(g['carrera'] ?? '').toString().isNotEmpty ? " · ${g['carrera']}" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setDlg(() => grupoId = v),
            ),
        ],
      ),
    );
    final tId = tutorId;
    final gId = grupoId;
    if (ok == true && tId != null && gId != null) {
      final done = await _api.asignarTutorGrupo(
        tutorId: tId,
        grupoId: gId,
      );
      if (done) {
        _snack('Tutor asignado correctamente.');
      } else {
        _snack(_api.lastError ?? 'No se pudo asignar tutor.', error: true);
      }
    }
  }

  Future<void> _crearSalonDialog() async {
    final numCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final edifCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '35');
    String? zoneId = _zonas.isNotEmpty ? _zonas.first['id']?.toString() : null;

    final ok = await _showFormSheet(
      title: 'Registrar Salón / Laboratorio',
      submitLabel: 'Registrar Salón',
      builder: (ctx, setDlg) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: numCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Número (ej. A-101)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: capCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacidad',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nomCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: edifCtrl,
            decoration: const InputDecoration(
              labelText: 'Edificio',
              border: OutlineInputBorder(),
            ),
          ),
          if (_zonas.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: zoneId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Zona',
                border: OutlineInputBorder(),
              ),
              items: _zonas
                  .map(
                    (z) => DropdownMenuItem(
                      value: z['id'].toString(),
                      child: Text(
                        z['nombre']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setDlg(() => zoneId = v),
            ),
          ],
        ],
      ),
    );
    if (ok == true) {
      final res = await _api.crearSalon(
        numero: numCtrl.text.trim(),
        nombre: nomCtrl.text.trim(),
        edificio: edifCtrl.text.trim(),
        zoneId: zoneId,
        capacidad: int.tryParse(capCtrl.text.trim()) ?? 35,
      );
      if (res != null) {
        _snack('Salón creado.');
        _cargarTodo();
      } else {
        _snack(_api.lastError ?? 'Error al crear salón.', error: true);
      }
    }
  }

  // ─── ACCIONES ZONAS E IOT ───────────────────────────────────────────────

  Future<void> _nuevaZonaDialog() async {
    final codCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool permiteVisitas = false;

    final ok = await _showFormSheet(
      title: 'Nueva Zona de Acceso',
      submitLabel: 'Crear Zona',
      builder: (ctx, setDlg) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codCtrl,
            decoration: const InputDecoration(
              labelText: 'Código (ej. LAB_A)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nomCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Permite visitantes'),
            value: permiteVisitas,
            onChanged: (v) => setDlg(() => permiteVisitas = v),
          ),
        ],
      ),
    );
    if (ok == true) {
      final created = await _api.crearZona(
        codigo: codCtrl.text.trim(),
        nombre: nomCtrl.text.trim(),
        descripcion: descCtrl.text.trim(),
        permiteVisitas: permiteVisitas,
      );
      if (created != null) {
        _snack('Zona creada.');
        _cargarTodo();
      } else {
        _snack(_api.lastError ?? 'No se pudo crear la zona.', error: true);
      }
    }
  }

  Future<void> _permisosZonaDialog(Map<String, dynamic> zona) async {
    final zoneId = zona['id'].toString();
    final permisos = await _api.getPermisosZona(zoneId);
    if (!mounted) return;

    const roles = [
      'alumno',
      'profesor',
      'tutor',
      'admin',
      'administrativo',
      'seguridad',
      'psicologo',
      'marketing',
    ];
    String rolSel = 'alumno';
    final hiCtrl = TextEditingController(text: '07:00');
    final hfCtrl = TextEditingController(text: '21:00');
    bool activo = true;

    final save = await _showFormSheet(
      title: 'Permisos: ${zona['nombre']}',
      submitLabel: 'Guardar Regla',
      builder: (ctx, setDlg) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (permisos.isNotEmpty) ...[
            const Text(
              'Reglas vigentes:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            ...permisos.map(
              (p) => Text(
                '• ${formatRoleLabel(p['rol_codigo']?.toString())} (${p['hora_inicio'] ?? '00:00'} - ${p['hora_fin'] ?? '23:59'}) · ${p['activo'] == true ? "Activo" : "Inactivo"}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Divider(height: 18),
          ],
          DropdownButtonFormField<String>(
            value: rolSel,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Rol',
              border: OutlineInputBorder(),
            ),
            items: roles
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      formatRoleLabel(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setDlg(() => rolSel = v);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: hiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Inicio (HH:mm)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: hfCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fin (HH:mm)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Acceso permitido'),
            value: activo,
            onChanged: (v) => setDlg(() => activo = v),
          ),
        ],
      ),
    );
    if (save == true) {
      final ok = await _api.upsertPermisoZona(
        zoneId: zoneId,
        rolCodigo: rolSel,
        horaInicio: hiCtrl.text.trim(),
        horaFin: hfCtrl.text.trim(),
        activo: activo,
      );
      if (ok) {
        _snack('Permiso de zona actualizado.');
      } else {
        _snack(_api.lastError ?? 'No se pudo guardar permiso.', error: true);
      }
    }
  }

  Future<void> _nuevoDispositivoIotDialog() async {
    final codCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    String? zoneId = _zonas.isNotEmpty ? _zonas.first['id']?.toString() : null;
    String direccion = 'ambos';
    bool generarKey = true;

    final ok = await _showFormSheet(
      title: 'Registrar Lector IoT',
      submitLabel: 'Registrar Lector',
      builder: (ctx, setDlg) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codCtrl,
            decoration: const InputDecoration(
              labelText: 'Código dispositivo (ej. TORNIQUETE-02)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nomCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          if (_zonas.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: zoneId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Zona',
                border: OutlineInputBorder(),
              ),
              items: _zonas
                  .map(
                    (z) => DropdownMenuItem(
                      value: z['id'].toString(),
                      child: Text(
                        z['nombre']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setDlg(() => zoneId = v),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: direccion,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'ambos', child: Text('Ambos')),
              DropdownMenuItem(value: 'entrada', child: Text('Solo entrada')),
              DropdownMenuItem(value: 'salida', child: Text('Solo salida')),
            ],
            onChanged: (v) {
              if (v != null) setDlg(() => direccion = v);
            },
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Generar API Key individual'),
            value: generarKey,
            onChanged: (v) => setDlg(() => generarKey = v),
          ),
        ],
      ),
    );

    final zId = zoneId;
    if (ok == true && zId != null) {
      final created = await _api.crearDispositivoIot(
        codigoDispositivo: codCtrl.text.trim(),
        nombre: nomCtrl.text.trim(),
        zoneId: zId,
        direccion: direccion,
        generarApiKeyIndividual: generarKey,
      );
      if (created != null) {
        final key = (created['apiKeyGenerada'] ??
                created['api_key_generada'] ??
                '')
            .toString();
        _cargarTodo();
        if (key.isNotEmpty && mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('API Key Generada (Uso Único)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Copia ahora esta clave X-Device-Key; por seguridad no volverá a mostrarse:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoftBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: key));
                    _snack('Clave copiada al portapapeles.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        } else {
          _snack('Dispositivo registrado.');
        }
      } else {
        _snack(_api.lastError ?? 'No se pudo registrar dispositivo.', error: true);
      }
    }
  }

  // ─── LIZARD Y REPORTES ──────────────────────────────────────────────────

  Future<void> _confirmarLizard() async {
    if (_selectedLizardIds.isEmpty) {
      _snack('Selecciona al menos un registro para sincronizar.', error: true);
      return;
    }
    final count = await _api.confirmarSincronizacionLizard(
      _selectedLizardIds.toList(),
    );
    if (count > 0) {
      _snack('$count calificaciones marcadas como sincronizadas con Lizard.');
      _cargarTodo();
    } else {
      _snack(
        _api.lastError ?? 'No se confirmó ninguna sincronización.',
        error: true,
      );
    }
  }

  Future<void> _exportarReporteAsistenciasGlobal() async {
    final rows = await _api.exportarReporteAsistencias();
    if (rows.isEmpty) {
      _snack(
        _api.lastError ?? 'No hay datos disponibles para exportar.',
        error: true,
      );
      return;
    }
    try {
      final excel = xl.Excel.createExcel();
      const sheetName = 'ReporteAsistencias';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];
      final headers = rows.first.keys.toList();
      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
            .value = headers[c];
      }
      for (int r = 0; r < rows.length; r++) {
        for (int c = 0; c < headers.length; c++) {
          sheet
              .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
              .value = rows[r][headers[c]]?.toString() ?? '';
        }
      }
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Error al codificar Excel');
      final dir = await getTemporaryDirectory();
      final file =
          '${dir.path}/reporte_global_asistencias_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await File(file).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file)], text: 'Reporte Global de Asistencias');
    } catch (e) {
      _snack('Error exportando reporte: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: DefaultTabController(
        length: 4,
        initialIndex: widget.initialTab.clamp(0, 3),
        child: Scaffold(
          backgroundColor: AppColors.surfaceLight,
          appBar: AppBar(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            title: const Text('Gestión Institucional'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _cargarTodo,
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              indicatorColor: AppColors.badgeGold,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Catálogos'),
                Tab(text: 'Académico'),
                Tab(text: 'Zonas e IoT'),
                Tab(text: 'Lizard y Auditoría'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _buildCatalogosTab(),
                    _buildAcademicoTab(),
                    _buildZonasIotTab(),
                    _buildLizardAuditoriaTab(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCatalogosTab() {
    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeaderTitle(
                        icon: Icons.calendar_today_outlined,
                        title: 'Periodos Escolares',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _nuevoPeriodoDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo Periodo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._periodos.map((p) {
                  final activo = p['activo'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      title: Text(
                        '${p['nombre'] ?? ''} (${p['codigo'] ?? ''})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      subtitle: Text(
                        '${p['fecha_inicio'] ?? ''} → ${p['fecha_fin'] ?? ''}',
                      ),
                      trailing: activo
                          ? const Chip(
                              label: Text('ACTIVO'),
                              backgroundColor: AppColors.surfaceSoftBlue,
                            )
                          : TextButton(
                              onPressed: () async {
                                final ok = await _api.activarPeriodo(
                                  p['id'].toString(),
                                );
                                if (ok) {
                                  _snack('Periodo activado.');
                                  _cargarTodo();
                                }
                              },
                              child: const Text('Activar'),
                            ),
                    ),
                  );
                }),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeaderTitle(
                        icon: Icons.groups_outlined,
                        title: 'Grupos Registrados',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _nuevoGrupoDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo Grupo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._grupos.map(
                  (g) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.groups,
                        color: AppColors.primaryDark,
                      ),
                      title: Text(
                        (g['codigo'] ?? '').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      subtitle: Text((g['carrera'] ?? '').toString()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicoTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeaderTitle(
                icon: Icons.school_outlined,
                title: 'Operaciones Académicas',
                subtitle: 'Configura materias, clases, horarios y salones sin UUIDs',
              ),
              const SizedBox(height: 12),
              ResponsiveModuleGrid(
                children: [
                  ExecutiveModuleCard(
                    icon: Icons.menu_book,
                    title: 'Crear Materia',
                    description:
                        'Registrar nueva asignatura y profesor titular con flujo directo a Clase',
                    color: AppColors.primaryDark,
                    onTap: _crearMateriaDialog,
                  ),
                  ExecutiveModuleCard(
                    icon: Icons.class_outlined,
                    title: 'Crear Clase',
                    description:
                        'Seleccionar materia, grupo, profesor y periodo académico',
                    color: AppColors.primaryAction,
                    onTap: () => _crearClaseDialog(),
                  ),
                  ExecutiveModuleCard(
                    icon: Icons.schedule,
                    title: 'Asignar Horario de Clase',
                    description: 'Filtrar por grupo/clase y elegir horario y salón',
                    color: AppColors.accentBlue,
                    onTap: _crearHorarioDialog,
                  ),
                  ExecutiveModuleCard(
                    icon: Icons.person_add_outlined,
                    title: 'Inscribir Alumno en Clase',
                    description: 'Buscar alumno y seleccionar grupo y materia',
                    color: AppColors.successDark,
                    onTap: _inscribirAlumnoDialog,
                  ),
                  ExecutiveModuleCard(
                    icon: Icons.supervisor_account_outlined,
                    title: 'Asignar Tutor a Grupo',
                    description: 'Vincular tutor académico con su grupo',
                    color: AppColors.primary,
                    onTap: _asignarTutorDialog,
                  ),
                  ExecutiveModuleCard(
                    icon: Icons.meeting_room_outlined,
                    title: 'Registrar Salón / Laboratorio',
                    description: 'Dar de alta aula física con zona de acceso',
                    color: AppColors.primaryDark,
                    onTap: _crearSalonDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZonasIotTab() {
    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeaderTitle(
                        icon: Icons.security_outlined,
                        title: 'Zonas del Campus',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _nuevaZonaDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva Zona'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._zonas.map(
                  (z) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.security,
                        color: AppColors.primaryDark,
                      ),
                      title: Text(
                        '${z['nombre'] ?? ''} (${z['codigo'] ?? ''})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      subtitle: Text(
                        'Tipo: ${z['tipo'] ?? ''} · Visitas: ${z['permite_visitas'] == true ? "Sí" : "No"}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _permisosZonaDialog(z),
                        child: const Text('Permisos'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeaderTitle(
                        icon: Icons.sensors,
                        title: 'Lectores IoT / Torniquetes',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _nuevoDispositivoIotDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo Lector'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._dispositivos.map(
                  (d) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.sensors,
                        color: AppColors.accentBlue,
                      ),
                      title: Text(
                        '${d['nombre'] ?? ''} (${d['codigo_dispositivo'] ?? d['codigoDispositivo'] ?? ''})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      subtitle: Text(
                        'Dirección: ${d['direccion'] ?? 'ambos'} · Activo: ${d['activo'] == true ? "Sí" : "No"}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLizardAuditoriaTab() {
    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _exportarReporteAsistenciasGlobal,
                    icon: const Icon(Icons.download),
                    label: const Text(
                      'Exportar Reporte Global de Asistencias (Excel)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SectionHeaderTitle(
                        icon: Icons.sync_outlined,
                        title:
                            'Pendientes Sync Lizard (${_lizardPendientes.length})',
                      ),
                    ),
                    if (_lizardPendientes.isNotEmpty)
                      ElevatedButton(
                        onPressed: _confirmarLizard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirmar Sync'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_lizardPendientes.isEmpty)
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const ListTile(
                      title: Text(
                        'No hay calificaciones pendientes por sincronizar.',
                      ),
                    ),
                  )
                else
                  ..._lizardPendientes.map((item) {
                    final cid =
                        (item['calificacion_id'] ?? item['id'] ?? '').toString();
                    final selected = _selectedLizardIds.contains(cid);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: CheckboxListTile(
                        value: selected,
                        title: Text(
                          '${item['alumno_nombre'] ?? ''} · ${item['materia'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Mat: ${item['matricula'] ?? ''} · P${item['parcial'] ?? ''}: ${item['calificacion'] ?? ''} (${item['nivel'] ?? ''})',
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedLizardIds.add(cid);
                            } else {
                              _selectedLizardIds.remove(cid);
                            }
                          });
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 18),
                SectionHeaderTitle(
                  icon: Icons.history_edu,
                  title: 'Bitácora de Auditoría (${_auditoria.length})',
                ),
                const SizedBox(height: 8),
                ..._auditoria.take(50).map(
                      (a) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.history_edu,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            '${a['accion'] ?? a['evento'] ?? 'Evento'} · ${a['entidad'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${a['usuario_nombre'] ?? a['actor_id'] ?? ''}\n${a['created_at'] ?? a['fecha'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          isThreeLine: true,
                        ),
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

import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
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
    if (!mounted) return;
    setState(() {
      _periodos = res[0];
      _grupos = res[1];
      _zonas = res[2];
      _dispositivos = res[3];
      _lizardPendientes = res[4];
      _auditoria = res[5];
      _users = res[6];
      _salones = res[7];
      _selectedLizardIds.clear();
      _isLoading = false;
    });
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

  // ─── ACCIONES CATÁLOGOS ─────────────────────────────────────────────────

  Future<void> _nuevoPeriodoDialog() async {
    final codCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final iniCtrl = TextEditingController(text: '2026-09-01');
    final finCtrl = TextEditingController(text: '2026-12-18');
    bool activo = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo Periodo Escolar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codCtrl,
                  decoration: const InputDecoration(labelText: 'Código (ej. 2026-3)'),
                ),
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (ej. Sep-Dic 2026)',
                  ),
                ),
                TextField(
                  controller: iniCtrl,
                  decoration: const InputDecoration(labelText: 'Inicio (yyyy-MM-dd)'),
                ),
                TextField(
                  controller: finCtrl,
                  decoration: const InputDecoration(labelText: 'Fin (yyyy-MM-dd)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activar al crear'),
                  value: activo,
                  onChanged: (v) => setDlg(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo Grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codCtrl,
                decoration: const InputDecoration(labelText: 'Código (ej. IDGS101)'),
              ),
              TextField(
                controller: carCtrl,
                decoration: const InputDecoration(labelText: 'Carrera'),
              ),
              if (_periodos.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: periodoId,
                  decoration: const InputDecoration(labelText: 'Periodo'),
                  items: _periodos
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text(p['nombre']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDlg(() => periodoId = v),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
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

  // ─── ACCIONES ACADÉMICO ─────────────────────────────────────────────────

  Future<void> _crearMateriaDialog() async {
    final codCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final profes = _users
        .where((u) => (u['rol'] ?? '').toString().toLowerCase() == 'profesor')
        .toList();
    String? profId = profes.isNotEmpty ? profes.first['id']?.toString() : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Crear Materia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codCtrl,
                decoration: const InputDecoration(labelText: 'Código (ej. MAT-101)'),
              ),
              TextField(
                controller: nomCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de materia'),
              ),
              if (profes.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: profId,
                  decoration: const InputDecoration(labelText: 'Profesor titular'),
                  items: profes
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text(p['nombre']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDlg(() => profId = v),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final res = await _api.crearMateria(
        codigo: codCtrl.text.trim(),
        nombre: nomCtrl.text.trim(),
        profesorTitularId: profId,
      );
      if (res != null) {
        _snack('Materia creada (ID: ${res['id'] ?? ''}).');
      } else {
        _snack(_api.lastError ?? 'Error creando materia.', error: true);
      }
    }
  }

  Future<void> _crearClaseDialog() async {
    final matCtrl = TextEditingController();
    final codCtrl = TextEditingController();
    final profes = _users
        .where((u) => (u['rol'] ?? '').toString().toLowerCase() == 'profesor')
        .toList();
    String? grupoId = _grupos.isNotEmpty ? _grupos.first['id']?.toString() : null;
    String? profId = profes.isNotEmpty ? profes.first['id']?.toString() : null;
    String? periodoId =
        _periodos.isNotEmpty ? _periodos.first['id']?.toString() : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Crear Clase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: matCtrl,
                  decoration: const InputDecoration(labelText: 'Materia ID (UUID)'),
                ),
                TextField(
                  controller: codCtrl,
                  decoration: const InputDecoration(labelText: 'Código (opcional)'),
                ),
                if (_grupos.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: grupoId,
                    decoration: const InputDecoration(labelText: 'Grupo'),
                    items: _grupos
                        .map(
                          (g) => DropdownMenuItem(
                            value: g['id'].toString(),
                            child: Text(g['codigo']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlg(() => grupoId = v),
                  ),
                if (profes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: profId,
                    decoration: const InputDecoration(labelText: 'Profesor'),
                    items: profes
                        .map(
                          (p) => DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(p['nombre']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlg(() => profId = v),
                  ),
                if (_periodos.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: periodoId,
                    decoration: const InputDecoration(labelText: 'Periodo'),
                    items: _periodos
                        .map(
                          (p) => DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(p['nombre']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlg(() => periodoId = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    final gId = grupoId;
    final pId = profId;
    if (ok == true && gId != null && pId != null) {
      final res = await _api.crearClase(
        materiaId: matCtrl.text.trim(),
        grupoId: gId,
        profesorId: pId,
        periodoId: periodoId,
        codigo: codCtrl.text.trim(),
      );
      if (res != null) {
        _snack('Clase creada (ID: ${res['id'] ?? ''}).');
      } else {
        _snack(_api.lastError ?? 'No se pudo crear la clase.', error: true);
      }
    }
  }

  Future<void> _crearHorarioDialog() async {
    final claseCtrl = TextEditingController();
    final hiCtrl = TextEditingController(text: '08:00');
    final hfCtrl = TextEditingController(text: '10:00');
    int dia = 1;
    String? salonId = _salones.isNotEmpty ? _salones.first['id']?.toString() : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Asignar Horario de Clase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: claseCtrl,
                  decoration: const InputDecoration(labelText: 'Clase ID (UUID)'),
                ),
                DropdownButtonFormField<int>(
                  value: dia,
                  decoration: const InputDecoration(labelText: 'Día'),
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
                TextField(
                  controller: hiCtrl,
                  decoration: const InputDecoration(labelText: 'Hora inicio (HH:mm)'),
                ),
                TextField(
                  controller: hfCtrl,
                  decoration: const InputDecoration(labelText: 'Hora fin (HH:mm)'),
                ),
                if (_salones.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: salonId,
                    decoration: const InputDecoration(labelText: 'Salón'),
                    items: _salones
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'].toString(),
                            child: Text(s['numero']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlg(() => salonId = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final res = await _api.crearHorarioClase(
        claseId: claseCtrl.text.trim(),
        salonId: salonId,
        diaSemana: dia,
        horaInicio: hiCtrl.text.trim(),
        horaFin: hfCtrl.text.trim(),
      );
      if (res != null) {
        _snack('Horario asignado.');
      } else {
        _snack(_api.lastError ?? 'No se pudo asignar horario.', error: true);
      }
    }
  }

  Future<void> _inscribirAlumnoDialog() async {
    final claseCtrl = TextEditingController();
    final alumnos = _users
        .where((u) => (u['rol'] ?? '').toString().toLowerCase() == 'alumno')
        .toList();
    String? alumnoId = alumnos.isNotEmpty ? alumnos.first['id']?.toString() : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Inscribir Alumno a Clase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (alumnos.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: alumnoId,
                  decoration: const InputDecoration(labelText: 'Alumno'),
                  items: alumnos
                      .map(
                        (a) => DropdownMenuItem(
                          value: a['id'].toString(),
                          child: Text(
                            '${a['nombre'] ?? ''} (${a['matricula'] ?? ''})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDlg(() => alumnoId = v),
                ),
              TextField(
                controller: claseCtrl,
                decoration: const InputDecoration(labelText: 'Clase ID (UUID)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Inscribir'),
            ),
          ],
        ),
      ),
    );
    final aId = alumnoId;
    if (ok == true && aId != null) {
      final done = await _api.inscribirAlumnoClase(
        alumnoId: aId,
        claseId: claseCtrl.text.trim(),
      );
      if (done) {
        _snack('Alumno inscrito.');
      } else {
        _snack(_api.lastError ?? 'Error al inscribir alumno.', error: true);
      }
    }
  }

  Future<void> _asignarTutorDialog() async {
    final tutores = _users
        .where(
          (u) =>
              (u['rol'] ?? '').toString().toLowerCase() == 'tutor' ||
              (u['rol'] ?? '').toString().toLowerCase() == 'profesor',
        )
        .toList();
    String? tutorId = tutores.isNotEmpty ? tutores.first['id']?.toString() : null;
    String? grupoId = _grupos.isNotEmpty ? _grupos.first['id']?.toString() : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Asignar Tutor a Grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tutores.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: tutorId,
                  decoration: const InputDecoration(labelText: 'Tutor / Docente'),
                  items: tutores
                      .map(
                        (t) => DropdownMenuItem(
                          value: t['id'].toString(),
                          child: Text(t['nombre']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDlg(() => tutorId = v),
                ),
              if (_grupos.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: grupoId,
                  decoration: const InputDecoration(labelText: 'Grupo'),
                  items: _grupos
                      .map(
                        (g) => DropdownMenuItem(
                          value: g['id'].toString(),
                          child: Text(g['codigo']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDlg(() => grupoId = v),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Registrar Salón'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numCtrl,
                  decoration: const InputDecoration(labelText: 'Número (ej. A-101)'),
                ),
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: edifCtrl,
                  decoration: const InputDecoration(labelText: 'Edificio'),
                ),
                TextField(
                  controller: capCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Capacidad'),
                ),
                if (_zonas.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: zoneId,
                    decoration: const InputDecoration(labelText: 'Zona'),
                    items: _zonas
                        .map(
                          (z) => DropdownMenuItem(
                            value: z['id'].toString(),
                            child: Text(z['nombre']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlg(() => zoneId = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nueva Zona de Acceso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codCtrl,
                decoration: const InputDecoration(labelText: 'Código (ej. LAB_A)'),
              ),
              TextField(
                controller: nomCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permite visitantes'),
                value: permiteVisitas,
                onChanged: (v) => setDlg(() => permiteVisitas = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
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

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Permisos: ${zona['nombre']}'),
          content: SingleChildScrollView(
            child: Column(
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
                  const Divider(height: 16),
                ],
                DropdownButtonFormField<String>(
                  value: rolSel,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: roles
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(formatRoleLabel(r)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlg(() => rolSel = v);
                  },
                ),
                TextField(
                  controller: hiCtrl,
                  decoration: const InputDecoration(labelText: 'Hora inicio (HH:mm)'),
                ),
                TextField(
                  controller: hfCtrl,
                  decoration: const InputDecoration(labelText: 'Hora fin (HH:mm)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Acceso permitido'),
                  value: activo,
                  onChanged: (v) => setDlg(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await _api.upsertPermisoZona(
                  zoneId: zoneId,
                  rolCodigo: rolSel,
                  horaInicio: hiCtrl.text.trim(),
                  horaFin: hfCtrl.text.trim(),
                  activo: activo,
                );
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.pop(ctx);
                  _snack('Permiso de zona actualizado.');
                } else {
                  _snack(
                    _api.lastError ?? 'No se pudo guardar permiso.',
                    error: true,
                  );
                }
              },
              child: const Text('Guardar Regla'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _nuevoDispositivoIotDialog() async {
    final codCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    String? zoneId = _zonas.isNotEmpty ? _zonas.first['id']?.toString() : null;
    String direccion = 'ambos';
    bool generarKey = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Registrar Lector IoT'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código dispositivo (ej. TORNIQUETE-02)',
                  ),
                ),
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                if (_zonas.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: zoneId,
                    decoration: const InputDecoration(labelText: 'Zona'),
                    items: _zonas
                        .map(
                          (z) => DropdownMenuItem(
                            value: z['id'].toString(),
                            child: Text(z['nombre']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlg(() => zoneId = v),
                  ),
                DropdownButtonFormField<String>(
                  value: direccion,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                  items: const [
                    DropdownMenuItem(value: 'ambos', child: Text('Ambos')),
                    DropdownMenuItem(value: 'entrada', child: Text('Solo entrada')),
                    DropdownMenuItem(value: 'salida', child: Text('Solo salida')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlg(() => direccion = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Generar API Key individual'),
                  value: generarKey,
                  onChanged: (v) => setDlg(() => generarKey = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar'),
            ),
          ],
        ),
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
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Periodos Escolares',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _nuevoPeriodoDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Periodo'),
            ),
          ],
        ),
        ..._periodos.map((p) {
          final activo = p['activo'] == true;
          return Card(
            color: Colors.white,
            child: ListTile(
              title: Text(
                '${p['nombre'] ?? ''} (${p['codigo'] ?? ''})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${p['fecha_inicio'] ?? ''} → ${p['fecha_fin'] ?? ''}'),
              trailing: activo
                  ? const Chip(
                      label: Text('ACTIVO'),
                      backgroundColor: AppColors.surfaceSoftBlue,
                    )
                  : TextButton(
                      onPressed: () async {
                        final ok = await _api.activarPeriodo(p['id'].toString());
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
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Grupos Registrados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _nuevoGrupoDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Grupo'),
            ),
          ],
        ),
        ..._grupos.map(
          (g) => Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.groups, color: AppColors.primaryDark),
              title: Text(
                (g['codigo'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text((g['carrera'] ?? '').toString()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicoTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _hubActionTile(
          Icons.menu_book,
          'Crear Materia',
          'Registrar nueva asignatura y profesor titular',
          _crearMateriaDialog,
        ),
        _hubActionTile(
          Icons.class_outlined,
          'Crear Clase',
          'Vincular materia, grupo, profesor y periodo',
          _crearClaseDialog,
        ),
        _hubActionTile(
          Icons.schedule,
          'Asignar Horario de Clase',
          'Definir día, bloque horario y salón',
          _crearHorarioDialog,
        ),
        _hubActionTile(
          Icons.person_add_outlined,
          'Inscribir Alumno en Clase',
          'Alta de estudiante en una clase existente',
          _inscribirAlumnoDialog,
        ),
        _hubActionTile(
          Icons.supervisor_account_outlined,
          'Asignar Tutor a Grupo',
          'Vincular tutor académico con su grupo',
          _asignarTutorDialog,
        ),
        _hubActionTile(
          Icons.meeting_room_outlined,
          'Registrar Salón / Laboratorio',
          'Dar de alta aula física con zona de acceso',
          _crearSalonDialog,
        ),
      ],
    );
  }

  Widget _hubActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Icon(icon, color: AppColors.primaryDark),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildZonasIotTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Zonas del Campus',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _nuevaZonaDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nueva Zona'),
            ),
          ],
        ),
        ..._zonas.map(
          (z) => Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.security, color: AppColors.primaryDark),
              title: Text(
                '${z['nombre'] ?? ''} (${z['codigo'] ?? ''})',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lectores IoT / Torniquetes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _nuevoDispositivoIotDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Lector'),
            ),
          ],
        ),
        ..._dispositivos.map(
          (d) => Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.sensors, color: AppColors.accentBlue),
              title: Text(
                '${d['nombre'] ?? ''} (${d['codigo_dispositivo'] ?? d['codigoDispositivo'] ?? ''})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Dirección: ${d['direccion'] ?? 'ambos'} · Activo: ${d['activo'] == true ? "Sí" : "No"}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLizardAuditoriaTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exportarReporteAsistenciasGlobal,
            icon: const Icon(Icons.download),
            label: const Text('Exportar Reporte Global de Asistencias (Excel)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Pendientes Sync Lizard (${_lizardPendientes.length})',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
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
        const SizedBox(height: 6),
        if (_lizardPendientes.isEmpty)
          const Card(
            color: Colors.white,
            child: ListTile(
              title: Text('No hay calificaciones pendientes por sincronizar.'),
            ),
          )
        else
          ..._lizardPendientes.map((item) {
            final cid = (item['calificacion_id'] ?? item['id'] ?? '').toString();
            final selected = _selectedLizardIds.contains(cid);
            return Card(
              color: Colors.white,
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
        const SizedBox(height: 16),
        Text(
          'Bitácora de Auditoría (${_auditoria.length})',
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        ..._auditoria.take(50).map(
              (a) => Card(
                color: Colors.white,
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
      ],
    );
  }
}

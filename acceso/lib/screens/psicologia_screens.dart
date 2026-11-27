import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../navigation/role_router.dart';
import '../service/api_service.dart';
import '../service/connectivity_service.dart';
import '../service/screen_security_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import 'noticias_screen.dart';
import 'profile_screen.dart';
import 'qralumnos.dart';

String _diaNombreCompleto(dynamic d) {
  switch (int.tryParse(d?.toString() ?? '') ?? 0) {
    case 1:
      return 'Lunes';
    case 2:
      return 'Martes';
    case 3:
      return 'Miércoles';
    case 4:
      return 'Jueves';
    case 5:
      return 'Viernes';
    case 6:
      return 'Sábado';
    case 7:
      return 'Domingo';
    default:
      return 'Día $d';
  }
}

class CitasAlumnoScreen extends StatefulWidget {
  final String alumnoId;
  final String? nombreAlumno;

  const CitasAlumnoScreen({
    super.key,
    required this.alumnoId,
    this.nombreAlumno,
  });

  @override
  State<CitasAlumnoScreen> createState() => _CitasAlumnoScreenState();
}

class _CitasAlumnoScreenState extends State<CitasAlumnoScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late final TabController _tabs;

  List<Map<String, dynamic>> _citas = [];
  List<Map<String, dynamic>> _disponibilidad = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getCitasAlumno(widget.alumnoId),
      _apiService.getDisponibilidadPsicologos(),
    ]);
    if (!mounted) return;
    setState(() {
      _citas = results[0];
      _disponibilidad = results[1];
      _isLoading = false;
    });
  }

  Future<void> _agendarDesdeBloque(Map<String, dynamic> slot) async {
    final psicologoId =
        (slot['psicologo_id'] ?? slot['psicologoId'] ?? '').toString();
    final psicologoNombre =
        (slot['psicologo_nombre'] ?? slot['nombre'] ?? 'Psicólogo').toString();
    final hi = (slot['hora_inicio'] ?? slot['horaInicio'] ?? '09:00').toString();
    final hf = (slot['hora_fin'] ?? slot['horaFin'] ?? '10:00').toString();

    DateTime fecha = DateTime.now().add(const Duration(days: 1));
    String motivo = '';
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Agendar con $psicologoNombre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bloque: ${_diaNombreCompleto(slot['dia_semana'] ?? slot['diaSemana'])} · $hi - $hf',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: fecha,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setDlg(() => fecha = picked);
                    },
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                onChanged: (v) => motivo = v,
                decoration: const InputDecoration(
                  labelText: 'Motivo de consulta (confidencial)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!ConnectivityService().isOnline.value) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Necesitas conexión a internet para agendar una cita.',
                            ),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }
                      setDlg(() => saving = true);
                      final created = await _apiService.agendarCitaPsicologica(
                        alumnoId: widget.alumnoId,
                        psicologoId: psicologoId,
                        fecha: DateFormat('yyyy-MM-dd').format(fecha),
                        horaInicio: hi.length >= 5 ? hi.substring(0, 5) : hi,
                        horaFin: hf.length >= 5 ? hf.substring(0, 5) : hf,
                        motivo: motivo,
                      );
                      if (!ctx.mounted) return;
                      setDlg(() => saving = false);

                      if (created != null) {
                        Navigator.pop(ctx);
                        await _cargar();
                        if (!mounted) return;
                        _tabs.animateTo(0);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cita psicológica agendada.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _apiService.lastError ??
                                  'No se pudo agendar la cita.',
                            ),
                            backgroundColor: AppColors.dangerRed,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              child: Text(saving ? 'Agendando...' : 'Confirmar Cita'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelarCita(String citaId) async {
    final ok = await _apiService.actualizarEstadoCita(
      citaId: citaId,
      estado: 'cancelada',
      motivoCancelacion: 'Cancelada por el estudiante',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Cita cancelada.'
              : (_apiService.lastError ?? 'No se pudo cancelar.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.dangerRed,
      ),
    );
    if (ok) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('Orientación Psicológica'),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AppColors.badgeGold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Mis Citas'),
              Tab(text: 'Agendar Cita'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [
                  RefreshIndicator(
                    onRefresh: _cargar,
                    child: _citas.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(32),
                            children: const [
                              Text(
                                'No tienes citas registradas. Revisa los horarios disponibles en la pestaña "Agendar Cita".',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _citas.length,
                            itemBuilder: (ctx, i) {
                              final c = _citas[i];
                              final est = (c['estado'] ?? 'agendada').toString();
                              final psi = (c['psicologo_nombre'] ??
                                      c['psicologoNombre'] ??
                                      'Psicología')
                                  .toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.12),
                                    child: const Icon(
                                      Icons.psychology_outlined,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  title: Text(
                                    psi,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${c['fecha'] ?? ''} · ${c['hora_inicio'] ?? c['horaInicio'] ?? ''} - ${c['hora_fin'] ?? c['horaFin'] ?? ''}\nEstado: ${est.toUpperCase()}',
                                  ),
                                  isThreeLine: true,
                                  trailing: est == 'agendada'
                                      ? IconButton(
                                          tooltip: 'Cancelar cita',
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                            color: AppColors.dangerRed,
                                          ),
                                          onPressed: () =>
                                              _cancelarCita(c['id'].toString()),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                  RefreshIndicator(
                    onRefresh: _cargar,
                    child: _disponibilidad.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(32),
                            children: const [
                              Text(
                                'No hay horarios de atención publicados actualmente.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _disponibilidad.length,
                            itemBuilder: (ctx, i) {
                              final s = _disponibilidad[i];
                              final psi = (s['psicologo_nombre'] ??
                                      s['nombre'] ??
                                      'Especialista')
                                  .toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primaryDark,
                                    child: Icon(
                                      Icons.calendar_month,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    psi,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_diaNombreCompleto(s['dia_semana'] ?? s['diaSemana'])} · ${s['hora_inicio'] ?? s['horaInicio'] ?? ''} - ${s['hora_fin'] ?? s['horaFin'] ?? ''}',
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _agendarDesdeBloque(s),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryDark,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Agendar'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class PsicologoDashboardScreen extends StatefulWidget {
  final String userId;
  final String? nombre;

  const PsicologoDashboardScreen({
    super.key,
    required this.userId,
    this.nombre,
  });

  @override
  State<PsicologoDashboardScreen> createState() =>
      _PsicologoDashboardScreenState();
}

class _PsicologoDashboardScreenState extends State<PsicologoDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late final TabController _tabs;

  List<Map<String, dynamic>> _agenda = [];
  List<Map<String, dynamic>> _disponibilidad = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getAgendaPsicologo(widget.userId),
      _apiService.getDisponibilidadPsicologos(),
    ]);
    if (!mounted) return;
    setState(() {
      _agenda = results[0];
      _disponibilidad = results[1]
          .where(
            (d) =>
                (d['psicologo_id'] ?? d['psicologoId'] ?? '').toString() ==
                widget.userId,
          )
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _cambiarEstado(String citaId, String nuevoEstado) async {
    final ok = await _apiService.actualizarEstadoCita(
      citaId: citaId,
      estado: nuevoEstado,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Cita marcada como $nuevoEstado.'
              : (_apiService.lastError ?? 'No se pudo actualizar estado.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.dangerRed,
      ),
    );
    if (ok) await _cargar();
  }

  Future<void> _agregarBloqueDisponibilidad() async {
    int dia = 1;
    final hiCtrl = TextEditingController(text: '09:00');
    final hfCtrl = TextEditingController(text: '13:00');
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo horario de atención'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: dia,
                decoration: const InputDecoration(
                  labelText: 'Día de la semana',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 4, 5, 6]
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(_diaNombreCompleto(d)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDlg(() => dia = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hiCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hora inicio (HH:mm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hfCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hora fin (HH:mm)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDlg(() => saving = true);
                      final created =
                          await _apiService.crearDisponibilidadPsicologo(
                        psicologoId: widget.userId,
                        diaSemana: dia,
                        horaInicio: hiCtrl.text.trim(),
                        horaFin: hfCtrl.text.trim(),
                      );
                      if (!ctx.mounted) return;
                      setDlg(() => saving = false);
                      if (created != null) {
                        Navigator.pop(ctx);
                        await _cargar();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _apiService.lastError ?? 'No se pudo guardar.',
                            ),
                            backgroundColor: AppColors.dangerRed,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              child: Text(saving ? 'Guardando...' : 'Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('CONTROL+ · Psicología'),
          actions: [
            RoleSwitcherButton(
              currentRole: 'psicologo',
              userId: widget.userId,
              nombre: widget.nombre,
            ),
            IconButton(
              tooltip: 'Noticias',
              icon: const Icon(Icons.newspaper),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoticiasFeedScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Mi QR',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QRScreen(userId: widget.userId),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mi Perfil',
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userId: widget.userId,
                    nombre: widget.nombre,
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AppColors.badgeGold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Agenda'),
              Tab(text: 'Disponibilidad'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _agregarBloqueDisponibilidad,
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add_alarm),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [
                  RefreshIndicator(
                    onRefresh: _cargar,
                    child: _agenda.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(32),
                            children: const [
                              Text(
                                'No hay citas registradas en tu agenda.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _agenda.length,
                            itemBuilder: (ctx, i) {
                              final c = _agenda[i];
                              final alumno = (c['alumno_nombre'] ??
                                      c['alumnoNombre'] ??
                                      'Alumno')
                                  .toString();
                              final estado = (c['estado'] ?? 'agendada').toString();
                              final citaId = c['id'].toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              alumno,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15.5,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              estado.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${c['fecha'] ?? ''} · ${c['hora_inicio'] ?? c['horaInicio'] ?? ''} - ${c['hora_fin'] ?? c['horaFin'] ?? ''}',
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                      if ((c['motivo'] ?? '').toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Motivo: ${c['motivo']}',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      NotaClinicaScreen(
                                                    citaId: citaId,
                                                    alumnoNombre: alumno,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.lock_outline,
                                              size: 16,
                                            ),
                                            label: const Text('Nota Clínica'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryDark,
                                              foregroundColor: Colors.white,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (v) =>
                                                _cambiarEstado(citaId, v),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'completada',
                                                child: Text('Marcar Completada'),
                                              ),
                                              PopupMenuItem(
                                                value: 'no_asistio',
                                                child: Text('No asistió'),
                                              ),
                                              PopupMenuItem(
                                                value: 'cancelada',
                                                child: Text('Cancelar cita'),
                                              ),
                                            ],
                                            child: const Chip(
                                              label: Text('Estado'),
                                              avatar: Icon(
                                                Icons.edit,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _disponibilidad.length,
                      itemBuilder: (ctx, i) {
                        final s = _disponibilidad[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: Colors.white,
                          child: ListTile(
                            leading: const Icon(
                              Icons.schedule,
                              color: AppColors.primaryDark,
                            ),
                            title: Text(
                              _diaNombreCompleto(
                                s['dia_semana'] ?? s['diaSemana'],
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${s['hora_inicio'] ?? s['horaInicio'] ?? ''} - ${s['hora_fin'] ?? s['horaFin'] ?? ''}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.dangerRed,
                              ),
                              onPressed: () async {
                                await _apiService.eliminarDisponibilidadPsicologo(
                                  s['id'].toString(),
                                );
                                _cargar();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Expediente clínico confidencial protegido con ScreenSecurityService y cero caché local.
class NotaClinicaScreen extends StatefulWidget {
  final String citaId;
  final String alumnoNombre;

  const NotaClinicaScreen({
    super.key,
    required this.citaId,
    required this.alumnoNombre,
  });

  @override
  State<NotaClinicaScreen> createState() => _NotaClinicaScreenState();
}

class _NotaClinicaScreenState extends State<NotaClinicaScreen> {
  final ApiService _apiService = ApiService();
  final ScreenSecurityService _security = ScreenSecurityService();

  final TextEditingController _notasCtrl = TextEditingController();
  final TextEditingController _acuerdosCtrl = TextEditingController();
  String _nivelRiesgo = 'bajo';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _security.acquire();
    _cargarNota();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _acuerdosCtrl.dispose();
    _security.release();
    super.dispose();
  }

  Future<void> _cargarNota() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getNotaClinica(widget.citaId);
    if (!mounted) return;
    if (res != null) {
      _notasCtrl.text =
          (res['notas_clinicas'] ?? res['notasClinicas'] ?? '').toString();
      _acuerdosCtrl.text =
          (res['acuerdos_seguimiento'] ?? res['acuerdosSeguimiento'] ?? '')
              .toString();
      final nr =
          (res['nivel_riesgo'] ?? res['nivelRiesgo'] ?? 'bajo').toString();
      if (['bajo', 'medio', 'alto'].contains(nr)) _nivelRiesgo = nr;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _guardar() async {
    if (_notasCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa las notas clínicas.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final saved = await _apiService.upsertNotaClinica(
      citaId: widget.citaId,
      notasClinicas: _notasCtrl.text.trim(),
      acuerdosSeguimiento: _acuerdosCtrl.text.trim(),
      nivelRiesgo: _nivelRiesgo,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota clínica guardada de forma segura.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiService.lastError ?? 'No se pudo guardar el expediente.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('Expediente Confidencial'),
        ),
        body: ValueListenableBuilder<bool>(
          valueListenable: _security.isCaptured,
          builder: (context, captured, _) {
            if (captured) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.security,
                        size: 56,
                        color: AppColors.warning,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Grabación o captura detectada.\nEl expediente confidencial fue ocultado por seguridad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoftBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Paciente: ${widget.alumnoNombre} · Bloqueo de captura activo (no se almacena localmente).',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _nivelRiesgo,
                  decoration: const InputDecoration(
                    labelText: 'Nivel de riesgo',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'bajo', child: Text('Bajo')),
                    DropdownMenuItem(value: 'medio', child: Text('Medio')),
                    DropdownMenuItem(value: 'alto', child: Text('Alto')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _nivelRiesgo = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notasCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Notas clínicas de sesión',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _acuerdosCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Acuerdos y plan de seguimiento',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _guardar,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar Nota Clínica'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/connectivity_service.dart';
import '../service/session_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import 'qralumnos.dart';

class PedirSalonScreen extends StatefulWidget {
  final String profesorId;
  final String nombreProfesor;
  final String? numeroEmpleado;

  const PedirSalonScreen({
    super.key,
    required this.profesorId,
    required this.nombreProfesor,
    this.numeroEmpleado,
  });

  @override
  State<PedirSalonScreen> createState() => _PedirSalonScreenState();
}

class _PedirSalonScreenState extends State<PedirSalonScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _numEmpCtrl;
  final TextEditingController _materiaCtrl = TextEditingController();
  final TextEditingController _motivoCtrl = TextEditingController();

  List<Map<String, dynamic>> _salones = [];
  List<Map<String, dynamic>> _misReservaciones = [];
  List<Map<String, dynamic>> _clasesProfesor = [];

  String? _salonSeleccionadoId;
  String? _claseSeleccionadaId;
  String _tipoUso = 'asesoria';
  int _duracionMinutos = 120;
  bool _requierePaseLista = false;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _numEmpCtrl = TextEditingController(
      text: widget.numeroEmpleado ?? SessionService().numeroEmpleado ?? '',
    );
    _cargarDatos();
  }

  @override
  void dispose() {
    _numEmpCtrl.dispose();
    _materiaCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getSalonesConEstado(),
      _apiService.getReservacionesActivasProfesor(widget.profesorId),
      _apiService.getMateriasByProfesor(widget.profesorId),
    ]);

    if (!mounted) return;
    final salones = results[0];
    final disponibles = salones.where((s) => s['disponible'] == true).toList();

    setState(() {
      _salones = salones;
      _misReservaciones = results[1];
      _clasesProfesor = results[2];
      if (_salonSeleccionadoId == null && disponibles.isNotEmpty) {
        _salonSeleccionadoId = disponibles.first['id']?.toString();
      }
      _isLoading = false;
    });
  }

  Future<void> _reservar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_salonSeleccionadoId == null || _salonSeleccionadoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un salón disponible.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!ConnectivityService().isOnline.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere conexión a internet para reservar un salón.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await _apiService.reservarSalon(
      salonId: _salonSeleccionadoId!,
      profesorId: widget.profesorId,
      numeroEmpleado: _numEmpCtrl.text.trim(),
      nombreProfesor: widget.nombreProfesor,
      materia: _materiaCtrl.text.trim(),
      motivo: _motivoCtrl.text.trim(),
      claseId: _claseSeleccionadaId,
      tipoUso: _tipoUso,
      duracionMinutos: _duracionMinutos,
      requierePaseLista: _requierePaseLista,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true || res['id'] != null) {
      _materiaCtrl.clear();
      _motivoCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salón reservado correctamente.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _cargarDatos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ??
                _apiService.lastError ??
                'No se pudo reservar el salón.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  Future<void> _checkIn(String reservacionId) async {
    final ok = await _apiService.checkInSalon(reservacionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Check-in registrado correctamente.'
              : (_apiService.lastError ?? 'No se pudo realizar check-in.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.dangerRed,
      ),
    );
    if (ok) await _cargarDatos();
  }

  Future<void> _liberar(String reservacionId) async {
    final ok = await _apiService.liberarSalon(reservacionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Salón liberado.' : (_apiService.lastError ?? 'No se pudo liberar.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.dangerRed,
      ),
    );
    if (ok) await _cargarDatos();
  }

  Future<void> _cancelar(String reservacionId) async {
    final ok = await _apiService.cancelarReservacionSalon(reservacionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Reservación cancelada.'
              : (_apiService.lastError ?? 'No se pudo cancelar.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.dangerRed,
      ),
    );
    if (ok) await _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    final libres = _salones.where((s) => s['disponible'] == true).toList();

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('Solicitar Salón'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargarDatos,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_misReservaciones.isNotEmpty) ...[
                      const Text(
                        'Mis Reservaciones Activas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._misReservaciones.map(_buildReservacionCard),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nueva Solicitud de Salón',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: libres.any(
                                (s) => s['id']?.toString() == _salonSeleccionadoId,
                              )
                                  ? _salonSeleccionadoId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Salón disponible',
                                border: OutlineInputBorder(),
                              ),
                              items: libres.map((s) {
                                final id = s['id'].toString();
                                final num = s['numero'] ?? '';
                                final nom = s['nombre'] ?? '';
                                final edif = s['edificio'] ?? '';
                                return DropdownMenuItem(
                                  value: id,
                                  child: Text(
                                    '$num ${nom.toString().isNotEmpty ? "· $nom" : ""} ${edif.toString().isNotEmpty ? "($edif)" : ""}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _salonSeleccionadoId = v),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _numEmpCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Número de empleado',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Ingresa tu número de empleado'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _tipoUso,
                                    decoration: const InputDecoration(
                                      labelText: 'Tipo de uso',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'asesoria',
                                        child: Text('Asesoría'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'extraordinario',
                                        child: Text('Extraordinario'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'evento',
                                        child: Text('Evento'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'clase_reposicion',
                                        child: Text('Reposición'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setState(() => _tipoUso = v);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _duracionMinutos,
                                    decoration: const InputDecoration(
                                      labelText: 'Duración',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [60, 90, 120, 180]
                                        .map(
                                          (m) => DropdownMenuItem(
                                            value: m,
                                            child: Text('$m min'),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _duracionMinutos = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _materiaCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Materia o actividad',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Indica la materia o actividad'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _motivoCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Motivo de solicitud',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Indica el motivo'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Requiere pase de lista con QR'),
                              value: _requierePaseLista,
                              onChanged: (v) =>
                                  setState(() => _requierePaseLista = v),
                            ),
                            if (_requierePaseLista && _clasesProfesor.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DropdownButtonFormField<String>(
                                  value: _claseSeleccionadaId,
                                  decoration: const InputDecoration(
                                    labelText: 'Vincular materia / clase',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _clasesProfesor
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: (m['clase_id'] ?? m['id'])
                                              .toString(),
                                          child: Text(
                                            m['nombre']?.toString() ?? 'Clase',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _claseSeleccionadaId = v),
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _reservar,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.meeting_room_outlined),
                                label: Text(
                                  _isSubmitting
                                      ? 'Reservando...'
                                      : 'Confirmar Reservación',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Disponibilidad General (${libres.length}/${_salones.length} libres)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _salones.map((s) {
                        final disp = s['disponible'] == true;
                        final num = s['numero']?.toString() ?? '';
                        return Chip(
                          avatar: Icon(
                            disp ? Icons.check_circle : Icons.lock,
                            size: 16,
                            color: disp ? AppColors.success : AppColors.dangerRed,
                          ),
                          label: Text(
                            num,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: Colors.white,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildReservacionCard(Map<String, dynamic> r) {
    final resId = r['id']?.toString() ?? '';
    final salon = (r['salon_numero'] ?? r['salon'] ?? 'Salón').toString();
    final materia = (r['materia'] ?? '').toString();
    final motivo = (r['motivo'] ?? '').toString();
    final estado = (r['estado'] ?? 'reservado').toString();
    final claseId = (r['clase_id'] ?? r['claseId'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.meeting_room, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Salón $salon · $materia',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
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
            if (motivo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(motivo, style: TextStyle(color: Colors.grey[700])),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (estado != 'en_uso')
                  ElevatedButton.icon(
                    onPressed: () => _checkIn(resId),
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Check-in'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (claseId.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClaseQrScreen(
                          claseId: claseId,
                          nombreMateria: materia,
                          grupo: salon,
                          reservacionId: resId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_2, size: 16),
                    label: const Text('QR Pase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _liberar(resId),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Liberar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.successDark,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _cancelar(resId),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerRed,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

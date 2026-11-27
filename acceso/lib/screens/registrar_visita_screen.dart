import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../service/api_service.dart';
import '../service/connectivity_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui_components.dart';

class RegistrarVisitaScreen extends StatefulWidget {
  final String adminId;

  const RegistrarVisitaScreen({
    super.key,
    required this.adminId,
  });

  @override
  State<RegistrarVisitaScreen> createState() => _RegistrarVisitaScreenState();
}

class _RegistrarVisitaScreenState extends State<RegistrarVisitaScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();

  DateTime _fechaVisita = DateTime.now();
  TimeOfDay? _horaInicio = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _horaFin = const TimeOfDay(hour: 13, minute: 0);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _empresaCtrl.dispose();
    _cargoCtrl.dispose();
    _motivoCtrl.dispose();
    _contactoCtrl.dispose();
    super.dispose();
  }

  String? _formatTime(TimeOfDay? t) {
    if (t == null) return null;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVisita,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _fechaVisita = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial =
        (isStart ? _horaInicio : _horaFin) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _horaInicio = picked;
        } else {
          _horaFin = picked;
        }
      });
    }
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!ConnectivityService().isOnline.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere conexión a internet para registrar visitas.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await _apiService.registrarVisita(
      nombre: _nombreCtrl.text.trim(),
      correo: _correoCtrl.text.trim(),
      empresa: _empresaCtrl.text.trim(),
      cargo: _cargoCtrl.text.trim(),
      motivo: _motivoCtrl.text.trim(),
      contactoInterno: _contactoCtrl.text.trim(),
      fechaVisita: _fechaVisita,
      horaInicio: _formatTime(_horaInicio),
      horaFin: _formatTime(_horaFin),
      registradoPor: widget.adminId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final ok = res['success'] == true ||
        res['id'] != null ||
        res['qr_codigo'] != null ||
        res['qrCodigo'] != null;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ??
                _apiService.lastError ??
                'No se pudo registrar la visita.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    final visitorName = _nombreCtrl.text.trim();
    final company = _empresaCtrl.text.trim();
    final qrCode = (res['qr_codigo'] ??
            res['qrCodigo'] ??
            res['codigo'] ??
            res['id'] ??
            '')
        .toString();

    _nombreCtrl.clear();
    _correoCtrl.clear();
    _empresaCtrl.clear();
    _cargoCtrl.clear();
    _motivoCtrl.clear();
    _contactoCtrl.clear();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Visita Registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$visitorName ($company)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Fecha: ${DateFormat('dd/MM/yyyy').format(_fechaVisita)} · ${_formatTime(_horaInicio) ?? ''} - ${_formatTime(_horaFin) ?? ''}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            if (qrCode.isNotEmpty)
              QrImageView(
                data: qrCode,
                version: QrVersions.auto,
                size: 190,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.primaryDark,
                ),
              ),
            const SizedBox(height: 8),
            SelectableText(
              'Código de acceso: $qrCode',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        actions: [
          if (qrCode.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Share.share(
                  'Pase de Acceso CONTROL+\nVisitante: $visitorName ($company)\nFecha: ${DateFormat('dd/MM/yyyy').format(_fechaVisita)} (${_formatTime(_horaInicio) ?? ''} - ${_formatTime(_horaFin) ?? ''})\nCódigo QR: $qrCode',
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir Pase'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Listo'),
          ),
        ],
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
          title: const Text('Registrar Visita'),
        ),
        body: ResponsiveContainer(
          padding: EdgeInsets.zero,
          child: Form(
            key: _formKey,
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo del visitante',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _empresaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Empresa / Institución',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _cargoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cargo / Puesto',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Persona o área que visita',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _motivoCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Motivo de la visita',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                      title: const Text('Fecha de visita'),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaVisita)),
                      trailing: TextButton(
                        onPressed: _pickDate,
                        child: const Text('Cambiar'),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(true),
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text('Inicio: ${_formatTime(_horaInicio) ?? "--:--"}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(false),
                            icon: const Icon(Icons.access_time_filled, size: 18),
                            label: Text('Fin: ${_formatTime(_horaFin) ?? "--:--"}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _registrar,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.qr_code_2),
                        label: Text(
                          _isSubmitting
                              ? 'Registrando...'
                              : 'Generar Pase QR de Visita',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
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

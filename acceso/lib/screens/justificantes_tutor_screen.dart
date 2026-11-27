import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';

class JustificantesTutorScreen extends StatefulWidget {
  final String tutorId;
  final String? nombreTutor;

  const JustificantesTutorScreen({
    super.key,
    required this.tutorId,
    this.nombreTutor,
  });

  @override
  State<JustificantesTutorScreen> createState() =>
      _JustificantesTutorScreenState();
}

class _JustificantesTutorScreenState extends State<JustificantesTutorScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _justificantes = [];
  bool _isLoading = true;
  bool _fromCache = false;
  String _filtroEstado = 'pendiente';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getJustificantesByTutor(widget.tutorId);
    if (!mounted) return;
    setState(() {
      _justificantes = list;
      _fromCache = _apiService.lastDataFromCache;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtroEstado == 'todos') return _justificantes;
    return _justificantes.where((j) {
      return (j['estado'] ?? 'pendiente').toString().toLowerCase() ==
          _filtroEstado;
    }).toList();
  }

  Future<void> _revisar(
    Map<String, dynamic> justificante,
    String nuevoEstado,
  ) async {
    String comentario = '';
    final aprobar = nuevoEstado == 'aprobado';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(aprobar ? 'Aprobar justificante' : 'Rechazar justificante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alumno: ${justificante['alumno_nombre'] ?? justificante['alumnoNombre'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              maxLines: 3,
              onChanged: (v) => comentario = v,
              decoration: InputDecoration(
                labelText: aprobar
                    ? 'Observaciones (opcional)'
                    : 'Motivo de rechazo',
                border: const OutlineInputBorder(),
              ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: aprobar ? AppColors.success : AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: Text(aprobar ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final justId = justificante['id']?.toString() ?? '';
    final ok = await _apiService.revisarJustificante(
      justificanteId: justId,
      tutorId: widget.tutorId,
      nuevoEstado: nuevoEstado,
      comentario: comentario.trim(),
    );

    if (!mounted) return;

    if (ok) {
      final msg = _apiService.lastMutationQueuedOffline
          ? 'Revisión guardada en cola offline. Se sincronizará automáticamente.'
          : (aprobar
              ? 'Justificante aprobado y notificado.'
              : 'Justificante rechazado.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: _apiService.lastMutationQueuedOffline
              ? AppColors.warning
              : AppColors.success,
        ),
      );
      if (!_apiService.lastMutationQueuedOffline) {
        await _cargar();
      } else {
        setState(() {
          justificante['estado'] = nuevoEstado;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiService.lastError ?? 'No se pudo procesar la revisión.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return raw.toString();
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtrados;
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('Revisión de Justificantes'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          ],
        ),
        body: Column(
          children: [
            if (_fromCache)
              Container(
                width: double.infinity,
                color: AppColors.surfaceSoftBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: const Text(
                  'Modo sin conexión: las revisiones se enviarán al recuperar señal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  _chip('pendiente', 'Pendientes'),
                  const SizedBox(width: 8),
                  _chip('aprobado', 'Aprobados'),
                  const SizedBox(width: 8),
                  _chip('rechazado', 'Rechazados'),
                  const SizedBox(width: 8),
                  _chip('todos', 'Todos (${_justificantes.length})'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: items.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: [
                                Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 62,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay justificantes en esta bandeja.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: items.length,
                              itemBuilder: (ctx, i) => _buildCard(items[i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _filtroEstado == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primaryDark,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _filtroEstado = value),
    );
  }

  Widget _buildCard(Map<String, dynamic> j) {
    final alumno =
        (j['alumno_nombre'] ?? j['alumnoNombre'] ?? 'Alumno').toString();
    final matricula = (j['matricula'] ?? '').toString();
    final grupo = (j['grupo'] ?? '').toString();
    final titulo = (j['titulo'] ?? 'Justificante').toString();
    final asunto = (j['asunto'] ?? '').toString();
    final estado = (j['estado'] ?? 'pendiente').toString().toLowerCase();
    final rawUrls = (j['imagenes_urls'] ??
            j['imagenesUrls'] ??
            j['evidencia_url'] ??
            '')
        .toString();

    final rawFechas = j['fechas_faltas'] ?? j['fechasFaltas'];
    final fechas = rawFechas is List
        ? rawFechas.map((e) => e.toString()).join(', ')
        : (rawFechas?.toString() ?? '');

    final color = estado == 'aprobado'
        ? AppColors.success
        : (estado == 'rechazado' ? AppColors.dangerRed : AppColors.warning);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryDark,
                  child: Text(
                    alumno.isNotEmpty ? alumno[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alumno,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        [
                          if (matricula.isNotEmpty) 'Mat: $matricula',
                          if (grupo.isNotEmpty) 'Grupo $grupo',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    estado.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            if (asunto.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(asunto, style: TextStyle(color: Colors.grey[800])),
            ],
            if (fechas.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Fechas: $fechas',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
            if (rawUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              EvidencePreviewStrip(rawUrlsCsv: rawUrls),
            ],
            const SizedBox(height: 6),
            Text(
              'Recibido: ${_formatDate(j['created_at'] ?? j['createdAt'])}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
            ),
            if (estado == 'pendiente') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _revisar(j, 'rechazado'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dangerRed,
                        side: const BorderSide(color: AppColors.dangerRed),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _revisar(j, 'aprobado'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

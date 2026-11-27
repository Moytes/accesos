import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';

class JustificantesProfesorScreen extends StatefulWidget {
  final String profesorId;
  final String materiaNombre;
  final String grupo;
  final String claseId;

  const JustificantesProfesorScreen({
    super.key,
    required this.profesorId,
    required this.materiaNombre,
    required this.grupo,
    required this.claseId,
  });

  @override
  State<JustificantesProfesorScreen> createState() =>
      _JustificantesProfesorScreenState();
}

class _JustificantesProfesorScreenState
    extends State<JustificantesProfesorScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _justificantes = [];
  bool _isLoading = true;
  bool _soloEstaClase = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getJustificantesAprobadosByProfesor(
      widget.profesorId,
    );
    if (!mounted) return;
    setState(() {
      _justificantes = list;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _itemsFiltrados {
    if (!_soloEstaClase || widget.claseId.isEmpty) return _justificantes;
    return _justificantes.where((j) {
      final detalles = j['detalles'];
      if (detalles is List) {
        return detalles.any(
          (d) =>
              d is Map &&
              (d['clase_id']?.toString() == widget.claseId ||
                  d['materia_id']?.toString() == widget.claseId),
        );
      }
      final cids = j['clase_ids'] ?? j['claseIds'];
      if (cids is List) {
        return cids.map((e) => e.toString()).contains(widget.claseId);
      }
      return true;
    }).toList();
  }

  Future<String?> _pedirComentario(bool aceptar) async {
    String texto = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          aceptar ? 'Aplicar justificación' : 'No aplicar justificación',
        ),
        content: TextField(
          maxLines: 3,
          onChanged: (v) => texto = v,
          decoration: const InputDecoration(
            labelText: 'Comentario docente (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  aceptar ? AppColors.success : AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: Text(aceptar ? 'Aplicar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return texto.trim();
  }

  Future<void> _dictaminarDetalle(
    Map<String, dynamic> detalle,
    bool aceptar,
  ) async {
    final comentario = await _pedirComentario(aceptar);
    if (comentario == null || !mounted) return;

    final detalleId = detalle['id']?.toString() ?? '';
    final ok = await _apiService.dictaminarDetalleJustificante(
      detalleId: detalleId,
      estadoProfesor: aceptar ? 'aplicado' : 'rechazado',
      comentario: comentario,
    );
    if (!mounted) return;

    if (ok) {
      final queued = _apiService.lastMutationQueuedOffline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Dictamen guardado offline. Se sincronizará al conectarse.'
                : (aceptar
                    ? 'Asistencia marcada como justificada.'
                    : 'Detalle rechazado.'),
          ),
          backgroundColor: queued ? AppColors.warning : AppColors.success,
        ),
      );
      if (queued) {
        setState(() {
          detalle['estado_profesor'] = aceptar ? 'aplicado' : 'rechazado';
        });
      } else {
        await _cargar();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiService.lastError ?? 'Error dictaminando justificante.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  Future<void> _aplicarGeneral(
    Map<String, dynamic> j,
    bool aceptar,
  ) async {
    final comentario = await _pedirComentario(aceptar);
    if (comentario == null || !mounted) return;

    final rawFechas = j['fechas_faltas'] ?? j['fechasFaltas'];
    final fechas = rawFechas is List
        ? rawFechas.map((e) => e.toString()).toList()
        : (rawFechas?.toString() ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final cidsRaw = j['clase_ids'] ?? j['claseIds'];
    final claseIds = cidsRaw is List
        ? cidsRaw.map((e) => e.toString()).toList()
        : [widget.claseId];

    final ok = await _apiService.aplicarJustificanteGeneral(
      justificanteId: j['id']?.toString() ?? '',
      userId: (j['user_id'] ?? j['userId'] ?? '').toString(),
      claseIds: claseIds,
      fechas: fechas,
      aceptado: aceptar,
      comentario: comentario,
    );
    if (!mounted) return;

    if (ok) {
      final queued = _apiService.lastMutationQueuedOffline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Dictamen en cola offline. Se aplicará al reconectar.'
                : (aceptar
                    ? 'Justificación aplicada a la asistencia.'
                    : 'Justificación marcada como no aceptada.'),
          ),
          backgroundColor: queued ? AppColors.warning : AppColors.success,
        ),
      );
      if (!queued) await _cargar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiService.lastError ?? 'No se pudo procesar el justificante.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsFiltrados;
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Justificantes Aprobados', style: TextStyle(fontSize: 17)),
              Text(
                '${widget.materiaNombre} · Grupo ${widget.grupo}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          ],
        ),
        body: Column(
          children: [
            if (widget.claseId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Esta clase'),
                      selected: _soloEstaClase,
                      selectedColor: AppColors.primaryDark,
                      labelStyle: TextStyle(
                        color: _soloEstaClase
                            ? Colors.white
                            : AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _soloEstaClase = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Todas (${_justificantes.length})'),
                      selected: !_soloEstaClase,
                      selectedColor: AppColors.primaryDark,
                      labelStyle: TextStyle(
                        color: !_soloEstaClase
                            ? Colors.white
                            : AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _soloEstaClase = false),
                    ),
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
                                  Icons.assignment_turned_in_outlined,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay justificantes aprobados pendientes por aplicar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
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

  Widget _buildCard(Map<String, dynamic> j) {
    final alumno =
        (j['alumno_nombre'] ?? j['alumnoNombre'] ?? 'Alumno').toString();
    final matricula = (j['matricula'] ?? '').toString();
    final titulo = (j['titulo'] ?? 'Justificante').toString();
    final asunto = (j['asunto'] ?? '').toString();
    final comentarioTutor =
        (j['comentario_tutor'] ?? j['comentarioTutor'] ?? '').toString();
    final rawUrls = (j['imagenes_urls'] ??
            j['imagenesUrls'] ??
            j['evidencia_url'] ??
            '')
        .toString();
    final rawDetalles = j['detalles'];
    final detalles = rawDetalles is List
        ? rawDetalles
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(
              (d) =>
                  !_soloEstaClase ||
                  widget.claseId.isEmpty ||
                  d['clase_id']?.toString() == widget.claseId,
            )
            .toList()
        : <Map<String, dynamic>>[];

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
                  backgroundColor: AppColors.primary,
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
                      if (matricula.isNotEmpty)
                        Text(
                          'Matrícula: $matricula',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'AVAL TUTOR',
                    style: TextStyle(
                      color: AppColors.successDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
            if (asunto.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(asunto, style: TextStyle(color: Colors.grey[800])),
            ],
            if (comentarioTutor.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tutoría: $comentarioTutor',
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ],
            if (rawUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              EvidencePreviewStrip(rawUrlsCsv: rawUrls),
            ],
            if (detalles.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Sesiones incluidas:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              ...detalles.map((d) {
                final est = (d['estado_profesor'] ??
                        d['estadoProfesor'] ??
                        'pendiente')
                    .toString();
                final mat = (d['materia_nombre'] ??
                        d['materiaNombre'] ??
                        widget.materiaNombre)
                    .toString();
                final fecha =
                    (d['fecha_falta'] ?? d['fechaFalta'] ?? '').toString();
                final hasId = (d['id']?.toString() ?? '').isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoftBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$mat · $fecha',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            est.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: est == 'aplicado'
                                  ? AppColors.successDark
                                  : (est == 'rechazado'
                                      ? AppColors.dangerRed
                                      : AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                      if (est == 'pendiente' && hasId) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _dictaminarDetalle(d, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.dangerRed,
                                  side: const BorderSide(
                                    color: AppColors.dangerRed,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Rechazar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _dictaminarDetalle(d, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Aplicar Justificación'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _aplicarGeneral(j, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dangerRed,
                        side: const BorderSide(color: AppColors.dangerRed),
                      ),
                      child: const Text('No aplicar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _aplicarGeneral(j, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aplicar en clase'),
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

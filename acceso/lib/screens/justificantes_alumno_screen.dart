import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service/api_service.dart';
import '../service/app_permissions_service.dart';
import '../service/connectivity_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';

class JustificantesAlumnoScreen extends StatefulWidget {
  final String userId;

  const JustificantesAlumnoScreen({
    super.key,
    required this.userId,
  });

  @override
  State<JustificantesAlumnoScreen> createState() =>
      _JustificantesAlumnoScreenState();
}

class _JustificantesAlumnoScreenState extends State<JustificantesAlumnoScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _justificantes = [];
  bool _isLoading = true;
  bool _fromCache = false;
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _cargarJustificantes();
  }

  Future<void> _cargarJustificantes() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getJustificantesByAlumno(widget.userId);
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
      final estado = (j['estado'] ?? 'pendiente').toString().toLowerCase();
      return estado == _filtroEstado;
    }).toList();
  }

  Color _estadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'aprobado':
        return AppColors.success;
      case 'rechazado':
        return AppColors.dangerRed;
      default:
        return AppColors.warning;
    }
  }

  String _estadoLabel(String estado) {
    switch (estado.toLowerCase()) {
      case 'aprobado':
        return 'Aprobado por Tutor';
      case 'rechazado':
        return 'Rechazado';
      default:
        return 'En revisión';
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return raw.toString();
    return DateFormat('dd/MM/yyyy').format(dt);
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
          title: const Text('Mis Justificantes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarJustificantes,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => CrearJustificanteScreen(userId: widget.userId),
              ),
            );
            if (created == true) {
              _cargarJustificantes();
            }
          },
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Nuevo Justificante'),
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
                  'Mostrando historial guardado localmente.',
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
                  _filterChip('todos', 'Todos (${_justificantes.length})'),
                  const SizedBox(width: 8),
                  _filterChip('pendiente', 'En revisión'),
                  const SizedBox(width: 8),
                  _filterChip('aprobado', 'Aprobados'),
                  const SizedBox(width: 8),
                  _filterChip('rechazado', 'Rechazados'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargarJustificantes,
                      child: items.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No tienes justificantes registrados en esta categoría.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                8,
                                14,
                                90,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) =>
                                  _buildJustificanteCard(items[index]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filtroEstado == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primaryDark,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      onSelected: (_) => setState(() => _filtroEstado = value),
    );
  }

  Widget _buildJustificanteCard(Map<String, dynamic> j) {
    final estado = (j['estado'] ?? 'pendiente').toString();
    final color = _estadoColor(estado);
    final titulo = (j['titulo'] ?? 'Justificante de inasistencia').toString();
    final asunto = (j['asunto'] ?? '').toString();
    final comentarioTutor =
        (j['comentario_tutor'] ?? j['comentarioTutor'] ?? '').toString();
    final rawUrls = (j['imagenes_urls'] ??
            j['imagenesUrls'] ??
            j['evidencia_url'] ??
            '')
        .toString();

    final rawFechas = j['fechas_faltas'] ?? j['fechasFaltas'];
    final List<String> fechas = rawFechas is List
        ? rawFechas.map((e) => e.toString()).toList()
        : (rawFechas?.toString() ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final rawDetalles = j['detalles'];
    final List<Map<String, dynamic>> detalles = rawDetalles is List
        ? rawDetalles
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _estadoLabel(estado),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            if (asunto.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                asunto,
                style: TextStyle(color: Colors.grey[800], fontSize: 13.5),
              ),
            ],
            if (fechas.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: fechas
                    .map(
                      (f) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoftBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (detalles.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Dictamen por materia:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              ...detalles.map((d) {
                final mat =
                    (d['materia_nombre'] ?? d['materiaNombre'] ?? 'Materia')
                        .toString();
                final estProf = (d['estado_profesor'] ??
                        d['estadoProfesor'] ??
                        'pendiente')
                    .toString();
                final commProf = (d['comentario_profesor'] ??
                        d['comentarioProfesor'] ??
                        '')
                    .toString();
                final estColor = estProf == 'aplicado'
                    ? AppColors.success
                    : (estProf == 'rechazado'
                        ? AppColors.dangerRed
                        : AppColors.warning);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: estColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$mat (${d['fecha_falta'] ?? d['fechaFalta'] ?? ''})${commProf.isNotEmpty ? " · $commProf" : ""}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      Text(
                        estProf.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: estColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (comentarioTutor.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Comentario de Tutoría: $comentarioTutor',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey[800],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (rawUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              EvidencePreviewStrip(rawUrlsCsv: rawUrls),
            ],
            const SizedBox(height: 8),
            Text(
              'Enviado: ${_formatDate(j['created_at'] ?? j['createdAt'])}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class CrearJustificanteScreen extends StatefulWidget {
  final String userId;

  const CrearJustificanteScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CrearJustificanteScreen> createState() =>
      _CrearJustificanteScreenState();
}

class _CrearJustificanteScreenState extends State<CrearJustificanteScreen> {
  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivity = ConnectivityService();
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _asuntoCtrl = TextEditingController();

  List<Map<String, dynamic>> _faltasAgrupadas = [];
  final Set<String> _fechasSeleccionadas = {};
  final List<PickedAttachment> _adjuntos = [];
  bool _isLoadingFaltas = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cargarFaltas();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _asuntoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarFaltas() async {
    setState(() => _isLoadingFaltas = true);
    final list = await _apiService.getFaltasAgrupadasPorFecha(widget.userId);
    if (!mounted) return;
    setState(() {
      _faltasAgrupadas = list;
      _isLoadingFaltas = false;
    });
  }

  Future<void> _agregarEvidencia() async {
    final nuevos = await AppPermissionsService.showAttachmentPickerSheet(
      context,
      allowPdf: true,
      allowMultiple: true,
      title: 'Adjuntar receta, constancia o evidencia',
    );
    if (nuevos.isEmpty || !mounted) return;

    setState(() {
      for (final item in nuevos) {
        if (_adjuntos.length >= 5) break;
        _adjuntos.add(item);
      }
    });
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechasSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos una fecha con falta a justificar.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_connectivity.isOnline.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Necesitas conexión a internet para subir tus evidencias y registrar el justificante.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final claseIdsSet = <String>{};
    for (final f in _faltasAgrupadas) {
      final fecha = f['fecha']?.toString() ?? '';
      if (_fechasSeleccionadas.contains(fecha)) {
        final cids = f['claseIds'];
        if (cids is List) {
          for (final id in cids) {
            if (id.toString().isNotEmpty) claseIdsSet.add(id.toString());
          }
        }
      }
    }

    final uploadedUrls = <String>[];
    for (final adj in _adjuntos) {
      final url = await _apiService.uploadJustificanteImage(
        adj.bytes,
        adj.fileName,
        widget.userId,
      );
      if (url != null && url.isNotEmpty) {
        uploadedUrls.add(url);
      } else {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _apiService.lastError ??
                  'Error subiendo el archivo "${adj.fileName}".',
            ),
            backgroundColor: AppColors.dangerRed,
          ),
        );
        return;
      }
    }

    final created = await _apiService.crearJustificanteGeneral(
      userId: widget.userId,
      titulo: _tituloCtrl.text.trim(),
      asunto: _asuntoCtrl.text.trim(),
      fechasFaltas: _fechasSeleccionadas.toList(),
      claseIds: claseIdsSet.toList(),
      imagenesUrls: uploadedUrls,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Justificante enviado correctamente a Tutoría.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiService.lastError ?? 'No se pudo enviar el justificante.',
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
          title: const Text('Nuevo Justificante'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Fechas de inasistencia',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingFaltas)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_faltasAgrupadas.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoftBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'No se encontraron faltas pendientes por justificar.',
                          style: TextStyle(color: AppColors.primaryDark),
                        ),
                      )
                    else
                      ..._faltasAgrupadas.map((item) {
                        final fecha = item['fecha']?.toString() ?? '';
                        final materias = List<String>.from(
                          item['materias'] ?? const [],
                        );
                        final selected = _fechasSeleccionadas.contains(fecha);
                        return CheckboxListTile(
                          value: selected,
                          activeColor: AppColors.primaryDark,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            fecha,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            materias.join(', '),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey[700],
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _fechasSeleccionadas.add(fecha);
                              } else {
                                _fechasSeleccionadas.remove(fecha);
                              }
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2. Motivo y descripción',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título / Motivo breve',
                        hintText: 'Ej. Consulta médica IMSS',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().length < 4)
                          ? 'Ingresa un título válido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _asuntoCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción detallada',
                        hintText: 'Explica el motivo de la inasistencia...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().length < 8)
                          ? 'Describe brevemente la situación'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '3. Evidencias (Foto, Galería o PDF)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        Text(
                          '${_adjuntos.length}/5',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'La app solicitará permiso para cámara o archivos al seleccionar tu comprobante.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    if (_adjuntos.isNotEmpty)
                      SizedBox(
                        height: 92,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _adjuntos.length,
                          itemBuilder: (context, idx) {
                            final adj = _adjuntos[idx];
                            return Stack(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoftBlue,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: adj.isPdf
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.picture_as_pdf,
                                              color: AppColors.dangerRed,
                                              size: 32,
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              child: Text(
                                                adj.fileName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Image.memory(
                                          Uint8List.fromList(adj.bytes),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _adjuntos.removeAt(idx)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          _adjuntos.length >= 5 ? null : _agregarEvidencia,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Adjuntar Foto o PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: const BorderSide(color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _enviar,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'Enviando...' : 'Enviar Justificante',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

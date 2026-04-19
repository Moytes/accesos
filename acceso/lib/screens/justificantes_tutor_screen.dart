import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';

class JustificantesTutorScreen extends StatefulWidget {
  final String tutorId;
  final String? nombreTutor;

  const JustificantesTutorScreen({
    Key? key,
    required this.tutorId,
    this.nombreTutor,
  }) : super(key: key);

  @override
  State<JustificantesTutorScreen> createState() =>
      _JustificantesTutorScreenState();
}

class _JustificantesTutorScreenState
    extends State<JustificantesTutorScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _justificantes = [];
  bool _isLoading = true;
  String _filtroEstado = 'pendiente';

  @override
  void initState() {
    super.initState();
    _cargarJustificantes();
  }

  Future<void> _cargarJustificantes() async {
    setState(() => _isLoading = true);
    try {
      final todos = await _apiService.getJustificantesByTutor(widget.tutorId);
      setState(() {
        _justificantes = todos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _justificantesFiltrados {
    if (_filtroEstado == 'todos') return _justificantes;
    return _justificantes
        .where((j) => j['estado'] == _filtroEstado)
        .toList();
  }

  int get _pendientesCount =>
      _justificantes.where((j) => j['estado'] == 'pendiente').length;

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'aprobado':
      case 'aplicado':
        return const Color(0xFF4CAF50);
      case 'rechazado':
      case 'rechazado_profesor':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFF9800);
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'aprobado':
        return 'Aprobado';
      case 'aplicado':
        return 'Aplicado';
      case 'rechazado':
        return 'Rechazado';
      case 'rechazado_profesor':
        return 'Rechazado por profesor';
      default:
        return estado;
    }
  }

  // ── CORRECCIÓN PRINCIPAL: Dialog con ConstrainedBox ──
  Future<void> _mostrarDialogoRevision(
      Map<String, dynamic> justificante) async {
    final comentarioController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        // ✅ Controla el margen lateral del Dialog directamente
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            // ❌ Quita el maxWidth de aquí — el insetPadding ya lo controla
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Revisar justificante',
                        style: TextStyle(
                          color: Color(0xFF004C8C),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Contenido scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),

                      // Info alumno
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004C8C).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person,
                                    size: 16, color: Color(0xFF004C8C)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    justificante['users']?['nombre'] ??
                                        'Sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF004C8C),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Matrícula: ${justificante['users']?['matricula'] ?? 'N/A'}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            Text(
                              'Grupo: ${justificante['users']?['grupo'] ?? 'N/A'}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        justificante['titulo'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        justificante['asunto'] ?? '',
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'Fechas solicitadas:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children:
                            (justificante['fechas_faltas'] as String? ?? '')
                                .split(',')
                                .where((f) => f.isNotEmpty)
                                .map((f) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF004C8C)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        f,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF004C8C),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ))
                                .toList(),
                      ),

                      // Imágenes — CORRECCIÓN: SizedBox con altura fija
                      if ((justificante['imagen_url'] as String? ?? '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Evidencias adjuntas:',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),
                        _buildImagenesPreview(
                            justificante['imagen_url'] as String),
                      ],

                      const SizedBox(height: 16),
                      const Text(
                        'Comentario (opcional):',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: comentarioController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'Escribe un comentario para el alumno...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF004C8C), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Botones de acción fuera del scroll
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancelar',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _procesarRevision(
                          justificante['id'],
                          'rechazado',
                          comentarioController.text,
                        );
                      },
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Rechazar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF44336),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _procesarRevision(
                          justificante['id'],
                          'aprobado',
                          comentarioController.text,
                        );
                      },
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CORRECCIÓN: ListView horizontal con shrinkWrap y ClampingScrollPhysics ──
  Widget _buildImagenesPreview(String imagenesStr) {
    final urls =
        imagenesStr.split(',').where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        shrinkWrap: true,
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.black,
                  child: InteractiveViewer(
                    child: Image.network(
                      urls[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image,
                            size: 80, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  urls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _procesarRevision(
      String id, String estado, String comentario) async {
    final resultado = await _apiService.revisarJustificante(
      justificanteId: id,
      tutorId: widget.tutorId,
      nuevoEstado: estado,
      comentario: comentario,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado
                ? 'Justificante ${estado == 'aprobado' ? 'aprobado' : 'rechazado'} exitosamente'
                : 'Error al procesar justificante',
          ),
          backgroundColor:
              resultado ? const Color(0xFF4CAF50) : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      if (resultado) _cargarJustificantes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFE8E8E8),
        appBar: AppBar(
          title: Row(
            children: [
              const Text(
                'Justificantes',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              if (_pendientesCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_pendientesCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: const Color(0xFF004C8C),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Column(
          children: [
            // Filtros con scroll horizontal
            Container(
              color: const Color(0xFF004C8C),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFiltroChip('Pendientes', 'pendiente'),
                    const SizedBox(width: 8),
                    _buildFiltroChip('Aprobados', 'aprobado'),
                    const SizedBox(width: 8),
                    _buildFiltroChip('Rechazados', 'rechazado'),
                    const SizedBox(width: 8),
                    _buildFiltroChip('Todos', 'todos'),
                  ],
                ),
              ),
            ),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF004C8C)))
                  : RefreshIndicator(
                      onRefresh: _cargarJustificantes,
                      color: const Color(0xFF004C8C),
                      child: _justificantesFiltrados.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context)
                                          .size
                                          .height *
                                      0.5,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          Icons.description_outlined,
                                          size: 70,
                                          color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No hay justificantes',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount:
                                  _justificantesFiltrados.length,
                              itemBuilder: (context, index) {
                                final j =
                                    _justificantesFiltrados[index];
                                return _buildJustificanteCard(j);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String label, String value) {
    final isSelected = _filtroEstado == value;
    final pendientes =
        value == 'pendiente' ? _pendientesCount : 0;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF004C8C)
                    : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (pendientes > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendientes',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJustificanteCard(Map<String, dynamic> j) {
    final estado = j['estado'] as String? ?? 'pendiente';
    final isPendiente = estado == 'pendiente';
    final userData = j['users'] as Map<String, dynamic>?;
    final classData = j['classes'] as Map<String, dynamic>?;
    final materiasData =
        classData?['materias'] as Map<String, dynamic>?;
    final fechas =
        (j['fechas_faltas'] as String? ?? '').split(',');
    final imagenes =
        (j['imagen_url'] as String? ?? '').split(',');
    final tieneImagenes =
        imagenes.isNotEmpty && imagenes.first.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isPendiente
            ? Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.5),
                width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado alumno + estado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004C8C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person,
                      color: Color(0xFF004C8C), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userData?['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF004C8C),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Mat: ${userData?['matricula'] ?? 'N/A'} · Grupo ${userData?['grupo'] ?? 'N/A'}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 110),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _estadoColor(estado).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _estadoColor(estado), width: 1),
                  ),
                  child: Text(
                    _estadoLabel(estado),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _estadoColor(estado),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (materiasData != null)
              Row(
                children: [
                  Icon(Icons.book, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      materiasData['nom_mat'] ?? '',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),

            Text(
              j['titulo'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              j['asunto'] ?? '',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fechas.where((f) => f.isNotEmpty).join(' · '),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tieneImagenes)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file,
                          size: 13, color: Colors.grey[500]),
                      Text(
                        '${imagenes.where((i) => i.isNotEmpty).length}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
              ],
            ),

            if (isPendiente) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoRevision(j),
                  icon: const Icon(Icons.rate_review, size: 18),
                  label: const Text(
                    'Revisar justificante',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004C8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
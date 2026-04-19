import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';

// ============================================================
// PANTALLA DE JUSTIFICANTES PARA EL PROFESOR
// ============================================================
class JustificantesProfesorScreen extends StatefulWidget {
  final String profesorId;
  final String materiaNombre;
  final String grupo;
  final String claseId;

  const JustificantesProfesorScreen({
    Key? key,
    required this.profesorId,
    required this.materiaNombre,
    required this.grupo,
    required this.claseId,
  }) : super(key: key);

  @override
  State<JustificantesProfesorScreen> createState() =>
      _JustificantesProfesorScreenState();
}

class _JustificantesProfesorScreenState
    extends State<JustificantesProfesorScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _justificantes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarJustificantes();
  }

  Future<void> _cargarJustificantes() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final lista = await _apiService
          .getJustificantesAprobadosByProfesor(widget.profesorId);
      
      if (mounted) {
        setState(() {
          _justificantes = lista;
          _isLoading = false;
        });
        print('✅ Justificantes cargados: ${lista.length}');
      }
    } catch (e) {
      print('❌ Error al cargar justificantes: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar los justificantes';
          _isLoading = false;
        });
      }
    }
  }

  // ── CORRECCIÓN: Usar la misma estructura que funciona en el tutor ──
  Future<void> _mostrarDialogoConfirmacion(
      Map<String, dynamic> justificante, bool aceptado) async {
    final titulo = aceptado ? 'Justificar falta' : 'No aceptar justificante';
    final mensaje = aceptado
        ? '¿Confirmas que deseas cambiar las faltas de este alumno a asistencia justificada?'
        : '¿Confirmas que no aceptas este justificante? Las faltas se mantendrán.';
    final colorBoton =
        aceptado ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final textoBoton = aceptado ? 'Sí, justificar' : 'No aceptar';

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                        'Confirmar acción',
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

                      // Imágenes - Usando el mismo método que funciona en el tutor
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
                      Text(
                        mensaje,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
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
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text('Cancelar',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorBoton,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(textoBoton,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((confirm) async {
      if (confirm == true && mounted) {
        await _procesarJustificante(justificante, aceptado);
      }
    });
  }

  // ── Usar EXACTAMENTE el mismo método que funciona en el tutor ──
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

  Future<void> _procesarJustificante(
      Map<String, dynamic> justificante, bool aceptado) async {
    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Procesando justificante...'),
              ],
            ),
          ),
        ),
      ),
    );

    final userId = justificante['user_id'] as String;
    final fechas = (justificante['fechas_faltas'] as String? ?? '')
        .split(',')
        .where((f) => f.isNotEmpty)
        .map((f) => f.trim())
        .toList();

    final clasesDeLaTarjeta = justificante['clases_del_profesor'] as List?;
    List<String> claseIds;
    if (clasesDeLaTarjeta != null && clasesDeLaTarjeta.isNotEmpty) {
      claseIds = clasesDeLaTarjeta
          .map((c) => c['clase_id'] as String)
          .toList();
    } else {
      claseIds = [justificante['clase_id'] as String? ?? ''];
    }

    bool resultado = false;
    try {
      resultado = await _apiService.aplicarJustificanteGeneral(
        justificanteId: justificante['id'],
        userId: userId,
        claseIds: claseIds,
        fechas: fechas,
        aceptado: aceptado,
      );
    } catch (e) {
      print('❌ Error en _procesarJustificante: $e');
      resultado = false;
    }

    // Cerrar diálogo de carga
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (mounted) {
      if (resultado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aceptado
                  ? '✓ Asistencia justificada correctamente'
                  : 'Justificante marcado como no aceptado',
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 2),
          ),
        );
        await _cargarJustificantes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al procesar el justificante'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFE8E8E8),
        appBar: AppBar(
          title: const Text(
            'Justificantes',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF004C8C),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Column(
          children: [
            // Header informativo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF004C8C), Color(0xFF4A9FD8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.book, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        widget.materiaNombre,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.groups, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Grupo ${widget.grupo}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estos justificantes ya fueron aprobados por el tutor. '
                            'Puedes aceptarlos para cambiar la falta a asistencia justificada.',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Cuerpo principal
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF004C8C)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarJustificantes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004C8C),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_justificantes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay justificantes pendientes',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Todos los justificantes han sido procesados',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarJustificantes,
      color: const Color(0xFF004C8C),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _justificantes.length,
        itemBuilder: (context, index) {
          return _buildJustificanteCard(_justificantes[index]);
        },
      ),
    );
  }

  Widget _buildJustificanteCard(Map<String, dynamic> j) {
    final estado = j['estado'] as String? ?? 'aprobado';
    final isAprobado = estado == 'aprobado';
    final userData = j['users'] as Map<String, dynamic>?;
    final fechas = (j['fechas_faltas'] as String? ?? '').split(',');
    final imagenes = (j['imagen_url'] as String? ?? '').split(',');
    final tieneImagenes = imagenes.isNotEmpty && imagenes.first.isNotEmpty;

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
        border: isAprobado
            ? Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.4),
                width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      ),
                      Text(
                        'Matrícula: ${userData?['matricula'] ?? 'N/A'}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF4CAF50), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified,
                          size: 12, color: Color(0xFF4CAF50)),
                      SizedBox(width: 3),
                      Text(
                        'Tutor aprobó',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              j['titulo'] ?? '',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              j['asunto'] ?? '',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: fechas
                  .where((f) => f.isNotEmpty)
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004C8C)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF004C8C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            if (tieneImagenes) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.attach_file,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${imagenes.where((i) => i.isNotEmpty).length} evidencia(s)',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Evidencias'),
                          content: Container(
                            width: 300,
                            height: 300,
                            child: _buildImagenesPreview(j['imagen_url'] as String),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'Ver imágenes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A9FD8),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (isAprobado) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _mostrarDialogoConfirmacion(j, false),
                      icon: const Icon(Icons.cancel_outlined,
                          size: 18),
                      label: const Text('No aceptar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF44336),
                        side: const BorderSide(
                            color: Color(0xFFF44336)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _mostrarDialogoConfirmacion(j, true),
                      icon: const Icon(Icons.check_circle,
                          size: 18),
                      label: const Text(
                        'Justificar',
                        style: TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Ya procesado',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
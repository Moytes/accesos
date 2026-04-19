import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../service/api_service.dart';

// ============================================================
// PANTALLA PRINCIPAL DE JUSTIFICANTES PARA EL ALUMNO
// ============================================================
class JustificantesAlumnoScreen extends StatefulWidget {
  final String userId;
  const JustificantesAlumnoScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<JustificantesAlumnoScreen> createState() =>
      _JustificantesAlumnoScreenState();
}

class _JustificantesAlumnoScreenState
    extends State<JustificantesAlumnoScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _justificantes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarJustificantes();
  }

  Future<void> _cargarJustificantes() async {
    print('=== [JustificantesAlumnoScreen] CARGANDO JUSTIFICANTES ===');
    print('User ID: ${widget.userId}');
    setState(() => _isLoading = true);
    try {
      final todos =
          await _apiService.getJustificantesByAlumno(widget.userId);
      print('✓ Justificantes obtenidos: ${todos.length}');
      for (int i = 0; i < todos.length; i++) {
        print('  [$i] id=${todos[i]['id']} estado=${todos[i]['estado']} titulo=${todos[i]['titulo']}');
      }
      setState(() {
        _justificantes = todos;
        _isLoading = false;
      });
    } catch (e) {
      print('✗ Error al cargar justificantes: $e');
      setState(() => _isLoading = false);
    }
  }

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
        return 'Aprobado por tutor';
      case 'aplicado':
        return 'Justificado ✓';
      case 'rechazado':
        return 'Rechazado por tutor';
      case 'rechazado_profesor':
        return 'No aceptado por profesor';
      default:
        return estado;
    }
  }

  IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'aprobado':
      case 'aplicado':
        return Icons.check_circle;
      case 'rechazado':
      case 'rechazado_profesor':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Mis Justificantes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF003366),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          print('=== [JustificantesAlumnoScreen] Navegando a CrearJustificanteScreen ===');
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CrearJustificanteScreen(
                userId: widget.userId,
              ),
            ),
          );
          print('=== [JustificantesAlumnoScreen] Regresó de CrearJustificante, result=$result ===');
          if (result == true) {
            _cargarJustificantes();
          }
        },
        backgroundColor: const Color(0xFF003366),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nuevo justificante',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF003366)))
          : RefreshIndicator(
              onRefresh: _cargarJustificantes,
              color: const Color(0xFF003366),
              child: _justificantes.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.description_outlined,
                                  size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No tienes justificantes',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Crea uno con el botón +',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: _justificantes.length,
                      itemBuilder: (context, index) {
                        final j = _justificantes[index];
                        final estado = j['estado'] as String? ?? 'pendiente';
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
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        j['titulo'] ?? 'Sin título',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF003366),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _estadoColor(estado)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: _estadoColor(estado),
                                            width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_estadoIcon(estado),
                                              size: 14,
                                              color: _estadoColor(estado)),
                                          const SizedBox(width: 4),
                                          Text(
                                            _estadoLabel(estado),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _estadoColor(estado),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  j['asunto'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
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
                                              color: const Color(0xFF003366)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              f,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF003366),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                                if (tieneImagenes) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.attach_file,
                                          size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${imagenes.where((i) => i.isNotEmpty).length} imagen(es) adjunta(s)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (j['tutor_comentario'] != null &&
                                    (j['tutor_comentario'] as String)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.blue.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.comment_outlined,
                                            size: 14,
                                            color: Colors.blue[400]),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Tutor: ${j['tutor_comentario']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[700],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  _formatFecha(j['fecha_envio'] as String?),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _formatFecha(String? fechaStr) {
    if (fechaStr == null) return '';
    try {
      final fecha = DateTime.parse(fechaStr).toLocal();
      final months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      return 'Enviado el ${fecha.day} ${months[fecha.month - 1]} ${fecha.year}';
    } catch (e) {
      return '';
    }
  }
}

// ============================================================
// PANTALLA PARA CREAR UN NUEVO JUSTIFICANTE (general)
// ============================================================
class CrearJustificanteScreen extends StatefulWidget {
  final String userId;

  const CrearJustificanteScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<CrearJustificanteScreen> createState() =>
      _CrearJustificanteScreenState();
}

class _CrearJustificanteScreenState extends State<CrearJustificanteScreen> {
  final ApiService _apiService = ApiService();
  final _tituloController = TextEditingController();
  final _asuntoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _fechasConFaltas = [];
  List<String> _fechasSeleccionadas = [];
  List<XFile> _imagenesSeleccionadas = [];
  bool _isLoading = false;
  bool _cargandoFaltas = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarFechasConFaltas();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _asuntoController.dispose();
    super.dispose();
  }

  Future<void> _cargarFechasConFaltas() async {
    print('=== [CrearJustificante] CARGANDO FECHAS CON FALTAS ===');
    print('User ID: ${widget.userId}');
    setState(() => _cargandoFaltas = true);
    try {
      final fechas =
          await _apiService.getFaltasAgrupadasPorFecha(widget.userId);
      print('✓ Fechas con faltas obtenidas: ${fechas.length}');
      for (final f in fechas) {
        print('  fecha=${f['fecha']} materias=${f['materias']} claseIds=${f['claseIds']}');
      }
      setState(() {
        _fechasConFaltas = fechas;
        _cargandoFaltas = false;
      });
    } catch (e) {
      print('✗ Error al cargar fechas con faltas: $e');
      setState(() => _cargandoFaltas = false);
    }
  }

  Future<void> _seleccionarImagenes() async {
    print('=== [CrearJustificante] SELECCIONANDO IMÁGENES ===');
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 70,
      );
      print('Imágenes seleccionadas del picker: ${images.length}');
      for (final img in images) {
        print('  nombre=${img.name} path=${img.path}');
      }
      if (images.isNotEmpty) {
        setState(() {
          _imagenesSeleccionadas = [..._imagenesSeleccionadas, ...images]
              .take(5)
              .toList();
        });
        print('Total imágenes en lista: ${_imagenesSeleccionadas.length}');
      }
    } catch (e) {
      print('✗ Error al seleccionar imágenes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imágenes: $e')),
      );
    }
  }

  Future<void> _enviarJustificante() async {
    print('=== [CrearJustificante] INICIANDO ENVÍO ===');
    print('User ID: ${widget.userId}');
    print('Título: ${_tituloController.text.trim()}');
    print('Asunto (primeros 50 chars): ${_asuntoController.text.trim().substring(0, _asuntoController.text.trim().length.clamp(0, 50))}');
    print('Fechas seleccionadas: $_fechasSeleccionadas');
    print('Imágenes a subir: ${_imagenesSeleccionadas.length}');

    if (!_formKey.currentState!.validate()) {
      print('✗ Formulario inválido, abortando');
      return;
    }

    if (_fechasSeleccionadas.isEmpty) {
      print('✗ No hay fechas seleccionadas, abortando');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos una fecha'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── PASO 1: Subir imágenes ──────────────────────────────
      print('--- PASO 1: Subiendo imágenes ---');
      List<String> imagenesUrls = [];

      if (_imagenesSeleccionadas.isEmpty) {
        print('  Sin imágenes que subir, continuando...');
      }

      for (int i = 0; i < _imagenesSeleccionadas.length; i++) {
        final imagen = _imagenesSeleccionadas[i];
        print('  Subiendo imagen $i: nombre=${imagen.name}');

        final bytes = await imagen.readAsBytes();
        print('  Tamaño en bytes: ${bytes.length}');

        // Cambia esta línea (dentro del for loop en _enviarJustificante):
        final url = await _apiService.uploadJustificanteImage(
          bytes,
          imagen.name.isNotEmpty ? imagen.name : 'imagen_$i.jpg', // <-- fallback si name está vacío
          widget.userId,
        );

        print('  URL obtenida para imagen $i: $url');

        if (url != null) {
          imagenesUrls.add(url);
          print('  ✓ URL agregada a la lista');
        } else {
          print('  ✗ URL nula, imagen NO se guardará');
        }
      }

      print('Total URLs subidas exitosamente: ${imagenesUrls.length}');
      print('URLs: $imagenesUrls');

      // ── PASO 2: Recopilar claseIds ──────────────────────────
      print('--- PASO 2: Recopilando claseIds ---');
      final Set<String> claseIdsSet = {};

      for (final fechaData in _fechasConFaltas) {
        final fecha = fechaData['fecha'] as String;
        if (_fechasSeleccionadas.contains(fecha)) {
          final ids = fechaData['claseIds'] as List<String>;
          print('  Fecha $fecha → claseIds: $ids');
          claseIdsSet.addAll(ids);
        }
      }

      print('ClaseIds recopilados (únicos): ${claseIdsSet.toList()}');

      if (claseIdsSet.isEmpty) {
        print('⚠ ADVERTENCIA: No se encontraron claseIds para las fechas seleccionadas');
      }

      // ── PASO 3: Crear el justificante ───────────────────────
      print('--- PASO 3: Creando justificante general ---');
      print('  userId: ${widget.userId}');
      print('  titulo: ${_tituloController.text.trim()}');
      print('  fechasFaltas: $_fechasSeleccionadas');
      print('  claseIds: ${claseIdsSet.toList()}');
      print('  imagenesUrls: $imagenesUrls');

      final resultado = await _apiService.crearJustificanteGeneral(
        userId: widget.userId,
        titulo: _tituloController.text.trim(),
        asunto: _asuntoController.text.trim(),
        fechasFaltas: _fechasSeleccionadas,
        claseIds: claseIdsSet.toList(),
        imagenesUrls: imagenesUrls,
      );

      print('--- PASO 3 RESULTADO ---');
      print('  resultado: $resultado');

      setState(() => _isLoading = false);

      if (resultado != null) {
        print('✓ Justificante creado exitosamente');
        print('  ID generado: ${resultado['id']}');
        print('  imagen_url guardada: ${resultado['imagen_url']}');
        print('  fechas_faltas guardadas: ${resultado['fechas_faltas']}');
        print('  clases_ids guardadas: ${resultado['clases_ids']}');

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF4CAF50), size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    '¡Justificante enviado!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu tutor revisará tu justificante pronto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                  ),
                  child: const Text('Aceptar',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } else {
        print('✗ crearJustificanteGeneral retornó null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al enviar el justificante'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('✗ EXCEPCIÓN en _enviarJustificante: $e');
      print('StackTrace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Nuevo justificante',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF003366),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona los días a justificar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Solo se muestran días en que tienes falta',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),

              _cargandoFaltas
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF003366)))
                  : _fechasConFaltas.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 20),
                              SizedBox(width: 10),
                              Text('No tienes faltas registradas',
                                  style: TextStyle(color: Colors.green)),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Column(
                            children: _fechasConFaltas.map((fechaData) {
                              final fecha = fechaData['fecha'] as String;
                              final materias =
                                  fechaData['materias'] as List<String>;
                              final seleccionada =
                                  _fechasSeleccionadas.contains(fecha);

                              return CheckboxListTile(
                                title: Text(
                                  _formatFechaLegible(fecha),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: materias
                                          .map((m) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF003366)
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  m,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF003366),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                ),
                                value: seleccionada,
                                activeColor: const Color(0xFF003366),
                                onChanged: (val) {
                                  print('[CrearJustificante] Checkbox fecha=$fecha val=$val');
                                  setState(() {
                                    if (val == true) {
                                      _fechasSeleccionadas.add(fecha);
                                    } else {
                                      _fechasSeleccionadas.remove(fecha);
                                    }
                                  });
                                  print('Fechas seleccionadas ahora: $_fechasSeleccionadas');
                                },
                              );
                            }).toList(),
                          ),
                        ),
              const SizedBox(height: 20),

              const Text(
                'Título',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  hintText: 'Ej: Enfermedad, Cita médica...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF003366), width: 2),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),

              const Text(
                'Descripción / Asunto',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _asuntoController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Describe el motivo de tu inasistencia con el mayor detalle posible...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF003366), width: 2),
                  ),
                ),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Escribe al menos 10 caracteres'
                    : null,
              ),
              const SizedBox(height: 20),

              const Text(
                'Evidencias (opcional)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Adjunta hasta 5 imágenes como respaldo',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),

              if (_imagenesSeleccionadas.isNotEmpty) ...[
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagenesSeleccionadas.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(
                                    File(_imagenesSeleccionadas[index].path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () {
                                print('[CrearJustificante] Eliminando imagen $index');
                                setState(() {
                                  _imagenesSeleccionadas.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (_imagenesSeleccionadas.length < 5)
                OutlinedButton.icon(
                  onPressed: _seleccionarImagenes,
                  icon: const Icon(Icons.add_photo_alternate,
                      color: Color(0xFF003366)),
                  label: const Text(
                    'Agregar imágenes',
                    style: TextStyle(color: Color(0xFF003366)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF003366)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enviarJustificante,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Enviar justificante',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFechaLegible(String fecha) {
    try {
      final d = DateTime.parse(fecha);
      final days = [
        'Lunes', 'Martes', 'Miércoles', 'Jueves',
        'Viernes', 'Sábado', 'Domingo'
      ];
      final months = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      return '${days[d.weekday - 1]} ${d.day} de ${months[d.month - 1]}';
    } catch (e) {
      return fecha;
    }
  }
}
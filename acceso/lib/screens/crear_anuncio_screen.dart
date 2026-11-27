import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../service/api_service.dart';

class CrearAnuncioScreen extends StatefulWidget {
  final String profesorId;
  final String? nombreProfesor; // ← NUEVO: para mostrar en las notificaciones
  final List<Map<String, dynamic>> materias;

  const CrearAnuncioScreen({
    Key? key,
    required this.profesorId,
    this.nombreProfesor,
    required this.materias,
  }) : super(key: key);

  @override
  State<CrearAnuncioScreen> createState() => _CrearAnuncioScreenState();
}

class _CrearAnuncioScreenState extends State<CrearAnuncioScreen> {
  final ApiService _api = ApiService();
  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();

  // ── Selecciones ──
  String _tipo = 'aviso';
  Map<String, dynamic>? _materiaSeleccionada;
  String? _grupoSeleccionado;
  bool _todasLasMaterias = true;

  // ── Estado ──
  List<String> _grupos = [];
  bool _loadingGrupos = false;
  bool _isPublicando = false;

  final Map<String, Map<String, dynamic>> _tipoInfo = {
    'aviso': {
      'label': 'Aviso general',
      'icon': Icons.campaign_outlined,
      'color': const Color(0xFF004C8C),
    },
    'falta': {
      'label': 'Falta del profesor',
      'icon': Icons.event_busy_outlined,
      'color': const Color(0xFFE53935),
    },
    'tarea': {
      'label': 'Tarea / Actividad',
      'icon': Icons.assignment_outlined,
      'color': const Color(0xFF43A047),
    },
  };

  // ─── Cuando cambia la materia, carga los grupos ──────────────────────
  Future<void> _onMateriaChanged(Map<String, dynamic>? materia) async {
    setState(() {
      _materiaSeleccionada = materia;
      _grupoSeleccionado = null;
      _grupos = [];
    });

    if (materia == null) return;

    setState(() => _loadingGrupos = true);

    final grupos = await _api.getGruposByMateria(materia['id'] as String);

    setState(() {
      _grupos = grupos.map((g) => g['grupo'] as String).toList();
      _loadingGrupos = false;
    });
  }

  // ─── PUBLICAR ANUNCIO Y ENVIAR NOTIFICACIONES ────────────────────────
  Future<void> _publicar() async {
    if (_tituloCtrl.text.trim().isEmpty || _mensajeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa título y mensaje'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_todasLasMaterias && _materiaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una materia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isPublicando = true);

    bool exito = false;
    String? anuncioId;
    List<String> materiasIds = [];

    if (_todasLasMaterias) {
      // Publicar en TODAS las materias del profesor
      for (final materia in widget.materias) {
        final result = await _api.crearAnuncio(
          profesorId: widget.profesorId,
          materiaId: materia['id'] as String,
          grupo: null,
          titulo: _tituloCtrl.text.trim(),
          mensaje: _mensajeCtrl.text.trim(),
          tipo: _tipo,
        );
        if (result != null) {
          exito = true;
          anuncioId = result['id'] as String?;
          materiasIds.add(materia['id'] as String);
        }
      }
    } else {
      // Publicar solo en la materia seleccionada
      final result = await _api.crearAnuncio(
        profesorId: widget.profesorId,
        materiaId: _materiaSeleccionada!['id'] as String,
        grupo: _grupoSeleccionado,
        titulo: _tituloCtrl.text.trim(),
        mensaje: _mensajeCtrl.text.trim(),
        tipo: _tipo,
      );
      if (result != null) {
        exito = true;
        anuncioId = result['id'] as String?;
        materiasIds.add(_materiaSeleccionada!['id'] as String);
      }
    }

    // ── Si el anuncio se publicó, enviar notificaciones push ──
    if (exito && mounted) {
      // Enviar notificaciones push para cada materia
      for (final materiaId in materiasIds) {
        await _enviarNotificacionesPush(
          materiaId: materiaId,
          grupo: _todasLasMaterias ? null : _grupoSeleccionado,
          anuncioId: anuncioId,
        );
      }
    }

    setState(() => _isPublicando = false);

    if (!mounted) return;

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Aviso publicado exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al publicar el aviso'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── ENVIAR NOTIFICACIONES PUSH ──────────────────────────────────────
  Future<void> _enviarNotificacionesPush({
    required String materiaId,
    String? grupo,
    String? anuncioId,
  }) async {
    if (!ApiConfig.enablePushNotifications) return;
    try {
      // 1. Obtener tokens de los alumnos
      final tokens = await _api.obtenerTokensAlumnos(
        materiaId: materiaId,
        grupo: grupo,
      );

      if (tokens.isEmpty) {
        print('⚠️ No hay tokens para enviar notificaciones');
        return;
      }

      // 2. Obtener nombre del profesor
      final nombreProfesor = widget.nombreProfesor ?? 'Profesor';

      // 3. Obtener nombre de la materia
      String materiaNombre = '';
      if (_todasLasMaterias) {
        // Si es todas las materias, buscar el nombre
        final materia = widget.materias.firstWhere(
          (m) => m['id'] == materiaId,
          orElse: () => {'nombre': 'Materia'},
        );
        materiaNombre = materia['nombre'] as String? ?? 'Materia';
      } else {
        materiaNombre = _materiaSeleccionada?['nombre'] as String? ?? 'Materia';
      }

      // 4. Determinar el mensaje de la notificación
      String tituloNotificacion;
      String cuerpoNotificacion;

      switch (_tipo) {
        case 'falta':
          tituloNotificacion = '📢 Falta del profesor';
          cuerpoNotificacion =
              '$nombreProfesor ha registrado una falta en $materiaNombre';
          break;
        case 'tarea':
          tituloNotificacion = '📝 Nueva tarea/actividad';
          cuerpoNotificacion =
              '$nombreProfesor ha publicado una tarea en $materiaNombre';
          break;
        default:
          tituloNotificacion = '📢 Nuevo aviso';
          cuerpoNotificacion =
              '$nombreProfesor ha publicado un aviso en $materiaNombre';
      }

      // 5. Si hay grupo específico, agregarlo al mensaje
      if (grupo != null && grupo.isNotEmpty) {
        cuerpoNotificacion += ' (Grupo $grupo)';
      }

      // 6. Enviar notificaciones
      final enviadas = await _api.enviarNotificacionPush(
        titulo: tituloNotificacion,
        cuerpo: cuerpoNotificacion,
        tokens: tokens,
        data: {
          'screen': 'notificaciones',
          'anuncio_id': anuncioId ?? '',
          'tipo': _tipo,
        },
      );

      if (enviadas) {
        print('✅ Notificaciones push enviadas a ${tokens.length} alumnos');
      } else {
        print('⚠️ Error enviando algunas notificaciones');
      }
    } catch (e) {
      print('❌ Error enviando notificaciones push: $e');
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Nuevo aviso'),
        backgroundColor: const Color(0xFF004C8C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Botón de ayuda
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PASO 1: Tipo de aviso ──────────────────────────────────
            _buildSectionLabel('1. Tipo de aviso'),
            const SizedBox(height: 10),
            Row(
              children: _tipoInfo.entries.map((e) {
                final selected = _tipo == e.key;
                final info = e.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipo = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? (info['color'] as Color).withOpacity(0.10)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? info['color'] as Color
                              : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            info['icon'] as IconData,
                            color: selected
                                ? info['color'] as Color
                                : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            info['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: selected
                                  ? info['color'] as Color
                                  : Colors.grey,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── PASO 2: Destinatarios ──────────────────────────────────
            _buildSectionLabel('2. ¿A quién va dirigido?'),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    groupValue: _todasLasMaterias,
                    onChanged: (v) {
                      setState(() {
                        _todasLasMaterias = true;
                        _materiaSeleccionada = null;
                        _grupoSeleccionado = null;
                        _grupos = [];
                      });
                    },
                    activeColor: const Color(0xFF004C8C),
                    title: const Text(
                      'Todos mis grupos de todas las materias',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'El aviso llegará a todos tus alumnos',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  RadioListTile<bool>(
                    value: false,
                    groupValue: _todasLasMaterias,
                    onChanged: (v) {
                      setState(() {
                        _todasLasMaterias = false;
                      });
                    },
                    activeColor: const Color(0xFF004C8C),
                    title: const Text(
                      'Una materia específica',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Elige la materia y el grupo',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            if (!_todasLasMaterias) ...[
              const SizedBox(height: 16),
              _buildSectionLabel('Materia'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: widget.materias.asMap().entries.map((entry) {
                    final materia = entry.value;
                    final isLast =
                        entry.key == widget.materias.length - 1;
                    final selected =
                        _materiaSeleccionada?['id'] == materia['id'];

                    return Column(
                      children: [
                        ListTile(
                          onTap: () => _onMateriaChanged(materia),
                          leading: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? const Color(0xFF004C8C)
                                  : Colors.transparent,
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF004C8C)
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          title: Text(
                            materia['nombre'] ?? 'Sin nombre',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected
                                  ? const Color(0xFF004C8C)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                              height: 1, color: Colors.grey.shade200),
                      ],
                    );
                  }).toList(),
                ),
              ),

              if (_materiaSeleccionada != null) ...[
                const SizedBox(height: 16),
                _buildSectionLabel('Grupo'),
                const SizedBox(height: 8),

                if (_loadingGrupos)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: Color(0xFF004C8C)),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String?>(
                          value: null,
                          groupValue: _grupoSeleccionado,
                          onChanged: (v) =>
                              setState(() => _grupoSeleccionado = v),
                          activeColor: const Color(0xFF004C8C),
                          title: const Text(
                            'Todos los grupos de esta materia',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ),
                        if (_grupos.isNotEmpty)
                          Divider(
                              height: 1, color: Colors.grey.shade200),
                        ..._grupos.asMap().entries.map((entry) {
                          final grupo = entry.value;
                          final isLast =
                              entry.key == _grupos.length - 1;
                          return Column(
                            children: [
                              RadioListTile<String?>(
                                value: grupo,
                                groupValue: _grupoSeleccionado,
                                onChanged: (v) => setState(
                                    () => _grupoSeleccionado = v),
                                activeColor: const Color(0xFF004C8C),
                                title: Text(
                                  'Grupo $grupo',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              if (!isLast)
                                Divider(
                                    height: 1,
                                    color: Colors.grey.shade200),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
              ],
            ],

            const SizedBox(height: 24),

            // ── PASO 3: Título y mensaje ───────────────────────────────
            _buildSectionLabel('3. Contenido del aviso'),
            const SizedBox(height: 10),

            TextField(
              controller: _tituloCtrl,
              maxLength: 80,
              decoration: _inputDecoration('Título del aviso',
                  'Ej. No habrá clase el viernes'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _mensajeCtrl,
              maxLines: 5,
              maxLength: 500,
              decoration: _inputDecoration('Mensaje',
                  'Escribe el contenido del aviso para tus alumnos...'),
            ),
            const SizedBox(height: 30),

            _buildResumen(),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPublicando ? null : _publicar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004C8C),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isPublicando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Publicar aviso',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── DIÁLOGO DE AYUDA ──────────────────────────────────────────────
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayuda'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Selecciona el tipo de aviso'),
            SizedBox(height: 8),
            Text('2. Elige los destinatarios'),
            SizedBox(height: 8),
            Text('3. Escribe el título y mensaje'),
            SizedBox(height: 8),
            Text('4. Publica el aviso'),
            SizedBox(height: 12),
            Text(
              'Los alumnos recibirán una notificación push en sus dispositivos.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ─── RESUMEN ───────────────────────────────────────────────────────────
  Widget _buildResumen() {
    String destino;
    if (_todasLasMaterias) {
      destino = 'Todos mis grupos de todas las materias';
    } else if (_materiaSeleccionada == null) {
      return const SizedBox.shrink();
    } else if (_grupoSeleccionado == null) {
      destino =
          'Todos los grupos de ${_materiaSeleccionada!['nombre']}';
    } else {
      destino =
          'Grupo $_grupoSeleccionado · ${_materiaSeleccionada!['nombre']}';
    }

    final tipoInfo = _tipoInfo[_tipo]!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (tipoInfo['color'] as Color).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (tipoInfo['color'] as Color).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(tipoInfo['icon'] as IconData,
              color: tipoInfo['color'] as Color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipoInfo['label'] as String,
                  style: TextStyle(
                    color: tipoInfo['color'] as Color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destino,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF004C8C), width: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }
}
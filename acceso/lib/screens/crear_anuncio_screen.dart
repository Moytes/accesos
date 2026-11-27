import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui_components.dart';
import '../widgets/anuncio_helpers.dart';

class CrearAnuncioScreen extends StatefulWidget {
  final String profesorId;
  final String? nombreProfesor;
  final List<Map<String, dynamic>> materias;
  final Map<String, dynamic>? anuncioExistente;
  final String? initialMateriaId;
  final String? initialClaseId;
  final String? initialGrupo;
  final String? initialMateriaNombre;

  const CrearAnuncioScreen({
    super.key,
    required this.profesorId,
    this.nombreProfesor,
    this.materias = const [],
    this.anuncioExistente,
    this.initialMateriaId,
    this.initialClaseId,
    this.initialGrupo,
    this.initialMateriaNombre,
  });

  @override
  State<CrearAnuncioScreen> createState() => _CrearAnuncioScreenState();
}

class _CrearAnuncioScreenState extends State<CrearAnuncioScreen> {
  final ApiService _api = ApiService();
  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();

  bool get _isEditMode => widget.anuncioExistente != null;

  String _tipo = 'aviso';
  List<Map<String, dynamic>> _materias = [];
  Map<String, dynamic>? _materiaSeleccionada;
  String? _grupoSeleccionado;
  String? _claseIdSeleccionada;
  bool _todasLasMaterias = true;

  List<Map<String, dynamic>> _grupos = [];
  bool _loadingMaterias = false;
  bool _loadingGrupos = false;
  bool _isPublicando = false;

  @override
  void initState() {
    super.initState();
    _inicializarEstado();
  }

  Future<void> _inicializarEstado() async {
    _materias = widget.materias
        .map((m) => {
              'id': m['id']?.toString() ?? '',
              'nombre': (m['nombre'] ?? m['nom_mat'] ?? 'Sin nombre').toString(),
            })
        .where((m) => (m['id'] as String).isNotEmpty)
        .toList();

    final existente = widget.anuncioExistente;
    if (existente != null) {
      _tituloCtrl.text = (existente['titulo'] ?? '').toString();
      _mensajeCtrl.text = (existente['mensaje'] ?? '').toString();
      _tipo = AnuncioHelper.normalizeTipo(existente['tipo']?.toString());
      _todasLasMaterias = false;
    }

    final initMateriaId =
        (existente?['materia_id'] ?? widget.initialMateriaId)?.toString();
    final initClaseId =
        (existente?['clase_id'] ?? widget.initialClaseId)?.toString();
    final initGrupo = (existente?['grupo'] ?? widget.initialGrupo)?.toString();
    final initMateriaNombre =
        (existente?['materia_nombre'] ?? widget.initialMateriaNombre)?.toString();

    if (initMateriaId != null && initMateriaId.isNotEmpty ||
        initClaseId != null && initClaseId.isNotEmpty) {
      _todasLasMaterias = false;
    }

    if (_materias.isEmpty && _todasLasMaterias == false) {
      setState(() => _loadingMaterias = true);
      final fetched = await _api.getMateriasByProfesor(widget.profesorId);
      if (!mounted) return;
      _materias = fetched
          .map((m) => {
                'id': m['id']?.toString() ?? '',
                'nombre':
                    (m['nom_mat'] ?? m['nombre'] ?? 'Sin nombre').toString(),
              })
          .where((m) => (m['id'] as String).isNotEmpty)
          .toList();
      if (_materias.isEmpty &&
          initMateriaId != null &&
          initMateriaId.isNotEmpty) {
        _materias = [
          {
            'id': initMateriaId,
            'nombre': (initMateriaNombre != null && initMateriaNombre.isNotEmpty)
                ? initMateriaNombre
                : 'Materia seleccionada',
          }
        ];
      }
      _loadingMaterias = false;
    }

    if (initMateriaId != null && initMateriaId.isNotEmpty) {
      final match = _materias.cast<Map<String, dynamic>?>().firstWhere(
            (m) => m?['id']?.toString() == initMateriaId,
            orElse: () => null,
          );
      final selected = match ??
          {
            'id': initMateriaId,
            'nombre': (initMateriaNombre != null && initMateriaNombre.isNotEmpty)
                ? initMateriaNombre
                : 'Materia seleccionada',
          };
      if (match == null) {
        _materias = [..._materias, selected];
      }
      await _onMateriaChanged(
        selected,
        preselectGrupo:
            (initGrupo != null && initGrupo.isNotEmpty) ? initGrupo : null,
        preselectClaseId:
            (initClaseId != null && initClaseId.isNotEmpty) ? initClaseId : null,
      );
    } else if (initClaseId != null && initClaseId.isNotEmpty) {
      _claseIdSeleccionada = initClaseId;
      _grupoSeleccionado =
          (initGrupo != null && initGrupo.isNotEmpty) ? initGrupo : null;
      if (mounted) setState(() {});
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onMateriaChanged(
    Map<String, dynamic>? materia, {
    String? preselectGrupo,
    String? preselectClaseId,
  }) async {
    setState(() {
      _materiaSeleccionada = materia;
      _grupoSeleccionado = preselectGrupo;
      _claseIdSeleccionada = preselectClaseId;
      _grupos = [];
    });

    final matId = materia?['id']?.toString() ?? '';
    if (matId.isEmpty) return;

    setState(() => _loadingGrupos = true);
    final rawGrupos = await _api.getGruposByMateria(matId);
    if (!mounted) return;

    final normalizedGrupos = rawGrupos
        .map((g) => {
              'grupo': (g['grupo'] ?? g['nombre'] ?? '').toString(),
              'clase_id': (g['clase_id'] ?? g['id'] ?? '').toString(),
            })
        .where((g) => (g['grupo'] as String).isNotEmpty)
        .toList();

    String? resolvedClase = preselectClaseId;
    if (preselectGrupo != null &&
        preselectGrupo.isNotEmpty &&
        (resolvedClase == null || resolvedClase.isEmpty)) {
      final hit = normalizedGrupos.cast<Map<String, dynamic>?>().firstWhere(
            (g) =>
                g?['grupo']?.toString().toLowerCase() ==
                preselectGrupo.toLowerCase(),
            orElse: () => null,
          );
      resolvedClase = hit?['clase_id']?.toString();
    }

    setState(() {
      _grupos = normalizedGrupos;
      _claseIdSeleccionada =
          (resolvedClase != null && resolvedClase.isNotEmpty)
              ? resolvedClase
              : null;
      _loadingGrupos = false;
    });
  }

  void _selectGrupo(Map<String, dynamic>? item) {
    setState(() {
      if (item == null) {
        _grupoSeleccionado = null;
        _claseIdSeleccionada = null;
      } else {
        _grupoSeleccionado = item['grupo']?.toString();
        final cid = item['clase_id']?.toString() ?? '';
        _claseIdSeleccionada = cid.isNotEmpty ? cid : null;
      }
    });
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    final mensaje = _mensajeCtrl.text.trim();

    if (titulo.isEmpty || mensaje.isEmpty) {
      _showMessage('Por favor completa título y mensaje', AppColors.warning);
      return;
    }

    if (!_todasLasMaterias &&
        _materiaSeleccionada == null &&
        (_claseIdSeleccionada == null || _claseIdSeleccionada!.isEmpty)) {
      _showMessage('Selecciona una materia o clase destino', AppColors.warning);
      return;
    }

    setState(() => _isPublicando = true);

    if (_isEditMode) {
      await _guardarEdicion(titulo, mensaje);
      return;
    }

    bool exito = false;
    String? anuncioId;
    final materiasIds = <String>[];

    if (_todasLasMaterias) {
      for (final materia in _materias) {
        final mid = materia['id']?.toString() ?? '';
        if (mid.isEmpty) continue;
        final result = await _api.crearAnuncio(
          profesorId: widget.profesorId,
          materiaId: mid,
          grupo: null,
          titulo: titulo,
          mensaje: mensaje,
          tipo: _tipo,
        );
        if (result != null) {
          exito = true;
          anuncioId = result['id']?.toString();
          materiasIds.add(mid);
        }
      }
    } else {
      final mid = _materiaSeleccionada?['id']?.toString();
      final result = await _api.crearAnuncio(
        profesorId: widget.profesorId,
        materiaId: (mid != null && mid.isNotEmpty) ? mid : null,
        claseId: _claseIdSeleccionada,
        grupo: _grupoSeleccionado,
        titulo: titulo,
        mensaje: mensaje,
        tipo: _tipo,
      );
      if (result != null) {
        exito = true;
        anuncioId = result['id']?.toString();
        if (mid != null && mid.isNotEmpty) {
          materiasIds.add(mid);
        } else if (_claseIdSeleccionada != null) {
          materiasIds.add(_claseIdSeleccionada!);
        }
      }
    }

    if (exito && mounted) {
      for (final materiaId in materiasIds) {
        await _enviarNotificacionesPush(
          materiaId: materiaId,
          grupo: _todasLasMaterias ? null : _grupoSeleccionado,
          anuncioId: anuncioId,
        );
      }
    }

    if (!mounted) return;
    setState(() => _isPublicando = false);

    if (exito) {
      _showMessage('Aviso publicado exitosamente', AppColors.successDark);
      Navigator.pop(context, true);
    } else {
      _showMessage(
        _api.lastError ?? 'Error al publicar el aviso',
        AppColors.dangerRed,
      );
    }
  }

  Future<void> _guardarEdicion(String titulo, String mensaje) async {
    final existente = widget.anuncioExistente!;
    final anuncioId = existente['id']?.toString() ?? '';
    final materiaId = _materiaSeleccionada?['id']?.toString() ?? '';
    final claseId = _claseIdSeleccionada ?? '';
    final grupo = _grupoSeleccionado ?? '';

    final updated = await _api.actualizarAnuncio(
      anuncioId: anuncioId,
      titulo: titulo,
      mensaje: mensaje,
      tipo: _tipo,
      materiaId: materiaId,
      claseId: claseId,
      grupo: grupo,
    );

    if (!mounted) return;
    setState(() => _isPublicando = false);

    if (updated != null) {
      _showMessage('Aviso actualizado correctamente', AppColors.successDark);
      Navigator.pop(context, true);
    } else {
      _showMessage(
        _api.lastError ?? 'No se pudo actualizar el aviso',
        AppColors.dangerRed,
      );
    }
  }

  Future<void> _enviarNotificacionesPush({
    required String materiaId,
    String? grupo,
    String? anuncioId,
  }) async {
    if (!ApiConfig.enablePushNotifications) return;
    try {
      final tokens = await _api.obtenerTokensAlumnos(
        materiaId: materiaId,
        grupo: grupo,
      );
      if (tokens.isEmpty) return;

      final nombreProfesor = widget.nombreProfesor ?? 'Profesor';
      final materiaNombre = _todasLasMaterias
          ? (_materias.firstWhere(
                  (m) => m['id'] == materiaId,
                  orElse: () => {'nombre': 'tu materia'},
                )['nombre'] ??
                'tu materia')
              .toString()
          : (_materiaSeleccionada?['nombre'] ??
                  widget.initialMateriaNombre ??
                  'tu materia')
              .toString();

      final meta = AnuncioHelper.metaFor(_tipo);
      final tituloNotificacion = '${meta.shortLabel}: ${_tituloCtrl.text.trim()}';
      var cuerpoNotificacion =
          '$nombreProfesor publicó un aviso (${meta.label}) en $materiaNombre';
      if (grupo != null && grupo.isNotEmpty) {
        cuerpoNotificacion += ' (Grupo $grupo)';
      }

      await _api.enviarNotificacionPush(
        titulo: tituloNotificacion,
        cuerpo: cuerpoNotificacion,
        tokens: tokens,
        data: {
          'screen': 'notificaciones',
          'anuncio_id': anuncioId ?? '',
          'tipo': _tipo,
        },
      );
    } catch (e) {
      debugPrint('Error enviando push de anuncio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLockedContext = !_isEditMode &&
        ((widget.initialMateriaId != null &&
                widget.initialMateriaId!.isNotEmpty) ||
            (widget.initialClaseId != null &&
                widget.initialClaseId!.isNotEmpty));

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          title: Text(_isEditMode ? 'Editar aviso' : 'Nuevo aviso'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Ayuda',
              onPressed: _showHelpDialog,
            ),
          ],
        ),
        body: ResponsiveContainer(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLockedContext || _isEditMode) _buildContextChipBar(),
                _buildSectionLabel('1. Tipo de aviso'),
                const SizedBox(height: 10),
                _buildTipoSelectorGrid(),
                const SizedBox(height: 22),
                _buildSectionLabel('2. Destinatarios'),
                const SizedBox(height: 10),
                if (!_isEditMode && _materias.isNotEmpty)
                  _buildAlcanceCard(),
                if (!_todasLasMaterias) ...[
                  if (!_isEditMode && _materias.isNotEmpty)
                    const SizedBox(height: 16),
                  _buildMateriaYGrupoSelector(),
                ],
                const SizedBox(height: 22),
                _buildSectionLabel('3. Contenido del aviso'),
                const SizedBox(height: 10),
                TextField(
                  controller: _tituloCtrl,
                  maxLength: 200,
                  decoration: _inputDecoration(
                    'Título del aviso',
                    'Ej. Entrega de proyecto final / Suspensión de sesión',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mensajeCtrl,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: _inputDecoration(
                    'Mensaje',
                    'Escribe los detalles para tus alumnos...',
                  ),
                ),
                const SizedBox(height: 20),
                _buildResumen(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isPublicando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isPublicando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _isEditMode
                                ? Icons.save_outlined
                                : Icons.send_outlined,
                          ),
                    label: Text(
                      _isPublicando
                          ? 'Guardando...'
                          : (_isEditMode ? 'Guardar cambios' : 'Publicar aviso'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextChipBar() {
    final materiaLabel =
        (_materiaSeleccionada?['nombre'] ?? widget.initialMateriaNombre ?? '')
            .toString();
    final grupoLabel = _grupoSeleccionado;
    if (materiaLabel.isEmpty && (grupoLabel == null || grupoLabel.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoftBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.class_outlined, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                if (materiaLabel.isNotEmpty) materiaLabel,
                if (grupoLabel != null && grupoLabel.isNotEmpty)
                  'Grupo $grupoLabel',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoSelectorGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 4 : 2;
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: AnuncioHelper.tipos.map((meta) {
            final selected = _tipo == meta.key;
            return SizedBox(
              width: itemWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _tipo = meta.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? meta.color.withValues(alpha: 0.10)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? meta.color : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(meta.icon, color: meta.color, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meta.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? meta.color : Colors.black87,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAlcanceCard() {
    return Container(
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
                _claseIdSeleccionada = null;
                _grupos = [];
              });
            },
            activeColor: AppColors.primary,
            title: const Text(
              'Todos mis grupos de todas las materias',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Publica el aviso para todos tus alumnos activos',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          RadioListTile<bool>(
            value: false,
            groupValue: _todasLasMaterias,
            onChanged: (v) => setState(() => _todasLasMaterias = false),
            activeColor: AppColors.primary,
            title: const Text(
              'Una materia o grupo específico',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Elige exactamente la materia y el grupo destinatario',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMateriaYGrupoSelector() {
    if (_loadingMaterias) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_materias.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          _claseIdSeleccionada != null
              ? 'Clase seleccionada${_grupoSeleccionado != null ? " (Grupo $_grupoSeleccionado)" : ""}.'
              : 'No se encontraron materias disponibles.',
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _materiaSeleccionada?['id']?.toString(),
          isExpanded: true,
          decoration: _inputDecoration('Materia', 'Selecciona una materia'),
          items: _materias
              .map(
                (m) => DropdownMenuItem<String>(
                  value: m['id'].toString(),
                  child: Text(
                    m['nombre'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            final found = _materias.firstWhere(
              (m) => m['id'].toString() == val,
              orElse: () => _materias.first,
            );
            _onMateriaChanged(found);
          },
        ),
        if (_materiaSeleccionada != null) ...[
          const SizedBox(height: 14),
          if (_loadingGrupos)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            DropdownButtonFormField<String?>(
              value: _grupos.any((g) => g['grupo'] == _grupoSeleccionado)
                  ? _grupoSeleccionado
                  : null,
              isExpanded: true,
              decoration: _inputDecoration('Grupo destino', 'Elige un grupo'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Todos los grupos de esta materia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ..._grupos.map(
                  (g) => DropdownMenuItem<String?>(
                    value: g['grupo'].toString(),
                    child: Text(
                      'Grupo ${g['grupo']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val == null) {
                  _selectGrupo(null);
                  return;
                }
                final hit = _grupos.firstWhere(
                  (g) => g['grupo'].toString() == val,
                  orElse: () => {'grupo': val, 'clase_id': ''},
                );
                _selectGrupo(hit);
              },
            ),
        ],
      ],
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Ayuda sobre avisos',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Elige el tipo de aviso (Aviso, Tarea, Examen o Urgente).'),
            SizedBox(height: 8),
            Text('2. Selecciona si aplica a todas tus materias, a una materia o a un grupo específico.'),
            SizedBox(height: 8),
            Text('3. Podrás editar o eliminar cualquiera de tus avisos en todo momento.'),
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

  Widget _buildResumen() {
    String destino;
    if (_todasLasMaterias) {
      destino = 'Todos mis grupos de todas las materias';
    } else if (_materiaSeleccionada != null) {
      final nom = _materiaSeleccionada!['nombre'].toString();
      destino = _grupoSeleccionado == null
          ? 'Todos los grupos de $nom'
          : 'Grupo $_grupoSeleccionado · $nom';
    } else if (_claseIdSeleccionada != null) {
      destino = _grupoSeleccionado != null
          ? 'Grupo $_grupoSeleccionado'
          : 'Clase seleccionada';
    } else {
      return const SizedBox.shrink();
    }

    final meta = AnuncioHelper.metaFor(_tipo);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(meta.icon, color: meta.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.label,
                  style: TextStyle(
                    color: meta.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destino,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
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
        color: AppColors.primaryDark,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
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

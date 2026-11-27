import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui_components.dart';
import '../widgets/anuncio_helpers.dart';
import 'crear_anuncio_screen.dart';

class AvisosProfesorScreen extends StatefulWidget {
  final String profesorId;
  final String? nombreProfesor;
  final List<Map<String, dynamic>> materias;
  final String? materiaId;
  final String? claseId;
  final String? materiaNombre;
  final String? grupo;

  const AvisosProfesorScreen({
    super.key,
    required this.profesorId,
    this.nombreProfesor,
    this.materias = const [],
    this.materiaId,
    this.claseId,
    this.materiaNombre,
    this.grupo,
  });

  @override
  State<AvisosProfesorScreen> createState() => _AvisosProfesorScreenState();
}

class _AvisosProfesorScreenState extends State<AvisosProfesorScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _anuncios = [];
  List<Map<String, dynamic>> _materias = [];
  bool _isLoading = true;
  bool _fromCache = false;
  String _search = '';
  String _tipoFiltro = 'todos';
  String? _materiaFiltroId;
  String? _eliminandoId;

  bool get _esContextual =>
      (widget.claseId != null && widget.claseId!.isNotEmpty) ||
      (widget.materiaId != null && widget.materiaId!.isNotEmpty) ||
      (widget.grupo != null && widget.grupo!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _materias = List<Map<String, dynamic>>.from(widget.materias);
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);

    final hasClase = widget.claseId != null && widget.claseId!.isNotEmpty;
    final list = await _api.getAnunciosByProfesor(
      widget.profesorId,
      materiaId: hasClase ? null : widget.materiaId,
      claseId: hasClase ? widget.claseId : null,
      grupo: hasClase ? null : widget.grupo,
    );
    final fromCache = _api.lastDataFromCache;

    if (!_esContextual && _materias.isEmpty && widget.profesorId.isNotEmpty) {
      final fetchedMats = await _api.getMateriasByProfesor(widget.profesorId);
      if (mounted && fetchedMats.isNotEmpty) {
        _materias = fetchedMats
            .map((m) => {
                  'id': m['id']?.toString() ?? '',
                  'nombre':
                      (m['nom_mat'] ?? m['nombre'] ?? 'Sin nombre').toString(),
                })
            .where((m) => (m['id'] as String).isNotEmpty)
            .toList();
      }
    }

    if (!mounted) return;
    setState(() {
      _anuncios = list;
      _fromCache = fromCache;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _search.trim().toLowerCase();
    return _anuncios.where((a) {
      final tipo = AnuncioHelper.normalizeTipo(a['tipo']?.toString());
      if (_tipoFiltro != 'todos' && tipo != _tipoFiltro) {
        return false;
      }
      if (!_esContextual &&
          _materiaFiltroId != null &&
          _materiaFiltroId!.isNotEmpty) {
        if ((a['materia_id']?.toString() ?? '') != _materiaFiltroId) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      final titulo = (a['titulo'] ?? '').toString().toLowerCase();
      final mensaje = (a['mensaje'] ?? '').toString().toLowerCase();
      final materia = (a['materia_nombre'] ?? '').toString().toLowerCase();
      final grupo = (a['grupo'] ?? '').toString().toLowerCase();
      return titulo.contains(q) ||
          mensaje.contains(q) ||
          materia.contains(q) ||
          grupo.contains(q);
    }).toList();
  }

  int _contarPorTipo(String key) {
    final base = (!_esContextual &&
            _materiaFiltroId != null &&
            _materiaFiltroId!.isNotEmpty)
        ? _anuncios
            .where((a) => (a['materia_id']?.toString() ?? '') == _materiaFiltroId)
            .toList()
        : _anuncios;
    if (key == 'todos') return base.length;
    return base
        .where((a) => AnuncioHelper.normalizeTipo(a['tipo']?.toString()) == key)
        .length;
  }

  Future<void> _abrirCrear({Map<String, dynamic>? existente}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CrearAnuncioScreen(
          profesorId: widget.profesorId,
          nombreProfesor: widget.nombreProfesor ?? 'Profesor',
          materias: _materias,
          anuncioExistente: existente,
          initialMateriaId: existente == null ? widget.materiaId : null,
          initialClaseId: existente == null ? widget.claseId : null,
          initialGrupo: existente == null ? widget.grupo : null,
          initialMateriaNombre:
              existente == null ? widget.materiaNombre : null,
        ),
      ),
    );
    if (result == true && mounted) {
      await _cargar();
    }
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> anuncio) async {
    final id = anuncio['id']?.toString() ?? '';
    final titulo = (anuncio['titulo'] ?? 'este aviso').toString();
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.dangerRed),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Eliminar aviso',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Seguro que deseas eliminar "$titulo"? Los alumnos dejarán de verlo de inmediato.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _eliminandoId = id);
    final ok = await _api.eliminarAnuncio(id);
    if (!mounted) return;
    setState(() => _eliminandoId = null);

    if (ok) {
      setState(() {
        _anuncios.removeWhere((a) => a['id']?.toString() == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aviso eliminado correctamente'),
          backgroundColor: AppColors.successDark,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_api.lastError ?? 'No se pudo eliminar el aviso'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  void _mostrarDetalleSheet(Map<String, dynamic> anuncio) {
    final editado = AnuncioHelper.fueEditado(anuncio);
    final materia = (anuncio['materia_nombre'] ?? 'Materia').toString();
    final grupo = anuncio['grupo']?.toString();
    final leidos = (anuncio['total_leidos'] as num?)?.toInt() ?? 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AnuncioHelper.buildTipoBadge(anuncio['tipo']?.toString()),
                  if (editado)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Editado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                (anuncio['titulo'] ?? '').toString(),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _metaChip(Icons.book_outlined, materia),
                  _metaChip(
                    Icons.groups_outlined,
                    (grupo != null && grupo.isNotEmpty)
                        ? 'Grupo $grupo'
                        : 'Todos los grupos',
                  ),
                  _metaChip(
                    Icons.visibility_outlined,
                    '$leidos ${leidos == 1 ? 'lectura' : 'lecturas'}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Text(
                (anuncio['mensaje'] ?? '').toString(),
                style: TextStyle(
                  fontSize: 14.5,
                  color: Colors.grey[800],
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Publicado: ${AnuncioHelper.formatFechaCompleta(anuncio['fecha_creacion'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (editado) ...[
                const SizedBox(height: 4),
                Text(
                  'Última edición: ${AnuncioHelper.formatFechaCompleta(anuncio['updated_at'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmarEliminar(anuncio);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dangerRed,
                        side: const BorderSide(color: AppColors.dangerRed),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _abrirCrear(existente: anuncio);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _materiasDisponiblesFiltro() {
    if (_materias.isNotEmpty) return _materias;
    final map = <String, String>{};
    for (final a in _anuncios) {
      final mid = a['materia_id']?.toString() ?? '';
      final nom = (a['materia_nombre'] ?? '').toString();
      if (mid.isNotEmpty && nom.isNotEmpty) {
        map[mid] = nom;
      }
    }
    return map.entries
        .map((e) => {'id': e.key, 'nombre': e.value})
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtrados;
    final subtitulo = _esContextual
        ? [
            if (widget.materiaNombre != null &&
                widget.materiaNombre!.isNotEmpty)
              widget.materiaNombre!,
            if (widget.grupo != null && widget.grupo!.isNotEmpty)
              'Grupo ${widget.grupo}',
          ].join(' · ')
        : 'Todos los grupos y materias';

    final materiasFiltro = _materiasDisponiblesFiltro();

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _esContextual ? 'Avisos del grupo' : 'Mis avisos',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              if (subtitulo.isNotEmpty)
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _cargar,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirCrear(),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text(
            'Nuevo aviso',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Column(
          children: [
            if (_fromCache)
              Container(
                width: double.infinity,
                color: AppColors.surfaceSoftBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: const Text(
                  'Mostrando avisos guardados en caché offline.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: ResponsiveContainer(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildFiltrosPanel(materiasFiltro),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryDark,
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _cargar,
                              color: AppColors.primaryDark,
                              child: items.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        14,
                                        88,
                                      ),
                                      itemCount: items.length,
                                      itemBuilder: (ctx, i) =>
                                          _buildAvisoCard(items[i]),
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltrosPanel(List<Map<String, dynamic>> materiasFiltro) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_esContextual) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoftBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_anuncios.length} ${_anuncios.length == 1 ? 'aviso publicado' : 'avisos publicados'} en esta materia y grupo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (materiasFiltro.length > 1) ...[
            DropdownButtonFormField<String?>(
              value: materiasFiltro.any((m) => m['id'] == _materiaFiltroId)
                  ? _materiaFiltroId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Filtrar por materia',
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Todas las materias',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...materiasFiltro.map(
                  (m) => DropdownMenuItem<String?>(
                    value: m['id']?.toString(),
                    child: Text(
                      (m['nombre'] ?? 'Materia').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _materiaFiltroId = v),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar aviso por título, mensaje o grupo...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  keyVal: 'todos',
                  label: 'Todos (${_contarPorTipo('todos')})',
                  color: AppColors.primaryDark,
                ),
                ...AnuncioHelper.tipos.map(
                  (meta) => _filterChip(
                    keyVal: meta.key,
                    label: '${meta.shortLabel} (${_contarPorTipo(meta.key)})',
                    color: meta.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String keyVal,
    required String label,
    required Color color,
  }) {
    final selected = _tipoFiltro == keyVal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.primaryDark,
          ),
        ),
        selectedColor: color,
        backgroundColor: AppColors.surfaceSoftBlue,
        side: BorderSide(
          color: selected ? color : color.withValues(alpha: 0.22),
        ),
        showCheckmark: false,
        onSelected: (_) => setState(() => _tipoFiltro = keyVal),
      ),
    );
  }

  Widget _buildAvisoCard(Map<String, dynamic> anuncio) {
    final id = anuncio['id']?.toString() ?? '';
    final tipoRaw = anuncio['tipo']?.toString();
    final meta = AnuncioHelper.metaFor(tipoRaw);
    final editado = AnuncioHelper.fueEditado(anuncio);
    final materia = (anuncio['materia_nombre'] ?? 'Materia').toString();
    final grupo = anuncio['grupo']?.toString();
    final leidos = (anuncio['total_leidos'] as num?)?.toInt() ?? 0;
    final eliminando = _eliminandoId == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: meta.color.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _mostrarDetalleSheet(anuncio),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AnuncioHelper.buildTipoBadge(tipoRaw, compact: true),
                        if (editado)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Editado',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        Text(
                          AnuncioHelper.formatFechaRelativa(
                            anuncio['fecha_creacion'],
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'editar') {
                        _abrirCrear(existente: anuncio);
                      } else if (value == 'eliminar') {
                        _confirmarEliminar(anuncio);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'editar',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'eliminar',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.dangerRed,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: AppColors.dangerRed),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                (anuncio['titulo'] ?? 'Sin título').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                (anuncio['mensaje'] ?? '').toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _metaChip(Icons.book_outlined, materia),
                  _metaChip(
                    Icons.groups_outlined,
                    (grupo != null && grupo.isNotEmpty)
                        ? 'Grupo $grupo'
                        : 'Todos los grupos',
                  ),
                  _metaChip(
                    Icons.visibility_outlined,
                    '$leidos ${leidos == 1 ? 'leído' : 'leídos'}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: eliminando
                          ? null
                          : () => _abrirCrear(existente: anuncio),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: eliminando
                          ? null
                          : () => _confirmarEliminar(anuncio),
                      icon: eliminando
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dangerRed,
                        side: BorderSide(
                          color: AppColors.dangerRed.withValues(alpha: 0.4),
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoftBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: AppColors.primary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hayFiltro =
        _search.isNotEmpty || _tipoFiltro != 'todos' || _materiaFiltroId != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 96),
      children: [
        Icon(
          Icons.campaign_outlined,
          size: 64,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 14),
        Text(
          hayFiltro
              ? 'No hay avisos que coincidan con el filtro'
              : (_esContextual
                  ? 'Aún no hay avisos en este grupo y materia'
                  : 'Todavía no has publicado avisos'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hayFiltro
              ? 'Prueba cambiando el tipo de aviso o limpiando la búsqueda.'
              : 'Crea un aviso general, tarea, examen o comunicado urgente para tus alumnos.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 18),
        if (!hayFiltro)
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _abrirCrear(),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Crear primer aviso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

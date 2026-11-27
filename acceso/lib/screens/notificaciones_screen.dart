import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui_components.dart';
import '../widgets/anuncio_helpers.dart';
import 'anuncio_detalle_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  final String userId;

  const NotificacionesScreen({super.key, required this.userId});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _anuncios = [];
  bool _isLoading = true;
  bool _fromCache = false;
  String _search = '';
  String _tipoFiltro = 'todos';
  bool _soloNoLeidos = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final data = await _api.getAnunciosByAlumno(widget.userId);
    final fromCache = _api.lastDataFromCache;

    if (!mounted) return;
    setState(() {
      _anuncios = data;
      _fromCache = fromCache;
      _isLoading = false;
    });
  }

  void _actualizarAnuncio(String anuncioId) {
    setState(() {
      final index = _anuncios.indexWhere((a) => a['id']?.toString() == anuncioId);
      if (index != -1) {
        _anuncios[index]['leido'] = true;
      }
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _search.trim().toLowerCase();
    return _anuncios.where((a) {
      final leido = a['leido'] == true;
      if (_soloNoLeidos && leido) return false;
      final tipo = AnuncioHelper.normalizeTipo(a['tipo']?.toString());
      if (_tipoFiltro != 'todos' && tipo != _tipoFiltro) return false;
      if (q.isEmpty) return true;
      final titulo = (a['titulo'] ?? '').toString().toLowerCase();
      final mensaje = (a['mensaje'] ?? '').toString().toLowerCase();
      final materia = (a['materia_nombre'] ?? '').toString().toLowerCase();
      final prof = (a['profesor_nombre'] ?? '').toString().toLowerCase();
      return titulo.contains(q) ||
          mensaje.contains(q) ||
          materia.contains(q) ||
          prof.contains(q);
    }).toList();
  }

  int _contarPorTipo(String key) {
    if (key == 'todos') return _anuncios.length;
    return _anuncios
        .where((a) => AnuncioHelper.normalizeTipo(a['tipo']?.toString()) == key)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtrados;
    final noLeidosCount =
        _anuncios.where((a) => a['leido'] != true).length;

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Avisos y notificaciones',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              if (!_isLoading && _anuncios.isNotEmpty)
                Text(
                  noLeidosCount > 0
                      ? '$noLeidosCount sin leer · ${_anuncios.length} en total'
                      : '${_anuncios.length} avisos recibidos',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _cargar,
            ),
          ],
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
                  'Avisos cargados desde caché offline.',
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
                    _buildFiltrosPanel(noLeidosCount),
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
                                  ? _buildEmpty()
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(14),
                                      itemCount: items.length,
                                      itemBuilder: (context, i) =>
                                          _buildCard(items[i]),
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

  Widget _buildFiltrosPanel(int noLeidosCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por título, materia o profesor...',
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
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _soloNoLeidos,
                    label: Text(
                      'No leídos ($noLeidosCount)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            _soloNoLeidos ? Colors.white : AppColors.warning,
                      ),
                    ),
                    selectedColor: AppColors.warning,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _soloNoLeidos = v),
                  ),
                ),
                _tipoChip('todos', 'Todos (${_contarPorTipo('todos')})',
                    AppColors.primaryDark),
                ...AnuncioHelper.tipos.map(
                  (meta) => _tipoChip(
                    meta.key,
                    '${meta.shortLabel} (${_contarPorTipo(meta.key)})',
                    meta.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipoChip(String keyVal, String label, Color color) {
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
        side: BorderSide(color: color.withValues(alpha: 0.22)),
        showCheckmark: false,
        onSelected: (_) => setState(() => _tipoFiltro = keyVal),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> anuncio) {
    final tipoRaw = anuncio['tipo']?.toString();
    final meta = AnuncioHelper.metaFor(tipoRaw);
    final leido = anuncio['leido'] == true;
    final editado = AnuncioHelper.fueEditado(anuncio);
    final grupo = anuncio['grupo']?.toString();
    final materia = (anuncio['materia_nombre'] ?? 'Materia').toString();
    final prof = (anuncio['profesor_nombre'] ?? 'Profesor').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: leido ? 1 : 2.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: leido
            ? BorderSide(color: Colors.grey.shade200)
            : BorderSide(
                color: meta.color.withValues(alpha: 0.45),
                width: 1.5,
              ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnuncioDetalleScreen(
                anuncio: anuncio,
                userId: widget.userId,
              ),
            ),
          );
          if (result == true && mounted) {
            _actualizarAnuncio(anuncio['id']?.toString() ?? '');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          materia,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: meta.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (grupo != null && grupo.isNotEmpty)
                              ? 'Grupo $grupo'
                              : 'Todos los grupos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
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
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      if (!leido)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: meta.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Nuevo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  AnuncioHelper.buildTipoBadge(tipoRaw, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                (anuncio['titulo'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: leido ? FontWeight.w600 : FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                (anuncio['mensaje'] ?? '').toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      prof,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AnuncioHelper.formatFechaRelativa(anuncio['fecha_creacion']),
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final hayFiltro =
        _search.isNotEmpty || _tipoFiltro != 'todos' || _soloNoLeidos;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      children: [
        Icon(
          Icons.notifications_none_outlined,
          size: 70,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 14),
        Text(
          hayFiltro
              ? 'No hay avisos que coincidan con el filtro'
              : 'Sin avisos por el momento',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hayFiltro
              ? 'Prueba limpiando los filtros o la búsqueda.'
              : 'Aquí aparecerán los avisos, tareas y exámenes de tus profesores.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

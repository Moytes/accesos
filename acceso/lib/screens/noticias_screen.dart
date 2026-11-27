import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../navigation/role_router.dart';
import '../service/api_service.dart';
import '../service/app_permissions_service.dart';
import '../service/connectivity_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'profile_screen.dart';
import 'qralumnos.dart';

class NoticiasFeedScreen extends StatefulWidget {
  const NoticiasFeedScreen({super.key});

  @override
  State<NoticiasFeedScreen> createState() => _NoticiasFeedScreenState();
}

class _NoticiasFeedScreenState extends State<NoticiasFeedScreen> {
  final ApiService _apiService = ApiService();
  static const List<String> _categorias = [
    'Todas',
    'General',
    'Académico',
    'Deportes',
    'Cultura',
    'Avisos',
  ];

  List<Map<String, dynamic>> _noticias = [];
  bool _isLoading = true;
  String _categoria = 'Todas';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getNoticias(
      categoria: _categoria == 'Todas' ? null : _categoria,
    );
    if (!mounted) return;
    setState(() {
      _noticias = list;
      _isLoading = false;
    });
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return raw.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  void _verNoticia(Map<String, dynamic> n) {
    final titulo = (n['titulo'] ?? '').toString();
    final contenido = (n['contenido'] ?? '').toString();
    final img = (n['imagen_url'] ?? n['imagenUrl'] ?? '').toString();
    final cat = (n['categoria'] ?? 'General').toString();
    final fecha = _formatDate(
      n['fecha_publicacion'] ?? n['fechaPublicacion'] ?? n['created_at'],
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.94,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            if (img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SafeNetworkImage(
                  url: img,
                  height: 200,
                  width: double.infinity,
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(cat),
                  backgroundColor: AppColors.surfaceSoftBlue,
                  visualDensity: VisualDensity.compact,
                ),
                if (fecha.isNotEmpty)
                  Chip(
                    label: Text(fecha),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              contenido,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('Noticias Institucionales'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categorias.map((c) {
                    final active = _categoria == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: active,
                        selectedColor: AppColors.primaryDark,
                        labelStyle: TextStyle(
                          color: active ? Colors.white : AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) {
                          setState(() => _categoria = c);
                          _cargar();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: _noticias.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: const [
                                Text(
                                  'No hay noticias publicadas en esta categoría.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: _noticias.length,
                              itemBuilder: (ctx, i) {
                                final n = _noticias[i];
                                final img =
                                    (n['imagen_url'] ?? n['imagenUrl'] ?? '')
                                        .toString();
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  color: Colors.white,
                                  clipBehavior: Clip.antiAlias,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: InkWell(
                                    onTap: () => _verNoticia(n),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (img.isNotEmpty)
                                          SafeNetworkImage(
                                            url: img,
                                            height: 160,
                                            width: double.infinity,
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .surfaceSoftBlue,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        8,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      (n['categoria'] ??
                                                              'General')
                                                          .toString(),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .primaryDark,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    _formatDate(
                                                      n['fecha_publicacion'] ??
                                                          n['fechaPublicacion'] ??
                                                          n['created_at'],
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                (n['titulo'] ?? '').toString(),
                                                style: const TextStyle(
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryDark,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                (n['contenido'] ?? '')
                                                    .toString(),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketingDashboardScreen extends StatefulWidget {
  final String userId;
  final String? nombre;

  const MarketingDashboardScreen({
    super.key,
    required this.userId,
    this.nombre,
  });

  @override
  State<MarketingDashboardScreen> createState() =>
      _MarketingDashboardScreenState();
}

class _MarketingDashboardScreenState extends State<MarketingDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _noticias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getNoticias(incluirBorradores: true);
    if (!mounted) return;
    setState(() {
      _noticias = list;
      _isLoading = false;
    });
  }

  Future<void> _abrirEditorNoticia([Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final tituloCtrl = TextEditingController(
      text: existing?['titulo']?.toString() ?? '',
    );
    final contenidoCtrl = TextEditingController(
      text: existing?['contenido']?.toString() ?? '',
    );

    const cats = ['General', 'Académico', 'Deportes', 'Cultura', 'Avisos'];
    String categoria = (existing?['categoria'] ?? 'General').toString();
    if (!cats.contains(categoria)) categoria = 'General';
    bool activo = existing?['activo'] != false;
    String? imagenUrl =
        (existing?['imagen_url'] ?? existing?['imagenUrl'])?.toString();
    PickedAttachment? nuevaImagen;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Editar Publicación' : 'Nueva Noticia / Comunicado',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tituloCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().length < 4)
                        ? 'Título requerido'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: categoria,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: cats
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => categoria = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: contenidoCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Contenido',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'Contenido muy corto'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  if (nuevaImagen != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        Uint8List.fromList(nuevaImagen!.bytes),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (imagenUrl != null && imagenUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SafeNetworkImage(
                        url: imagenUrl,
                        height: 120,
                        width: double.infinity,
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked =
                          await AppPermissionsService.showAttachmentPickerSheet(
                        ctx,
                        allowPdf: false,
                        allowMultiple: false,
                        title: 'Imagen de portada',
                      );
                      if (picked.isNotEmpty && ctx.mounted) {
                        setModalState(() => nuevaImagen = picked.first);
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Seleccionar imagen de portada'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicada (visible para toda la comunidad)'),
                    value: activo,
                    onChanged: (v) => setModalState(() => activo = v),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              if (!ConnectivityService().isOnline.value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Se requiere conexión a internet para publicar noticias.',
                                    ),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => saving = true);
                              String? finalUrl = imagenUrl;
                              if (nuevaImagen != null) {
                                final uploaded =
                                    await _apiService.uploadNoticiaImagen(
                                  nuevaImagen!.bytes,
                                  nuevaImagen!.fileName,
                                );
                                if (uploaded == null) {
                                  if (ctx.mounted) {
                                    setModalState(() => saving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _apiService.lastError ??
                                              'Error subiendo imagen.',
                                        ),
                                        backgroundColor: AppColors.dangerRed,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                finalUrl = uploaded;
                              }

                              final res = isEdit
                                  ? await _apiService.actualizarNoticia(
                                      id: existing['id'].toString(),
                                      titulo: tituloCtrl.text.trim(),
                                      contenido: contenidoCtrl.text.trim(),
                                      imagenUrl: finalUrl,
                                      categoria: categoria,
                                      activo: activo,
                                    )
                                  : await _apiService.crearNoticia(
                                      titulo: tituloCtrl.text.trim(),
                                      contenido: contenidoCtrl.text.trim(),
                                      imagenUrl: finalUrl,
                                      categoria: categoria,
                                      activo: activo,
                                    );

                              if (!ctx.mounted) return;
                              setModalState(() => saving = false);

                              if (res != null) {
                                Navigator.pop(ctx);
                                await _cargar();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEdit
                                          ? 'Publicación actualizada.'
                                          : 'Noticia publicada correctamente.',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _apiService.lastError ??
                                          'Error guardando noticia.',
                                    ),
                                    backgroundColor: AppColors.dangerRed,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(saving ? 'Publicando...' : 'Guardar Noticia'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _eliminar(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content: const Text('¿Deseas eliminar permanentemente esta publicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _apiService.eliminarNoticia(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Noticia eliminada.'
              : (_apiService.lastError ?? 'No se pudo eliminar.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.dangerRed,
      ),
    );
    if (ok) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('CONTROL+ · Marketing'),
          actions: [
            RoleSwitcherButton(
              currentRole: 'marketing',
              userId: widget.userId,
              nombre: widget.nombre,
            ),
            IconButton(
              tooltip: 'Mi QR',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QRScreen(userId: widget.userId),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mi Perfil',
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userId: widget.userId,
                    nombre: widget.nombre,
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirEditorNoticia(),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Publicar Noticia'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                  itemCount: _noticias.length,
                  itemBuilder: (ctx, i) {
                    final n = _noticias[i];
                    final activo = n['activo'] != false;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        onTap: () => _abrirEditorNoticia(n),
                        leading: CircleAvatar(
                          backgroundColor: activo
                              ? AppColors.primary
                              : Colors.grey,
                          child: const Icon(Icons.campaign, color: Colors.white),
                        ),
                        title: Text(
                          (n['titulo'] ?? '').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        subtitle: Text(
                          '${n['categoria'] ?? 'General'} · ${activo ? "Publicada" : "Borrador"}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.dangerRed,
                          ),
                          onPressed: () => _eliminar(n['id'].toString()),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

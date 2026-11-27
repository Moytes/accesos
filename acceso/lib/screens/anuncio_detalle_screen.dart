import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui_components.dart';
import '../widgets/anuncio_helpers.dart';

class AnuncioDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> anuncio;
  final String userId;

  const AnuncioDetalleScreen({
    super.key,
    required this.anuncio,
    required this.userId,
  });

  @override
  State<AnuncioDetalleScreen> createState() => _AnuncioDetalleScreenState();
}

class _AnuncioDetalleScreenState extends State<AnuncioDetalleScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _marcarComoLeido();
  }

  Future<void> _marcarComoLeido() async {
    if (widget.anuncio['leido'] == false || widget.anuncio['leido'] == null) {
      setState(() => _isLoading = true);
      final id = widget.anuncio['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        await _api.marcarAnuncioLeido(id, widget.userId);
      }
      widget.anuncio['leido'] = true;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipoRaw = widget.anuncio['tipo']?.toString();
    final meta = AnuncioHelper.metaFor(tipoRaw);
    final grupo = widget.anuncio['grupo']?.toString();
    final materia = (widget.anuncio['materia_nombre'] ?? 'Materia').toString();
    final editado = AnuncioHelper.fueEditado(widget.anuncio);

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          title: const Text('Detalle del aviso'),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
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
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: meta.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(meta.icon, color: meta.color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    materia,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: meta.color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (grupo != null && grupo.isNotEmpty)
                                        ? 'Grupo $grupo'
                                        : 'Todos los grupos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.anuncio['leido'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Leído',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AnuncioHelper.buildTipoBadge(tipoRaw),
                            if (editado)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Editado',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          (widget.anuncio['titulo'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: Colors.grey[200]),
                        const SizedBox(height: 14),
                        Text(
                          (widget.anuncio['mensaje'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Divider(height: 1, color: Colors.grey[200]),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 20,
                          runSpacing: 12,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Publicado por:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_outline,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 240),
                                      child: Text(
                                        (widget.anuncio['profesor_nombre'] ??
                                                'Profesor')
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editado ? 'Última actualización:' : 'Fecha:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AnuncioHelper.formatFechaCompleta(
                                    editado
                                        ? (widget.anuncio['updated_at'] ??
                                            widget.anuncio['fecha_creacion'])
                                        : widget.anuncio['fecha_creacion'],
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver a avisos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

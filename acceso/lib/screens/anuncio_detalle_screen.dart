import 'package:flutter/material.dart';
import '../service/api_service.dart';

class AnuncioDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> anuncio;
  final String userId;

  const AnuncioDetalleScreen({
    Key? key,
    required this.anuncio,
    required this.userId,
  }) : super(key: key);

  @override
  State<AnuncioDetalleScreen> createState() => _AnuncioDetalleScreenState();
}

class _AnuncioDetalleScreenState extends State<AnuncioDetalleScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Marcar como leído al abrir la pantalla
    _marcarComoLeido();
  }

  Future<void> _marcarComoLeido() async {
    if (widget.anuncio['leido'] == false) {
      setState(() => _isLoading = true);
      await _api.marcarAnuncioLeido(
        widget.anuncio['id'] as String,
        widget.userId,
      );
      // Actualizar el estado local
      widget.anuncio['leido'] = true;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'falta':
        return const Color(0xFFE53935);
      case 'tarea':
        return const Color(0xFF43A047);
      default:
        return const Color(0xFF004C8C);
    }
  }

  IconData _iconTipo(String tipo) {
    switch (tipo) {
      case 'falta':
        return Icons.event_busy_outlined;
      case 'tarea':
        return Icons.assignment_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'falta':
        return 'Falta del profesor';
      case 'tarea':
        return 'Tarea / Actividad';
      default:
        return 'Aviso';
    }
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha).toLocal();
      final meses = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      return '${dt.day} de ${meses[dt.month - 1]} ${dt.year} a las ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.anuncio['tipo'] as String? ?? 'aviso';
    final color = _colorTipo(tipo);
    final grupo = widget.anuncio['grupo'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Detalle del anuncio'),
        backgroundColor: const Color(0xFF003366),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta principal
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo y materia
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_iconTipo(tipo), color: color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.anuncio['materia_nombre'] ?? 'Materia',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_labelTipo(tipo)}${grupo != null ? ' • Grupo $grupo' : ' • Todos los grupos'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
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
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Título
                    Text(
                      widget.anuncio['titulo'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Divider
                    Container(
                      height: 1,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    // Mensaje completo
                    Text(
                      widget.anuncio['mensaje'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Divider
                    Container(
                      height: 1,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    // Información adicional
                    Row(
                      children: [
                        Expanded(
                          child: Column(
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
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.anuncio['profesor_nombre'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Fecha:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatFecha(widget.anuncio['fecha_creacion'] as String?),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Botón para volver
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver a notificaciones'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
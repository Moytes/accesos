import 'package:flutter/material.dart';
import '../service/api_service.dart';
import 'anuncio_detalle_screen.dart'; // Importar la nueva pantalla

class NotificacionesScreen extends StatefulWidget {
  final String userId;

  const NotificacionesScreen({Key? key, required this.userId})
      : super(key: key);

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _anuncios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final data = await _api.getAnunciosByAlumno(widget.userId);
    
    // Ya no marcamos todos como leídos al entrar
    // Ahora se marcarán al abrir cada anuncio individualmente

    setState(() {
      _anuncios = data;
      _isLoading = false;
    });
  }

  // Método para actualizar el estado de un anuncio específico
  void _actualizarAnuncio(String anuncioId) {
    setState(() {
      final index = _anuncios.indexWhere((a) => a['id'] == anuncioId);
      if (index != -1) {
        _anuncios[index]['leido'] = true;
      }
    });
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
        'ene','feb','mar','abr','may','jun',
        'jul','ago','sep','oct','nov','dic'
      ];
      final ahora = DateTime.now();
      final diff = ahora.difference(dt);
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
      return '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_anuncios.isNotEmpty)
            TextButton(
              onPressed: _cargar,
              child: const Text('Actualizar',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF003366)))
          : _anuncios.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  color: const Color(0xFF003366),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _anuncios.length,
                    itemBuilder: (context, i) =>
                        _buildCard(_anuncios[i]),
                  ),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> anuncio) {
    final tipo = anuncio['tipo'] as String? ?? 'aviso';
    final leido = anuncio['leido'] as bool? ?? false;
    final color = _colorTipo(tipo);
    final grupo = anuncio['grupo'] as String?;

    return GestureDetector(
      onTap: () async {
        // Navegar al detalle del anuncio
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnuncioDetalleScreen(
              anuncio: anuncio,
              userId: widget.userId,
            ),
          ),
        );
        
        // Si volvemos con resultado true, actualizar el estado
        if (result == true) {
          _actualizarAnuncio(anuncio['id'] as String);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: leido
              ? null
              : Border.all(color: color.withOpacity(0.4), width: 1.5),
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
              // Fila superior
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_iconTipo(tipo), color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anuncio['materia_nombre'] ?? 'Materia',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_labelTipo(tipo)}${grupo != null ? ' • Grupo $grupo' : ' • Todos los grupos'}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (!leido)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Título
              Text(
                anuncio['titulo'] ?? '',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      leido ? FontWeight.w600 : FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),

              // Mensaje (truncado)
              Text(
                anuncio['mensaje'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Pie
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        anuncio['profesor_nombre'] ?? '',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  Text(
                    _formatFecha(
                        anuncio['fecha_creacion'] as String?),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
              
              // Indicador "Toca para ver más"
              if (!leido)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Text(
                        'Toca para leer completo',
                        style: TextStyle(
                          fontSize: 11,
                          color: color.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: color.withOpacity(0.7),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined,
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Sin notificaciones',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Aquí aparecerán los avisos de tus profesores',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
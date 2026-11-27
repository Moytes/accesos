import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';

class DetalleAsistenciaAlumnoScreen extends StatefulWidget {
  final String userId;
  final String alumnoNombre;
  final String materiaId; // claseId
  final String materiaNombre;
  final String grupo;

  const DetalleAsistenciaAlumnoScreen({
    super.key,
    required this.userId,
    required this.alumnoNombre,
    required this.materiaId,
    required this.materiaNombre,
    required this.grupo,
  });

  @override
  State<DetalleAsistenciaAlumnoScreen> createState() =>
      _DetalleAsistenciaAlumnoScreenState();
}

class _DetalleAsistenciaAlumnoScreenState
    extends State<DetalleAsistenciaAlumnoScreen> {
  final ApiService _apiService = ApiService();

  Map<String, int> _stats = const {
    'total': 0,
    'presentes': 0,
    'faltas': 0,
    'retardos': 0,
    'justificados': 0,
  };
  List<Map<String, dynamic>> _registros = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() => _isLoading = true);
    final stats = await _apiService.getEstadisticasAsistencia(
      widget.userId,
      widget.materiaId,
    );
    final inasistencias = await _apiService.getInasistenciasByAlumnoYMateria(
      widget.userId,
      widget.materiaId,
    );
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _registros = inasistencias;
      _isLoading = false;
    });
  }

  Future<void> _cambiarEstadoRegistro(
    Map<String, dynamic> reg,
    String nuevoEstado,
  ) async {
    final fecha = (reg['fecha'] ?? '').toString();
    if (fecha.isEmpty) return;

    try {
      final ok = await _apiService.updateAsistencia(
        widget.materiaId,
        widget.userId,
        fecha,
        nuevoEstado,
      );
      if (!mounted) return;

      final queued = !ok && _apiService.lastMutationQueuedOffline;
      if (ok || queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              queued
                  ? 'Cambio guardado en cola offline. Se sincronizará automáticamente.'
                  : 'Estado actualizado a $nuevoEstado.',
            ),
            backgroundColor: queued ? AppColors.warning : AppColors.success,
          ),
        );
        if (queued) {
          setState(() => reg['estado'] = nuevoEstado);
        } else {
          await _cargarDetalle();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error actualizando registro: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  Color _estadoColor(String est) {
    switch (est.toLowerCase()) {
      case 'presente':
        return AppColors.success;
      case 'retardo':
        return AppColors.warning;
      case 'justificado':
      case 'justificada':
        return AppColors.accentBlue;
      default:
        return AppColors.dangerRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _stats['total'] ?? 0;
    final presentes = _stats['presentes'] ?? 0;
    final justificados = _stats['justificados'] ?? 0;
    final retardos = _stats['retardos'] ?? 0;
    final faltas = _stats['faltas'] ?? 0;
    final pct = total > 0
        ? (((presentes + justificados + retardos * 0.5) / total) * 100.0)
        : 100.0;

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.alumnoNombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16.5),
              ),
              Text(
                '${widget.materiaNombre} · Grupo ${widget.grupo}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargarDetalle,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Asistencia Acumulada',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${pct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '$total sesiones registradas',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.pie_chart,
                            size: 46,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statTile('Presentes', presentes, AppColors.success),
                        const SizedBox(width: 8),
                        _statTile('Justif.', justificados, AppColors.accentBlue),
                        const SizedBox(width: 8),
                        _statTile('Retardos', retardos, AppColors.warning),
                        const SizedBox(width: 8),
                        _statTile('Faltas', faltas, AppColors.dangerRed),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Historial de incidencias y faltas',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_registros.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Sin faltas ni incidencias registradas.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._registros.map((reg) {
                        final fecha = (reg['fecha'] ?? '').toString();
                        final estado = (reg['estado'] ?? 'falta').toString();
                        final c = _estadoColor(estado);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: c.withOpacity(0.15),
                              child: Icon(Icons.event_note, color: c, size: 20),
                            ),
                            title: Text(
                              fecha,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            subtitle: Text(
                              'Estado actual: ${estado.toUpperCase()}',
                              style: TextStyle(
                                color: c,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.edit_outlined),
                              onSelected: (v) => _cambiarEstadoRegistro(reg, v),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'presente',
                                  child: Text('Marcar Presente'),
                                ),
                                PopupMenuItem(
                                  value: 'retardo',
                                  child: Text('Marcar Retardo'),
                                ),
                                PopupMenuItem(
                                  value: 'justificado',
                                  child: Text('Marcar Justificado'),
                                ),
                                PopupMenuItem(
                                  value: 'falta',
                                  child: Text('Marcar Falta'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statTile(String label, int val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$val',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

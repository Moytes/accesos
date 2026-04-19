import 'package:flutter/material.dart';
import '../service/api_service.dart';

class VisitasScreen extends StatefulWidget {
  final String adminId;

  const VisitasScreen({Key? key, required this.adminId}) : super(key: key);

  @override
  State<VisitasScreen> createState() => _VisitasScreenState();
}

class _VisitasScreenState extends State<VisitasScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _todasVisitas = [];
  List<Map<String, dynamic>> _visitasHoy = [];
  List<Map<String, dynamic>> _visitasPendientes = [];
  List<Map<String, dynamic>> _visitasPasadas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarVisitas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarVisitas() async {
    setState(() => _isLoading = true);
    try {
      final visitas = await _apiService.getTodasLasVisitas();
      final hoy = DateTime.now();
      final hoyStr =
          '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

      setState(() {
        _todasVisitas = visitas;
        _visitasHoy = visitas.where((v) {
          final fecha = (v['fecha_visita'] as String?)?.split('T')[0] ?? '';
          return fecha == hoyStr;
        }).toList();
        _visitasPendientes = visitas.where((v) {
          final fecha = (v['fecha_visita'] as String?)?.split('T')[0] ?? '';
          return fecha.compareTo(hoyStr) > 0;
        }).toList();
        _visitasPasadas = visitas.where((v) {
          final fecha = (v['fecha_visita'] as String?)?.split('T')[0] ?? '';
          return fecha.compareTo(hoyStr) < 0;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        title: const Text(
          'Visitas registradas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFC107),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Hoy (${_visitasHoy.length})'),
            Tab(text: 'Próximas (${_visitasPendientes.length})'),
            Tab(text: 'Pasadas (${_visitasPasadas.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF003366)),
            )
          : RefreshIndicator(
              onRefresh: _cargarVisitas,
              color: const Color(0xFF003366),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildListaVisitas(_visitasHoy, esHoy: true),
                  _buildListaVisitas(_visitasPendientes),
                  _buildListaVisitas(_visitasPasadas, esPasada: true),
                ],
              ),
            ),
    );
  }

  Widget _buildListaVisitas(
    List<Map<String, dynamic>> visitas, {
    bool esHoy = false,
    bool esPasada = false,
  }) {
    if (visitas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay visitas registradas',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visitas.length,
      itemBuilder: (context, index) {
        return _buildVisitaCard(visitas[index],
            esHoy: esHoy, esPasada: esPasada);
      },
    );
  }

  Widget _buildVisitaCard(
    Map<String, dynamic> visita, {
    bool esHoy = false,
    bool esPasada = false,
  }) {
    final nombre = visita['nombre'] as String? ?? 'Sin nombre';
    final empresa = visita['empresa'] as String? ?? 'Sin empresa';
    final cargo = visita['cargo'] as String? ?? '';
    final correo = visita['correo'] as String? ?? '';
    final motivo = visita['motivo'] as String? ?? '';
    final contactoInterno = visita['contacto_interno'] as String? ?? '';
    final fechaStr = visita['fecha_visita'] as String? ?? '';
    final qrUsado = visita['qr_usado'] as bool? ?? false;

    DateTime? fecha;
    try {
      fecha = DateTime.parse(fechaStr);
    } catch (_) {}

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (esPasada && qrUsado) {
      statusColor = Colors.grey;
      statusText = 'Visita completada';
      statusIcon = Icons.check_circle_outline;
    } else if (esPasada) {
      statusColor = Colors.orange;
      statusText = 'No asistió / QR no usado';
      statusIcon = Icons.cancel_outlined;
    } else if (esHoy) {
      statusColor = const Color(0xFF1B7A3E);
      statusText = qrUsado ? 'Ya ingresó' : 'Visita hoy - QR activo';
      statusIcon =
          qrUsado ? Icons.check_circle : Icons.qr_code_scanner_outlined;
    } else {
      statusColor = const Color(0xFF0055A0);
      statusText = 'QR pendiente de activación';
      statusIcon = Icons.schedule_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF003366),
                        ),
                      ),
                      Text(
                        cargo.isNotEmpty ? '$cargo · $empresa' : empresa,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        esHoy && qrUsado ? 'Ingresó' : esHoy ? 'Hoy' : esPasada ? 'Pasada' : 'Próxima',
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow(Icons.calendar_today_outlined,
                fecha != null ? _formatFecha(fecha) : fechaStr),
            const SizedBox(height: 6),
            _buildDetailRow(Icons.email_outlined, correo),
            if (motivo.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildDetailRow(Icons.description_outlined, motivo),
            ],
            if (contactoInterno.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildDetailRow(Icons.record_voice_over_outlined,
                  'Visita a: $contactoInterno'),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  String _formatFecha(DateTime fecha) {
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    return '${days[fecha.weekday - 1]} ${fecha.day} ${months[fecha.month - 1]} ${fecha.year}';
  }
}
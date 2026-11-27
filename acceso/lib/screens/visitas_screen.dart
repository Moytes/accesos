import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui_components.dart';

class VisitasScreen extends StatefulWidget {
  final String adminId;

  const VisitasScreen({super.key, required this.adminId});

  @override
  State<VisitasScreen> createState() => _VisitasScreenState();
}

class _VisitasScreenState extends State<VisitasScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _visitas = [];
  bool _isLoading = true;
  String _filtroEstado = 'todos';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _cargarVisitas();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarVisitas() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getTodasLasVisitas();
    if (!mounted) return;
    setState(() {
      _visitas = list;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filtradas {
    final q = _search.trim().toLowerCase();
    return _visitas.where((v) {
      final estado = (v['estado'] ?? 'pendiente').toString().toLowerCase();
      if (_filtroEstado != 'todos' && estado != _filtroEstado) return false;
      if (q.isEmpty) return true;
      final nom = (v['nombre'] ?? '').toString().toLowerCase();
      final emp = (v['empresa'] ?? '').toString().toLowerCase();
      final cont = (v['contacto_interno'] ?? v['contactoInterno'] ?? '')
          .toString()
          .toLowerCase();
      return nom.contains(q) || emp.contains(q) || cont.contains(q);
    }).toList();
  }

  Color _estadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'ingresado':
        return AppColors.success;
      case 'finalizado':
        return AppColors.primary;
      case 'cancelado':
        return AppColors.dangerRed;
      default:
        return AppColors.warning;
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return raw.toString();
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  Future<void> _cancelarVisita(String visitaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar visita'),
        content: const Text('¿Deseas cancelar este pase de visitante?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok = await _apiService.cancelarVisita(visitaId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Visita cancelada.'
              : (_apiService.lastError ?? 'No se pudo cancelar la visita.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.dangerRed,
      ),
    );
    if (ok) await _cargarVisitas();
  }

  void _mostrarDetallePase(Map<String, dynamic> v) {
    final id = v['id']?.toString() ?? '';
    final nombre = (v['nombre'] ?? '').toString();
    final empresa = (v['empresa'] ?? '').toString();
    final motivo = (v['motivo'] ?? '').toString();
    final contacto =
        (v['contacto_interno'] ?? v['contactoInterno'] ?? '').toString();
    final fecha = _formatDate(v['fecha_visita'] ?? v['fechaVisita']);
    final hi = (v['hora_inicio'] ?? v['horaInicio'] ?? '').toString();
    final hf = (v['hora_fin'] ?? v['horaFin'] ?? '').toString();
    final qr =
        (v['qr_codigo'] ?? v['qrCodigo'] ?? v['codigo'] ?? id).toString();
    final estado = (v['estado'] ?? 'pendiente').toString().toLowerCase();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                nombre,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                '$empresa · Recibe: $contacto',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Text(
                '$fecha${hi.isNotEmpty ? " · $hi-$hf" : ""}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              if (motivo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Motivo: $motivo', textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              if (qr.isNotEmpty && estado != 'cancelado')
                QrImageView(
                  data: qr,
                  version: QrVersions.auto,
                  size: 190,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.primaryDark,
                  ),
                ),
              const SizedBox(height: 8),
              SelectableText(
                'Código: $qr',
                style: const TextStyle(fontSize: 12, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (estado != 'cancelado')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _cancelarVisita(id);
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerRed,
                          side: const BorderSide(color: AppColors.dangerRed),
                        ),
                      ),
                    ),
                  if (estado != 'cancelado') const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Share.share(
                          'Pase de Visita CONTROL+\nVisitante: $nombre ($empresa)\nFecha: $fecha\nCódigo QR: $qr',
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Compartir Pase'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final items = _filtradas;
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('Control de Visitas'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarVisitas,
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar visitante, empresa o anfitrión...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('todos', 'Todas'),
                        const SizedBox(width: 6),
                        _chip('pendiente', 'Pendientes'),
                        const SizedBox(width: 6),
                        _chip('ingresado', 'En Campus'),
                        const SizedBox(width: 6),
                        _chip('finalizado', 'Finalizadas'),
                        const SizedBox(width: 6),
                        _chip('cancelado', 'Canceladas'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ResponsiveContainer(
                padding: EdgeInsets.zero,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _cargarVisitas,
                      child: items.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay visitas que coincidan con el filtro.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: items.length,
                              itemBuilder: (ctx, i) {
                                final v = items[i];
                                final est =
                                    (v['estado'] ?? 'pendiente').toString();
                                final color = _estadoColor(est);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    onTap: () => _mostrarDetallePase(v),
                                    leading: CircleAvatar(
                                      backgroundColor: color.withOpacity(0.15),
                                      child: Icon(Icons.qr_code, color: color),
                                    ),
                                    title: Text(
                                      (v['nombre'] ?? 'Visitante').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${v['empresa'] ?? ''} · ${_formatDate(v['fecha_visita'] ?? v['fechaVisita'])}\nRecibe: ${v['contacto_interno'] ?? v['contactoInterno'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    isThreeLine: true,
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        est.toUpperCase(),
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _filtroEstado == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primaryDark,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _filtroEstado = value),
    );
  }
}

import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../service/api_service.dart';
import '../service/connectivity_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';

class EntradasSalidasScreen extends StatefulWidget {
  final String? userIdFilter;

  const EntradasSalidasScreen({super.key, this.userIdFilter});

  @override
  State<EntradasSalidasScreen> createState() => _EntradasSalidasScreenState();
}

class _EntradasSalidasScreenState extends State<EntradasSalidasScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _registros = [];
  List<Map<String, dynamic>> _zonas = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String _tipoFiltro = 'todos';
  String? _zonaFiltroId;
  String _search = '';

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
    final accessFuture = _apiService.getAccess(
      userId: widget.userIdFilter,
      zoneId: _zonaFiltroId,
      tipo: _tipoFiltro == 'todos' ? null : _tipoFiltro,
      limit: 250,
    );
    final zonasFuture = widget.userIdFilter == null
        ? _apiService.getZonas()
        : Future.value(<Map<String, dynamic>>[]);

    final registros = await accessFuture;
    final zonas = await zonasFuture;
    if (!mounted) return;
    setState(() {
      _registros = registros;
      _zonas = zonas;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _search.trim().toLowerCase();
    return _registros.where((r) {
      final tipo = (r['tipo'] ?? '').toString().toLowerCase();
      if (_tipoFiltro != 'todos' && tipo != _tipoFiltro) return false;
      if (q.isEmpty) return true;
      final nom = (r['nombre'] ?? r['usuario_nombre'] ?? '')
          .toString()
          .toLowerCase();
      final mat = (r['matricula'] ?? '').toString().toLowerCase();
      final zona = (r['zona_nombre'] ?? r['zona'] ?? '').toString().toLowerCase();
      return nom.contains(q) || mat.contains(q) || zona.contains(q);
    }).toList();
  }

  Future<void> _exportarExcel() async {
    setState(() => _isExporting = true);
    try {
      List<Map<String, dynamic>> source = _filtrados;
      if (widget.userIdFilter == null && ConnectivityService().isOnline.value) {
        final serverReport = await _apiService.exportarReporteAccesos(
          tipo: _tipoFiltro == 'todos' ? null : _tipoFiltro,
        );
        if (serverReport.isNotEmpty) source = serverReport;
      }

      if (source.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay accesos para exportar.')),
        );
        return;
      }

      final excel = xl.Excel.createExcel();
      const name = 'Accesos';
      excel.rename('Sheet1', name);
      final sheet = excel[name];

      final headers = [
        'Fecha/Hora',
        'Usuario',
        'Matrícula / ID',
        'Tipo',
        'Zona',
        'Motivo Denegación',
      ];
      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
            .value = headers[c];
      }

      for (int r = 0; r < source.length; r++) {
        final item = source[r];
        final row = r + 1;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
            _formatDate(item['fecha'] ?? item['created_at'] ?? item['timestamp']);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
            (item['nombre'] ?? item['usuario_nombre'] ?? '').toString();
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
            (item['matricula'] ?? item['numero_empleado'] ?? '').toString();
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
            (item['tipo'] ?? '').toString();
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
            (item['zona_nombre'] ?? item['zona'] ?? '').toString();
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
            (item['motivo_denegacion'] ?? item['motivoDenegacion'] ?? '')
                .toString();
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Error codificando Excel.');
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/reporte_accesos_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await File(path).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles([XFile(path)], text: 'Reporte de Accesos CONTROL+');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return raw.toString();
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Color _tipoColor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'entrada':
        return AppColors.success;
      case 'salida':
        return AppColors.accentBlue;
      case 'denegado':
        return AppColors.dangerRed;
      default:
        return Colors.grey;
    }
  }

  IconData _tipoIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'entrada':
        return Icons.login;
      case 'salida':
        return Icons.logout;
      case 'denegado':
        return Icons.block;
      default:
        return Icons.sync_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtrados;
    final esPersonal = widget.userIdFilter != null;

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: Text(esPersonal ? 'Mis Accesos' : 'Entradas y Salidas'),
          actions: [
            IconButton(
              tooltip: 'Exportar Excel',
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download),
              onPressed: _isExporting ? null : _exportarExcel,
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
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
                      hintText: esPersonal
                          ? 'Filtrar por zona...'
                          : 'Buscar usuario, matrícula o zona...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  if (!esPersonal && _zonas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: _zonaFiltroId,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por zona',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todas las zonas'),
                        ),
                        ..._zonas.map(
                          (z) => DropdownMenuItem<String?>(
                            value: z['id']?.toString(),
                            child: Text(
                              (z['nombre'] ?? z['codigo'] ?? 'Zona').toString(),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _zonaFiltroId = val);
                        _cargar();
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _tipoChip('todos', 'Todos'),
                        const SizedBox(width: 6),
                        _tipoChip('entrada', 'Entradas'),
                        const SizedBox(width: 6),
                        _tipoChip('salida', 'Salidas'),
                        const SizedBox(width: 6),
                        _tipoChip('denegado', 'Denegados'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: items.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: [
                                Icon(
                                  Icons.door_sliding_outlined,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Sin registros de acceso para este filtro.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: items.length,
                              itemBuilder: (ctx, i) {
                                final r = items[i];
                                final tipo = (r['tipo'] ?? '').toString();
                                final color = _tipoColor(tipo);
                                final motivo = (r['motivo_denegacion'] ??
                                        r['motivoDenegacion'] ??
                                        '')
                                    .toString();
                                final zona =
                                    (r['zona_nombre'] ?? r['zona'] ?? 'Campus')
                                        .toString();
                                final fecha = _formatDate(
                                  r['fecha'] ??
                                      r['created_at'] ??
                                      r['timestamp'],
                                );

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: color.withOpacity(0.15),
                                      child: Icon(_tipoIcon(tipo), color: color),
                                    ),
                                    title: Text(
                                      (r['nombre'] ??
                                              r['usuario_nombre'] ??
                                              'Usuario')
                                          .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$zona · $fecha',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (motivo.isNotEmpty)
                                          Text(
                                            'Motivo: $motivo',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.dangerRed,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
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
                                        tipo.toUpperCase(),
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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

  Widget _tipoChip(String value, String label) {
    final selected = _tipoFiltro == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        setState(() => _tipoFiltro = value);
        _cargar();
      },
    );
  }
}

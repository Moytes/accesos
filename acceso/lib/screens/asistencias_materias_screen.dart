import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import 'qralumnos.dart';

class AsistenciasMateriasScreen extends StatefulWidget {
  final String claseId;
  final String nombreMateria;
  final String grupo;

  const AsistenciasMateriasScreen({
    super.key,
    required this.claseId,
    required this.nombreMateria,
    required this.grupo,
  });

  @override
  State<AsistenciasMateriasScreen> createState() =>
      _AsistenciasMateriasScreenState();
}

class _AsistenciasMateriasScreenState extends State<AsistenciasMateriasScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _alumnos = [];
  List<String> _fechas = [];
  Map<String, Map<String, String>> _asistencias = {};
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _cargarTabla();
  }

  Future<void> _cargarTabla() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getAsistenciasTabla(widget.claseId);
    if (!mounted) return;

    final rawAsist = (data['asistencias'] as Map?) ?? const {};
    final Map<String, Map<String, String>> parsed = {};
    rawAsist.forEach((uid, mapa) {
      if (mapa is Map) {
        parsed[uid.toString()] = mapa.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    });

    setState(() {
      _alumnos = List<Map<String, dynamic>>.from(
        data['alumnos'] as List? ?? const [],
      );
      _fechas = List<String>.from(data['fechas'] as List? ?? const []);
      _asistencias = parsed;
      _isLoading = false;
    });
  }

  String _formatFechaCorta(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM').format(dt.toLocal());
  }

  String _codigoCelda(String? estado) {
    switch ((estado ?? '').trim().toLowerCase()) {
      case 'presente':
        return 'P';
      case 'retardo':
        return 'R';
      case 'justificado':
      case 'justificada':
        return 'J';
      case 'falta':
      case 'ausente':
        return 'F';
      default:
        return '-';
    }
  }

  Color _colorCelda(String codigo) {
    switch (codigo) {
      case 'P':
        return AppColors.success;
      case 'R':
        return AppColors.warning;
      case 'J':
        return AppColors.accentBlue;
      case 'F':
        return AppColors.dangerRed;
      default:
        return Colors.grey;
    }
  }

  Future<void> _editarCelda(
    Map<String, dynamic> alumno,
    String fecha,
    String? estadoActual,
  ) async {
    String seleccionado = (estadoActual ?? 'presente').toLowerCase();
    if (seleccionado == 'justificada') seleccionado = 'justificado';
    if (seleccionado == 'ausente') seleccionado = 'falta';
    if (!['presente', 'falta', 'retardo', 'justificado'].contains(seleccionado)) {
      seleccionado = 'presente';
    }
    bool primeraPasada = seleccionado == 'presente' || seleccionado == 'retardo';
    bool segundaPasada = seleccionado == 'presente';

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(alumno['nombre']?.toString() ?? 'Alumno'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha: $fecha',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _estadoChip(
                    'presente',
                    'Presente (P)',
                    AppColors.success,
                    seleccionado,
                    (v) => setDlgState(() => seleccionado = v),
                  ),
                  _estadoChip(
                    'retardo',
                    'Retardo (R)',
                    AppColors.warning,
                    seleccionado,
                    (v) => setDlgState(() => seleccionado = v),
                  ),
                  _estadoChip(
                    'justificado',
                    'Justificado (J)',
                    AppColors.accentBlue,
                    seleccionado,
                    (v) => setDlgState(() => seleccionado = v),
                  ),
                  _estadoChip(
                    'falta',
                    'Falta (F)',
                    AppColors.dangerRed,
                    seleccionado,
                    (v) => setDlgState(() => seleccionado = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('1ra pasada (Entrada)', style: TextStyle(fontSize: 13.5)),
                value: primeraPasada,
                onChanged: (v) => setDlgState(() => primeraPasada = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('2da pasada (Salida)', style: TextStyle(fontSize: 13.5)),
                value: segundaPasada,
                onChanged: (v) => setDlgState(() => segundaPasada = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardado != true || !mounted) return;
    final uid = alumno['id']?.toString() ?? '';

    try {
      final ok = await _apiService.updateAsistencia(
        widget.claseId,
        uid,
        fecha,
        seleccionado,
        primeraPasada: primeraPasada,
        segundaPasada: segundaPasada,
      );
      if (!mounted) return;

      final queued = !ok && _apiService.lastMutationQueuedOffline;
      if (ok || queued) {
        setState(() {
          _asistencias.putIfAbsent(uid, () => {})[fecha] = seleccionado;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              queued
                  ? 'Asistencia guardada en cola offline. Se sincronizará automáticamente.'
                  : 'Asistencia actualizada correctamente.',
            ),
            backgroundColor: queued ? AppColors.warning : AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  Widget _estadoChip(
    String value,
    String label,
    Color color,
    String current,
    ValueChanged<String> onSelected,
  ) {
    final active = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: color,
      labelStyle: TextStyle(
        color: active ? Colors.white : AppColors.primaryDark,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  Future<void> _exportarExcel() async {
    if (_alumnos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final excel = xl.Excel.createExcel();
      const sheetName = 'Asistencias';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          'REGISTRO DE ASISTENCIAS - CONTROL+';
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
          'Materia: ${widget.nombreMateria} | Grupo: ${widget.grupo}';
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value =
          'Exportado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';

      const headerRow = 4;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow)).value =
          'Alumno';
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow)).value =
          'Matrícula';

      for (int i = 0; i < _fechas.length; i++) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: 2 + i,
              rowIndex: headerRow,
            ))
            .value = _formatFechaCorta(_fechas[i]);
      }

      final baseCol = 2 + _fechas.length;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol, rowIndex: headerRow)).value =
          'Presentes';
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol + 1, rowIndex: headerRow)).value =
          'Justificados';
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol + 2, rowIndex: headerRow)).value =
          'Retardos';
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol + 3, rowIndex: headerRow)).value =
          'Faltas';
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol + 4, rowIndex: headerRow)).value =
          '% Asistencia';

      for (int r = 0; r < _alumnos.length; r++) {
        final al = _alumnos[r];
        final uid = al['id']?.toString() ?? '';
        final row = headerRow + 1 + r;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
            al['nombre']?.toString() ?? '';
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
            al['matricula']?.toString() ?? '';

        int p = 0, j = 0, ret = 0, f = 0, reg = 0;
        for (int c = 0; c < _fechas.length; c++) {
          final est = _asistencias[uid]?[_fechas[c]];
          final code = _codigoCelda(est);
          sheet
              .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 2 + c,
                rowIndex: row,
              ))
              .value = code;
          if (code != '-') {
            reg++;
            if (code == 'P') p++;
            if (code == 'J') j++;
            if (code == 'R') ret++;
            if (code == 'F') f++;
          }
        }
        final pct = reg > 0 ? ((p + j + (ret * 0.5)) / reg) * 100.0 : 100.0;

        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol, rowIndex: row)).value = p;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol + 1, rowIndex: row)).value = j;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol + 2, rowIndex: row)).value = ret;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: baseCol + 3, rowIndex: row)).value = f;
        sheet
            .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: baseCol + 4,
              rowIndex: row,
            ))
            .value = '${pct.toStringAsFixed(1)}%';
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('No se pudieron generar los bytes del Excel.');
      }

      final dir = await getTemporaryDirectory();
      final cleanMat = widget.nombreMateria
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filePath =
          '${dir.path}/asistencias_${cleanMat}_${widget.grupo}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Asistencias ${widget.nombreMateria} - Grupo ${widget.grupo}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar Excel: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tabla de Asistencias', style: TextStyle(fontSize: 16.5)),
              Text(
                '${widget.nombreMateria} · ${widget.grupo}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Pase QR',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClaseQrScreen(
                    claseId: widget.claseId,
                    nombreMateria: widget.nombreMateria,
                    grupo: widget.grupo,
                  ),
                ),
              ),
            ),
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
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _cargarTabla,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _alumnos.isEmpty
                ? const Center(
                    child: Text('No hay alumnos registrados en esta clase.'),
                  )
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _legend('P', 'Presente', AppColors.success),
                            _legend('R', 'Retardo', AppColors.warning),
                            _legend('J', 'Justificado', AppColors.accentBlue),
                            _legend('F', 'Falta', AppColors.dangerRed),
                            Text(
                              '· Toca cualquier celda para editar',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AppColors.primaryDark,
                              ),
                              dataRowColor: WidgetStateProperty.all(Colors.white),
                              border: TableBorder.all(
                                color: Colors.grey.shade300,
                              ),
                              columns: [
                                const DataColumn(
                                  label: Text(
                                    'Alumno',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ..._fechas.map(
                                  (f) => DataColumn(
                                    label: Text(
                                      _formatFechaCorta(f),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    '%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: _alumnos.map((al) {
                                final uid = al['id']?.toString() ?? '';
                                final mapa = _asistencias[uid] ?? const {};
                                int reg = 0;
                                double score = 0;
                                for (final f in _fechas) {
                                  final c = _codigoCelda(mapa[f]);
                                  if (c != '-') {
                                    reg++;
                                    if (c == 'P' || c == 'J') score += 1;
                                    if (c == 'R') score += 0.5;
                                  }
                                }
                                final pct =
                                    reg > 0 ? (score / reg) * 100.0 : 100.0;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 170,
                                        child: Text(
                                          al['nombre']?.toString() ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    ..._fechas.map((f) {
                                      final rawEst = mapa[f];
                                      final code = _codigoCelda(rawEst);
                                      final color = _colorCelda(code);
                                      return DataCell(
                                        Center(
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              code,
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        onTap: () =>
                                            _editarCelda(al, f, rawEst),
                                      );
                                    }),
                                    DataCell(
                                      Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: pct >= 80
                                              ? AppColors.successDark
                                              : AppColors.dangerRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _legend(String code, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: color.withOpacity(0.16),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}

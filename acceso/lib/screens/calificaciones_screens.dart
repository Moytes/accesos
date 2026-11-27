import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';

class CalificacionesClaseScreen extends StatefulWidget {
  final String claseId;
  final String nombreMateria;
  final String grupo;

  const CalificacionesClaseScreen({
    super.key,
    required this.claseId,
    required this.nombreMateria,
    required this.grupo,
  });

  @override
  State<CalificacionesClaseScreen> createState() =>
      _CalificacionesClaseScreenState();
}

class _CalificacionesClaseScreenState extends State<CalificacionesClaseScreen> {
  final ApiService _apiService = ApiService();

  int _parcial = 1;
  List<Map<String, dynamic>> _alumnos = [];
  List<Map<String, dynamic>> _calificaciones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final tablaFuture = _apiService.getAsistenciasTabla(widget.claseId);
    final califFuture = _apiService.getCalificacionesByClase(widget.claseId);

    final tabla = await tablaFuture;
    final califs = await califFuture;
    if (!mounted) return;

    setState(() {
      _alumnos = List<Map<String, dynamic>>.from(
        tabla['alumnos'] as List? ?? const [],
      );
      _calificaciones = califs;
      _isLoading = false;
    });
  }

  Map<String, dynamic>? _findCalificacion(String alumnoId, int parcial) {
    for (final c in _calificaciones) {
      final uid = (c['alumno_id'] ?? c['alumnoId'] ?? c['user_id'] ?? '')
          .toString();
      final p = int.tryParse((c['parcial'] ?? '').toString()) ?? 0;
      if (uid == alumnoId && p == parcial) return c;
    }
    return null;
  }

  String _sugerirNivel(double? nota) {
    if (nota == null) return 'SA';
    if (nota >= 9.5) return 'AU';
    if (nota >= 8.5) return 'DE';
    if (nota >= 7.5) return 'SA';
    return 'NA';
  }

  Color _nivelColor(String nivel) {
    switch (nivel.toUpperCase()) {
      case 'AU':
        return AppColors.successDark;
      case 'DE':
        return AppColors.primary;
      case 'SA':
        return AppColors.accentBlue;
      default:
        return AppColors.dangerRed;
    }
  }

  Future<void> _capturarCalificacion(Map<String, dynamic> alumno) async {
    final uid = alumno['id']?.toString() ?? '';
    final existing = _findCalificacion(uid, _parcial);

    final notaCtrl = TextEditingController(
      text: existing?['calificacion']?.toString() ?? '',
    );
    String nivel = (existing?['nivel'] ?? 'SA').toString().toUpperCase();
    if (!['AU', 'DE', 'SA', 'NA'].contains(nivel)) nivel = 'SA';
    String comentario = (existing?['comentario'] ?? '').toString();
    final commCtrl = TextEditingController(text: comentario);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alumno['nombre']?.toString() ?? 'Alumno',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                '${widget.nombreMateria} · Parcial $_parcial',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Calificación numérica (0.0 - 10.0)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val.replaceAll(',', '.'));
                  if (parsed != null) {
                    setModalState(() => nivel = _sugerirNivel(parsed));
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Nivel de Desempeño:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['AU', 'DE', 'SA', 'NA'].map((n) {
                  final selected = nivel == n;
                  final c = _nivelColor(n);
                  return ChoiceChip(
                    label: Text(n),
                    selected: selected,
                    selectedColor: c,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => setModalState(() => nivel = n),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Retroalimentación / comentario (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final rawTxt = notaCtrl.text.trim();
                          final parsed = rawTxt.isEmpty
                              ? null
                              : double.tryParse(rawTxt.replaceAll(',', '.'));
                          if (rawTxt.isNotEmpty &&
                              (parsed == null || parsed < 0 || parsed > 10)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'La calificación debe estar entre 0 y 10.',
                                ),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }

                          setModalState(() => saving = true);
                          final ok = await _apiService.upsertCalificacion(
                            alumnoId: uid,
                            claseId: widget.claseId,
                            parcial: _parcial,
                            calificacion: parsed,
                            nivel: nivel,
                            comentario: commCtrl.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          setModalState(() => saving = false);

                          if (ok) {
                            final queued =
                                _apiService.lastMutationQueuedOffline;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  queued
                                      ? 'Calificación guardada offline. Se sincronizará automáticamente.'
                                      : 'Calificación registrada correctamente.',
                                ),
                                backgroundColor: queued
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            );
                            if (queued) {
                              setState(() {
                                if (existing != null) {
                                  existing['calificacion'] = parsed;
                                  existing['nivel'] = nivel;
                                  existing['comentario'] = commCtrl.text.trim();
                                } else {
                                  _calificaciones.add({
                                    'alumno_id': uid,
                                    'clase_id': widget.claseId,
                                    'parcial': _parcial,
                                    'calificacion': parsed,
                                    'nivel': nivel,
                                    'comentario': commCtrl.text.trim(),
                                  });
                                }
                              });
                            } else {
                              await _cargar();
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _apiService.lastError ??
                                      'No se pudo guardar la calificación.',
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
                  child: Text(saving ? 'Guardando...' : 'Guardar Calificación'),
                ),
              ),
            ],
          ),
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Calificaciones', style: TextStyle(fontSize: 17)),
              Text(
                '${widget.nombreMateria} · Grupo ${widget.grupo}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [1, 2, 3].map((p) {
                  final active = _parcial == p;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('Parcial $p'),
                        selected: active,
                        selectedColor: AppColors.primaryDark,
                        labelStyle: TextStyle(
                          color: active ? Colors.white : AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => setState(() => _parcial = p),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: _alumnos.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: const [
                                Text(
                                  'No hay alumnos inscritos en esta clase.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: _alumnos.length,
                              itemBuilder: (ctx, i) {
                                final al = _alumnos[i];
                                final uid = al['id']?.toString() ?? '';
                                final cal = _findCalificacion(uid, _parcial);
                                final nota = cal?['calificacion'];
                                final nivel =
                                    (cal?['nivel'] ?? '--').toString();
                                final color = cal != null
                                    ? _nivelColor(nivel)
                                    : Colors.grey;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    onTap: () => _capturarCalificacion(al),
                                    leading: CircleAvatar(
                                      backgroundColor: color.withOpacity(0.15),
                                      child: Text(
                                        nivel,
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      al['nombre']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Matrícula: ${al['matricula'] ?? ''}${cal?['comentario'] != null ? "\n${cal!['comentario']}" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSoftBlue,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        nota != null ? '$nota' : 'Capturar',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
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
}

class KardexAlumnoScreen extends StatefulWidget {
  final String alumnoId;
  final String? nombreAlumno;

  const KardexAlumnoScreen({
    super.key,
    required this.alumnoId,
    this.nombreAlumno,
  });

  @override
  State<KardexAlumnoScreen> createState() => _KardexAlumnoScreenState();
}

class _KardexAlumnoScreenState extends State<KardexAlumnoScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getKardexAlumno(widget.alumnoId);
    if (!mounted) return;
    setState(() {
      _items = list;
      _fromCache = _apiService.lastDataFromCache;
      _isLoading = false;
    });
  }

  Color _nivelColor(String n) {
    switch (n.toUpperCase()) {
      case 'AU':
        return AppColors.successDark;
      case 'DE':
        return AppColors.primary;
      case 'SA':
        return AppColors.accentBlue;
      default:
        return AppColors.dangerRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    double sumNotas = 0;
    int countNotas = 0;

    for (final row in _items) {
      final mat = (row['materia_nombre'] ??
              row['materiaNombre'] ??
              row['materia'] ??
              'Materia')
          .toString();
      grouped.putIfAbsent(mat, () => []).add(row);
      final n = (row['calificacion'] as num?)?.toDouble();
      if (n != null) {
        sumNotas += n;
        countNotas++;
      }
    }

    final promedioGeneral = countNotas > 0 ? (sumNotas / countNotas) : 0.0;

    return SessionWrapper(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('Mi Kárdex Académico'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_fromCache)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoftBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Kárdex disponible offline desde la última sincronización.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(18),
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
                                Text(
                                  widget.nombreAlumno ?? 'Historial Académico',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  countNotas > 0
                                      ? promedioGeneral.toStringAsFixed(2)
                                      : '--',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Promedio general acumulado',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.school,
                            size: 46,
                            color: AppColors.badgeGold,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (grouped.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Aún no hay calificaciones registradas para tu cuenta.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...grouped.entries.map((entry) {
                        final parciales = [...entry.value]..sort((a, b) {
                            final pa = int.tryParse(
                                    a['parcial']?.toString() ?? '0') ??
                                0;
                            final pb = int.tryParse(
                                    b['parcial']?.toString() ?? '0') ??
                                0;
                            return pa.compareTo(pb);
                          });
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: parciales.map((p) {
                                    final numP = p['parcial']?.toString() ?? '';
                                    final nota = p['calificacion'];
                                    final nivel = (p['nivel'] ?? '')
                                        .toString()
                                        .toUpperCase();
                                    final color = _nivelColor(nivel);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: color.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        'P$numP: ${nota ?? ''} ($nivel)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: color,
                                        ),
                                      ),
                                    );
                                  }).toList(),
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
}

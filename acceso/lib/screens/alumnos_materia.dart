import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import 'asistencias_materias_screen.dart';
import 'avisos_profesor_screen.dart';
import 'calificaciones_screens.dart';
import 'detalle_asistencia_alumno_screen.dart';
import 'justificantes_profesor_screen.dart';
import 'prediccion_alumno_screen.dart';
import 'qralumnos.dart';

class AlumnosMateriaScreen extends StatefulWidget {
  final String materiaId; // Representa el claseId en esta vista
  final String materiaNombre;
  final String grupo;
  final String? materiaRealId;

  const AlumnosMateriaScreen({
    super.key,
    required this.materiaId,
    required this.materiaNombre,
    required this.grupo,
    this.materiaRealId,
  });

  @override
  State<AlumnosMateriaScreen> createState() => _AlumnosMateriaScreenState();
}

class _AlumnosMateriaScreenState extends State<AlumnosMateriaScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _alumnos = [];
  List<Map<String, dynamic>> _horarios = [];
  bool _isLoading = true;
  bool _fromCache = false;
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

    final tablaFuture = _apiService.getAsistenciasTabla(widget.materiaId);
    final horariosFuture = _apiService.getHorariosClase(widget.materiaId);

    final tabla = await tablaFuture;
    final fromCache = _apiService.lastDataFromCache;
    final horarios = await horariosFuture;

    final rawAlumnos = List<Map<String, dynamic>>.from(
      tabla['alumnos'] as List? ?? const [],
    );
    final fechas = List<String>.from(tabla['fechas'] as List? ?? const []);
    final asistencias = (tabla['asistencias'] as Map?) ?? const {};

    List<Map<String, dynamic>> procesados = [];

    if (rawAlumnos.isNotEmpty) {
      for (final al in rawAlumnos) {
        final uid = al['id']?.toString() ?? '';
        final mapaFechas = (asistencias[uid] as Map?) ?? const {};
        int presentes = 0;
        int faltas = 0;
        int retardos = 0;
        int justificados = 0;
        int registrados = 0;

        for (final f in fechas) {
          final est = mapaFechas[f]?.toString().toLowerCase();
          if (est == null || est.isEmpty) continue;
          registrados++;
          if (est == 'presente') {
            presentes++;
          } else if (est == 'retardo') {
            retardos++;
          } else if (est == 'justificado' || est == 'justificada') {
            justificados++;
          } else {
            faltas++;
          }
        }
        final pct = registrados > 0
            ? ((presentes + justificados + (retardos * 0.5)) / registrados) *
                100.0
            : 100.0;

        procesados.add({
          'id': uid,
          'nombre': (al['nombre'] ?? 'Sin nombre').toString(),
          'matricula': (al['matricula'] ?? '').toString(),
          'presentes': presentes,
          'faltas': faltas,
          'retardos': retardos,
          'justificados': justificados,
          'porcentaje': pct.clamp(0.0, 100.0),
        });
      }
    } else {
      final fallbackList = await _apiService.getAlumnosConAsistenciaByGrupoYMateria(
        widget.grupo,
        widget.materiaId,
      );
      procesados = fallbackList.map((al) {
        final p = (al['porcentaje'] as num?)?.toDouble() ?? 100.0;
        return {
          'id': (al['id'] ?? al['user_id'] ?? '').toString(),
          'nombre': (al['nombre'] ?? 'Sin nombre').toString(),
          'matricula': (al['matricula'] ?? '').toString(),
          'presentes': (al['presentes'] as num?)?.toInt() ?? 0,
          'faltas': (al['faltas'] as num?)?.toInt() ?? 0,
          'retardos': (al['retardos'] as num?)?.toInt() ?? 0,
          'justificados': (al['justificados'] as num?)?.toInt() ?? 0,
          'porcentaje': p,
        };
      }).toList();
    }

    if (!mounted) return;
    setState(() {
      _alumnos = procesados;
      _horarios = horarios;
      _fromCache = fromCache;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _alumnos;
    return _alumnos.where((al) {
      final n = al['nombre'].toString().toLowerCase();
      final m = al['matricula'].toString().toLowerCase();
      return n.contains(q) || m.contains(q);
    }).toList();
  }

  String _diaNombre(dynamic d) {
    switch (int.tryParse(d?.toString() ?? '') ?? 0) {
      case 1:
        return 'Lun';
      case 2:
        return 'Mar';
      case 3:
        return 'Mié';
      case 4:
        return 'Jue';
      case 5:
        return 'Vie';
      case 6:
        return 'Sáb';
      case 7:
        return 'Dom';
      default:
        return 'Día';
    }
  }

  Color _pctColor(double pct) {
    if (pct >= 85) return AppColors.success;
    if (pct >= 75) return AppColors.warning;
    return AppColors.dangerRed;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtrados;
    final profId = SessionService().userId ?? '';

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
                widget.materiaNombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16.5),
              ),
              Text(
                'Grupo ${widget.grupo} · ${_alumnos.length} alumnos',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'QR de clase',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClaseQrScreen(
                      claseId: widget.materiaId,
                      nombreMateria: widget.materiaNombre,
                      grupo: widget.grupo,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Tabla completa',
              icon: const Icon(Icons.table_chart_outlined),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AsistenciasMateriasScreen(
                      claseId: widget.materiaId,
                      nombreMateria: widget.materiaNombre,
                      grupo: widget.grupo,
                    ),
                  ),
                );
                _cargar();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_fromCache)
              Container(
                width: double.infinity,
                color: AppColors.surfaceSoftBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: const Text(
                  'Mostrando datos guardados en caché offline.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickAction(
                          icon: Icons.qr_code_2,
                          label: 'Pase QR Clase',
                          color: AppColors.primaryDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClaseQrScreen(
                                claseId: widget.materiaId,
                                nombreMateria: widget.materiaNombre,
                                grupo: widget.grupo,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _quickAction(
                          icon: Icons.fact_check_outlined,
                          label: 'Tabla & Excel',
                          color: AppColors.primary,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AsistenciasMateriasScreen(
                                  claseId: widget.materiaId,
                                  nombreMateria: widget.materiaNombre,
                                  grupo: widget.grupo,
                                ),
                              ),
                            );
                            _cargar();
                          },
                        ),
                        const SizedBox(width: 8),
                        _quickAction(
                          icon: Icons.grade_outlined,
                          label: 'Calificaciones',
                          color: AppColors.accentBlue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CalificacionesClaseScreen(
                                claseId: widget.materiaId,
                                nombreMateria: widget.materiaNombre,
                                grupo: widget.grupo,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _quickAction(
                          icon: Icons.assignment_turned_in_outlined,
                          label: 'Justificantes',
                          color: AppColors.successDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JustificantesProfesorScreen(
                                profesorId: profId,
                                materiaNombre: widget.materiaNombre,
                                grupo: widget.grupo,
                                claseId: widget.materiaId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _quickAction(
                          icon: Icons.campaign_outlined,
                          label: 'Avisos',
                          color: AppColors.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AvisosProfesorScreen(
                                profesorId: profId,
                                nombreProfesor: SessionService().nombre,
                                materiaId: widget.materiaRealId,
                                claseId: widget.materiaId,
                                materiaNombre: widget.materiaNombre,
                                grupo: widget.grupo,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_horarios.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _horarios.map((h) {
                          final dia = _diaNombre(h['dia_semana'] ?? h['diaSemana']);
                          final hi = (h['hora_inicio'] ?? h['horaInicio'] ?? '').toString();
                          final hf = (h['hora_fin'] ?? h['horaFin'] ?? '').toString();
                          final salon = (h['salon_nombre'] ?? h['salon'] ?? '').toString();
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoftBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$dia $hi-$hf${salon.isNotEmpty ? " · $salon" : ""}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o matrícula...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _search = v),
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
                                  Icons.person_search_outlined,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No se encontraron alumnos en este grupo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: items.length,
                              itemBuilder: (ctx, i) => _buildAlumnoCard(items[i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildAlumnoCard(Map<String, dynamic> al) {
    final uid = al['id']?.toString() ?? '';
    final nombre = al['nombre']?.toString() ?? '';
    final matricula = al['matricula']?.toString() ?? '';
    final pct = (al['porcentaje'] as num?)?.toDouble() ?? 100.0;
    final pColor = _pctColor(pct);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryDark,
          child: Text(
            nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          nombre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (matricula.isNotEmpty)
                Text(
                  'Matrícula: $matricula',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _miniStat('P: ${al['presentes']}', AppColors.successDark),
                  const SizedBox(width: 8),
                  _miniStat('F: ${al['faltas']}', AppColors.dangerRed),
                  const SizedBox(width: 8),
                  _miniStat('J: ${al['justificados']}', AppColors.accentBlue),
                ],
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: pColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pColor,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Análisis predictivo',
              icon: const Icon(Icons.analytics_outlined, color: AppColors.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrediccionAlumnoScreen(
                      alumnoId: uid,
                      nombreAlumno: nombre,
                      matricula: matricula,
                      claseId: widget.materiaId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleAsistenciaAlumnoScreen(
                userId: uid,
                alumnoNombre: nombre,
                materiaId: widget.materiaId,
                materiaNombre: widget.materiaNombre,
                grupo: widget.grupo,
              ),
            ),
          );
          _cargar();
        },
      ),
    );
  }

  Widget _miniStat(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}

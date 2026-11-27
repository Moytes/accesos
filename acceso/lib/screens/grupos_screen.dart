import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_wrapper.dart';
import '../theme/app_colors.dart';
import 'alumnos_materia.dart';
import 'asistencias_materias_screen.dart';
import 'calificaciones_screens.dart';
import 'qralumnos.dart';

class GruposScreen extends StatefulWidget {
  final String materiaId;
  final String materiaNombre;

  const GruposScreen({
    super.key,
    required this.materiaId,
    required this.materiaNombre,
  });

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _grupos = [];
  bool _isLoading = true;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _cargarGrupos();
  }

  Future<void> _cargarGrupos() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getGruposByMateria(widget.materiaId);
    if (!mounted) return;
    setState(() {
      _grupos = list;
      _fromCache = _apiService.lastDataFromCache;
      _isLoading = false;
    });
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
              const Text('Grupos asignados', style: TextStyle(fontSize: 17)),
              Text(
                widget.materiaNombre,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarGrupos,
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
                  'Grupos cargados desde memoria offline.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargarGrupos,
                      child: _grupos.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: [
                                Icon(
                                  Icons.groups_outlined,
                                  size: 62,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No tienes grupos vinculados a esta materia.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: _grupos.length,
                              itemBuilder: (context, index) {
                                final item = _grupos[index];
                                final claseId =
                                    (item['clase_id'] ?? item['id'] ?? '')
                                        .toString();
                                final grupo =
                                    (item['grupo'] ?? item['nombre'] ?? 'Sin grupo')
                                        .toString();
                                final totalAlumnos =
                                    item['total_alumnos']?.toString();
                                final periodo = item['periodo']?.toString();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  color: Colors.white,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AlumnosMateriaScreen(
                                            materiaId: claseId,
                                            materiaNombre: widget.materiaNombre,
                                            grupo: grupo,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(15),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.groups,
                                                  color: AppColors.primaryDark,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Grupo $grupo',
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .primaryDark,
                                                      ),
                                                    ),
                                                    Text(
                                                      [
                                                        if (totalAlumnos !=
                                                            null)
                                                          '$totalAlumnos alumnos',
                                                        if (periodo != null &&
                                                            periodo.isNotEmpty)
                                                          periodo,
                                                      ].join(' · '),
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                Icons.chevron_right,
                                                color: AppColors.primaryDark,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              _actionPill(
                                                icon: Icons.qr_code_2,
                                                label: 'Pase QR',
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ClaseQrScreen(
                                                      claseId: claseId,
                                                      nombreMateria:
                                                          widget.materiaNombre,
                                                      grupo: grupo,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _actionPill(
                                                icon: Icons.table_chart_outlined,
                                                label: 'Asistencias',
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        AsistenciasMateriasScreen(
                                                      claseId: claseId,
                                                      nombreMateria:
                                                          widget.materiaNombre,
                                                      grupo: grupo,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _actionPill(
                                                icon: Icons.grade_outlined,
                                                label: 'Calificaciones',
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        CalificacionesClaseScreen(
                                                      claseId: claseId,
                                                      nombreMateria:
                                                          widget.materiaNombre,
                                                      grupo: grupo,
                                                    ),
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
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primaryDark),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
      backgroundColor: AppColors.surfaceSoftBlue,
      side: BorderSide(color: AppColors.primary.withOpacity(0.18)),
      onPressed: onTap,
    );
  }
}

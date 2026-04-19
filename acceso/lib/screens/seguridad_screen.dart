import 'dart:async';
import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/session_service.dart';
import '../service/session_wrapper.dart';
import 'profile_screen.dart';
import 'qralumnos.dart';

class SeguridadScreen extends StatefulWidget {
  final String userId;
  final String? nombre;

  const SeguridadScreen({Key? key, required this.userId, this.nombre})
      : super(key: key);

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final SessionService _sessionService = SessionService();

  List<Map<String, dynamic>> _salones = [];
  bool _isLoading = true;
  bool _isLoggingOut = false;
  int _pisoActual = 1; // 1 o 2
  Timer? _refreshTimer;
  late AnimationController _pulseController;

  int get _ocupados =>
      _salones.where((s) => s['piso'] == _pisoActual && s['ocupado'] == true).length;
  int get _libres =>
      _salones.where((s) => s['piso'] == _pisoActual && s['ocupado'] == false).length;
  List<Map<String, dynamic>> get _salonesPiso =>
      _salones.where((s) => s['piso'] == _pisoActual).toList();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _cargarSalones();
    // Auto-refresco cada 30 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cargarSalones(silencioso: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _sessionService.endSession();
    super.dispose();
  }

  Future<void> _cargarSalones({bool silencioso = false}) async {
    if (!silencioso) setState(() => _isLoading = true);
    final salones = await _apiService.getSalonesConEstado();
    if (mounted) {
      setState(() {
        _salones = salones;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('¿Cerrar sesión?',
            style: TextStyle(
                color: Color(0xFF1A3A5C), fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A5C)),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isLoggingOut = true);
      await _apiService.logout(widget.userId);
      _sessionService.endSession();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/', (r) => false);
      }
    }
  }

  void _mostrarDetalleSalon(Map<String, dynamic> salon) {
    final ocupado = salon['ocupado'] as bool;
    final res = salon['reservacion'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SalonDetalleSheet(
        salon: salon,
        ocupado: ocupado,
        reservacion: res,
        onLiberar: ocupado && res != null
            ? () async {
                Navigator.pop(context);
                await _apiService.liberarSalon(res['id']);
                _cargarSalones();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Column(children: [
          _buildHeader(),
          _buildPisoSelector(),
          _buildLeyenda(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
                : RefreshIndicator(
                    onRefresh: () => _cargarSalones(),
                    color: const Color(0xFF4FC3F7),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(children: [
                        _buildCroquis(),
                        const SizedBox(height: 20),
                        _buildListaSalones(),
                      ]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    final meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final fechaStr =
        '${now.day} ${meses[now.month - 1]} ${now.year}  •  ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF1A3A5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CONTROL+',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF4FC3F7)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SEGURIDAD',
                          style: TextStyle(
                              color: Color(0xFF4FC3F7),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                    ),
                  ]),
                ]),
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.account_circle,
                        color: Colors.white70, size: 28),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfileScreen(
                                userId: widget.userId,
                                nombre: widget.nombre))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code,
                        color: Colors.white70, size: 26),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => QRScreen(userId: widget.userId))),
                    tooltip: 'Mi QR',
                  ),
                  IconButton(
                    onPressed: _isLoggingOut ? null : _handleLogout,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.logout,
                            color: Colors.white70, size: 26),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 14),
            // Bienvenida + fecha
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Hola, ${_primerNombre(widget.nombre)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(fechaStr,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ]),
              ),
              // Stats rápidas
              Row(children: [
                _buildStatChip(_ocupados.toString(), 'Ocupados',
                    const Color(0xFFEF5350)),
                const SizedBox(width: 8),
                _buildStatChip(_libres.toString(), 'Libres',
                    const Color(0xFF66BB6A)),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatChip(String num, String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(children: [
          Text(num,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
        ]),
      );

  // ── SELECTOR DE PISO ───────────────────────────────────────
  Widget _buildPisoSelector() => Container(
        color: const Color(0xFF0D1B2A),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          _buildPisoBtn(1),
          const SizedBox(width: 10),
          _buildPisoBtn(2),
          const Spacer(),
          GestureDetector(
            onTap: () => _cargarSalones(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh,
                  color: Color(0xFF4FC3F7), size: 20),
            ),
          ),
        ]),
      );

  Widget _buildPisoBtn(int piso) {
    final active = _pisoActual == piso;
    return GestureDetector(
      onTap: () => setState(() => _pisoActual = piso),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4FC3F7)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? const Color(0xFF4FC3F7)
                  : Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          'Piso $piso',
          style: TextStyle(
              color: active ? const Color(0xFF0D1B2A) : Colors.white60,
              fontWeight:
                  active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13),
        ),
      ),
    );
  }

  // ── LEYENDA ────────────────────────────────────────────────
  Widget _buildLeyenda() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          _legendItem(const Color(0xFFEF5350), 'Ocupado'),
          const SizedBox(width: 16),
          _legendItem(const Color(0xFF66BB6A), 'Libre'),
          const SizedBox(width: 16),
          _legendItem(const Color(0xFF42A5F5), 'Lab / Sala'),
        ]),
      );

  Widget _legendItem(Color color, String label) => Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ]);

  // ── CROQUIS ────────────────────────────────────────────────
  Widget _buildCroquis() {
    final salonesPiso = _salonesPiso;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(children: [
        // Título del croquis
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Icon(Icons.maps_home_work_outlined,
                color: Color(0xFF4FC3F7), size: 18),
            const SizedBox(width: 8),
            Text('Edificio Principal — Piso $_pisoActual',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const Spacer(),
            Text('${salonesPiso.length} salones',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ]),
        ),
        const Divider(color: Colors.white12, height: 1),
        // Plano
        Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(builder: (ctx, constraints) {
            final W = constraints.maxWidth;
            const H = 280.0;
            return SizedBox(
              width: W,
              height: H,
              child: Stack(
                children: [
                  // Fondo del edificio
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2137),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: CustomPaint(
                        painter: _GridPainter(),
                      ),
                    ),
                  ),
                  // Pasillo central
                  Positioned(
                    left: W * 0.0,
                    top: H * 0.285,
                    child: Container(
                      width: W,
                      height: H * 0.11,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                      ),
                      child: Center(
                        child: Text(
                          '— PASILLO —',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              fontSize: 10,
                              letterSpacing: 2),
                        ),
                      ),
                    ),
                  ),
                  // Salones
                  ...salonesPiso.map((salon) {
                    final x = (salon['pos_x'] as num?)?.toDouble() ?? 0;
                    final y = (salon['pos_y'] as num?)?.toDouble() ?? 0;
                    final w = (salon['ancho'] as num?)?.toDouble() ?? 15;
                    final h = (salon['alto'] as num?)?.toDouble() ?? 12;
                    final ocupado = salon['ocupado'] as bool;
                    final tipo = salon['tipo'] as String? ?? 'aula';
                    final numero = salon['numero'] as String;

                    return Positioned(
                      left: W * x / 100,
                      top: H * y / 100,
                      width: W * w / 100,
                      height: H * h / 100,
                      child: GestureDetector(
                        onTap: () => _mostrarDetalleSalon(salon),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) {
                            final pulse =
                                ocupado ? _pulseController.value : 0.0;
                            return Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: ocupado
                                    ? Color.lerp(
                                        const Color(0xFFB71C1C),
                                        const Color(0xFFEF5350),
                                        pulse)!
                                        .withOpacity(0.85)
                                    : tipo == 'laboratorio' ||
                                            tipo == 'sala'
                                        ? const Color(0xFF1565C0)
                                            .withOpacity(0.75)
                                        : const Color(0xFF1B5E20)
                                            .withOpacity(0.75),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: ocupado
                                      ? const Color(0xFFFF5252)
                                      : tipo == 'laboratorio' ||
                                              tipo == 'sala'
                                          ? const Color(0xFF42A5F5)
                                          : const Color(0xFF66BB6A),
                                  width: 1.2,
                                ),
                                boxShadow: ocupado
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFEF5350)
                                              .withOpacity(
                                                  0.3 + pulse * 0.3),
                                          blurRadius: 8 + pulse * 6,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(numero,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  if (ocupado)
                                    Icon(Icons.person,
                                        color: Colors.white70,
                                        size: 11),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }),
        ),
      ]),
    );
  }

  // ── LISTA DE SALONES ───────────────────────────────────────
  Widget _buildListaSalones() {
    final ocupados =
        _salonesPiso.where((s) => s['ocupado'] == true).toList();
    final libres =
        _salonesPiso.where((s) => s['ocupado'] == false).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ocupados.isNotEmpty) ...[
          _buildListHeader('🔴  Ocupados', const Color(0xFFEF5350)),
          const SizedBox(height: 8),
          ...ocupados.map((s) => _buildSalonTile(s)),
          const SizedBox(height: 16),
        ],
        if (libres.isNotEmpty) ...[
          _buildListHeader('🟢  Disponibles', const Color(0xFF66BB6A)),
          const SizedBox(height: 8),
          ...libres.map((s) => _buildSalonTile(s)),
        ],
      ],
    );
  }

  Widget _buildListHeader(String text, Color color) => Text(text,
      style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));

  Widget _buildSalonTile(Map<String, dynamic> salon) {
    final ocupado = salon['ocupado'] as bool;
    final numero = salon['numero'] as String;
    final nombre = salon['nombre'] as String? ?? '';
    final tipo = salon['tipo'] as String? ?? 'aula';
    final res = salon['reservacion'] as Map<String, dynamic>?;
    final capacidad = salon['capacidad'] as int? ?? 0;

    final color = ocupado
        ? const Color(0xFFEF5350)
        : tipo == 'laboratorio' || tipo == 'sala'
            ? const Color(0xFF42A5F5)
            : const Color(0xFF66BB6A);

    return GestureDetector(
      onTap: () => _mostrarDetalleSalon(salon),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(numero,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre.isNotEmpty ? nombre : 'Salón $numero',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  if (ocupado && res != null)
                    Text(
                      '${res['nombre_profesor']} • ${res['materia']}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      '${_labelTipo(tipo)} • Cap. $capacidad',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ocupado ? 'Ocupado' : 'Libre',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ]),
      ),
    );
  }

  String _primerNombre(String? nombre) {
    if (nombre == null || nombre.isEmpty) return 'Seguridad';
    return nombre.split(' ').first;
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'laboratorio': return 'Laboratorio';
      case 'sala': return 'Sala';
      default: return 'Aula';
    }
  }
}

// ── Painter para la cuadrícula del croquis ────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.5;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Bottom Sheet de detalle ────────────────────────────────
class _SalonDetalleSheet extends StatelessWidget {
  final Map<String, dynamic> salon;
  final bool ocupado;
  final Map<String, dynamic>? reservacion;
  final VoidCallback? onLiberar;

  const _SalonDetalleSheet({
    required this.salon,
    required this.ocupado,
    this.reservacion,
    this.onLiberar,
  });

  @override
  Widget build(BuildContext context) {
    final numero = salon['numero'] as String;
    final nombre = salon['nombre'] as String? ?? '';
    final tipo = salon['tipo'] as String? ?? 'aula';
    final capacidad = salon['capacidad'] as int? ?? 0;
    final piso = salon['piso'] as int? ?? 1;

    final color =
        ocupado ? const Color(0xFFEF5350) : const Color(0xFF66BB6A);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 20),
        // Cabecera
        Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(numero,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre.isNotEmpty ? nombre : 'Salón $numero',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(
                    'Piso $piso  •  ${_labelTipo(tipo)}  •  Cap. $capacidad',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                  ),
                ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              ocupado ? 'OCUPADO' : 'LIBRE',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        if (ocupado && reservacion != null) ...[
          const Divider(color: Colors.white12),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.person_outline, 'Profesor',
              reservacion!['nombre_profesor'] ?? '-'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.badge_outlined, 'No. Empleado',
              reservacion!['numero_empleado'] ?? '-'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.school_outlined, 'Materia',
              reservacion!['materia'] ?? '-'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.description_outlined, 'Motivo',
              reservacion!['motivo'] ?? '-'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.access_time_outlined, 'Desde',
              _formatDateTime(reservacion!['fecha_hora'])),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLiberar,
              icon: const Icon(Icons.lock_open_outlined,
                  color: Colors.white),
              label: const Text('Liberar salón',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ] else ...[
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF66BB6A), size: 28),
            const SizedBox(width: 8),
            const Text('Salón disponible',
                style: TextStyle(
                    color: Color(0xFF66BB6A),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Colors.white38, size: 18),
      const SizedBox(width: 10),
      SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 13))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
    ],
  );

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'laboratorio': return 'Laboratorio';
      case 'sala': return 'Sala';
      default: return 'Aula';
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year}  $h:$m';
    } catch (_) {
      return iso;
    }
  }
}
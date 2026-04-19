import 'package:flutter/material.dart';
import '../service/api_service.dart';

class PedirSalonScreen extends StatefulWidget {
  final String profesorId;
  final String nombreProfesor;
  final String? numeroEmpleado; // Se puede pasar desde el perfil

  const PedirSalonScreen({
    Key? key,
    required this.profesorId,
    required this.nombreProfesor,
    this.numeroEmpleado,
  }) : super(key: key);

  @override
  State<PedirSalonScreen> createState() => _PedirSalonScreenState();
}

class _PedirSalonScreenState extends State<PedirSalonScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _numEmpleadoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();

  List<Map<String, dynamic>> _salonesLibres = [];
  List<Map<String, dynamic>> _misReservaciones = [];
  String? _salonSeleccionadoId;
  String? _materiaSeleccionada;
  List<Map<String, dynamic>> _materias = [];

  bool _loadingSalones = true;
  bool _loadingMaterias = true;
  bool _submitting = false;
  bool _liberando = false;

  @override
  void initState() {
    super.initState();
    if (widget.numeroEmpleado != null) {
      _numEmpleadoCtrl.text = widget.numeroEmpleado!;
    }
    _cargarDatos();
  }

  @override
  void dispose() {
    _numEmpleadoCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await Future.wait([
      _cargarSalones(),
      _cargarMaterias(),
      _cargarMisReservaciones(),
    ]);
  }

  Future<void> _cargarSalones() async {
    setState(() => _loadingSalones = true);
    final salones = await _apiService.getSalonesLibres();
    if (mounted) {
      setState(() {
        _salonesLibres = salones;
        _loadingSalones = false;
      });
    }
  }

  Future<void> _cargarMaterias() async {
    setState(() => _loadingMaterias = true);
    final materias = await _apiService.getMateriasByProfesor(widget.profesorId);
    if (mounted) {
      setState(() {
        _materias = materias;
        _loadingMaterias = false;
      });
    }
  }

  Future<void> _cargarMisReservaciones() async {
    final res = await _apiService.getReservacionesActivasProfesor(widget.profesorId);
    if (mounted) setState(() => _misReservaciones = res);
  }

  Future<void> _reservar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_salonSeleccionadoId == null) {
      _snack('Selecciona un salón disponible', isError: true);
      return;
    }
    if (_materiaSeleccionada == null) {
      _snack('Selecciona la materia', isError: true);
      return;
    }

    setState(() => _submitting = true);

    final resultado = await _apiService.reservarSalon(
      salonId: _salonSeleccionadoId!,
      profesorId: widget.profesorId,
      numeroEmpleado: _numEmpleadoCtrl.text.trim(),
      nombreProfesor: widget.nombreProfesor,
      materia: _materiaSeleccionada!,
      motivo: _motivoCtrl.text.trim(),
    );

    setState(() => _submitting = false);

    if (!mounted) return;

    if (resultado['success'] == true) {
      _mostrarExito(
        resultado['salon_numero'] ?? '',
        resultado['salon_nombre'] ?? '',
        resultado['reservacion_id']?.toString(),
      );
    } else {
      _snack(resultado['message'] ?? 'Error al reservar', isError: true);
    }
  }

  Future<void> _liberarReservacion(String reservacionId, String salonNumero) async {
    setState(() => _liberando = true);
    
    final ok = await _apiService.liberarSalon(reservacionId);
    
    setState(() => _liberando = false);
    
    if (ok && mounted) {
      _snack('Salón $salonNumero liberado exitosamente');
      await _cargarDatos();
      
      // Limpiar selección si el salón liberado era el seleccionado
      if (_salonSeleccionadoId != null) {
        final salonLiberado = _misReservaciones.firstWhere(
          (r) => r['id'].toString() == reservacionId,
          orElse: () => {},
        );
        if (salonLiberado.isNotEmpty) {
          setState(() {
            _salonSeleccionadoId = null;
          });
        }
      }
    } else if (mounted) {
      _snack('Error al liberar el salón', isError: true);
    }
  }

  void _mostrarExito(String numero, String nombre, String? reservacionId) {
    final hora = TimeOfDay.now().format(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Icon(Icons.meeting_room_outlined,
                color: Color(0xFF1B7A3E), size: 48),
          ),
          const SizedBox(height: 16),
          const Text('¡Salón asignado!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004C8C))),
          const SizedBox(height: 8),
          Text('Salón $numero — $nombre',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Registrado a las $hora',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFC107))),
            child: const Text(
              'Recuerda liberar el salón cuando termines.',
              style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
        actions: [
          Column(
            children: [
              // Botón Desocupar (nuevo)
              if (reservacionId != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context); // Cerrar diálogo de éxito
                      
                      // Mostrar confirmación
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          title: const Text('¿Desocupar salón?',
                              style: TextStyle(
                                  color: Color(0xFF004C8C),
                                  fontWeight: FontWeight.bold)),
                          content: Text(
                              '¿Confirmas que ya no necesitas el salón $numero?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Desocupar',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true && mounted) {
                        await _liberarReservacion(reservacionId, numero);
                      }
                      
                      // Limpiar formulario
                      setState(() {
                        _salonSeleccionadoId = null;
                        _materiaSeleccionada = null;
                        _motivoCtrl.clear();
                      });
                      await _cargarDatos();
                    },
                    icon: const Icon(Icons.exit_to_app, color: Colors.white),
                    label: const Text('DESOCUPAR SALÓN AHORA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (reservacionId != null) const SizedBox(height: 8),
              // Botón Aceptar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Limpiar formulario
                    _salonSeleccionadoId = null;
                    _materiaSeleccionada = null;
                    _motivoCtrl.clear();
                    _cargarDatos();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004C8C),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Aceptar',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : Colors.green[700],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004C8C),
        foregroundColor: Colors.white,
        title: const Text('Solicitar Salón',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFF004C8C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Mis reservaciones activas ──
                if (_misReservaciones.isNotEmpty) ...[
                  _buildSectionTitle(
                      Icons.meeting_room, 'Mis salones activos'),
                  const SizedBox(height: 10),
                  ..._misReservaciones.map((r) {
                    final salon = r['salones'] as Map<String, dynamic>?;
                    final numero = salon?['numero'] ?? '?';
                    final nombre = salon?['nombre'] ?? '';
                    final hora = _formatHora(r['fecha_hora']);
                    final reservacionId = r['id'].toString();
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF004C8C).withOpacity(0.1),
                          child: Text(numero,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004C8C),
                                  fontSize: 13)),
                        ),
                        title: Text(nombre.isNotEmpty ? nombre : 'Salón $numero',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                            '${r['materia']} • desde $hora',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        trailing: _liberando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.red))
                            : ElevatedButton.icon(
                                onPressed: () => _liberarReservacion(reservacionId, numero),
                                icon: const Icon(Icons.exit_to_app, size: 16),
                                label: const Text('Desocupar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                ],

                // ── Formulario ──
                _buildSectionTitle(
                    Icons.edit_note_outlined, 'Nueva solicitud'),
                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Card 1: datos del profesor
                      _buildCard(children: [
                        _buildTextField(
                          controller: _numEmpleadoCtrl,
                          label: 'Número de empleado *',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        // Nombre (no editable, viene del login)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[100],
                          ),
                          child: Row(children: [
                            Icon(Icons.person_outline,
                                color: Colors.grey[500], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(widget.nombreProfesor,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF004C8C),
                                      fontWeight: FontWeight.w500)),
                            ),
                            Icon(Icons.lock_outline,
                                color: Colors.grey[400], size: 16),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Card 2: materia
                      _buildCard(children: [
                        _buildSectionLabel('Materia *'),
                        const SizedBox(height: 10),
                        _loadingMaterias
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF004C8C)))
                            : _materias.isEmpty
                                ? _buildEmptyHint(
                                    'No tienes materias asignadas')
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _materias.map((m) {
                                      final nombre =
                                          m['nom_mat'] as String? ??
                                              m['nombre'] as String? ??
                                              'Sin nombre';
                                      final selected =
                                          _materiaSeleccionada == nombre;
                                      return GestureDetector(
                                        onTap: () => setState(
                                            () => _materiaSeleccionada =
                                                nombre),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? const Color(0xFF004C8C)
                                                : Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: selected
                                                  ? const Color(0xFF004C8C)
                                                  : Colors.grey[300]!,
                                            ),
                                          ),
                                          child: Text(nombre,
                                              style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : Colors.grey[700],
                                                  fontSize: 13,
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal)),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ]),
                      const SizedBox(height: 16),

                      // Card 3: motivo
                      _buildCard(children: [
                        _buildTextField(
                          controller: _motivoCtrl,
                          label: 'Motivo / Para qué ocupa el salón *',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Describe para qué necesitas el salón'
                                  : null,
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Card 4: salones disponibles
                      _buildCard(children: [
                        _buildSectionLabel('Salón disponible *'),
                        const SizedBox(height: 4),
                        Text(
                          'Solo se muestran salones libres ahora mismo',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 12),
                        _loadingSalones
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF004C8C)))
                            : _salonesLibres.isEmpty
                                ? _buildEmptyHint(
                                    'No hay salones disponibles en este momento')
                                : Column(
                                    children: _salonesLibres.map((s) {
                                      final id = s['id'] as String;
                                      final numero = s['numero'] as String;
                                      final nombre =
                                          s['nombre'] as String? ?? '';
                                      final capacidad =
                                          s['capacidad'] as int? ?? 0;
                                      final tipo = s['tipo'] as String? ??
                                          'aula';
                                      final piso = s['piso'] as int? ?? 1;
                                      final selected =
                                          _salonSeleccionadoId == id;

                                      return GestureDetector(
                                        onTap: () => setState(
                                            () => _salonSeleccionadoId = id),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          margin: const EdgeInsets.only(
                                              bottom: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? const Color(0xFF004C8C)
                                                : Colors.grey[50],
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: selected
                                                  ? const Color(0xFF004C8C)
                                                  : Colors.grey[200]!,
                                              width: selected ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? Colors.white
                                                        .withOpacity(0.2)
                                                    : const Color(0xFF004C8C)
                                                        .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(numero,
                                                    style: TextStyle(
                                                        color: selected
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF004C8C),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14)),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    nombre.isNotEmpty
                                                        ? nombre
                                                        : 'Salón $numero',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                        color: selected
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF1A1A2E)),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Piso $piso  •  Cap. $capacidad  •  ${_labelTipo(tipo)}',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: selected
                                                            ? Colors.white70
                                                            : Colors
                                                                .grey[500]),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (selected)
                                              const Icon(Icons.check_circle,
                                                  color: Colors.white,
                                                  size: 22),
                                          ]),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ]),

                      const SizedBox(height: 24),

                      // Botón reservar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _reservar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004C8C),
                            disabledBackgroundColor:
                                const Color(0xFF004C8C).withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.meeting_room_outlined,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 10),
                                    Text('Solicitar salón',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── helpers de UI ──────────────────────────────────────────

  Widget _buildSectionTitle(IconData icon, String title) => Row(children: [
        Icon(icon, color: const Color(0xFF004C8C), size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF004C8C))),
      ]);

  Widget _buildSectionLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF004C8C)));

  Widget _buildCard({required List<Widget> children}) => Card(
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children)),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              Icon(icon, color: const Color(0xFF004C8C), size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide:
                  BorderSide(color: Color(0xFF004C8C), width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          filled: true,
          fillColor: Colors.grey[50],
          labelStyle:
              TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      );

  Widget _buildEmptyHint(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(msg,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ),
      );

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'laboratorio':
        return 'Laboratorio';
      case 'sala':
        return 'Sala';
      default:
        return 'Aula';
    }
  }

  String _formatHora(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}
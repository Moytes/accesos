import 'package:flutter/material.dart';
import '../service/api_service.dart';


class RegistrarVisitaScreen extends StatefulWidget {
  final String adminId;

  const RegistrarVisitaScreen({
    Key? key,
    required this.adminId,
  }) : super(key: key);

  @override
  State<RegistrarVisitaScreen> createState() => _RegistrarVisitaScreenState();
}

class _RegistrarVisitaScreenState extends State<RegistrarVisitaScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _empresaController = TextEditingController();
  final TextEditingController _cargoController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();
  final TextEditingController _contactoInternoController =
      TextEditingController();

  DateTime? _fechaVisita;
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _empresaController.dispose();
    _cargoController.dispose();
    _motivoController.dispose();
    _contactoInternoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es', 'MX'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF003366),
              onPrimary: Colors.white,
              onSurface: Color(0xFF003366),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaVisita = picked;
      });
    }
  }

  String _formatFecha(DateTime fecha) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final days = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ];
    return '${days[fecha.weekday - 1]}, ${fecha.day} de ${months[fecha.month - 1]} de ${fecha.year}';
  }

  Future<void> _registrarVisita() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaVisita == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona la fecha de visita'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resultado = await _apiService.registrarVisita(
        nombre: _nombreController.text.trim(),
        correo: _correoController.text.trim(),
        empresa: _empresaController.text.trim(),
        cargo: _cargoController.text.trim(),
        motivo: _motivoController.text.trim(),
        contactoInterno: _contactoInternoController.text.trim(),
        fechaVisita: _fechaVisita!,
        registradoPor: widget.adminId,
      );

      if (mounted) {
        if (resultado['success'] == true) {
          _mostrarDialogoExito(resultado);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message'] ?? 'Error al registrar visita'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarDialogoExito(Map<String, dynamic> resultado) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF1B7A3E),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Visita registrada!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Se ha enviado un correo a ${resultado['correo']} con el código QR de acceso.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFC107)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule,
                      size: 16, color: Color(0xFF856404)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'El QR se activará el día de la visita',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF856404),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Aceptar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        title: const Text(
          'Registrar Visita',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner superior
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              color: const Color(0xFF003366),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.business_center_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nueva visita empresarial',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'El visitante recibirá un QR por correo',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Datos del visitante ──
                    _buildSectionTitle(
                        Icons.person_outline, 'Datos del visitante'),
                    const SizedBox(height: 12),

                    _buildCard(children: [
                      _buildTextField(
                        controller: _nombreController,
                        label: 'Nombre completo *',
                        icon: Icons.badge_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es requerido'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _correoController,
                        label: 'Correo electrónico *',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El correo es requerido';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                              .hasMatch(v.trim())) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Datos de la empresa ──
                    _buildSectionTitle(
                        Icons.business_outlined, 'Datos de la empresa'),
                    const SizedBox(height: 12),

                    _buildCard(children: [
                      _buildTextField(
                        controller: _empresaController,
                        label: 'Empresa / Institución *',
                        icon: Icons.apartment_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'La empresa es requerida'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _cargoController,
                        label: 'Cargo o puesto',
                        icon: Icons.work_outline,
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Detalles de la visita ──
                    _buildSectionTitle(
                        Icons.calendar_today_outlined, 'Detalles de la visita'),
                    const SizedBox(height: 12),

                    _buildCard(children: [
                      // Selector de fecha
                      GestureDetector(
                        onTap: _seleccionarFecha,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _fechaVisita != null
                                  ? const Color(0xFF003366)
                                  : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: _fechaVisita != null
                                ? const Color(0xFFE8EFF7)
                                : Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_outlined,
                                color: _fechaVisita != null
                                    ? const Color(0xFF003366)
                                    : Colors.grey[500],
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _fechaVisita != null
                                      ? _formatFecha(_fechaVisita!)
                                      : 'Seleccionar fecha de visita *',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _fechaVisita != null
                                        ? const Color(0xFF003366)
                                        : Colors.grey[500],
                                    fontWeight: _fechaVisita != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _motivoController,
                        label: 'Motivo de la visita *',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El motivo es requerido'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _contactoInternoController,
                        label: 'Persona a visitar (nombre interno)',
                        icon: Icons.record_voice_over_outlined,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Nota informativa
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF90CAF9)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFF1565C0), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'El visitante recibirá un correo con su QR de acceso. Este código se activará únicamente el día seleccionado y tendrá validez de 24 horas.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[800],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón de registro
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _registrarVisita,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          disabledBackgroundColor:
                              const Color(0xFF003366).withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_outlined,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Registrar y enviar QR',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF003366), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003366),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF003366), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFF003366), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        filled: true,
        fillColor: Colors.grey[50],
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
    );
  }
}
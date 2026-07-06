import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../providers/order_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final _dniController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  bool _obscurePassword = true;
  String _selectedRole = 'repartidor'; // 'repartidor' or 'cliente'
  String _selectedVehicle = 'Moto'; // 'Moto' or 'Auto'

  // Paleta de colores local limpia y segura
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _dniController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  String getInitials(String fullName) {
    if (fullName.trim().isEmpty) return '?';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<OrderProvider>(context, listen: false);
    try {
      final fullName = _nameController.text.trim();
      final role = _selectedRole;
      final avatarUrl = role == 'repartidor'
          ? 'assets/repartidor.png'
          : 'assets/cliente.png';

      await provider.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        fullName,
        role,
        avatarUrl,
        dni: role == 'cliente' ? _dniController.text.trim() : null,
        direccion: role == 'cliente' ? _addressController.text.trim() : null,
        celular: role == 'cliente' ? _phoneController.text.trim() : null,
        tipoVehiculo: role == 'repartidor' ? _selectedVehicle : null,
        matricula: role == 'repartidor' ? _plateController.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada! Por favor inicia sesión.'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: slate800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white10),
            ),
            title: Text(
              'Ocurrió un error',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            content: Text(
              e.toString().replaceAll('Exception:', '').trim(),
              style: GoogleFonts.openSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Entendido',
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  // Helper para las etiquetas arriba de los inputs
  Widget _buildFieldLabel(String labelText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        labelText,
        style: GoogleFonts.outfit(
          color: slate300,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required Widget prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black, // Fondo Negro Puro solicitado
      body: Stack(
        children: [
          // Botón Atrás
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 60.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mensaje Gancho Separado
                    Text(
                      'Únete a la Red',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Crea tu cuenta hoy y empieza a gestionar tus despachos de hielo con la mayor velocidad.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(
                          fontSize: 14,
                          color: slate400,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tarjeta Vertical Organizada
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 480,
                      ), // Tamaño controlado y estético
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: slate900,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Foto de Perfil Grande
                          Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyanAccent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withOpacity(0.15),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(60),
                                child: _nameController.text.trim().isEmpty
                                    ? Image.asset(
                                        _selectedRole == 'repartidor'
                                            ? 'assets/repartidor.png'
                                            : 'assets/cliente.png',
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.cyan.shade800,
                                        alignment: Alignment.center,
                                        child: Text(
                                          getInitials(_nameController.text),
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 38,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Formulario
                          _buildFieldLabel('Nombre y Apellido'),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              hint: 'Ej: Mauricio Heredia',
                              prefix: const Icon(
                                Icons.person_outline,
                                color: Colors.cyanAccent,
                                size: 20,
                              ),
                            ),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty)
                                ? 'Ingresa tu nombre'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          _buildFieldLabel('Correo Electrónico'),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              hint: 'Ej: usuario@correo.com',
                              prefix: const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedMail01,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (val) =>
                                (val == null || !val.contains('@'))
                                ? 'Correo inválido'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          _buildFieldLabel('Contraseña'),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                _buildInputDecoration(
                                  hint: 'Mínimo 6 caracteres',
                                  prefix: const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedLock,
                                      color: Colors.cyanAccent,
                                      size: 20,
                                    ),
                                  ),
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: HugeIcon(
                                      icon: _obscurePassword
                                          ? HugeIcons.strokeRoundedViewOff
                                          : HugeIcons.strokeRoundedView,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                            validator: (val) => (val == null || val.length < 6)
                                ? 'Contraseña muy corta'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // --- Campos Dinámicos para Clientes ---
                          if (_selectedRole == 'cliente') ...[
                            _buildFieldLabel('DNI / Documento'),
                            TextFormField(
                              controller: _dniController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: 54321098',
                                prefix: const Icon(
                                  Icons.badge_outlined,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa tu DNI'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildFieldLabel('Dirección de Entrega'),
                            TextFormField(
                              controller: _addressController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: Av. Mariscal López 1420',
                                prefix: const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa tu dirección'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildFieldLabel('Número de Celular'),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: +595981234567',
                                prefix: const Icon(
                                  Icons.phone_android_outlined,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa tu celular'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // --- Campos Dinámicos para Repartidores ---
                          if (_selectedRole == 'repartidor') ...[
                            _buildFieldLabel('Tipo de Vehículo'),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedVehicle,
                                  dropdownColor: slate800,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.cyanAccent,
                                  ),
                                  isExpanded: true,
                                  items: ['Moto', 'Auto'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => _selectedVehicle = val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFieldLabel('Matrícula / Patente'),
                            TextFormField(
                              controller: _plateController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: AAA 123 PY',
                                prefix: const Icon(
                                  Icons.numbers_outlined,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa la patente'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Selector de Rol
                          _buildFieldLabel('Selecciona tu Rol'),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedRole = 'repartidor',
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedRole == 'repartidor'
                                            ? Colors.cyanAccent
                                            : Colors.white12,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Repartidor',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedRole = 'cliente'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedRole == 'cliente'
                                            ? Colors.cyanAccent
                                            : Colors.white12,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Cliente',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Botón Registrarse
                          provider.isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.cyanAccent,
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      colors: [Colors.cyan, Colors.teal],
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'REGISTRARSE',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              '¿Ya tienes cuenta? Inicia Sesión',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

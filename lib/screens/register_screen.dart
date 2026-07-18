import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../providers/order_provider.dart';
import 'sub_screens/shared/widgets/success_overlay_dialog.dart';

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
  final _plateController = TextEditingController();

  bool _obscurePassword = true;
  String _selectedVehicle = 'Moto'; // 'Moto', 'Auto' or 'Camión'

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
      const role = 'repartidor';
      const avatarUrl = 'assets/repartidor.png';

      await provider.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        fullName,
        role,
        avatarUrl,
        tipoVehiculo: _selectedVehicle,
        matricula: _plateController.text.trim(),
      );
      if (mounted) {
        final loginContext = context;
        Navigator.pop(context);
        showPremiumSuccessDialog(
          loginContext,
          title: '¡Registro Exitoso!',
          message: 'Tu cuenta ha sido creada correctamente. Ya puedes iniciar sesión con tus credenciales.',
        );
      }
    } catch (e) {
      if (mounted) {
        showPremiumErrorDialog(
          context,
          title: 'Error al Registrarse',
          message: e.toString().replaceAll('Exception:', '').trim(),
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
                          // Avatar de Perfil Dinámico (Solo en pantallas donde ya se ingresó nombre)
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyanAccent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withOpacity(0.12),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: _nameController.text.trim().isEmpty
                                    ? Image.asset(
                                        'assets/repartidor.png',
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
                                            fontSize: 34,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

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
                              hint: 'Ej: preventista@correo.com',
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
                            decoration: _buildInputDecoration(
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
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                            validator: (val) => (val == null || val.length < 6)
                                ? 'Contraseña muy corta'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          _buildFieldLabel('Tipo de Vehículo'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedVehicle,
                                dropdownColor: slate800,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                                isExpanded: true,
                                items: ['Moto', 'Auto', 'Camión'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedVehicle = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildFieldLabel('Matrícula / Patente del Vehículo'),
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
                          const SizedBox(height: 28),

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
                                      padding: const EdgeInsets.symmetric(vertical: 14),
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

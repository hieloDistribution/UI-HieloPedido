import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../providers/order_provider.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onBack;
  const LoginScreen({super.key, required this.onBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<OrderProvider>(context, listen: false);
    try {
      if (_isSignUp) {
        await provider.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta creada! Por favor inicia sesión.'),
              backgroundColor: Colors.teal,
            ),
          );
          setState(() => _isSignUp = false);
        }
      } else {
        await provider.loginWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              'Ocurrió un error',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: Text(
              e.toString().replaceAll('Exception:', '').trim(),
              style: GoogleFonts.openSans(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido', style: TextStyle(color: Colors.teal)),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Back button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: Colors.white,
                size: 24,
              ),
              onPressed: widget.onBack,
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Snowflake logo icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedSnow,
                        color: Colors.cyanAccent,
                        size: 64,
                      ),
                    ).animate().fade(duration: 800.ms).scale(delay: 200.ms),
                    const SizedBox(height: 24),
                    
                    // Brand Title (Inter Font, Bold)
                    Text(
                      'Hielo Distribution',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ).animate().fade(delay: 300.ms).slideY(begin: 0.3),
                    
                    Text(
                      'Pedidos Rápidos & Sincronizados',
                      style: GoogleFonts.openSans(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ).animate().fade(delay: 450.ms).slideY(begin: 0.3),
                    const SizedBox(height: 32),

                    // Auth Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isSignUp ? 'Crear Cuenta' : 'Iniciar Sesión',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email Input
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Correo Electrónico',
                              labelStyle: const TextStyle(color: Colors.white70),
                              floatingLabelStyle: const TextStyle(color: Colors.cyanAccent),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.0),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedMail01,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.redAccent),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty || !val.contains('@')) {
                                return 'Introduce un correo válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: const TextStyle(color: Colors.white70),
                              floatingLabelStyle: const TextStyle(color: Colors.cyanAccent),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.0),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedLock,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              suffixIcon: IconButton(
                                icon: HugeIcon(
                                  icon: _obscurePassword
                                      ? HugeIcons.strokeRoundedViewOff
                                      : HugeIcons.strokeRoundedView,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.redAccent),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Submit button
                          provider.isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(color: Colors.cyanAccent),
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
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      _isSignUp ? 'REGISTRARSE' : 'INGRESAR',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 16),

                          // Toggle Sign Up / Sign In
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _emailController.clear();
                                _passwordController.clear();
                              });
                            },
                            child: Text(
                              _isSignUp
                                  ? '¿Ya tienes cuenta? Inicia Sesión'
                                  : '¿No tienes cuenta? Regístrate',
                              style: const TextStyle(color: Colors.cyanAccent),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 500.ms).slideY(begin: 0.1),

                    const SizedBox(height: 24),
                    
                    // Google Sign-In button
                    if (!_isSignUp)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await provider.loginWithGoogle();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error de Google Auth: ${e.toString()}'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          icon: Image.network(
                            'https://img.icons8.com/color/48/000000/google-logo.png',
                            height: 22,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.g_mobiledata, color: Colors.cyanAccent, size: 24);
                            },
                          ),
                          label: Text(
                            'Iniciar Sesión con Google',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ).animate().fade(delay: 650.ms),
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

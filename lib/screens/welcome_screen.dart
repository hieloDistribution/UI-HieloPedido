import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onComenzar;
  const WelcomeScreen({super.key, required this.onComenzar});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Top Icon (Snowflake)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSnow,
                    color: Colors.white,
                    size: 64,
                  ),
                ).animate().fade(duration: 800.ms).scale(delay: 200.ms),
              ),
              
              const SizedBox(height: 40),
              
              // App Name (Inter Font, Bold/Heavy)
              Text(
                'Hielo\nDistribution',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
              ).animate().fade(delay: 300.ms).slideY(begin: 0.3, duration: 600.ms),
              
              const SizedBox(height: 16),
              
              // Description (Open Sans Font)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Gestioná tus pedidos de hielo de forma rápida y profesional. Anotá tus ventas incluso sin conexión y sincronizalas al instante.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ).animate().fade(delay: 500.ms).slideY(begin: 0.2, duration: 600.ms),
              
              const Spacer(flex: 2),
              
              // Bottom Button "Comenzar" (White background, Black text)
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: onComenzar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Comenzar',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        color: Colors.black,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ).animate().fade(delay: 700.ms).slideY(begin: 0.4, duration: 600.ms),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

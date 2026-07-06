import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onComenzar;
  const WelcomeScreen({super.key, required this.onComenzar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900 de fondo para consistencia con tu Admin
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Top Icon (Snowflake) con efecto Neumórfico Dark
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.05),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ]
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSnow,
                    color: Colors.cyanAccent, // Unificado con tu paleta Cyan
                    size: 64,
                  ),
                ).animate().fade(duration: 800.ms).scale(delay: 200.ms),
              ),
              
              const SizedBox(height: 40),
              
              // App Name
              Text(
                'Hielo\nDistribution',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit( // Outfit para títulos
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.5,
                  height: 1.05,
                ),
              ).animate().fade(delay: 300.ms).slideY(begin: 0.3, duration: 600.ms),
              
              const SizedBox(height: 16),
              
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'Gestioná tus pedidos de hielo de forma rápida y profesional. Anotá tus ventas incluso sin conexión y sincronizalas al instante.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8), // Slate 400
                    height: 1.6,
                  ),
                ),
              ).animate().fade(delay: 500.ms).slideY(begin: 0.2, duration: 600.ms),
              
              const Spacer(flex: 2),
              
              // Bottom Button "Comenzar" Premium
              Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
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
                        style: GoogleFonts.outfit(
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

// welcome_screen.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onComenzar;

  const WelcomeScreen({super.key, required this.onComenzar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Capa fondo: degradado blanco -> azul con blobs animados
          const _AuroraBackground(),

          // Capa Contenido UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),

                  // Ícono / logo arriba de los textos (opcional, como la referencia)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hub_outlined,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tu distribución,\nsimplificada',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.15),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Gestioná pedidos, stock y entregas\nde hielo en un solo lugar.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón principal - Glass
                  _GlassButton(
                    label: 'Comenzar',
                    icon: Icons.arrow_forward_rounded,
                    isPrimary: true,
                    onTap: onComenzar,
                  ),

                  const SizedBox(height: 14),

                  // Botón secundario - Glass más sutil
                  _GlassButton(
                    label: 'Ya tengo una cuenta',
                    icon: Icons.login_rounded,
                    isPrimary: false,
                    onTap: () {},
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;

        return Stack(
          children: [
            // Base: blanco arriba -> azul fuerte abajo
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 0.75, 1.0],
                  colors: [
                    Colors.white,
                    Colors.white,
                    Color(0xFF2E9BFF), // celeste intenso
                    Color(0xFF0057FF), // azul fuerte abajo
                  ],
                ),
              ),
            ),

            // Blob 1 - celeste brillante, se mueve en la zona media-baja
            _AuroraBlob(
              color: const Color(0xFF00C2FF),
              top: 420 + math.sin(t) * 40,
              left: -100 + math.cos(t * 0.7) * 80,
              size: 380,
              opacity: 0.55,
            ),

            // Blob 2 - azul profundo abajo a la derecha
            _AuroraBlob(
              color: const Color(0xFF0038FF),
              top: 600 + math.cos(t * 0.8) * 50,
              left: 180 + math.sin(t * 0.6) * 70,
              size: 420,
              opacity: 0.5,
            ),

            // Blob 3 - celeste más claro cerca del medio para dar brillo
            _AuroraBlob(
              color: const Color(0xFF7CD9FF),
              top: 350 + math.sin(t * 0.5) * 60,
              left: 40 + math.cos(t * 0.9) * 90,
              size: 320,
              opacity: 0.4,
            ),
          ],
        );
      },
    );
  }
}

/// Una "mancha" de luz difuminada
class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double top;
  final double left;
  final double size;
  final double opacity;

  const _AuroraBlob({
    required this.color,
    required this.top,
    required this.left,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón con efecto vidrio esmerilado (glassmorphism)
class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _GlassButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: isPrimary
              ? Colors.white.withOpacity(0.85)
              : Colors.white.withOpacity(0.15),
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(isPrimary ? 0.6 : 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isPrimary ? Colors.black87 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 18,
                    color: isPrimary ? Colors.black87 : Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

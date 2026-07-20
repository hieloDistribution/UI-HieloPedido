import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum PremiumNotificationType { success, warning, error }

class IrregularNotificationClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    const double mainRadius = 24.0; // Radio de los bordes del cuerpo principal
    const double tabHeight = 30.0; // Altura de la pestaña superior
    const double tabWidth =
        150.0; // Ancho de la pestaña superior (ligeramente más ancho para advertencias)
    const double tabRadius =
        14.0; // Radio de las esquinas superiores de la pestaña

    // Punto de partida: esquina inferior izquierda del cuerpo principal
    path.moveTo(0, tabHeight + mainRadius);

    // Curva esquina inferior izquierda
    path.quadraticBezierTo(0, tabHeight, mainRadius, tabHeight);

    // Línea hacia el inicio de la pestaña central (izquierda)
    double startTab = (size.width - tabWidth) / 2;
    path.lineTo(startTab, tabHeight);

    // DIBUJO DE LA PESTAÑA CENTRAL:
    // Curva que sube hacia la izquierda de la pestaña
    path.quadraticBezierTo(
      startTab,
      tabHeight,
      startTab,
      tabHeight - tabRadius,
    );
    path.quadraticBezierTo(
      startTab,
      0,
      startTab + tabRadius,
      0,
    ); // Curva superior izquierda de pestaña
    path.lineTo(startTab + tabWidth - tabRadius, 0); // Línea superior pestaña
    path.quadraticBezierTo(
      startTab + tabWidth,
      0,
      startTab + tabWidth,
      tabRadius,
    ); // Curva superior derecha pestaña
    path.quadraticBezierTo(
      startTab + tabWidth,
      tabHeight,
      startTab + tabWidth,
      tabHeight,
    ); // Curva que baja hacia la derecha

    // Continúa el cuerpo principal hacia la derecha
    path.lineTo(size.width - mainRadius, tabHeight);

    // Curva esquina superior derecha cuerpo principal
    path.quadraticBezierTo(
      size.width,
      tabHeight,
      size.width,
      tabHeight + mainRadius,
    );

    // Borde derecho y esquina inferior derecha (usando size.height corregido)
    path.lineTo(size.width, size.height - mainRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - mainRadius,
      size.height,
    );

    // Borde inferior y esquina inferior izquierda
    path.lineTo(mainRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - mainRadius);

    // Cierra el camino
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Widget animado para la notificación que gestiona internamente TickerProvider
class PremiumTopNotificationWidget extends StatefulWidget {
  final String title;
  final String message;
  final PremiumNotificationType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const PremiumTopNotificationWidget({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<PremiumTopNotificationWidget> createState() =>
      _PremiumTopNotificationWidgetState();
}

class _PremiumTopNotificationWidgetState
    extends State<PremiumTopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _slideAnimation = Tween<double>(begin: -220, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack, // Rebote sutil premium al bajar
      ),
    );

    _controller.forward();

    // Auto-descarte
    Future.delayed(widget.duration).then((_) {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color accentColor;

    switch (widget.type) {
      case PremiumNotificationType.success:
        icon = Icons.check_circle_outline;
        accentColor = const Color(0xFF38CC77); // Verde vibrante
        break;
      case PremiumNotificationType.warning:
        icon = Icons.warning_amber_outlined;
        accentColor = const Color(0xFFF59E0B); // Amarillo/Naranja advertencia
        break;
      case PremiumNotificationType.error:
        icon = Icons.error_outline;
        accentColor = const Color(0xFFEF4444); // Rojo vibrante
        break;
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: GestureDetector(
            onPanUpdate: (details) {
              // Deslizar hacia arriba para cerrar al instante
              if (details.delta.dy < -5) {
                _dismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipPath(
                  clipper: IrregularNotificationClipper(),
                  child: Container(
                    color: const Color(0xFF1E1E1E),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Pestaña Superior
                        Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: accentColor, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 2. Cuerpo con Mensaje
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          child: Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.openSans(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Función global única para mostrar la notificación superior premium
void showPremiumTopNotification(
  BuildContext context, {
  required String title,
  required String message,
  required PremiumNotificationType type,
  Duration duration = const Duration(seconds: 4),
}) {
  late final OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: PremiumTopNotificationWidget(
          title: title,
          message: message,
          type: type,
          duration: duration,
          onDismiss: () {
            overlayEntry.remove();
          },
        ),
      );
    },
  );

  Overlay.of(context).insert(overlayEntry);
}

/// Adaptador para mantener compatibilidad con diálogos de éxito
void showPremiumSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showPremiumTopNotification(
    context,
    title: title,
    message: message,
    type: PremiumNotificationType.success,
  );
}

/// Adaptador para mantener compatibilidad con diálogos de error
void showPremiumErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showPremiumTopNotification(
    context,
    title: title,
    message: message,
    type: PremiumNotificationType.error,
  );
}

// welcome_screen.dart

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/order_provider.dart';
import 'sub_screens/shared/widgets/success_overlay_dialog.dart';

enum OnboardingStep { welcome, email, password }

/// Color de acento por paso — esto es lo que hace que el fondo "cambie de
/// humor" entre pantallas (celeste -> naranja -> violeta).
Color _accentForStep(OnboardingStep step) {
  switch (step) {
    case OnboardingStep.welcome:
      return const Color(0xFF00C2FF); // celeste/azul
    case OnboardingStep.email:
      return const Color(0xFFFF9331); // naranja
    case OnboardingStep.password:
      return const Color(0xFF8B5CF6); // violeta
  }
}

/// Lo que rota en el carrusel vertical — adaptalo a lo que quieras destacar
/// de tu app.
const List<_CarouselItem> _kWelcomeHighlights = [
  _CarouselItem('Pedidos', Icons.receipt_long_rounded, 'Gestioná pedidos\nde hielo en tiempo real'),
  _CarouselItem('Stock', Icons.inventory_2_rounded, 'Controlá tu inventario\nsin complicaciones'),
  _CarouselItem('Entregas', Icons.local_shipping_rounded, 'Seguí cada entrega\nal instante'),
  _CarouselItem('Rutas', Icons.map_rounded, 'Optimizá tus rutas\nde entrega'),
];

const List<_CarouselItem> _kEmailHighlights = [
  _CarouselItem('Inicio', Icons.login_rounded, 'Accedé a tu cuenta\ncon tu correo electrónico'),
  _CarouselItem('Rápido', Icons.flash_on_rounded, 'Inicio de sesión\nen segundos'),
  _CarouselItem('Seguro', Icons.lock_rounded, 'Tus datos protegidos\ncon encriptación'),
];

const List<_CarouselItem> _kPasswordHighlights = [
  _CarouselItem('Seguridad', Icons.shield_rounded, 'Protegé tu cuenta\ncon una contraseña segura'),
  _CarouselItem('Privacidad', Icons.visibility_off_rounded, 'Tus datos personales\nsiempre privados'),
  _CarouselItem('Confianza', Icons.verified_rounded, 'Sistema seguro\ny confiable'),
];

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onComenzar;

  const WelcomeScreen({super.key, required this.onComenzar});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  OnboardingStep _step = OnboardingStep.welcome;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  // Cuando un input tiene foco, pintamos toda la pantalla de blanco
  // (igual que en el video de referencia).
  bool _emailFocused = false;
  bool _passwordFocused = false;
  bool get _whiteOut => _emailFocused || _passwordFocused;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      setState(() => _emailFocused = _emailFocusNode.hasFocus);
    });
    _passwordFocusNode.addListener(() {
      setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit(OrderProvider provider) async {
    if (!_passwordFormKey.currentState!.validate()) return;

    try {
      await provider.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        showPremiumSuccessDialog(
          context,
          title: 'Sesión Iniciada',
          message: 'Iniciado session con exito',
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception:', '').trim();
        final lower = errorMsg.toLowerCase();
        if (lower.contains('invalid login credentials') ||
            lower.contains('invalid_credentials')) {
          errorMsg =
              'El correo o la contraseña son incorrectos. Por favor, verifica tus datos.';
        } else if (lower.contains('email not confirmed')) {
          errorMsg =
              'Tu cuenta aún no ha sido confirmada. Revisa tu bandeja de entrada.';
        } else if (lower.contains('network_error') ||
            lower.contains('socketexception') ||
            lower.contains('connection timed out')) {
          errorMsg =
              'No se pudo establecer conexión con el servidor. Verifica tu internet.';
        }
        showPremiumErrorDialog(
          context,
          title: 'Error de Inicio de Sesión',
          message: errorMsg,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final accent = _accentForStep(_step);

    return Scaffold(
      backgroundColor: Colors.white,
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0.0,
          end: _step == OnboardingStep.welcome
              ? 0.0
              : _step == OnboardingStep.email
              ? 0.35
              : 0.65,
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        builder: (context, offset, child) {
          return Stack(
            children: [
              _AuroraBackground(
                liquidOffset: offset,
                accentColor: accent,
                heightFraction: _step == OnboardingStep.welcome
                    ? 0.55
                    : (_step == OnboardingStep.email || _step == OnboardingStep.password ? -0.75 : 0.55),
                fromBottom: _step == OnboardingStep.welcome,
                topOverlayColor: _step == OnboardingStep.email
                    ? const Color(0xFFFF6B6B)
                    : (_step == OnboardingStep.password ? const Color(0xFF7C3AED) : null),
              ),

              // Overlay blanco: aparece cuando el usuario toca un input,
              // igual que en el video de referencia.
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  opacity: _whiteOut ? 1 : 0,
                  child: Container(color: Colors.white),
                ),
              ),

              // Contenido con animaciones
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildStepContent(provider, accent),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepContent(OrderProvider provider, Color accent) {
    // Cuando la pantalla se pintó de blanco, el texto pasa a oscuro para
    // que se siga leyendo.
    final dark = _whiteOut;
    final titleColor = dark ? Colors.black87 : Colors.white;
    final subtitleColor = dark ? Colors.black54 : Colors.white.withOpacity(0.8);
    final backIconColor = dark ? Colors.black87 : Colors.white;
    final fieldFillColor = dark
        ? Colors.black.withOpacity(0.04)
        : Colors.white.withOpacity(0.08);
    final hintColor = dark ? Colors.black38 : Colors.white30;
    final borderColor = dark
        ? Colors.black.withOpacity(0.08)
        : Colors.white.withOpacity(0.15);
    final inputTextColor = dark ? Colors.black87 : Colors.white;

    switch (_step) {
      case OnboardingStep.welcome:
        return Column(
          key: const ValueKey('welcome_step'),
          children: [
            const SizedBox(height: 16),
            // Carrusel en zona blanca, pegado al borde izquierdo
              Transform.translate(
                offset: const Offset(-85, 140),
                child: _VerticalWordCarousel(
                  items: _kWelcomeHighlights,
                  accent: accent,
                  variant: _CarouselVariant.light,
                  carouselWidth: 600,
                  rowHeight: 150,
                ),
              ),
            const Spacer(),

            // Logo, textos y botones en la parte inferior (como antes)
            Align(
              alignment: Alignment.centerLeft,
              child: _GlowLogo(
                accent: accent,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
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
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gestioná pedidos, stock y entregas\nde hielo en un solo lugar.',
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _GlassButton(
              label: 'Comenzar',
              icon: Icons.arrow_forward_rounded,
              isPrimary: false,
              isDark: false,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              onTap: widget.onComenzar,
            ),
            const SizedBox(height: 14),
            _GlassButton(
              label: 'Ya tengo una cuenta',
              icon: Icons.login_rounded,
              isPrimary: false,
              isDark: true,
              onTap: () {
                setState(() {
                  _step = OnboardingStep.email;
                });
              },
            ),
             const SizedBox(height: 24),
          ],
        );

      case OnboardingStep.email:
        return Form(
          key: _emailFormKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      key: const ValueKey('email_step'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios_new, color: backIconColor),
                            onPressed: () {
                              setState(() {
                                _step = OnboardingStep.welcome;
                              });
                            },
                          ),
                        ),
                        const Spacer(),
                        Transform.translate(
                          offset: const Offset(-85, 0),
                          child: _VerticalWordCarousel(
                            items: _kEmailHighlights,
                            accent: accent,
                            variant: _CarouselVariant.light,
                            carouselWidth: 600,
                            rowHeight: 130,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Ingrese su mail',
                          style: GoogleFonts.outfit(
                            color: Colors.black87,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Para poder iniciar sesión ingresa con el email que te asignó el administrador',
                          style: GoogleFonts.openSans(
                            color: Colors.black54,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: inputTextColor, fontSize: 16),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: fieldFillColor,
                            hintText: 'Ingrese su mail',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                            contentPadding: const EdgeInsets.only(left: 20, right: 60, top: 22, bottom: 22),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: accent, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 1.5,
                              ),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                                  onPressed: () {
                                    if (_emailFormKey.currentState!.validate()) {
                                      setState(() {
                                        _step = OnboardingStep.password;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || !val.contains('@')) {
                              return 'Por favor ingresa un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );

      case OnboardingStep.password:
        return Form(
          key: _passwordFormKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      key: const ValueKey('password_step'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios_new, color: backIconColor),
                            onPressed: () {
                              setState(() {
                                _step = OnboardingStep.email;
                              });
                            },
                          ),
                        ),
                        const Spacer(),
                        Transform.translate(
                          offset: const Offset(-85, 0),
                          child: _VerticalWordCarousel(
                            items: _kPasswordHighlights,
                            accent: accent,
                            variant: _CarouselVariant.light,
                            carouselWidth: 600,
                            rowHeight: 130,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Ingresa tu Contraseña',
                          style: GoogleFonts.outfit(
                            color: titleColor,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            shadows: dark
                                ? null
                                : [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.15),
                                      offset: const Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escribe la contraseña asociada a tu cuenta.',
                          style: GoogleFonts.openSans(color: subtitleColor, fontSize: 14),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: inputTextColor),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: fieldFillColor,
                            hintText: 'Escribe tu contraseña',
                            hintStyle: TextStyle(color: hintColor),
                            prefixIcon: Icon(Icons.lock_outline, color: accent),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: dark ? Colors.black45 : Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: accent, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        provider.isLoading
                            ? Center(child: CircularProgressIndicator(color: accent))
                            : _GlassButton(
                                label: 'Iniciar Sesión',
                                icon: Icons.login_rounded,
                                isPrimary: true,
                                onTap: () => _submit(provider),
                              ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

class _CarouselItem {
  final String label;
  final IconData icon;
  final String description;
  const _CarouselItem(this.label, this.icon, this.description);
}

enum _CarouselVariant { light, dark }

/// Carrusel vertical tipo "picker": el ítem del centro queda grande, los de
/// arriba/abajo quedan chicos y grisados, y todo se desvanece en los bordes
/// con un ShaderMask — igual al efecto "Save / Earn / Spend" del video.
///
/// variant.light -> para usar sobre fondo blanco: letras negras, ícono
/// en un chip de color de acento (para que se note bien que hay un ícono).
/// variant.dark  -> para usar sobre el fondo de color: letras e íconos
/// blancos.
class _VerticalWordCarousel extends StatefulWidget {
  final List<_CarouselItem> items;
  final Color accent;
  final _CarouselVariant variant;
  final double carouselWidth;
  final double rowHeight;

  const _VerticalWordCarousel({
    required this.items,
    required this.accent,
    this.variant = _CarouselVariant.dark,
    this.carouselWidth = 240,
    this.rowHeight = 56,
  });

  @override
  State<_VerticalWordCarousel> createState() => _VerticalWordCarouselState();
}

class _VerticalWordCarouselState extends State<_VerticalWordCarousel>
    with SingleTickerProviderStateMixin {
  double get _rowHeight => widget.rowHeight;

  late final AnimationController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) async {
      if (!mounted) return;
      await _controller.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % widget.items.length;
      });
      _controller.value = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.variant == _CarouselVariant.light;

    return SizedBox(
      height: _rowHeight * 3,
      width: widget.carouselWidth,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.32, 0.68, 1.0],
        ).createShader(rect),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            final n = widget.items.length;
            return Stack(
              alignment: Alignment.center,
              children: List.generate(5, (i) {
                final relIndex = i - 2; // -2, -1, 0, 1, 2
                final itemIndex = ((_index + relIndex) % n + n) % n;
                final item = widget.items[itemIndex];
                final pos = relIndex - progress; // distancia al centro
                final dist = pos.abs();
                final opacity = (1 - dist * 0.75).clamp(0.0, 1.0);
                final scale = (1 - dist * 0.18).clamp(0.72, 1.0);
                final isCenterish = dist < 0.5;

                final textColor = isLight
                    ? Colors.black87
                    : (isCenterish ? Colors.white : Colors.white54);

                Widget iconWidget;
                if (isLight && isCenterish) {
                  iconWidget = Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(item.icon, size: 22, color: widget.accent),
                  );
                } else if (isLight) {
                  iconWidget = Icon(item.icon, size: 15, color: Colors.black26);
                } else {
                  iconWidget = Icon(
                    item.icon,
                    size: isCenterish ? 22 : 17,
                    color: Colors.white.withOpacity(isCenterish ? 1 : 0.55),
                  );
                }

                return Transform.translate(
                  offset: Offset(0, pos * _rowHeight),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: isCenterish ? 4 : 0),
                            child: iconWidget,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: isCenterish ? 58 : 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isCenterish)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    item.description,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 16,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// Logo circular con gradiente diagonal + glow difuso alrededor,
/// igual que el ícono del video.
class _GlowLogo extends StatelessWidget {
  final Color accent;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _GlowLogo({
    required this.accent,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        gradient: backgroundColor != null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, Color.lerp(accent, Colors.white, 0.35)!],
              ),
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? accent).withOpacity(0.55),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.ac_unit_rounded,
        color: foregroundColor ?? Colors.white,
        size: 24,
      ),
    );
  }
}

class _AuroraBackground extends StatefulWidget {
  final double liquidOffset;
  final Color accentColor;
  final double heightFraction;
  final bool fromBottom;
  final Color? topOverlayColor;

  const _AuroraBackground({
    required this.liquidOffset,
    required this.accentColor,
    this.heightFraction = 0.30,
    this.fromBottom = false,
    this.topOverlayColor,
  });

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with TickerProviderStateMixin {
  // Controla el movimiento flotante de los blobs (loop infinito).
  late final AnimationController _floatController;

  // Controla la transición de color cuando cambia el paso (welcome/email/password).
  late final AnimationController _colorController;
  late Animation<Color?> _colorAnim;
  late Color _previousAccent;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();

    _previousAccent = widget.accentColor;
    _colorController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _colorAnim = ColorTween(
      begin: widget.accentColor,
      end: widget.accentColor,
    ).animate(_colorController);
  }

  @override
  void didUpdateWidget(covariant _AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accentColor != widget.accentColor) {
      _colorAnim = ColorTween(begin: _previousAccent, end: widget.accentColor)
          .animate(
            CurvedAnimation(
              parent: _colorController,
              curve: Curves.easeInOutCubic,
            ),
          );
      _previousAccent = widget.accentColor;
      _colorController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 800.0;

        return AnimatedBuilder(
          animation: Listenable.merge([_floatController, _colorController]),
          builder: (context, child) {
            final t = _floatController.value * 2 * math.pi;
            final accent = _colorAnim.value ?? widget.accentColor;
            // Núcleo más oscuro/saturado -> el azul (o el color que toque)
            // se ve más fuerte, no lavado.
            final core = Color.lerp(accent, Colors.black, 0.08)!;

            final hill = widget.fromBottom
                ? Positioned(
                    left: -w * 0.5,
                    width: w * 2,
                    bottom: -h * 0.15,
                    height: h * widget.heightFraction + h * 0.15,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 65, sigmaY: 65),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w),
                          gradient: RadialGradient(
                            center: const Alignment(0, 0.6),
                            radius: 0.75,
                            colors: [core, accent, accent.withOpacity(0)],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  )
                : Positioned(
                    left: -w * 0.5,
                    width: w * 2,
                    top:
                        h * widget.heightFraction -
                        widget.liquidOffset * h * 0.30,
                    height: h * 1.15,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 65, sigmaY: 65),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w),
                            gradient: RadialGradient(
                              center: const Alignment(0, -0.6),
                              radius: 0.6,
                              colors: [core, core, accent],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                        ),
                      ),
                    ),
                  );

            final blobTopBase = widget.fromBottom
                ? h * (1 - widget.heightFraction)
                : h * widget.heightFraction;

            final overlay = widget.topOverlayColor != null && !widget.fromBottom
                ? Positioned(
                    left: -w * 0.8,
                    width: w * 2.6,
                    top: -h * 0.05,
                    height: h * 0.7,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w),
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.5),
                            radius: 0.6,
                            colors: [
                              widget.topOverlayColor!.withOpacity(0.45),
                              widget.topOverlayColor!.withOpacity(0.3),
                              widget.topOverlayColor!.withOpacity(0),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink();

            return Stack(
              children: [
                const ColoredBox(color: Colors.white),

                hill,

                overlay,

                RepaintBoundary(
                  child: Stack(
                    children: [
                      _AuroraBlob(
                        color: accent,
                        top:
                            blobTopBase +
                            h * 0.25 -
                            widget.liquidOffset * h * 0.30 +
                            math.sin(t) * 30,
                        left: -w * 0.2 + math.cos(t * 0.7) * (w * 0.15),
                        size: w * 0.95,
                        opacity: 0.5,
                      ),
                      _AuroraBlob(
                        color: Color.lerp(
                          accent,
                          const Color(0xFF0038FF),
                          0.45,
                        )!,
                        top:
                            blobTopBase +
                            h * 0.45 -
                            widget.liquidOffset * h * 0.30 +
                            math.cos(t * 0.8) * 35,
                        left: w * 0.35 + math.sin(t * 0.6) * (w * 0.12),
                        size: w * 1.05,
                        opacity: 0.45,
                      ),
                      _AuroraBlob(
                        color: Color.lerp(accent, Colors.white, 0.35)!,
                        top:
                            blobTopBase +
                            h * 0.15 -
                            widget.liquidOffset * h * 0.30 +
                            math.sin(t * 0.5) * 40,
                        left: w * 0.05 + math.cos(t * 0.9) * (w * 0.18),
                        size: w * 0.8,
                        opacity: 0.35,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Una "mancha" de luz difuminada. backgroundBlendMode: BlendMode.plus hace
/// que, donde dos blobs se solapan, la luz se sume en vez de taparse —
/// es lo que le da ese brillo tipo aurora boreal del video.
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
              backgroundBlendMode: BlendMode.plus,
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
  final bool isDark;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _GlassButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
    this.isDark = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final white = isDark;
    final bg = backgroundColor ?? (isPrimary
        ? const Color(0xFF0F172A)
        : (white ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.04)));
    final fg = foregroundColor ?? (isPrimary ? Colors.white : (white ? Colors.white : Colors.black87));
    final borderColor = backgroundColor != null
        ? fg.withOpacity(0.2)
        : (white
            ? Colors.white.withOpacity(isPrimary ? 0.6 : 0.35)
            : Colors.black.withOpacity(isPrimary ? 0.6 : 0.08));
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: bg,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 18, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

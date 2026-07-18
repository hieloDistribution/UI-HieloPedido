import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../providers/order_provider.dart';
import 'sub_screens/admin/admin_home_view.dart';
import 'sub_screens/admin/admin_proveedores_view.dart';
import 'sub_screens/admin/admin_map_view.dart';
import 'sub_screens/admin/admin_calendario_view.dart';
import 'sub_screens/repartidor/repartidor_inicio_view.dart';
import 'sub_screens/repartidor/create_order_view.dart';
import 'sub_screens/shared/profile_section.dart';
import 'sub_screens/repartidor/distributor_orders_dashboard.dart';
import 'sub_screens/repartidor/incoming_order_overlay.dart';

class BottomNavItem {
  final IconData? icon;
  final List<List<dynamic>>? hugeIcon;
  final String label;
  BottomNavItem({this.icon, this.hugeIcon, required this.label});
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  List<Widget>? _screens;
  String? _cachedRole;

  // COLORES EXACTOS
  static const Color navBarColor = Color(0xFF26323F);
  static const Color inactiveIconColor = Color(0xFF9CA3AF);

  // TAMAÑOS DE LA BURBUJA / NOTCH (antes: bubble 56, radio de corte 34)
  static const double bubbleSize = 46.0;
  static const double notchCutRadius = 27.0;
  static const double activeIconSize = 23.0;
  static const double inactiveIconSize = 23.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.loadOrders();
      provider.syncUnsyncedOrders();
    }
  }

  List<Widget> _getScreens(String role) {
    if (_screens != null && _cachedRole == role) {
      return _screens!;
    }
    _cachedRole = role;
    _screens = role == 'admin'
        ? [
            const AdminHomeView(),
            AdminProveedoresView(onViewOnMap: (index) {
              setState(() {
                _currentIndex = index;
              });
            }),
            const AdminMapView(),
            const AdminCalendarioView(),
            const ProfileSection(),
          ]
        : [
            const RepartidorInicioView(),
            DistributorOrdersDashboard(),
            const CreateOrderView(),
            const ProfileSection(),
          ];
    return _screens!;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final userRole = provider.userRole;
    final screens = _getScreens(userRole);

    final List<BottomNavItem> navItems = userRole == 'admin'
        ? [
            BottomNavItem(
              hugeIcon: HugeIcons.strokeRoundedHome01,
              label: 'Inicio',
            ),
            BottomNavItem(
              hugeIcon: HugeIcons.strokeRoundedCar03,
              label: 'Proveedores',
            ),
            BottomNavItem(
              hugeIcon: HugeIcons.strokeRoundedMapPin,
              label: 'Mapa',
            ),
            BottomNavItem(
              hugeIcon: HugeIcons.strokeRoundedCalendar04,
              label: 'Calendario',
            ),
            BottomNavItem(
              hugeIcon: HugeIcons.strokeRoundedUser,
              label: 'Perfil',
            ),
          ]
        : [
            BottomNavItem(icon: Icons.home_outlined, label: 'Inicio'),
            BottomNavItem(icon: Icons.local_shipping_outlined, label: 'Viajes'),
            BottomNavItem(icon: Icons.add_circle_outline, label: 'Nuevo'),
            BottomNavItem(icon: Icons.person_outline, label: 'Perfil'),
          ];

    if (_currentIndex >= navItems.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      extendBody: true, // Permite que el contenido fluya debajo del navbar
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. EL CONTENIDO PRINCIPAL (MAPA, LISTAS, ETC)
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),

          // 2. NAVBAR FLOTANTE
          Positioned(
            bottom: 45,
            left: 20,
            right: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double hPadding = 24.0;
                final double availableWidth =
                    constraints.maxWidth - (hPadding * 2);
                final double itemWidth = availableWidth / navItems.length;

                final double targetX =
                    hPadding + (_currentIndex * itemWidth) + (itemWidth / 2);

                return TweenAnimationBuilder<double>(
                  tween: Tween(end: targetX),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, currentX, child) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // LA BARRA CON EL CORTE (más sutil que antes)
                        CustomPaint(
                          size: Size(constraints.maxWidth, 68),
                          painter: NotchPainter(
                            notchX: currentX,
                            color: navBarColor,
                            cutRadius: notchCutRadius,
                          ),
                        ),

                        // LA BURBUJA BLANCA FLOTANTE (más chica, menos "peso" visual)
                        Positioned(
                          top: -bubbleSize / 5,
                          left: currentX - (bubbleSize / 2),
                          child: Container(
                            width: bubbleSize,
                            height: bubbleSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: navItems[_currentIndex].hugeIcon != null
                                  ? HugeIcon(
                                      icon: navItems[_currentIndex].hugeIcon!,
                                      color: navBarColor,
                                      size: activeIconSize,
                                    )
                                  : Icon(
                                      navItems[_currentIndex].icon,
                                      color: navBarColor,
                                      size: activeIconSize,
                                    ),
                            ),
                          ),
                        ),

                        // ICONOS INACTIVOS Y ZONA TÁCTIL
                        SizedBox(
                          height: 68,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: hPadding,
                            ),
                            child: Row(
                              children: List.generate(navItems.length, (index) {
                                final item = navItems[index];
                                final isSelected = _currentIndex == index;

                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      setState(() => _currentIndex = index),
                                  child: SizedBox(
                                    width: itemWidth,
                                    child: Center(
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        opacity: isSelected ? 0.0 : 1.0,
                                        child: item.hugeIcon != null
                                            ? HugeIcon(
                                                icon: item.hugeIcon!,
                                                color: inactiveIconColor,
                                                size: inactiveIconSize,
                                              )
                                            : Icon(
                                                item.icon,
                                                color: inactiveIconColor,
                                                size: inactiveIconSize,
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          if (provider.incomingOrderAlert != null)
            Positioned.fill(
              child: IncomingOrderOverlay(order: provider.incomingOrderAlert!),
            ),
        ],
      ),
    );
  }
}

// CUSTOM PAINTER
class NotchPainter extends CustomPainter {
  final double notchX;
  final Color color;
  final double cutRadius;

  NotchPainter({
    required this.notchX,
    required this.color,
    this.cutRadius = 27.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hostRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final hostShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(34),
    );

    final guestRect = Rect.fromCircle(
      center: Offset(notchX, 14),
      radius: cutRadius,
    );
    final guestShape = const CircleBorder();

    final notchedShape = AutomaticNotchedShape(hostShape, guestShape);
    final Path path = notchedShape.getOuterPath(hostRect, guestRect);

    // Sombra
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );

    // Fondo
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant NotchPainter oldDelegate) {
    return oldDelegate.notchX != notchX ||
        oldDelegate.color != color ||
        oldDelegate.cutRadius != cutRadius;
  }
}

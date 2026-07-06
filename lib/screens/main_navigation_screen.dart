import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import 'admin_screen.dart';
import 'sub_screens/admin/admin_map_view.dart';
import 'sub_screens/cliente/cliente_inicio_view.dart';
import 'sub_screens/cliente/cliente_compras_view.dart';
import 'sub_screens/cliente/cliente_tracking_tab.dart';
import 'sub_screens/cliente/cliente_orders_history_view.dart';
import 'sub_screens/repartidor/repartidor_inicio_view.dart';
import 'sub_screens/repartidor/create_order_view.dart';
import 'sub_screens/shared/profile_section.dart';

// SOLUCIÓN: Forzamos el import con ruta relativa exacta por si el package name tiene discrepancias
import 'sub_screens/repartidor/distributor_orders_dashboard.dart';

class BottomNavItem {
  final IconData icon;
  final String label;
  BottomNavItem({required this.icon, required this.label});
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final userRole = provider.userRole;

    // Listado de pantallas limpio y corregido
    final List<Widget> screens = userRole == 'admin'
        ? [const AdminScreen(), const AdminMapView(), const ProfileSection()]
        : (userRole == 'cliente'
              ? [
                  const ClienteInicioView(),
                  const ClienteComprasView(),
                  const ClienteTrackingTab(),
                  const ClienteOrdersHistoryView(),
                  const ProfileSection(),
                ]
              : [
                  const RepartidorInicioView(),
                  DistributorOrdersDashboard(), // <-- Ya no tira error de tipo ni de const
                  const CreateOrderView(),
                  const ProfileSection(),
                ]);

    final List<BottomNavItem> navItems = userRole == 'admin'
        ? [
            BottomNavItem(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin',
            ),
            BottomNavItem(icon: Icons.map_outlined, label: 'Mapa'),
            BottomNavItem(icon: Icons.person_outline, label: 'Perfil'),
          ]
        : (userRole == 'cliente'
              ? [
                  BottomNavItem(icon: Icons.home_outlined, label: 'Inicio'),
                  BottomNavItem(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Comprar',
                  ),
                  BottomNavItem(icon: Icons.map_outlined, label: 'Mapa'),
                  BottomNavItem(icon: Icons.history_outlined, label: 'Pedidos'),
                  BottomNavItem(icon: Icons.person_outline, label: 'Perfil'),
                ]
              : [
                  BottomNavItem(icon: Icons.home_outlined, label: 'Inicio'),
                  BottomNavItem(
                    icon: Icons.local_shipping_outlined,
                    label: 'Viajes',
                  ),
                  BottomNavItem(icon: Icons.add_circle_outline, label: 'Nuevo'),
                  BottomNavItem(icon: Icons.person_outline, label: 'Perfil'),
                ]);

    if (_currentIndex >= navItems.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 96.0),
              child: IndexedStack(index: _currentIndex, children: screens),
            ),
          ),

          // Navbar flotante premium
          Positioned(
            bottom: 26,
            left: 20,
            right: 20,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Slate 900
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final isSelected = _currentIndex == index;

                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : Colors.white60,
                        size: 24,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

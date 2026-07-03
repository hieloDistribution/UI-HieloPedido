import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';
import 'admin_screen.dart';

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

  // Custom Colors
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate850 = Color(0xFF131C2E);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color emeraldAccent = Color(0xFF34D399);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final isPageAdmin = provider.userRole == 'admin';

    // List of screens depending on user role
    final List<Widget> screens = isPageAdmin
        ? [
            const AdminScreen(),
            const ProfileSection(),
          ]
        : [
            const DistributorOrdersDashboard(),
            const CreateOrderView(),
            const ProfileSection(),
          ];

    final List<BottomNavItem> navItems = isPageAdmin
        ? [
            BottomNavItem(icon: Icons.admin_panel_settings, label: 'Admin'),
            BottomNavItem(icon: Icons.person, label: 'Perfil'),
          ]
        : [
            BottomNavItem(icon: Icons.history, label: 'Historial'),
            BottomNavItem(icon: Icons.add_circle_outline, label: 'Nuevo'),
            BottomNavItem(icon: Icons.person, label: 'Perfil'),
          ];

    // Safety check if index out of bounds after role switch
    if (_currentIndex >= navItems.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: slate900,
      body: Stack(
        children: [
          // Viewport
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 90.0), // leave space for bottom floating navbar
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ),

          // Rounded Floating Bottom Navbar
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: slate800.withOpacity(0.95),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final isSelected = _currentIndex == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.cyanAccent.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            color: isSelected ? Colors.cyanAccent : slate400,
                            size: 24,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Text(
                              item.label,
                              style: GoogleFonts.outfit(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ]
                        ],
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

// --- Distributor Dashboard: Order History Section ---
class DistributorOrdersDashboard extends StatelessWidget {
  const DistributorOrdersDashboard({super.key});

  // Custom Colors
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate850 = Color(0xFF131C2E);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color emeraldColor = Color(0xFF10B981);
  static const Color emeraldAccent = Color(0xFF34D399);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final currencyFormatter = NumberFormat.simpleCurrency(locale: 'es_PY', name: 'Gs', decimalDigits: 0);

    final totalOrders = provider.orders.length;
    final unsyncedCount = provider.orders.where((o) => o.isSynced == 0).length;
    final totalRevenue = provider.orders.fold<double>(0.0, (sum, o) => sum + o.total);

    return Scaffold(
      backgroundColor: slate900,
      appBar: AppBar(
        title: Text(
          'Mis Pedidos',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: slate800,
        elevation: 0,
        actions: [
          // Connection Pill
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: provider.isOnline ? emeraldColor.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: provider.isOnline ? emeraldAccent : Colors.amberAccent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  provider.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: provider.isOnline ? emeraldAccent : Colors.amberAccent,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  provider.isOnline ? 'Conectado' : 'Sin Internet',
                  style: GoogleFonts.outfit(
                    color: provider.isOnline ? emeraldAccent : Colors.amberAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync bar if syncing or unsynced pending
          if (provider.isSyncing)
            LinearProgressIndicator(color: Colors.cyanAccent, backgroundColor: Colors.cyan.shade900)
          else if (unsyncedCount > 0 && provider.isOnline)
            GestureDetector(
              onTap: () => provider.syncUnsyncedOrders(),
              child: Container(
                color: Colors.amber.shade900,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tienes $unsyncedCount pedidos pendientes de subir.',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        Text(
                          'Sincronizar ahora',
                          style: GoogleFonts.outfit(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.sync, color: Colors.cyanAccent, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Small Dashboard Metrics
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildDistributorMetric(
                    title: 'Ventas Totales',
                    value: currencyFormatter.format(totalRevenue),
                    icon: Icons.monetization_on_outlined,
                    color: emeraldAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDistributorMetric(
                    title: 'Pendientes',
                    value: '$unsyncedCount',
                    icon: Icons.cloud_off_outlined,
                    color: unsyncedCount > 0 ? Colors.amberAccent : slate500,
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : provider.orders.isEmpty
                    ? Center(
                        child: Text(
                          'No has registrado pedidos hoy.',
                          style: GoogleFonts.outfit(color: slate400),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.orders.length,
                        itemBuilder: (context, index) {
                          final order = provider.orders[index];
                          final formattedDate = DateFormat('HH:mm').format(order.createdAt);

                          return Card(
                            color: slate800,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: slate850),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.clientName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(order.total),
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.cyanAccent,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${order.productName} x${order.quantity}',
                                      style: GoogleFonts.outfit(color: slate300, fontSize: 13),
                                    ),
                                    Row(
                                      children: [
                                        // Sync status indicator
                                        Icon(
                                          order.isSynced == 1 ? Icons.cloud_done : Icons.cloud_queue,
                                          size: 14,
                                          color: order.isSynced == 1 ? emeraldAccent : Colors.amberAccent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          order.isSynced == 1 ? 'Subido' : 'Pendiente',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: order.isSynced == 1 ? emeraldAccent : Colors.amberAccent,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          formattedDate,
                                          style: GoogleFonts.outfit(color: slate500, fontSize: 11),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Eliminar Pedido'),
                                      content: const Text('¿Estás seguro de que deseas eliminar este pedido?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            provider.deleteOrder(order.clientOrderId);
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributorMetric({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slate800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slate850),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 12, color: slate400),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// --- Distributor Dashboard: Create Order Form Section ---
class CreateOrderView extends StatefulWidget {
  const CreateOrderView({super.key});

  @override
  State<CreateOrderView> createState() => _CreateOrderViewState();
}

class _CreateOrderViewState extends State<CreateOrderView> {
  final _formKey = GlobalKey<FormState>();
  final _clientController = TextEditingController();
  final _priceController = TextEditingController();

  final List<Map<String, dynamic>> _catalog = [
    {'id': 'PROD-ICE-001', 'name': 'Bolsa Hielo Cubos 2kg', 'price': 120.00},
    {'id': 'PROD-ICE-002', 'name': 'Bolsa Hielo Cubos 5kg', 'price': 250.00},
    {'id': 'PROD-ICE-003', 'name': 'Bolsa Hielo Molido 10kg', 'price': 450.00},
    {'id': 'PROD-ICE-004', 'name': 'Bolsa Hielo Escamas 15kg', 'price': 600.00},
  ];

  Map<String, dynamic>? _selectedProduct;
  int _quantity = 1;

  @override
  void dispose() {
    _clientController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _selectedProduct != null) {
      final double? price = double.tryParse(_priceController.text);
      if (price == null || price <= 0) return;

      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.addOrder(
        _clientController.text.trim(),
        _selectedProduct!['id'] as String,
        _selectedProduct!['name'] as String,
        _quantity,
        price,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.isOnline
                ? 'Pedido registrado y subido.'
                : 'Pedido guardado localmente (sin internet).',
          ),
          backgroundColor: provider.isOnline ? Colors.green : Colors.amber.shade900,
        ),
      );

      // Reset Form
      setState(() {
        _clientController.clear();
        _priceController.clear();
        _selectedProduct = null;
        _quantity = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Nuevo Pedido',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.icecream, color: Colors.cyanAccent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formulario de Distribución',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Registra ventas de bolsas de hielo al instante',
                            style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Client Name
              TextFormField(
                controller: _clientController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre del Cliente',
                  labelStyle: const TextStyle(color: Colors.white70),
                  floatingLabelStyle: const TextStyle(color: Colors.cyanAccent),
                  prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Por favor introduce el nombre';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Catalog dropdown
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedProduct,
                dropdownColor: const Color(0xFF1E293B),
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Producto (Hielo)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  floatingLabelStyle: const TextStyle(color: Colors.cyanAccent),
                  prefixIcon: const Icon(Icons.ac_unit, color: Colors.cyanAccent),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                ),
                items: _catalog.map((prod) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: prod,
                    child: Text('${prod['name']} (\$${prod['price']})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedProduct = val;
                    if (val != null) {
                      _priceController.text = (val['price'] as double).toStringAsFixed(2);
                    }
                  });
                },
              ),
              const SizedBox(height: 20),

              // Quantity Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cantidad:',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.cyanAccent),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Text(
                        '$_quantity',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
                        onPressed: () {
                          setState(() => _quantity++);
                        },
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 20),

              // Price input (prefilled)
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Precio Pactado (\$)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  floatingLabelStyle: const TextStyle(color: Colors.cyanAccent),
                  prefixIcon: const Icon(Icons.monetization_on, color: Colors.cyanAccent),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Por favor introduce el precio';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Register Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'REGISTRAR PEDIDO',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Profile & Logout Section ---
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final user = provider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Mi Cuenta',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar Placeholder
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan.withOpacity(0.12),
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                ),
                child: const Icon(Icons.person, size: 48, color: Colors.cyanAccent),
              ),
            ),
            const SizedBox(height: 24),

            // Profile info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF131C2E)),
              ),
              child: Column(
                children: [
                  Text(
                    user?.email ?? 'Invitado',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      provider.userRole == 'admin' ? 'ADMINISTRADOR' : 'DISTRIBUIDOR',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Logout Button
            OutlinedButton.icon(
              onPressed: () => provider.logout(),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: Text(
                'Cerrar Sesión',
                style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

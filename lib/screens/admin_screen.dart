import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _selectedDistributorEmail;
  final currencyFormatter = NumberFormat.simpleCurrency(
    locale: 'es_PY',
    name: 'Gs',
    decimalDigits: 0,
  );

  // Custom Colors - Centralizados y optimizados
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate750 = Color(
    0x801E293B,
  ); // 0x80 equivale a 50% de opacidad directamente en HEX
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emeraldAccent = Color(0xFF34D399);
  static const Color cyanCustom = Color(
    0xFF06B6D4,
  ); // Un cyan más integrado para diseño premium

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchAdminOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final allOrders = provider.adminOrders;

    // Extract unique distributors for filter
    final distributors = allOrders
        .map((o) => (o['profiles']?['email'] ?? 'Sin Email') as String)
        .toSet()
        .toList();

    // Filter orders
    final filteredOrders = _selectedDistributorEmail == null
        ? allOrders
        : allOrders
              .where(
                (o) => (o['profiles']?['email'] == _selectedDistributorEmail),
              )
              .toList();

    // Calculate metrics
    final double totalRevenue = filteredOrders.fold(0.0, (sum, item) {
      final double price = (item['price'] as num).toDouble();
      final int qty = item['quantity'] as int;
      return sum + (price * qty);
    });

    final int totalOrdersCount = filteredOrders.length;

    return Scaffold(
      backgroundColor: slate900,
      appBar: AppBar(
        title: Text(
          'Panel Administrador',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: slate800,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: cyanCustom),
            onPressed: () => provider.fetchAdminOrders(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => provider.logout(),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: cyanCustom))
          : RefreshIndicator(
              onRefresh: () => provider.fetchAdminOrders(),
              color: cyanCustom,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Welcome & subtitle
                  Text(
                    'Resumen de Distribución',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitorea las ventas en tiempo real de todos los distribuidores',
                    style: GoogleFonts.outfit(fontSize: 14, color: slate400),
                  ),
                  const SizedBox(height: 20),

                  // Filter dropdown mejorado estéticamente
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: slate800,
                      borderRadius: BorderRadius.circular(
                        14,
                      ), // Bordes un poco más suaves
                      border: Border.all(
                        color: _selectedDistributorEmail != null
                            ? cyanCustom
                            : slate700,
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDistributorEmail,
                        hint: Text(
                          'Filtrar por Distribuidor',
                          style: GoogleFonts.outfit(color: slate400),
                        ),
                        dropdownColor: slate800,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        icon: const Icon(
                          Icons.filter_list,
                          color: slate400,
                        ), // Icono más limpio para filtros
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'Todos los Distribuidores',
                              style: GoogleFonts.outfit(),
                            ),
                          ),
                          ...distributors.map((email) {
                            return DropdownMenuItem<String>(
                              value: email,
                              child: Text(email, style: GoogleFonts.outfit()),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedDistributorEmail = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // KPIs Metrics Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Recaudación Total',
                          value: currencyFormatter.format(totalRevenue),
                          icon: Icons
                              .payments_outlined, // Icono Outline se ve más moderno
                          iconColor: emeraldAccent,
                          bgGradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF065F46), Color(0xFF047857)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Pedidos',
                          value: totalOrdersCount.toString(),
                          icon: Icons
                              .local_shipping_outlined, // Más acorde a distribución de hielo
                          iconColor: cyanCustom,
                          bgGradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Orders list section header
                  Text(
                    'Detalle de Pedidos (${filteredOrders.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Orders list optimizado sin anidamientos pesados de scroll
                  filteredOrders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Text(
                              'No se encontraron pedidos subidos.',
                              style: GoogleFonts.outfit(color: slate400),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap:
                              true, // Se mantiene solo porque está dentro de otro ListView maestro temporalmente
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            final clientName =
                                order['client_name'] as String? ??
                                'Sin Cliente';
                            final prodName =
                                order['product_name'] as String? ??
                                'Sin Producto';
                            final quantity = order['quantity'] as int? ?? 0;
                            final price =
                                (order['price'] as num?)?.toDouble() ?? 0.0;
                            final dateStr =
                                order['created_at'] as String? ?? '';
                            final date = dateStr.isNotEmpty
                                ? DateTime.parse(dateStr)
                                : DateTime.now();
                            final formattedDate = DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(date);
                            final distributorEmail =
                                order['profiles']?['email'] as String? ??
                                'Sin email';

                            return Card(
                              color: slate800,
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                  color: slate700,
                                  width: 1,
                                ), // Corregido el bug de la variable
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.storefront,
                                                size: 18,
                                                color: slate400,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  clientName,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          currencyFormatter.format(
                                            price * quantity,
                                          ),
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: cyanCustom,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Product details con tag estético de cantidad
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: slate900,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$prodName × $quantity',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: slate300,
                                        ),
                                      ),
                                    ),
                                    const Divider(color: slate700, height: 24),

                                    // Metadata row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.badge_outlined,
                                                size: 14,
                                                color: slate400,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  distributorEmail,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: slate400,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.schedule,
                                              size: 14,
                                              color: slate400,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              formattedDate,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: slate400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Gradient bgGradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Icon(icon, size: 22, color: iconColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

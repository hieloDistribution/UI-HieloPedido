import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  final currencyFormatter = NumberFormat.simpleCurrency(
    locale: 'es_PY',
    name: 'Gs',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchAdminOrders();
      Provider.of<OrderProvider>(context, listen: false).fetchRepartidoresLocations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final allOrders = provider.adminOrders;

    final double totalRevenue = allOrders.fold(0.0, (sum, item) {
      final double price = (item['price'] as num).toDouble();
      final int qty = item['quantity'] as int;
      return sum + (price * qty);
    });

    final distributors = allOrders
        .map((o) => (o['profiles']?['email'] ?? 'Sin Email') as String)
        .toSet()
        .toList();

    final repartidores = provider.repartidores;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Panel de Control',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bienvenido al sistema de gestión',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Ingresos Totales',
                        currencyFormatter.format(totalRevenue),
                        HugeIcons.strokeRoundedMoneyBag01,
                        const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Pedidos',
                        '${allOrders.length}',
                        HugeIcons.strokeRoundedShoppingCart01,
                        const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Repartidores',
                        '${repartidores.length}',
                        HugeIcons.strokeRoundedTruck,
                        const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Clientes',
                        '${distributors.length}',
                        HugeIcons.strokeRoundedUserGroup,
                        const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Repartidores en Ruta',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                repartidores.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text(
                            'No hay repartidores en ruta activa.',
                            style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                          ),
                        ),
                      )
                    : Column(
                        children: repartidores.map((rep) {
                          final lastSeenStr = rep['last_seen_at'] as String?;
                          bool isOnline = false;
                          if (lastSeenStr != null) {
                            try {
                              final lastSeen = DateTime.parse(lastSeenStr);
                              isOnline = DateTime.now().toUtc().difference(lastSeen).inSeconds <= 30;
                            } catch (_) {}
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                buildAvatarHelper(
                                  rep['full_name'] ?? 'Repartidor',
                                  rep['avatar_url'] as String?,
                                  radius: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rep['full_name'] ?? 'Repartidor',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${rep['tipo_vehiculo'] ?? ''} ${rep['matricula'] ?? ''}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isOnline ? const Color(0xFFF1F5F9) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isOnline ? const Color(0xFFE2E8F0) : const Color(0xFFFEE2E2),
                                    ),
                                  ),
                                  child: Text(
                                    isOnline ? 'EN LÍNEA' : 'SIN SEÑAL',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isOnline ? const Color(0xFF0F172A) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 24),
                Text(
                  'Últimos Pedidos',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                allOrders.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text(
                            'No hay pedidos registrados.',
                            style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                          ),
                        ),
                      )
                    : Column(
                        children: allOrders.take(5).map((order) {
                          final clientName = order['client_name'] as String? ?? 'Sin Cliente';
                          final prodName = order['product_name'] as String? ?? '';
                          final quantity = order['quantity'] as int? ?? 0;
                          final price = (order['price'] as num?)?.toDouble() ?? 0.0;
                          final dateStr = order['created_at'] as String? ?? '';
                          final formattedDate = dateStr.isNotEmpty
                              ? DateFormat('dd/MM HH:mm').format(DateTime.parse(dateStr))
                              : '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        clientName,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '$prodName × $quantity • $formattedDate',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currencyFormatter.format(price * quantity),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ],
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              HugeIcon(icon: icon, color: accentColor, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

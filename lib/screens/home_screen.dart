import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';
import '../core/theme/colors.dart';
import 'add_order_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final currencyFormatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    // Calculate metrics
    final totalOrders = orderProvider.orders.length;
    final unsyncedCount = orderProvider.orders.where((o) => o.isSynced == 0).length;
    final totalRevenue = orderProvider.orders.fold<double>(0.0, (sum, o) => sum + o.total);

    return Scaffold(
      backgroundColor: TailwindColors.slate50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: TailwindColors.indigo100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2, color: TailwindColors.indigo600, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('OrderFlow'),
          ],
        ),
        actions: [
          // Connection Status Pill
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _buildConnectionPill(orderProvider.isOnline),
          ),
        ],
      ),
      body: Column(
        children: [
          // Synchronization Bar (only displays when sync is running or when pending sync and online)
          if (orderProvider.isSyncing)
            _buildSyncProgressBanner(orderProvider.syncProgress)
          else if (unsyncedCount > 0 && orderProvider.isOnline)
            _buildPendingSyncBanner(context, unsyncedCount),

          // Dashboard Metrics Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Ventas',
                    value: currencyFormatter.format(totalRevenue),
                    icon: Icons.attach_money,
                    color: TailwindColors.indigo600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Pendientes',
                    value: '$unsyncedCount',
                    icon: Icons.cloud_off,
                    color: unsyncedCount > 0 ? TailwindColors.amber600 : TailwindColors.slate500,
                    showSyncIcon: unsyncedCount > 0 && orderProvider.isOnline,
                    onSyncPressed: () => context.read<OrderProvider>().syncUnsyncedOrders(),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),

          // Title / Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedidos Registrados ($totalOrders)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        color: TailwindColors.slate800,
                      ),
                ),
                if (orderProvider.orders.isNotEmpty)
                  const Icon(Icons.filter_list, color: TailwindColors.slate500, size: 20),
              ],
            ),
          ),

          // Order List
          Expanded(
            child: orderProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: TailwindColors.indigo500))
                : orderProvider.orders.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: orderProvider.orders.length,
                        itemBuilder: (context, index) {
                          final order = orderProvider.orders[index];
                          return _buildOrderListItem(context, order, currencyFormatter, index);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddOrderScreen()),
          );
        },
        label: const Text('Nuevo Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, size: 20),
      ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  // Connection indicator badge
  Widget _buildConnectionPill(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOnline ? TailwindColors.emerald50 : TailwindColors.amber50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? TailwindColors.emerald100 : TailwindColors.amber100,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? TailwindColors.emerald500 : TailwindColors.amber500,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1000.ms),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isOnline ? TailwindColors.emerald700 : TailwindColors.amber700,
            ),
          ),
        ],
      ),
    );
  }

  // Banner when sync is actively in progress
  Widget _buildSyncProgressBanner(double progress) {
    return Container(
      color: TailwindColors.indigo50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: TailwindColors.indigo600,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Sincronizando pedidos con la base de datos central...',
              style: TextStyle(fontSize: 13, color: TailwindColors.indigo900, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(fontWeight: FontWeight.bold, color: TailwindColors.indigo900),
          ),
        ],
      ),
    );
  }

  // Banner to prompt sync when online and unsynced files exist
  Widget _buildPendingSyncBanner(BuildContext context, int count) {
    return Container(
      color: TailwindColors.amber50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: TailwindColors.amber600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tenés $count pedido(s) pendientes de sincronizar.',
              style: const TextStyle(fontSize: 13, color: TailwindColors.amber700, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => context.read<OrderProvider>().syncUnsyncedOrders(),
            style: TextButton.styleFrom(
              backgroundColor: TailwindColors.amber500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Sincronizar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).animate().slideY(begin: -1, end: 0, duration: 300.ms);
  }

  // Metric card widget
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool showSyncIcon = false,
    VoidCallback? onSyncPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TailwindColors.slate200),
        boxShadow: [
          BoxShadow(
            color: TailwindColors.slate900.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: TailwindColors.slate500, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TailwindColors.slate800),
              ),
            ],
          ),
          if (showSyncIcon)
            IconButton(
              onPressed: onSyncPressed,
              icon: Icon(Icons.sync, color: color, size: 24),
            ).animate(onPlay: (c) => c.repeat())
             .rotate(duration: 2.seconds)
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
        ],
      ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 64,
                color: TailwindColors.slate300,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'No hay pedidos cargados',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: TailwindColors.slate800,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hacé clic en el botón inferior para cargar el primer pedido del cliente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TailwindColors.slate500, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // Animated Order List Item
  Widget _buildOrderListItem(BuildContext context, OrderModel order, NumberFormat format, int index) {
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
    final isSynced = order.isSynced == 1;

    return Dismissible(
      key: Key(order.clientOrderId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        decoration: BoxDecoration(
          color: TailwindColors.rose100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: TailwindColors.rose700, size: 24),
      ),
      confirmDismiss: (direction) async {
        if (order.clientOrderId.isEmpty) return false;
        context.read<OrderProvider>().deleteOrder(order.clientOrderId);
        return true;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Client Initial Circular Indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSynced ? TailwindColors.emerald50 : TailwindColors.amber50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    order.clientName.isNotEmpty ? order.clientName[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSynced ? TailwindColors.emerald700 : TailwindColors.amber700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Order details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: TailwindColors.slate800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.productName} (x${order.quantity})',
                      style: const TextStyle(
                        color: TailwindColors.slate600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: TailwindColors.slate400, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: TailwindColors.slate400, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Pricing and Sync Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    format.format(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: TailwindColors.indigo600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sync Status Icon/Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSynced ? TailwindColors.emerald50 : TailwindColors.amber50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSynced ? Icons.cloud_done_outlined : Icons.cloud_off,
                          size: 14,
                          color: isSynced ? TailwindColors.emerald600 : TailwindColors.amber600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSynced ? 'Sincronizado' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSynced ? TailwindColors.emerald700 : TailwindColors.amber700,
                          ),
                        ),
                      ],
                    ),
                  ).animate(target: isSynced ? 1.0 : 0.0)
                   .shimmer(duration: 1000.ms, color: Colors.white.withOpacity(0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms, delay: (index * 50).ms).slideX(begin: 0.05, end: 0);
  }
}

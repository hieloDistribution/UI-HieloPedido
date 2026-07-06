import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';

class ClienteOrdersHistoryView extends StatefulWidget {
  const ClienteOrdersHistoryView({super.key});

  @override
  State<ClienteOrdersHistoryView> createState() =>
      _ClienteOrdersHistoryViewState();
}

class _ClienteOrdersHistoryViewState extends State<ClienteOrdersHistoryView> {
  String _selectedFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final currencyFormatter = NumberFormat.simpleCurrency(
      locale: 'es_PY',
      name: 'Gs',
      decimalDigits: 0,
    );

    // Apply Filter
    final List<OrderModel> filteredOrders = provider.orders.where((o) {
      if (_selectedFilter == 'Pendientes') {
        return o.status == 'pendiente' ||
            o.status == 'aceptado' ||
            o.status == 'en_camino';
      } else if (_selectedFilter == 'Entregados') {
        return o.status == 'entregado';
      }
      return true; // 'Todos'
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Historial de Pedidos',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => provider.loadOrders(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: ['Todos', 'Pendientes', 'Entregados'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      filter,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.black,
                    backgroundColor: const Color(0xFFF1F5F9),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyan),
                  )
                : filteredOrders.isEmpty
                ? Center(
                    child: Text(
                      'No hay pedidos en esta categoría.',
                      style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final formattedDate = DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(order.createdAt);

                      Color statusColor = Colors.grey;
                      if (order.status == 'pendiente')
                        statusColor = Colors.amber;
                      if (order.status == 'aceptado') statusColor = Colors.teal;
                      if (order.status == 'en_camino')
                        statusColor = Colors.cyan;
                      if (order.status == 'entregado')
                        statusColor = Colors.green;

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  order.productName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Text(
                                currencyFormatter.format(order.total),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Cantidad: ${order.quantity} | Dirección: ${order.deliveryAddress ?? "S/D"}\nFecha: $formattedDate',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF475569),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order.status.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
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
}

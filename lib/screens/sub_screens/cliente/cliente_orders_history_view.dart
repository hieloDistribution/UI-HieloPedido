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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false).loadOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final currencyFormatter = NumberFormat.simpleCurrency(
      locale: 'es_PY',
      name: 'Gs',
      decimalDigits: 0,
    );

    // Filtrado de estados limpio y reactivo
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
      backgroundColor: const Color(0xFFF8FAFC), // Fondo sutil ultra limpio
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
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: () => provider.loadOrders(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de Categorías Superior Minimalista
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
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
                    elevation: 0,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                    child: CircularProgressIndicator(color: Colors.black),
                  )
                : filteredOrders.isEmpty
                ? Center(
                    child: Text(
                      'No hay registros en esta categoría.',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final formattedDate = DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(order.createdAt);

                      // Lógica de detección de canal de venta (Cliente o Repartidor)
                      final bool isFieldSale = order.productId != 'hielo_bag';

                      Color statusColor = Colors.grey;
                      if (order.status == 'pendiente')
                        statusColor = Colors.amber.shade800;
                      if (order.status == 'aceptado') statusColor = Colors.teal;
                      if (order.status == 'en_camino')
                        statusColor = Colors.cyan.shade700;
                      if (order.status == 'entregado')
                        statusColor = Colors.green.shade700;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fila Superior: Nombre del Producto e Indicador de Venta Directa
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                const SizedBox(width: 8),
                                if (isFieldSale)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.local_shipping_outlined,
                                          size: 12,
                                          color: Color(0xFF475569),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'VENTA DE CAMPO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF475569),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Fila Central: Detalles de cantidad, fecha y dirección
                            Row(
                              children: [
                                const Icon(
                                  Icons.tag,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${order.quantity} Bolsas',
                                  style: GoogleFonts.openSans(
                                    fontSize: 13,
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.openSans(
                                    fontSize: 13,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.pin_drop_outlined,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    order.deliveryAddress ??
                                        "Entrega en Local Comercial",
                                    style: GoogleFonts.openSans(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // Bloque Condicional: Renderiza quién firmó la entrega física del hielo
                            if (order.receivedBy != null &&
                                order.receivedBy!.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(
                                  color: Color(0xFFF1F5F9),
                                  thickness: 1,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.assignment_turned_in_outlined,
                                    size: 14,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Recibido por Físico: ',
                                    style: GoogleFonts.openSans(
                                      fontSize: 12,
                                      color: const Color(0xFF475569),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      order.receivedBy!,
                                      style: GoogleFonts.openSans(
                                        fontSize: 12,
                                        color: const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              child: Divider(
                                color: Color(0xFFF1F5F9),
                                thickness: 1,
                              ),
                            ),

                            // Fila Inferior: Precio Total y Estado de Entrega Estilizado
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Monto Total Carga',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      currencyFormatter.format(order.total),
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.15),
                                    ),
                                  ),
                                  child: Text(
                                    order.status.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

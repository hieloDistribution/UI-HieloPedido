import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/order_provider.dart';
import '../models/order_model.dart';
import 'sub_screens/admin/admin_map_view.dart';
import 'sub_screens/shared/widgets/build_avatar_helper.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _currentTab =
      'Resumen'; // 'Resumen', 'Logística', 'Auditorías', 'Despachos'
  String? _selectedDistributorEmail;

  Timer? _refreshTimer;

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
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchRepartidoresLocations();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final allOrders = provider.adminOrders;

    final distributors = allOrders
        .map((o) => (o['profiles']?['email'] ?? 'Sin Email') as String)
        .toSet()
        .toList();

    final filteredOrders = _selectedDistributorEmail == null
        ? allOrders
        : allOrders
              .where(
                (o) => (o['profiles']?['email'] == _selectedDistributorEmail),
              )
              .toList();

    // Cálculo de métricas comerciales reales
    final double totalRevenue = filteredOrders.fold(0.0, (sum, item) {
      final double price = (item['price'] as num).toDouble();
      final int qty = item['quantity'] as int;
      return sum + (price * qty);
    });

    return Scaffold(
      backgroundColor: const Color(
        0xFFF8FAFC,
      ), // Fondo sutil ultra limpio corporativo
      appBar: AppBar(
        title: Text(
          'Consola de Administración',
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
            onPressed: () {
              provider.fetchAdminOrders();
              provider.fetchRepartidoresLocations();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => provider.logout(),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                // Barra de Pestañas Internas Estilo Chips Planos
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                            'Resumen',
                            'Logística',
                            'Auditorías',
                            'Despachos',
                          ].map((tab) {
                            final isSelected = _currentTab == tab;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(
                                  tab,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFF0F172A),
                                backgroundColor: const Color(0xFFF1F5F9),
                                elevation: 0,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => _currentTab = tab);
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),

                // Contenedor dinámico según sección seleccionada
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildActiveSection(
                      provider,
                      filteredOrders,
                      totalRevenue,
                      distributors,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActiveSection(
    OrderProvider provider,
    List<Map<String, dynamic>> filteredOrders,
    double totalRevenue,
    List<String> distributors,
  ) {
    switch (_currentTab) {
      case 'Resumen':
        return _buildResumenTab(filteredOrders, totalRevenue, distributors);
      case 'Logística':
        return const AdminMapView(); // Consumimos el mapa integrado directamente acá
      case 'Auditorías':
        return _buildAuditoriasTab(provider);
      case 'Despachos':
        return _buildDespachosTab(filteredOrders);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- SECCIÓN 1: RESUMEN BENTO UI ---
  Widget _buildResumenTab(
    List<Map<String, dynamic>> filteredOrders,
    double totalRevenue,
    List<String> distributors,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Dropdown de Filtrado Minimalista
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDistributorEmail,
              hint: Text(
                'Filtrar por Camión/Repartidor',
                style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
              ),
              dropdownColor: Colors.white,
              style: GoogleFonts.outfit(
                color: const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              isExpanded: true,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'Todos los Camiones Activos',
                    style: GoogleFonts.outfit(),
                  ),
                ),
                ...distributors.map(
                  (email) => DropdownMenuItem<String>(
                    value: email,
                    child: Text(email, style: GoogleFonts.outfit()),
                  ),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _selectedDistributorEmail = val),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Fila de Métricas Bento Cards
        Row(
          children: [
            Expanded(
              child: _buildBentoMetricCard(
                title: 'Flujo de Caja Real',
                value: currencyFormatter.format(totalRevenue),
                icon: Icons.payments_outlined,
                accentColor: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoMetricCard(
                title: 'Volumen Cargas',
                value: '${filteredOrders.length} Remitos',
                icon: Icons.local_shipping_outlined,
                accentColor: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- SECCIÓN 3: TAB DE AUDITORÍAS OFFLINE REAL ---
  Widget _buildAuditoriasTab(OrderProvider provider) {
    final repartidoresConUbicacion = provider.repartidores;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Monitoreo de Cobertura y Señal',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Auditoría en tiempo real sobre pérdidas de conectividad y sincronizaciones en ruta.',
          style: GoogleFonts.openSans(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),

        repartidoresConUbicacion.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No hay choferes en ruta activa.'),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: repartidoresConUbicacion.length,
                itemBuilder: (context, index) {
                  final rep = repartidoresConUbicacion[index];

                  // Evaluamos la conexión real del proveedor/repartidor basándonos en last_seen_at
                  bool isDriverOnline = false;
                  final lastSeenStr = rep['last_seen_at'] as String?;
                  if (lastSeenStr != null) {
                    try {
                      final lastSeen = DateTime.parse(lastSeenStr);
                      final difference = DateTime.now().toUtc().difference(lastSeen);
                      isDriverOnline = difference.inSeconds <= 30;
                    } catch (_) {
                      isDriverOnline = false;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        buildAvatarHelper(
                          rep['full_name'] ?? 'Chofer',
                          rep['avatar_url'] as String?,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rep['full_name'] ?? 'Distribuidor',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Unidad: ${rep['tipo_vehiculo']} • Patente: ${rep['matricula']}',
                                style: GoogleFonts.openSans(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge Dinámico Inteligente en Blanco y Negro / Rojo Sutil
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDriverOnline
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDriverOnline
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFFFEE2E2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDriverOnline ? Icons.wifi : Icons.wifi_off,
                                size: 12,
                                color: isDriverOnline
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDriverOnline ? 'SEÑAL OK' : 'SIN CONEXIÓN',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDriverOnline
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFEF4444),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  // --- SECCIÓN 4: HISTORIAL CRUDO DE DESPACHOS ---
  Widget _buildDespachosTab(List<Map<String, dynamic>> filteredOrders) {
    if (filteredOrders.isEmpty) {
      return Center(
        child: Text(
          'No se registraron movimientos.',
          style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        final clientName = order['client_name'] as String? ?? 'Sin Cliente';
        final prodName = order['product_name'] as String? ?? 'Sin Producto';
        final quantity = order['quantity'] as int? ?? 0;
        final price = (order['price'] as num?)?.toDouble() ?? 0.0;
        final dateStr = order['created_at'] as String? ?? '';
        final formattedDate = dateStr.isNotEmpty
            ? DateFormat('dd/MM HH:mm').format(DateTime.parse(dateStr))
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$prodName × $quantity Bolsas • $formattedDate',
                      style: GoogleFonts.openSans(
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
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBentoMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
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
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

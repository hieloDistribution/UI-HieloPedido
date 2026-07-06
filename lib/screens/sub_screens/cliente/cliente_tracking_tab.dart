import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import '../shared/widgets/build_avatar_helper.dart';
import '../shared/widgets/request_ice_dialog.dart';

class ClienteTrackingTab extends StatefulWidget {
  const ClienteTrackingTab({super.key});

  @override
  State<ClienteTrackingTab> createState() => _ClienteTrackingTabState();
}

class _ClienteTrackingTabState extends State<ClienteTrackingTab> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).loadOrders();
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false).loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _showDriverRatingDialog(
    BuildContext context,
    OrderProvider provider,
    OrderModel order,
  ) {
    double selectedRating = 5.0;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              title: Center(
                child: Text(
                  '¿Qué te pareció el repartidor?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Calificá tu experiencia de entrega con el repartidor:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.openSans(
                      color: const Color(0xFF475569),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stars Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final isSelected = starIndex <= selectedRating;
                      return IconButton(
                        icon: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = starIndex.toDouble();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Review Comment Field
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: 'Escribe tu reseña (Opcional)',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyan),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    provider.markOrderAsRated(order.clientOrderId);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Omitir',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (order.repartidorId != null) {
                      await provider.submitDriverReview(
                        order.repartidorId!,
                        selectedRating,
                      );
                    }
                    provider.markOrderAsRated(order.clientOrderId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Gracias por calificar!'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Enviar reseña',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);

    // Find any active order that is accepted or en_route
    final activeOrder = provider.orders.firstWhere(
      (o) => o.status == 'aceptado' || o.status == 'en_camino',
      orElse: () => OrderModel(
        clientOrderId: '',
        userId: '',
        clientName: '',
        productId: '',
        productName: '',
        quantity: 0,
        price: 0,
        createdAt: DateTime.now(),
      ),
    );

    // If there is an active order, show Map Tracking View
    if (activeOrder.clientOrderId.isNotEmpty) {
      return ClientTrackingView(order: activeOrder);
    }

    // Check if the most recent order is 'entregado' and hasn't been rated
    final latestOrder = provider.orders.isNotEmpty
        ? provider.orders.first
        : null;
    final showRatingCard =
        latestOrder != null &&
        latestOrder.status == 'entregado' &&
        !provider.ratedOrderIds.contains(latestOrder.clientOrderId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Seguimiento en Vivo',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock Icon Illustration
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.cyan,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Seguimiento Bloqueado',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'El mapa se activará en tiempo real en cuanto realices un pedido y el repartidor lo acepte y comience el viaje.',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Rating Card (if last order is delivered but not rated)
              if (showRatingCard) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '¡Tu último pedido ya fue entregado! 🎉',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ayúdanos a mejorar calificando el servicio de tu repartidor.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _showDriverRatingDialog(
                          context,
                          provider,
                          latestOrder,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Calificar Repartidor',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --- Cliente Live tracking View (Uber style map tracking) ---
class ClientTrackingView extends StatefulWidget {
  final OrderModel order;
  const ClientTrackingView({super.key, required this.order});

  @override
  State<ClientTrackingView> createState() => _ClientTrackingViewState();
}

class _ClientTrackingViewState extends State<ClientTrackingView> {
  Timer? _timer;
  final MapController _mapController = MapController();
  bool _hasCentered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchRepartidoresLocations();
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        Provider.of<OrderProvider>(
          context,
          listen: false,
        ).fetchRepartidoresLocations();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final driver = provider.repartidores.firstWhere(
      (r) => r['id'] == widget.order.repartidorId,
      orElse: () => <String, dynamic>{},
    );

    final double? driverLat = driver.isNotEmpty
        ? driver['last_latitude'] as double?
        : null;
    final double? driverLng = driver.isNotEmpty
        ? driver['last_longitude'] as double?
        : null;

    if (driverLat != null && driverLng != null && !_hasCentered) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(driverLat, driverLng), 15.0);
      });
    }

    final markers = <Marker>[];
    if (driverLat != null && driverLng != null) {
      markers.add(
        Marker(
          point: LatLng(driverLat, driverLng),
          width: 70,
          height: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.cyan, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/repartidor.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.cyan, size: 15),
            ],
          ),
        ),
      );
    }

    final String etaText = widget.order.status == 'en_camino'
        ? "Llegada en ~8 min"
        : "Preparando pedido...";

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Voyager Light Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  driverLat ?? -26.18500,
                  driverLng ?? -58.17417,
                ),
                initialZoom: 14.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.empresa.order_flow',
                ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.delivery_dining,
                    color: Colors.cyan,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.order.status == 'en_camino'
                              ? '¡Tu pedido va en camino!'
                              : 'Pedido Aceptado',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          widget.order.status == 'en_camino'
                              ? 'Seguí al repartidor en tiempo real.'
                              : 'El repartidor está organizando el despacho.',
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.order.status.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: Colors.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Uber-style Floating bottom card
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: buildAvatarHelper(
                            driver['full_name'] ?? 'Repartidor',
                            driver['avatar_url'] as String?,
                            radius: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver['full_name'] ?? 'Asignando repartidor...',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${driver['tipo_vehiculo'] ?? 'Moto'} • ${driver['matricula'] ?? 'Patente S/M'}',
                              style: GoogleFonts.openSans(
                                fontSize: 12,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${driver['stars'] ?? '5.0'}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    color: Color(0xFFE2E8F0),
                    height: 24,
                    thickness: 1,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: Colors.cyan,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            etaText,
                            style: GoogleFonts.outfit(
                              color: Colors.cyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyan.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'CÓDIGO: ${widget.order.verificationCode ?? '----'}',
                          style: GoogleFonts.outfit(
                            color: Colors.cyan,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

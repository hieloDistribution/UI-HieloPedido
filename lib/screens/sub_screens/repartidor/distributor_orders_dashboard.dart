import 'dart:async'
    as async; // Alias para evitar colisión de nombres con la clase Timer de dart:ui
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import '../shared/widgets/build_avatar_helper.dart';

class DistributorOrdersDashboard extends StatefulWidget {
  const DistributorOrdersDashboard({super.key});

  @override
  State<DistributorOrdersDashboard> createState() =>
      _DistributorOrdersDashboardState();
}

class _DistributorOrdersDashboardState extends State<DistributorOrdersDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color cyanCustom = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openRouteMapView(BuildContext context, OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => _RouteMapScreen(order: order)),
    );
  }

  Widget _buildDashboardDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cyanCustom),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationCodeDialog(
    BuildContext context,
    OrderProvider provider,
    OrderModel order,
  ) {
    final codeController = TextEditingController();
    final receivedByController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              title: Text(
                'Confirmar Entrega',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escribe el nombre de la persona que retira e ingresa el código de 4 dígitos:',
                    style: GoogleFonts.openSans(
                      color: const Color(0xFF475569),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: receivedByController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: '¿Quién recibe el producto?',
                      hintText: 'Ej: Juan (Empleado), Carlos (Cajero)',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.black),
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Código de Entrega',
                      labelStyle: const TextStyle(color: Color(0xFF64748B)),
                      counterStyle: const TextStyle(color: Color(0xFF64748B)),
                      errorText: errorMessage,
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyan),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final who = receivedByController.text.trim();
                    if (who.isEmpty) {
                      setDialogState(
                        () => errorMessage = 'Por favor, ingresá quién recibe',
                      );
                      return;
                    }
                    final enteredCode = codeController.text.trim();
                    if (enteredCode.length != 4) {
                      setDialogState(
                        () => errorMessage = 'El código debe tener 4 dígitos',
                      );
                      return;
                    }
                    final success = await provider.confirmDelivery(
                      order.clientOrderId,
                      enteredCode,
                      who,
                    );
                    if (success && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Entrega confirmada con éxito!'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    } else {
                      setDialogState(
                        () => errorMessage =
                            'Código incorrecto. Inténtalo de nuevo.',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Confirmar',
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
    final currencyFormatter = NumberFormat.simpleCurrency(
      locale: 'es_PY',
      name: 'Gs',
      decimalDigits: 0,
    );
    final availableOrders = provider.orders.where((o) {
      final isPending = o.status == 'pendiente';
      final isAcceptedByOther = o.status == 'aceptado' && o.repartidorId != provider.currentUser?.id;
      
      if (isPending) {
        // Si está asignado a otro repartidor, no mostrarlo a los demás en la lista hasta pasar 30s
        if (o.repartidorId != null && o.repartidorId != provider.currentUser?.id) {
          final elapsedSec = DateTime.now().difference(o.createdAt).inSeconds;
          if (elapsedSec < 30) {
            return false;
          }
        }
        return true;
      }
      return isAcceptedByOther;
    }).toList();
    final myDeliveries = provider.orders
        .where((o) => o.repartidorId == provider.currentUser?.id)
        .toList();

    return Scaffold(
      backgroundColor: slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Entregas de Hielo',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: slate900,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: slate900,
          labelColor: slate900,
          unselectedLabelColor: slate400,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'Disponibles (${availableOrders.length})'),
            Tab(text: 'Mis Viajes (${myDeliveries.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Disponibles
          availableOrders.isEmpty
              ? Center(
                  child: Text(
                    'No hay pedidos disponibles.',
                    style: GoogleFonts.outfit(color: slate400),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: availableOrders.length,
                  itemBuilder: (context, index) {
                    final order = availableOrders[index];
                    final formattedDate = DateFormat(
                      'dd/MM HH:mm',
                    ).format(order.createdAt);
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: slate200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                buildAvatarHelper(
                                  order.clientName,
                                  order.clientAvatarUrl,
                                  radius: 18,
                                  fontSize: 12,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    order.clientName,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: slate900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  currencyFormatter.format(order.total),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: cyanCustom,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildDashboardDetailRow(
                              Icons.icecream_outlined,
                              'Producto solicitado',
                              order.productName,
                            ),
                            _buildDashboardDetailRow(
                              Icons.shopping_bag_outlined,
                              'Cantidad de bolsas',
                              '${order.quantity} bolsas',
                            ),
                            _buildDashboardDetailRow(
                              Icons.payments_outlined,
                              'Medio de pago',
                              order.paymentMethod.toUpperCase(),
                            ),
                            const Divider(color: slate200, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.openSans(
                                    color: slate400,
                                    fontSize: 11,
                                  ),
                                ),
                                if (order.status == 'aceptado')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.teal.withOpacity(0.15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 14,
                                          color: Colors.teal,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Aceptado por ${order.repartidorName ?? 'otro repartidor'}',
                                          style: GoogleFonts.outfit(
                                            color: Colors.teal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () =>
                                        provider.acceptOrder(order.clientOrderId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Aceptar Pedido',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          // Tab 2: Mis Viajes
          myDeliveries.isEmpty
              ? Center(
                  child: Text(
                    'No tienes viajes asignados.',
                    style: GoogleFonts.outfit(color: slate400),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myDeliveries.length,
                  itemBuilder: (context, index) {
                    final order = myDeliveries[index];
                    final formattedDate = DateFormat(
                      'dd/MM HH:mm',
                    ).format(order.createdAt);
                    Color statusColor = order.status == 'en_camino'
                        ? cyanCustom
                        : (order.status == 'entregado'
                              ? Colors.green
                              : Colors.amber);

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                buildAvatarHelper(
                                  order.clientName,
                                  order.clientAvatarUrl,
                                  radius: 18,
                                  fontSize: 12,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    order.clientName,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: slate900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    order.status.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildDashboardDetailRow(
                              Icons.icecream_outlined,
                              'Producto solicitado',
                              order.productName,
                            ),
                            _buildDashboardDetailRow(
                              Icons.shopping_bag_outlined,
                              'Cantidad de bolsas',
                              '${order.quantity} bolsas',
                            ),
                            _buildDashboardDetailRow(
                              Icons.payments_outlined,
                              'Medio de pago',
                              order.paymentMethod.toUpperCase(),
                            ),
                            Text(
                              '📱 Teléfono: ${order.clientPhone ?? "S/D"}',
                              style: GoogleFonts.openSans(
                                color: const Color(0xFF334155),
                                fontSize: 13,
                              ),
                            ),
                            const Divider(color: slate200, height: 20),
                            if (order.status == 'aceptado') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openRouteMapView(context, order),
                                      icon: const Icon(
                                        Icons.map_outlined,
                                        size: 16,
                                        color: Colors.black87,
                                      ),
                                      label: Text(
                                        'Ver Ruta',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        side: const BorderSide(color: slate200),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await provider.startDelivery(order.clientOrderId);
                                        } catch (e) {
                                          if (context.mounted) {
                                            String errorMsg = e.toString().replaceAll('Exception:', '').trim();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error al iniciar viaje: $errorMsg'),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Iniciar Viaje',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (order.status == 'en_camino') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openRouteMapView(context, order),
                                      icon: const Icon(
                                        Icons.navigation_outlined,
                                        size: 16,
                                        color: cyanCustom,
                                      ),
                                      label: Text(
                                        'Ruta GPS',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: cyanCustom,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        side: const BorderSide(
                                          color: cyanCustom,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _showConfirmationCodeDialog(
                                            context,
                                            provider,
                                            order,
                                          ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Confirmar Entrega',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (order.status == 'entregado') ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Completado el $formattedDate',
                                    style: GoogleFonts.openSans(
                                      color: slate400,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

// --- Sub-pantalla de Hoja de Ruta Ultra Fluida con simulación interpolada paso a paso ---
class _RouteMapScreen extends StatefulWidget {
  final OrderModel order;
  const _RouteMapScreen({required this.order});

  @override
  State<_RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<_RouteMapScreen> {
  List<LatLng> _rawRoutePoints = [];
  List<LatLng> _interpolatedRoutePoints = [];
  bool _isLoadingRoute = true;

  late LatLng _driverPosition;
  late LatLng _destination;

  async.Timer?
  _simulationTimer; // Uso explícito del alias asasync para anular conflictos
  int _currentStepIndex = 0;

  int _remainingMinutes = 0;
  double _remainingMeters = 0.0;

  @override
  void initState() {
    super.initState();

    _destination = const LatLng(-26.18500, -58.17417);
    if (widget.order.deliveryLatitude != null &&
        widget.order.deliveryLongitude != null) {
      _destination = LatLng(
        widget.order.deliveryLatitude!,
        widget.order.deliveryLongitude!,
      );
    }

    _driverPosition = LatLng(
      _destination.latitude - 0.003,
      _destination.longitude - 0.003,
    );
    _initializeRealGpsAndRoute();
  }

  Future<void> _initializeRealGpsAndRoute() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition();
          if (mounted) {
            setState(() {
              _driverPosition = LatLng(position.latitude, position.longitude);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al capturar ubicación real: $e');
    }
    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_driverPosition.longitude},${_driverPosition.latitude};'
        '${_destination.longitude},${_destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'order_flow_app'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coordinates = routes[0]['geometry']['coordinates'] as List?;
          if (coordinates != null && mounted) {
            _rawRoutePoints = coordinates
                .map<LatLng>(
                  (coord) => LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  ),
                )
                .toList();

            _generateSmoothInterpolation();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error al trazar ruta OSRM: $e');
    }

    if (mounted) {
      _rawRoutePoints = [_driverPosition, _destination];
      _generateSmoothInterpolation();
    }
  }

  void _generateSmoothInterpolation() {
    if (_rawRoutePoints.length < 2) return;
    List<LatLng> smoothPoints = [];

    for (int i = 0; i < _rawRoutePoints.length - 1; i++) {
      LatLng start = _rawRoutePoints[i];
      LatLng end = _rawRoutePoints[i + 1];
      int segments = 15;

      for (int j = 0; j <= segments; j++) {
        double t = j / segments;
        double lat = start.latitude + (end.latitude - start.latitude) * t;
        double lng = start.longitude + (end.longitude - start.longitude) * t;
        smoothPoints.add(LatLng(lat, lng));
      }
    }

    if (mounted) {
      setState(() {
        _interpolatedRoutePoints = smoothPoints;
        _isLoadingRoute = false;
        _currentStepIndex = 0;
        _calculateEtaMetrics();
      });
      _startJourneySimulation();
    }
  }

  void _calculateEtaMetrics() {
    int pointsLeft = _interpolatedRoutePoints.length - _currentStepIndex;
    _remainingMeters = pointsLeft * 8.5;
    _remainingMinutes = (_remainingMeters / 280).ceil();
  }

  void _startJourneySimulation() {
    if (_interpolatedRoutePoints.isEmpty) return;
    _simulationTimer?.cancel();

    _simulationTimer = async.Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentStepIndex < _interpolatedRoutePoints.length - 1) {
        _currentStepIndex++;
        setState(() {
          _driverPosition = _interpolatedRoutePoints[_currentStepIndex];
          _calculateEtaMetrics();
        });
      } else {
        timer.cancel();
        _showArrivalCodeDialog();
      }
    });
  }

  void _showArrivalCodeDialog() {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final List<TextEditingController> otpControllers = List.generate(
      4,
      (_) => TextEditingController(),
    );
    final List<FocusNode> otpFocusNodes = List.generate(4, (_) => FocusNode());
    final receivedByController = TextEditingController();
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sports_motorsports_outlined,
                      color: Colors.teal,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '¡Destino Llegado! ❄️',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Escribí quién recibe e ingresá el código de 4 dígitos para validar la entrega:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: receivedByController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: '¿Quién recibe el producto?',
                      hintText: 'Ej: Juan (Empleado), Carlos (Cajero)',
                      labelStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      return SizedBox(
                        width: 44,
                        child: TextField(
                          controller: otpControllers[index],
                          focusNode: otpFocusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.cyan,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (val) async {
                            if (val.isNotEmpty) {
                              if (index < 3) {
                                FocusScope.of(
                                  ctx,
                                ).requestFocus(otpFocusNodes[index + 1]);
                              } else {
                                otpFocusNodes[index].unfocus();

                                final who = receivedByController.text.trim();
                                if (who.isEmpty) {
                                  setModalState(() {
                                    errorMsg = 'Debes indicar quién recibe';
                                    for (var c in otpControllers) {
                                      c.clear();
                                    }
                                    FocusScope.of(ctx).requestFocus(otpFocusNodes[0]);
                                  });
                                  return;
                                }

                                String code = otpControllers
                                    .map((c) => c.text)
                                    .join();
                                final success = await provider.confirmDelivery(
                                  widget.order.clientOrderId,
                                  code,
                                  who,
                                );
                                if (success) {
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '¡Entrega completada con éxito! 📦',
                                        ),
                                        backgroundColor: Colors.teal,
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {
                                    errorMsg = 'Código inválido';
                                    for (var c in otpControllers) {
                                      c.clear();
                                    }
                                    FocusScope.of(
                                      ctx,
                                    ).requestFocus(otpFocusNodes[0]);
                                  });
                                }
                              }
                            } else if (val.isEmpty && index > 0) {
                              FocusScope.of(
                                ctx,
                              ).requestFocus(otpFocusNodes[index - 1]);
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: GoogleFonts.outfit(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context, listen: false);

    List<LatLng> activeRouteSegment = [];
    if (!_isLoadingRoute &&
        _currentStepIndex < _interpolatedRoutePoints.length) {
      activeRouteSegment = _interpolatedRoutePoints.sublist(_currentStepIndex);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hoja de Ruta Real',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _destination,
              zoom: 15.0,
            ),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            polylines: {
              if (!_isLoadingRoute && activeRouteSegment.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('active_route'),
                  points: activeRouteSegment,
                  color: const Color(0xFF06B6D4),
                  width: 5,
                ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('driver'),
                position: _driverPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                onTap: () => _openDriverDetailSheet(context, provider),
              ),
              Marker(
                markerId: const MarkerId('destination'),
                position: _destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                onTap: () => _openClientDetailSheet(context, widget.order),
              ),
            },
          ),
          if (_isLoadingRoute)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
            ),

          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Entregando a: ${widget.order.clientName}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _remainingMinutes > 0
                              ? 'Llega en $_remainingMinutes min'
                              : 'Arribando...',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Distancia restante: ${_remainingMeters.toStringAsFixed(0)} metros.',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDriverDetailSheet(BuildContext context, OrderProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final oName = provider.currentUserFullName ?? 'Mi Perfil';
        final phone = provider.currentUserCelular ?? 'No registrado';
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  buildAvatarHelper(
                    oName,
                    provider.currentUserAvatarUrl,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          oName,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Repartidor en Ruta',
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(
                color: Color(0xFFF1F5F9),
                height: 24,
                thickness: 1.5,
              ),
              _buildSheetRow(
                Icons.phone_android_outlined,
                "Celular:",
                phone,
              ),
              const SizedBox(height: 8),
              _buildSheetRow(
                Icons.directions_car_outlined,
                "Rol Activo:",
                "Logística y Entrega",
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Cerrar',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openClientDetailSheet(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  buildAvatarHelper(
                    order.clientName,
                    order.clientAvatarUrl,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Destinatario de Entrega',
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(
                color: Color(0xFFF1F5F9),
                height: 24,
                thickness: 1.5,
              ),
              _buildSheetRow(
                Icons.location_on_outlined,
                "Dirección de Entrega:",
                order.deliveryAddress ?? 'Ubicación Fija',
              ),
              const SizedBox(height: 8),
              _buildSheetRow(
                Icons.phone_android_outlined,
                "Celular Cliente:",
                order.clientPhone ?? 'No registrado',
              ),
              const SizedBox(height: 8),
              _buildSheetRow(
                Icons.shopping_bag_outlined,
                "Carga Solicitada:",
                "${order.quantity} bolsas de ${order.productName}",
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Cerrar',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

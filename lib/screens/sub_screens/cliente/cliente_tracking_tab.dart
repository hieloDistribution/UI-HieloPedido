import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import '../shared/widgets/build_avatar_helper.dart';

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
                    'Calificá tu experiencia de entrega en tu local comercial:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.openSans(
                      color: const Color(0xFF475569),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final isSelected = starIndex <= selectedRating;
                      return IconButton(
                        icon: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 38,
                        ),
                        onPressed: () => setDialogState(
                          () => selectedRating = starIndex.toDouble(),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText:
                          'Escribe una breve reseña de la entrega (Opcional)...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black),
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
                  child: Text(
                    'Omitir',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
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
                          content: Text('¡Gracias por calificar la entrega!'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    'Enviar Reseña',
                    style: GoogleFonts.outfit(
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

    OrderModel trackingOrder = provider.orders.firstWhere(
      (o) =>
          o.status == 'pendiente' ||
          o.status == 'aceptado' ||
          o.status == 'en_camino',
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

    if (trackingOrder.clientOrderId.isEmpty && provider.orders.isNotEmpty) {
      trackingOrder = provider.orders.first;
    }

    if (trackingOrder.clientOrderId.isNotEmpty) {
      return ClientTrackingView(
        order: trackingOrder,
        onShowRating: () =>
            _showDriverRatingDialog(context, provider, trackingOrder),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Seguimiento de Distribución',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.route_outlined,
                  color: Colors.cyan,
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Inicializando Ruta...',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Generá un pedido desde tu panel comercial para activar la ruta interactiva de entrega en tiempo real.',
                textAlign: DateTime.now().isAfter(DateTime(2026))
                    ? TextAlign.center
                    : TextAlign.left,
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientTrackingView extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onShowRating;
  const ClientTrackingView({
    super.key,
    required this.order,
    required this.onShowRating,
  });

  @override
  State<ClientTrackingView> createState() => _ClientTrackingViewState();
}

class _ClientTrackingViewState extends State<ClientTrackingView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchRepartidoresLocations();
    });
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
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

  void _openDriverDetailSheet(
    BuildContext context,
    Map<String, dynamic> driver,
    String eta,
  ) {
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
                    driver['full_name'] ?? 'Chofer',
                    driver['avatar_url'] as String?,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver['full_name'] ?? 'Repartidor Asignado',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${driver['stars'] ?? '5.0'} • Logística de Campo',
                              style: GoogleFonts.openSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
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
                Icons.local_shipping_outlined,
                "Vehículo:",
                driver['tipo_vehiculo'] ?? 'Unidad de Distribución',
              ),
              const SizedBox(height: 8),
              _buildSheetRow(
                Icons.badge_outlined,
                "N° Matrícula:",
                driver['matricula'] ?? 'Patente Oficial',
              ),
              const SizedBox(height: 8),
              _buildSheetRow(Icons.access_time, "Arribo Estimado:", eta),
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
                    'Cerrar Panel',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.openSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);

    final driver = provider.repartidores.firstWhere(
      (r) => r['id'] == widget.order.repartidorId,
      orElse: () => provider.repartidores.isNotEmpty
          ? provider.repartidores.first
          : <String, dynamic>{},
    );

    final String etaText = widget.order.status == 'en_camino'
        ? "Llegada en ~8 min"
        : "Preparando pedido...";

    // Mapeo numérico del estado para el caminito Duolingo
    int currentStep = 0;
    if (widget.order.status == 'pendiente') currentStep = 0;
    if (widget.order.status == 'aceptado') currentStep = 1;
    if (widget.order.status == 'en_camino') currentStep = 2;
    if (widget.order.status == 'entregado') currentStep = 3;

    String statusDisplay = widget.order.status.toUpperCase();
    if (widget.order.status == 'pendiente') statusDisplay = 'PENDIENTE';
    else if (widget.order.status == 'aceptado') statusDisplay = 'ACEPTADO';
    else if (widget.order.status == 'en_camino') statusDisplay = 'EN CAMINO';
    else if (widget.order.status == 'entregado') statusDisplay = 'ENTREGADO';
    else if (widget.order.status == 'cancelado') statusDisplay = 'CANCELADO';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Seguimiento de Carga',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // --- NUEVO DISEÑO: CAMINITO INTERACTIVO ESTILO DUOLINGO ---
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 100,
                bottom: 220,
                left: 24,
                right: 24,
              ),
              child: Column(
                children: [
                  _buildDuolingoStep(
                    stepIndex: 0,
                    currentStep: currentStep,
                    title: 'Pedido Enviado',
                    subtitle: widget.order.status == 'pendiente'
                        ? 'Tu pedido de ${widget.order.productName} ha sido enviado y está pendiente de aceptación.'
                        : 'Tu pedido fue recibido y procesado.',
                    icon: Icons.assignment_outlined,
                  ),
                  _buildDuolingoLine(isActive: currentStep > 0),
                  _buildDuolingoStep(
                    stepIndex: 1,
                    currentStep: currentStep,
                    title: 'Pedido Aceptado',
                    subtitle: currentStep >= 1
                        ? (widget.order.repartidorName != null
                            ? 'Aceptado por el repartidor ${widget.order.repartidorName}.'
                            : (driver.isNotEmpty
                                ? 'Aceptado por ${driver['full_name']}.'
                                : 'Pedido aceptado por un repartidor.'))
                        : 'Esperando que un repartidor acepte el pedido...',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _buildDuolingoLine(isActive: currentStep > 1),
                  _buildDuolingoStep(
                    stepIndex: 2,
                    currentStep: currentStep,
                    title: 'En Camino',
                    subtitle: widget.order.status == 'en_camino'
                        ? 'El repartidor está en ruta hacia tu local comercial.'
                        : 'El camión iniciará la entrega al confirmar la ruta.',
                    icon: Icons.local_shipping_outlined,
                  ),
                  _buildDuolingoLine(isActive: currentStep > 2),
                  _buildDuolingoStep(
                    stepIndex: 3,
                    currentStep: currentStep,
                    title: 'Entregado',
                    subtitle: widget.order.status == 'entregado'
                        ? '¡Pedido entregado con éxito! 🎉'
                        : 'Esperando confirmación de descarga en el local.',
                    icon: Icons.check_circle_outline,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),

          // Barra Superior Minimalista de Estado Operativo Real
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.98),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.route_outlined,
                    color: Color(0xFF0F172A),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Estado del Despacho',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Dirección comercial: ${widget.order.deliveryAddress ?? "Local Verificado"}',
                          style: GoogleFonts.openSans(
                            fontSize: 11,
                            color: const Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.order.status == 'pendiente'
                          ? Colors.amber.shade700
                          : widget.order.status == 'aceptado'
                              ? Colors.blue.shade600
                              : widget.order.status == 'en_camino'
                                  ? Colors.indigo.shade600
                                  : widget.order.status == 'entregado'
                                      ? Colors.teal.shade600
                                      : Colors.red.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusDisplay,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Uber-Style Panel Flotante Inferior de Arribo
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      if (driver.isNotEmpty) {
                        _openDriverDetailSheet(context, driver, etaText);
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(23),
                            child: buildAvatarHelper(
                              driver['full_name'] ?? 'Chofer',
                              driver['avatar_url'] as String?,
                              radius: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver['full_name'] ?? 'Buscando Repartidor...',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${driver['tipo_vehiculo'] ?? 'Logística'} • ${driver['matricula'] ?? 'Patente'}',
                                style: GoogleFonts.openSans(
                                  fontSize: 12,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
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
                            color: Color(0xFF0F172A),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            etaText,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF0F172A),
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
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'TOKEN: ${widget.order.verificationCode ?? '----'}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF0F172A),
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

  // Helper Widget para construir los nodos estilizados del caminito Duolingo
  Widget _buildDuolingoStep({
    required int stepIndex,
    required int currentStep,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isLast = false,
  }) {
    final bool isCompleted = currentStep > stepIndex;
    final bool isCurrent = currentStep == stepIndex;

    Color nodeColor = const Color(0xFFE2E8F0);
    Color iconColor = const Color(0xFF94A3B8);
    double scale = 1.0;

    if (isCompleted) {
      nodeColor = Colors.black;
      iconColor = Colors.white;
    } else if (isCurrent) {
      nodeColor = const Color(0xFF0EA5E9); // Cyan de progreso activo
      iconColor = Colors.white;
      scale = 1.15; // Efecto de foco sutil al nodo activo
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: nodeColor,
              shape: BoxShape.circle,
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCurrent
                        ? const Color(0xFF0EA5E9)
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper Widget para dibujar las líneas conectoras del camino
  Widget _buildDuolingoLine({required bool isActive}) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(left: 22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 3,
        height: 36,
        color: isActive ? Colors.black : const Color(0xFFE2E8F0),
      ),
    );
  }
}

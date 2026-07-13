import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import '../shared/widgets/build_avatar_helper.dart';

class IncomingOrderOverlay extends StatefulWidget {
  final OrderModel order;

  const IncomingOrderOverlay({super.key, required this.order});

  @override
  State<IncomingOrderOverlay> createState() => _IncomingOrderOverlayState();
}

class _IncomingOrderOverlayState extends State<IncomingOrderOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnimation;
  double _slidePosition = 0.0;
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuad,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context, listen: false);

    // Coordenadas para el mapa conectado punto a punto
    final double shopLat = widget.order.deliveryLatitude ?? -26.18310;
    final double shopLng = widget.order.deliveryLongitude ?? -58.17520;
    final double driverLat =
        provider.currentRepartidorPosition?.latitude ?? -26.18500;
    final double driverLng =
        provider.currentRepartidorPosition?.longitude ?? -58.17417;

    return Material(
      color: Colors.black.withOpacity(0.3), // Fondo semitransparente muy sutil
      child: Stack(
        children: [
          // Al hacer clic fuera (en la zona superior), se ignora/descarta la alerta
          Positioned.fill(
            child: GestureDetector(
              onTap: () => provider.rejectIncomingOrder(widget.order.clientOrderId),
              child: Container(color: Colors.transparent),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _offsetAnimation,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🗺️ 1. MAPA CONECTADO PUNTO A PUNTO (OCUPA LA PARTE SUPERIOR DEL MODAL)
                    SizedBox(
                      height: 180,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              (shopLat + driverLat) / 2,
                              (shopLng + driverLng) / 2,
                            ),
                            zoom: 13.5,
                          ),
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          mapType: MapType.normal,
                          polylines: {
                            Polyline(
                              polylineId: const PolylineId('route'),
                              points: [
                                LatLng(driverLat, driverLng),
                                LatLng(shopLat, shopLng),
                              ],
                              width: 5,
                              color: const Color(0xFF00C853),
                            ),
                          },
                          markers: {
                            Marker(
                              markerId: const MarkerId('driver'),
                              position: LatLng(driverLat, driverLng),
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                            ),
                            Marker(
                              markerId: const MarkerId('shop'),
                              position: LatLng(shopLat, shopLng),
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                            ),
                          },
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 👤 2. FOTO DE PERFIL DEL CLIENTE E INFORMACIÓN DE CONTACTO
                          Row(
                            children: [
                              buildAvatarHelper(
                                widget.order.clientName,
                                widget.order.clientAvatarUrl,
                                radius: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.order.clientName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_android_outlined,
                                          size: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.order.clientPhone ??
                                              'Celular no registrado',
                                          style: GoogleFonts.openSans(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                          ),

                          // 📦 3. DETALLE DEL PEDIDO CON RECUADRO ESTÉTICO DE PRODUCTO/HIELO
                          Row(
                            children: [
                              // Icono/Miniatura de Hielo Estilizada sin sobrecargar
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFDCFCE7)),
                                ),
                                child: const Icon(
                                  Icons.ac_unit_rounded,
                                  color: Colors.green,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.order.productName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${widget.order.quantity} Bolsas Mayoristas',
                                      style: GoogleFonts.openSans(
                                        fontSize: 12,
                                        color: const Color(0xFF475569),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Gs ${NumberFormat.decimalPattern('es_PY').format(widget.order.total)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
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
                                  widget.order.deliveryAddress ??
                                      'Dirección Comercial Fija',
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 🚛 4. DESLIZADOR DE ACCIÓN PREMIUM (SLIDE TO ACCEPT)
                          if (!_isAccepted)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final double maxSlideFactor =
                                    constraints.maxWidth - 54;
                                return Container(
                                  height: 56,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Color(0xFF94A3B8),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Desliza para aceptar viaje',
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        left: _slidePosition,
                                        top: 3,
                                        child: GestureDetector(
                                          onHorizontalDragUpdate: (details) {
                                            setState(() {
                                              _slidePosition += details.delta.dx;
                                              if (_slidePosition < 0)
                                                _slidePosition = 0;
                                              if (_slidePosition > maxSlideFactor)
                                                _slidePosition = maxSlideFactor;
                                            });
                                          },
                                          onHorizontalDragEnd: (details) async {
                                            if (_slidePosition >=
                                                maxSlideFactor * 0.85) {
                                              // Confirmación del deslizamiento completo
                                              setState(() {
                                                _slidePosition = maxSlideFactor;
                                                _isAccepted = true;
                                              });
                                              try {
                                                await provider.acceptOrder(
                                                  widget.order.clientOrderId,
                                                );
                                                provider.clearIncomingOrderAlert();
                                              } catch (e) {
                                                setState(() {
                                                  _slidePosition = 0.0;
                                                  _isAccepted = false;
                                                });
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                                    backgroundColor: Colors.redAccent,
                                                  ),
                                                );
                                              }
                                            } else {
                                              // Cancelación y rebote elástico a posición cero
                                              setState(() {
                                                _slidePosition = 0.0;
                                              });
                                            }
                                          },
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: const BoxDecoration(
                                              color: Color(
                                                0xFF0F172A,
                                              ), // Botón Slate 900 Negro Sólido
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF0F172A),
                              ),
                            ),

                          // Enlace de rechazo sutil abajo
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () => provider.rejectIncomingOrder(
                                widget.order.clientOrderId,
                              ),
                              child: Text(
                                'Ignorar alerta',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

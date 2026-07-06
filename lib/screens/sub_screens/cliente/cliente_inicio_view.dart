import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import '../shared/widgets/build_avatar_helper.dart';
import '../shared/widgets/request_ice_dialog.dart';

class ClienteInicioView extends StatelessWidget {
  const ClienteInicioView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final user = provider.currentUser;

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

    return Scaffold(
      backgroundColor: const Color(
        0xFFF8FAFC,
      ), // Fondo gris muy claro para resaltar las cartas blancas
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: Avatar + Saludo
              Row(
                children: [
                  buildAvatarHelper(
                    provider.currentUserFullName ?? user?.email ?? 'Cliente',
                    provider.currentUserAvatarUrl,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bienvenido,",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        provider.currentUserFullName?.split(' ').first ??
                            'Cliente',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // BENTO GRID - HERO: Pedido rápido
              GestureDetector(
                onTap: () => showRequestIceDialog(context, provider),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors
                        .black, // Contraste fuerte para el bloque principal
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Stack(
                    children: [
                      // Imagen de Hielo - Posicionada a la derecha
                      Positioned(
                        right: -10,
                        top: 10,
                        bottom: 10,
                        child: Image.asset(
                          'assets/hielo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Contenido del CTA
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Hielo Premium',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Listo para tu delivery\ninmediato.',
                              style: GoogleFonts.openSans(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Pedir ahora',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black,
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

              const SizedBox(height: 24),

              // PROMOS BENTO GRID
              Text(
                'Promociones',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildBentoPromo(
                      '2x1',
                      'Hielo 5kg',
                      Colors.blue.shade50,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBentoPromo(
                      '15% OFF',
                      'Primera compra',
                      Colors.green.shade50,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLargePromo(
                'Envío Gratis',
                'En pedidos de 3+ bolsas de hielo',
                Colors.orange.shade50,
                Colors.orange,
              ),

              // Tarjeta de Código de Entrega (solo si hay pedido activo)
              if (activeOrder.clientOrderId.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.cyan.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.06),
                        blurRadius: 12,
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delivery_dining,
                                  color: Colors.cyan,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Código de tu Compra',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              activeOrder.status.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.cyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${activeOrder.productName} (x${activeOrder.quantity})',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dirección: ${activeOrder.deliveryAddress ?? "S/D"}',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const Divider(color: Color(0xFFE2E8F0), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Proporcioná este código al repartidor:',
                                style: GoogleFonts.openSans(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeOrder.verificationCode ?? '----',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.cyan,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  // Widget para Promos cuadradas (Bento)
  Widget _buildBentoPromo(String title, String sub, Color bg, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star_rounded, color: accent, size: 20),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: const Color(0xFF0F172A),
            ),
          ),
          Text(
            sub,
            style: GoogleFonts.openSans(
              fontSize: 11,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para Promos horizontales grandes
  Widget _buildLargePromo(String title, String sub, Color bg, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: accent, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                sub,
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

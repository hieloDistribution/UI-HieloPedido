import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../providers/order_provider.dart';
import 'create_order_view.dart';

class RepartidorAgendaView extends StatefulWidget {
  const RepartidorAgendaView({super.key});

  @override
  State<RepartidorAgendaView> createState() => _RepartidorAgendaViewState();
}

class _RepartidorAgendaViewState extends State<RepartidorAgendaView> {
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color indigoCustom = Color(0xFF4F46E5);

  // Indice del local con popover abierto
  int? _activePopoverIndex;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final agenda = provider.todayAgenda;

    return Scaffold(
      backgroundColor: slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mi Agenda de Trabajo',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: slate900,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchTodayAgenda();
          await provider.fetchAdminProfile();
        },
        child: agenda == null
            ? _buildEmptyState()
            : _buildAgendaScreen(provider, agenda),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: slate200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: slate100,
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar04,
                  color: slate400,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sin Agenda Asignada',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'El administrador no te ha asignado visitas para la fecha de hoy. Disfruta tu día o ponte en contacto.',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  color: slate400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaScreen(OrderProvider provider, Map<String, dynamic> agenda) {
    final status = agenda['status'] ?? 'PENDIENTE';
    final isPending = status == 'PENDIENTE';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Cabecera del Admin & Mensaje Motivador estilo Duolingo
        _buildAdminHeader(provider),
        const SizedBox(height: 20),

        if (isPending) ...[
          // Acceptance Panel (Antes de aceptar la agenda)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE68A)), // amber
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar04,
                  color: Colors.amber,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Confirmar Ruta del Día',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: slate900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'El administrador te ha planificado un recorrido. Confirma la aceptación para desbloquear el mapa de visitas e iniciar tu ruta comercial.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(
                    fontSize: 13,
                    color: slate700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      await provider.acceptAgenda(agenda['id']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: indigoCustom,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Aceptar Agenda y Empezar',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // 2. Ruta Gamificada estilo Duolingo (Cuando está ACEPTADA)
          Text(
            'Tu Ruta de Hoy',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca cualquier local de la ruta para ver sus detalles en pantalla y tomar pedido.',
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: slate400,
            ),
          ),
          const SizedBox(height: 16),
          _buildDuolingoPath(provider, agenda['items'] as List? ?? []),
        ],
      ],
    );
  }

  Widget _buildAdminHeader(OrderProvider provider) {
    final avatarUrl = provider.adminAvatarUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar del Admin Real-time
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
              image: avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null
                ? const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      color: indigoCustom,
                      size: 24,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          // Burbuja de Mensaje (Estilo diálogo de mascota de Duolingo)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.adminName,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: slate400,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4), // light green
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Text(
                    '¡Hola! Esta es tu agenda para hoy. Espero que puedas con ella. ¡Cada local es una gran oportunidad de venta. Mucho éxito en tu ruta hoy! 💪❄️',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: const Color(0xFF166534),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuolingoPath(OrderProvider provider, List items) {
    if (items.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double rowHeight = 130.0;
        final double nodeRadius = 32.0;

        final List<Offset> points = [];
        for (int i = 0; i < items.length; i++) {
          final double y = 50.0 + i * rowHeight;
          double x;
          // Patrón serpiente: Centro-Izquierda-Centro-Derecha-Centro...
          final int pattern = i % 4;
          if (pattern == 0) {
            x = width * 0.5;
          } else if (pattern == 1) {
            x = width * 0.25;
          } else if (pattern == 2) {
            x = width * 0.5;
          } else {
            x = width * 0.75;
          }
          points.add(Offset(x, y));
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              _activePopoverIndex = null;
            });
          },
          child: Container(
            height: 100.0 + (items.length - 1) * rowHeight,
            width: width,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: slate200),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Línea punteada de fondo
                Positioned.fill(
                  child: CustomPaint(
                    painter: DuolingoPathPainter(points),
                  ),
                ),

                // Botones circulares (Nodos de clientes)
                for (int i = 0; i < items.length; i++) ...[
                  Positioned(
                    left: points[i].dx - nodeRadius,
                    top: points[i].dy - nodeRadius,
                    child: _buildPathNode(context, items[i], i),
                  ),
                ],

                // Popover inline flotante al lado de la parada (estilo Duolingo sin abrir tarjeta separada)
                if (_activePopoverIndex != null) ...[
                  Builder(
                    builder: (context) {
                      final idx = _activePopoverIndex!;
                      final item = items[idx];
                      final client = item['client'] as Map<String, dynamic>? ?? {};
                      final name = client['name'] ?? 'Cliente';

                      // Buscar detalles actualizados en local shops para garantizar teléfono y dueño
                      final shopMatch = provider.clienteShops.firstWhere(
                        (shop) => shop['id'] == client['id'],
                        orElse: () => {},
                      );
                      final ownerName = shopMatch['full_name'] ?? 'No especificado';
                      final phone = shopMatch['celular'] != '' ? shopMatch['celular'] : 'No especificado';
                      final address = shopMatch['direccion'] ?? 'Sin dirección';
                      final isCompleted = item['status'] == 'COMPLETADO';

                      final nodeOffset = points[idx];
                      double popoverWidth = 240.0;
                      double popoverHeight = 155.0;
                      double left = nodeOffset.dx - (popoverWidth / 2);
                      // Clamp horizontal
                      if (left < 12) left = 12;
                      if (left + popoverWidth > width - 12) {
                        left = width - popoverWidth - 12;
                      }
                      double top = nodeOffset.dy - popoverHeight - 20;
                      if (top < 0) {
                        top = nodeOffset.dy + 80;
                      }

                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: popoverWidth,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: slate200, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: slate900,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _activePopoverIndex = null),
                                    child: const Icon(Icons.close, size: 14, color: slate400),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Dueño: $ownerName', style: GoogleFonts.openSans(fontSize: 11, color: slate700)),
                              Text('Cel: $phone', style: GoogleFonts.openSans(fontSize: 11, color: slate700)),
                              Text('Calle: $address', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.openSans(fontSize: 11, color: slate700)),
                              const SizedBox(height: 10),
                              if (isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Visita completada',
                                      style: GoogleFonts.outfit(color: const Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() => _activePopoverIndex = null);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CreateOrderView(
                                            prefilledClientId: client['id'],
                                            agendaItemId: item['id'],
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: indigoCustom,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'TOMAR PEDIDO',
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPathNode(BuildContext context, Map<String, dynamic> item, int index) {
    final client = item['client'] as Map<String, dynamic>? ?? {};
    final name = client['name'] ?? 'Cliente';
    final itemStatus = item['status'] as String? ?? 'PENDIENTE';
    final isCompleted = itemStatus == 'COMPLETADO';

    Color nodeColor = isCompleted ? const Color(0xFF10B981) : indigoCustom;
    Color shadowColor = isCompleted ? const Color(0xFF047857) : const Color(0xFF3730A3);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activePopoverIndex = index;
        });
      },
      child: Column(
        children: [
          // Botón circular estilo Duolingo con profundidad 3D
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: nodeColor,
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 24)
                  : const HugeIcon(
                      icon: HugeIcons.strokeRoundedStore03,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          // Nombre pequeño del local
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: slate100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pintador de curvas estilo Duolingo
class DuolingoPathPainter extends CustomPainter {
  final List<Offset> points;
  DuolingoPathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1) // slate300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      // Puntos de control Bezier
      final cp1 = Offset(p0.dx, (p0.dy + p1.dy) / 2);
      final cp2 = Offset(p1.dx, (p0.dy + p1.dy) / 2);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    // Dibujar línea punteada
    final dashWidth = 8.0;
    final dashSpace = 6.0;
    double distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DuolingoPathPainter oldDelegate) => false;
}

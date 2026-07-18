import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';

class AdminCalendarioView extends StatefulWidget {
  const AdminCalendarioView({super.key});

  @override
  State<AdminCalendarioView> createState() => _AdminCalendarioViewState();
}

class _AdminCalendarioViewState extends State<AdminCalendarioView> {
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color indigoCustom = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.fetchRepartidoresLocations();
      provider.fetchAdminAgendasToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final preventistas = provider.repartidores;
    final agendas = provider.adminAgendasToday;

    // Métricas
    final totalPreventistas = preventistas.length;
    final withAgendaCount = agendas.length;
    final completedAgendasCount = agendas.where((a) => a['status'] == 'COMPLETADA').length;

    return Scaffold(
      backgroundColor: slate50,
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchRepartidoresLocations();
          await provider.fetchAdminAgendasToday();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Planificación y Agendas',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Monitoreo de visitas y estados en tiempo real',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: slate400,
              ),
            ),
            const SizedBox(height: 20),

            // Bento Metric Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Planificadas',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: slate400,
                              ),
                            ),
                            const HugeIcon(icon: HugeIcons.strokeRoundedCalendar04, color: indigoCustom, size: 16),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$withAgendaCount / $totalPreventistas',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Completadas',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: slate400,
                              ),
                            ),
                            const HugeIcon(icon: HugeIcons.strokeRoundedTick01, color: Color(0xFF10B981), size: 16),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$completedAgendasCount',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Avance de Preventistas',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: slate900,
              ),
            ),
            const SizedBox(height: 12),

            preventistas.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: slate200),
                    ),
                    child: Center(
                      child: Text(
                        'No hay preventistas registrados',
                        style: GoogleFonts.outfit(color: slate400),
                      ),
                    ),
                  )
                : Column(
                    children: preventistas.map((rep) {
                      final repId = rep['id'] as String;
                      final repName = rep['full_name'] ?? rep['fullName'] ?? 'Preventista';

                      // Buscar si tiene agenda hoy
                      Map<String, dynamic>? agenda;
                      for (final a in agendas) {
                        if (a['preventista'] != null && a['preventista']['id'] == repId) {
                          agenda = a;
                          break;
                        }
                      }

                      final String status = agenda != null ? (agenda['status'] ?? 'PENDIENTE') : 'SIN_AGENDA';
                      final items = agenda != null ? (agenda['items'] as List? ?? []) : [];
                      final completedCount = items.where((i) => i['status'] == 'COMPLETADO').length;
                      final totalCount = items.length;
                      final double progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: slate200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Avatar, Name and Status
                            Row(
                              children: [
                                buildAvatarHelper(
                                  repName,
                                  rep['avatar_url'] as String?,
                                  radius: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        repName,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: slate900,
                                        ),
                                      ),
                                      Text(
                                        rep['tipo_vehiculo'] ?? 'Sin vehículo',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: slate400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(status),
                              ],
                            ),

                            // Progress section
                            if (status != 'SIN_AGENDA') ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(color: Color(0xFFF1F5F9)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progreso de visitas',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: slate700,
                                    ),
                                  ),
                                  Text(
                                    '$completedCount / $totalCount paradas',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: slate900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: slate100,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    status == 'COMPLETADA' ? const Color(0xFF10B981) : indigoCustom,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Ruta y Visitas de Hoy:',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: slate700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Column(
                                children: items.map<Widget>((item) {
                                  final client = item['client'] as Map<String, dynamic>? ?? {};
                                  final cName = client['name'] ?? 'Cliente';
                                  final isDone = item['status'] == 'COMPLETADO';

                                  // Find client orders taken by this preventista today
                                  final clientOrders = provider.adminOrders.where((o) =>
                                      (o['user_id'] == client['id'] || o['client_name'] == cName) &&
                                      o['repartidor_id']?.toString() == repId
                                  ).toList();

                                  String orderDetails = '';
                                  if (clientOrders.isNotEmpty) {
                                    orderDetails = clientOrders.map((o) => o['product_name'] ?? '').join(', ');
                                  }

                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDone ? const Color(0xFFF0FDF4) : slate100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDone ? const Color(0xFFDCFCE7) : slate200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                          color: isDone ? const Color(0xFF10B981) : slate400,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cName,
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: slate900,
                                                ),
                                              ),
                                              if (isDone) ...[
                                                if (orderDetails.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Pedido: $orderDetails',
                                                    style: GoogleFonts.openSans(
                                                      fontSize: 11,
                                                      color: const Color(0xFF1565C0),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ] else ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item['notes'] != null && (item['notes'] as String).isNotEmpty
                                                        ? 'Nota: ${item['notes']}'
                                                        : 'Visita registrada sin venta.',
                                                    style: GoogleFonts.openSans(
                                                      fontSize: 10,
                                                      color: slate400,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ] else ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Pendiente de visita',
                                                  style: GoogleFonts.openSans(
                                                    fontSize: 10,
                                                    color: slate400,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  'No se ha planificado recorrido para este preventista hoy.',
                                  style: TextStyle(
                                    color: slate400,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status.toUpperCase()) {
      case 'PENDIENTE':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        text = 'Pendiente';
        break;
      case 'ACEPTADA':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        text = 'Aceptada';
        break;
      case 'COMPLETADA':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        text = 'Completada';
        break;
      case 'SIN_AGENDA':
      default:
        bg = slate100;
        fg = slate400;
        text = 'Sin Agenda';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

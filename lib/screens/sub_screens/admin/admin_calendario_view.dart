import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';
import '../../../core/network/api_client.dart';

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

  final Map<String, List<Map<String, dynamic>>> _preventistaAgendas = {};
  final Set<String> _expandedRepIds = {};
  bool _loadingAgendas = false;

  Color getAgendaColor(String agendaId) {
    final List<Color> colors = [
      const Color(0xFFFEF08A), // Light Yellow
      const Color(0xFFBFDBFE), // Light Blue
      const Color(0xFFE9D5FF), // Light Purple
      const Color(0xFFFBCFE8), // Light Pink
      const Color(0xFFA7F3D0), // Light Green
    ];
    int hash = 0;
    for (int i = 0; i < agendaId.length; i++) {
      hash += agendaId.codeUnitAt(i);
    }
    return colors[hash % colors.length];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.fetchRepartidoresLocations();
      provider.fetchAdminAgendasToday();
      provider.fetchAdminOrders();
    });
  }

  Future<void> _loadAgendasForPreventista(String repId) async {
    setState(() {
      _loadingAgendas = true;
    });
    try {
      final response = await ApiClient.get('order', '/api/v1/agendas/preventista/$repId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _preventistaAgendas[repId] = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading agendas for preventista: $e');
    } finally {
      setState(() {
        _loadingAgendas = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final preventistas = provider.repartidores;
    final agendasToday = provider.adminAgendasToday;

    // Métricas para hoy
    final totalPreventistas = preventistas.length;
    final withAgendaTodayCount = agendasToday.length;
    final completedAgendasTodayCount = agendasToday.where((a) => a['status'] == 'COMPLETADA').length;

    return Scaffold(
      backgroundColor: slate50,
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchRepartidoresLocations();
          await provider.fetchAdminAgendasToday();
          await provider.fetchAdminOrders();
          for (final repId in _expandedRepIds) {
            await _loadAgendasForPreventista(repId);
          }
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

            // Bento Metric Cards para hoy
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
                              'Planificadas Hoy',
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
                          '$withAgendaTodayCount / $totalPreventistas',
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
                              'Completadas Hoy',
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
                          '$completedAgendasTodayCount',
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
                      final isExpanded = _expandedRepIds.contains(repId);

                      // Buscar si tiene agenda asignada hoy
                      Map<String, dynamic>? agendaToday;
                      for (final a in agendasToday) {
                        if (a['preventista'] != null && a['preventista']['id'] == repId) {
                          agendaToday = a;
                          break;
                        }
                      }
                      final String todayStatus = agendaToday != null 
                          ? (agendaToday['status'] ?? 'PENDIENTE') 
                          : 'SIN_AGENDA';

                      final hasTodayAgenda = todayStatus != 'SIN_AGENDA';
                      final headerBg = Colors.white;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                            // Header del Preventista (Clickeable para Expandir)
                            InkWell(
                              onTap: () {
                                if (isExpanded) {
                                  setState(() => _expandedRepIds.remove(repId));
                                } else {
                                  setState(() => _expandedRepIds.add(repId));
                                  _loadAgendasForPreventista(repId);
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: headerBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    buildAvatarHelper(
                                      repName,
                                      rep['avatar_url'] as String?,
                                      radius: 20,
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
                                              fontSize: 15,
                                              color: slate900,
                                            ),
                                          ),
                                          Text(
                                            rep['tipo_vehiculo'] ?? 'Sin vehículo',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: slate700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (hasTodayAgenda) ...[
                                      _buildStatusBadge(todayStatus),
                                      const SizedBox(width: 8),
                                    ],
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: slate700,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Contenido Expandido: Historial de Agendas & Pedidos
                            if (isExpanded) ...[
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. SECCIÓN HISTORIAL DE RUTAS
                                    _buildSectionHeader('HISTORIAL DE RUTAS Y AGENDAS'),
                                    const SizedBox(height: 8),
                                    _buildAgendasList(repId),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: slate700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildAgendasList(String repId) {
    if (_loadingAgendas && !_preventistaAgendas.containsKey(repId)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: indigoCustom, strokeWidth: 2),
        ),
      );
    }

    final agendas = _preventistaAgendas[repId] ?? [];
    if (agendas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'No tiene agendas registradas en el historial',
            style: GoogleFonts.openSans(fontSize: 12, color: slate400, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      children: agendas.map((agenda) {
        final dateStr = agenda['date'] ?? '';
        final status = agenda['status'] ?? 'PENDIENTE';
        final items = agenda['items'] as List? ?? [];
        final completedCount = items.where((i) => i['status'] == 'COMPLETADO').length;
        final totalCount = items.length;

        double totalRecaudado = 0.0;
        final provider = Provider.of<OrderProvider>(context, listen: false);
        for (var item in items) {
          final client = item['client'] as Map<String, dynamic>? ?? {};
          final cName = client['name'] ?? 'Cliente';
          final clientOrders = provider.adminOrders.where((o) {
            final orderDate = o['created_at'] != null && o['created_at'].toString().length >= 10
                ? o['created_at'].toString().substring(0, 10)
                : '';
            return (o['user_id'] == client['id'] || o['client_name'] == cName) &&
                   o['preventista_id']?.toString() == repId &&
                   orderDate == dateStr;
          }).toList();
          for (var o in clientOrders) {
            final List oItems = o['items'] as List? ?? [];
            for (var oi in oItems) {
              final double p = (oi['price'] ?? 0.0) as double;
              final int q = (oi['quantity'] ?? 1) as int;
              totalRecaudado += p * q;
            }
          }
        }

        final Color agendaColor = getAgendaColor(agenda['id'] ?? '').withOpacity(0.15);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: agendaColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: slate200),
          ),
          child: ExpansionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ruta del $dateStr',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: slate900,
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            subtitle: Text(
              '$completedCount / $totalCount paradas • Recaudado: \$${totalRecaudado.toStringAsFixed(2)}',
              style: GoogleFonts.openSans(
                fontSize: 11,
                color: slate700,
                fontWeight: FontWeight.w600,
              ),
            ),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              if (items.isEmpty)
                Text(
                  'No hay paradas definidas para esta ruta',
                  style: GoogleFonts.openSans(fontSize: 11, color: slate400),
                )
              else
                Column(
                  children: items.map<Widget>((item) {
                    final client = item['client'] as Map<String, dynamic>? ?? {};
                    final cName = client['name'] ?? 'Cliente';
                    final isDone = item['status'] == 'COMPLETADO';
                    final note = item['notes'] as String? ?? '';
                    final isRejected = status.toUpperCase() == 'RECHAZADA';

                    final provider = Provider.of<OrderProvider>(context, listen: false);
                    final clientOrders = provider.adminOrders.where((o) {
                      final orderDate = o['created_at'] != null && o['created_at'].toString().length >= 10
                          ? o['created_at'].toString().substring(0, 10)
                          : '';
                      return (o['user_id'] == client['id'] || o['client_name'] == cName) &&
                             o['preventista_id']?.toString() == repId &&
                             orderDate == dateStr;
                    }).toList();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isRejected 
                                    ? Icons.cancel 
                                    : (isDone ? Icons.check_circle : Icons.radio_button_unchecked),
                                color: isRejected 
                                    ? const Color(0xFFEF4444) 
                                    : (isDone ? const Color(0xFF10B981) : slate400),
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cName,
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: slate900,
                                    fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isRejected)
                            Padding(
                              padding: const EdgeInsets.only(left: 22.0, top: 2.0),
                              child: Text(
                                'No visitado (Ruta rechazada)',
                                style: GoogleFonts.openSans(
                                  fontSize: 11,
                                  color: const Color(0xFFEF4444),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else if (isDone && clientOrders.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 22.0, top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: clientOrders.expand((o) {
                                  final List orderItems = o['items'] as List? ?? [];
                                  return orderItems.map((item) {
                                    return Text(
                                      '• ${item['product_name']}  x${item['quantity']}  (\$${(item['price'] as double).toStringAsFixed(2)})',
                                      style: GoogleFonts.openSans(
                                        fontSize: 11,
                                        color: const Color(0xFF1E40AF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  });
                                }).toList(),
                              ),
                            )
                          else if (isDone && note.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 22.0, top: 2.0),
                              child: Text(
                                'Nota: $note',
                                style: GoogleFonts.openSans(
                                  fontSize: 11,
                                  color: slate400,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }



  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status.toUpperCase()) {
      case 'PENDIENTE':
      case 'PENDING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        text = 'Pendiente';
        break;
      case 'ACEPTADA':
      case 'ACCEPTED':
      case 'ACEPTADO':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        text = 'Aceptada';
        break;
      case 'COMPLETADA':
      case 'DELIVERED':
      case 'ENTREGADO':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        text = 'Completada';
        break;
      case 'RECHAZADA':
      case 'CANCELLED':
      case 'CANCELADO':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        text = 'Rechazada';
        break;
      case 'DISPATCHED':
      case 'EN_CAMINO':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        text = 'En Camino';
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
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

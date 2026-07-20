import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';
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

  String _selectedFilter = 'All';
  Map<String, dynamic>? _selectedAgenda;
  int? _activePopoverIndex;

  Color getAgendaColor(String agendaId) {
    final List<Color> colors = [
      const Color(0xFFFEF08A), // Light Yellow (yellow 200)
      const Color(0xFFBFDBFE), // Light Blue (blue 200)
      const Color(0xFFE9D5FF), // Light Purple (purple 200)
      const Color(0xFFFBCFE8), // Light Pink (pink 200)
      const Color(0xFFA7F3D0), // Light Green (emerald 200)
    ];
    int hash = 0;
    for (int i = 0; i < agendaId.length; i++) {
      hash += agendaId.codeUnitAt(i);
    }
    return colors[hash % colors.length];
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'PENDIENTE':
        return const Color(0xFFFEF3C7);
      case 'ACEPTADA':
        return const Color(0xFFE0E7FF);
      case 'COMPLETADA':
        return const Color(0xFFD1FAE5);
      case 'RECHAZADA':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'PENDIENTE':
        return const Color(0xFFD97706);
      case 'ACEPTADA':
        return const Color(0xFF4F46E5);
      case 'COMPLETADA':
        return const Color(0xFF059669);
      case 'RECHAZADA':
        return const Color(0xFFEF4444);
      default:
        return slate700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);

    // If a specific agenda is selected, render its Duolingo map path view
    if (_selectedAgenda != null) {
      final updatedAgenda = provider.userAgendas.firstWhere(
        (a) => a['id'] == _selectedAgenda!['id'],
        orElse: () => _selectedAgenda!,
      );

      return Scaffold(
        backgroundColor: slate50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
            onPressed: () {
              setState(() {
                _selectedAgenda = null;
                _activePopoverIndex = null;
              });
            },
          ),
          title: Text(
            'Ruta ${updatedAgenda['id'].toString().substring(0, 7)}',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: slate900,
            ),
          ),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await provider.fetchUserAgendas();
          },
          child: _buildAgendaScreen(provider, updatedAgenda),
        ),
      );
    }

    // Filter logic
    final filteredAgendas = provider.userAgendas.where((a) {
      if (_selectedFilter == 'All') return true;
      return a['status'] == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mis Agendas de Trabajo',
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
          await provider.fetchUserAgendas();
          await provider.fetchAdminProfile();
          await provider.fetchCurrentUserProfile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            // Filter Pills Selector
            _buildFilterPills(),
            const SizedBox(height: 16),

            if (filteredAgendas.isEmpty)
              _buildEmptyState()
            else
              ...filteredAgendas.map((agenda) => _buildAgendaCard(provider, agenda)).toList(),

            const SizedBox(height: 120), // bottom offset spacer
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills() {
    final filters = ['All', 'PENDIENTE', 'ACEPTADA', 'COMPLETADA'];
    final labels = {
      'All': 'Todas',
      'PENDIENTE': 'Pendientes',
      'ACEPTADA': 'Aceptadas',
      'COMPLETADA': 'Completadas',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                labels[f]!,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? Colors.white : slate700,
                ),
              ),
              selected: isSelected,
              selectedColor: slate900,
              backgroundColor: Colors.white,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = f;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
            'Sin Agendas Coincidentes',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: slate900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No se encontraron agendas registradas bajo este filtro en el día de hoy.',
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(
              fontSize: 13,
              color: slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaCard(OrderProvider provider, Map<String, dynamic> agenda) {
    final agendaId = agenda['id'] ?? '';
    final status = agenda['status'] ?? 'PENDIENTE';
    final dateStr = agenda['date'] ?? '';
    final items = agenda['items'] as List? ?? [];
    
    final headerColor = getAgendaColor(agendaId);
    
    final clientNames = items.map<String>((i) {
      final c = i['client'] as Map<String, dynamic>? ?? {};
      return c['name'] ?? 'Cliente';
    }).join(', ');

    final shortId = agendaId.length > 7 ? agendaId.substring(0, 7) : agendaId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(23),
                topRight: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: buildAvatarHelper(provider.adminName, provider.adminAvatarUrl, radius: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agenda Asignada',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          shortId,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: slate900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(status),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusTextColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Details
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildCardDetailRow('Clientes:', clientNames),
                const SizedBox(height: 10),
                _buildCardDetailRow('Asignado por:', provider.adminName),
                const SizedBox(height: 10),
                _buildCardDetailRow('Fecha:', dateStr),
              ],
            ),
          ),

          // Action buttons
          if (status == 'PENDIENTE') ...[
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, bottom: 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => provider.rejectAgenda(agendaId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Rechazar',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => provider.acceptAgenda(agendaId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: slate900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(
                        'Aceptar',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (status == 'ACEPTADA') ...[
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, bottom: 18),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedAgenda = agenda;
                    });
                  },
                  icon: const Icon(Icons.play_circle_outline, color: Colors.white, size: 16),
                  label: Text(
                    'Iniciar Ruta',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ] else if (status == 'COMPLETADA') ...[
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Completada',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedAgenda = agenda;
                      });
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF4F46E5)),
                    label: Text(
                      'Ver Ruta',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: slate400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.openSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: slate900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaScreen(OrderProvider provider, Map<String, dynamic> agenda) {
    final status = agenda['status'] ?? 'PENDIENTE';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildAdminHeader(provider),
        const SizedBox(height: 20),

        if (status == 'COMPLETADA') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF81C784)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Color(0xFF2E7D32), size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Ruta Completada!',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Completaste con éxito todas tus visitas programadas para el día de hoy. ¡Sigue así! 🚀',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

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
          status == 'COMPLETADA'
              ? '¡Completaste tu recorrido de hoy!'
              : 'Toca cualquier local de la ruta para ver sus detalles en pantalla y tomar pedido.',
          style: GoogleFonts.openSans(
            fontSize: 12,
            color: status == 'COMPLETADA' ? const Color(0xFF2E7D32) : slate400,
            fontWeight: status == 'COMPLETADA' ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 16),
        _buildDuolingoPath(provider, agenda['items'] as List? ?? []),
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
                    color: const Color(0xFFF0FDF4),
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
                Positioned.fill(
                  child: CustomPaint(
                    painter: DuolingoPathPainter(points),
                  ),
                ),
                for (int i = 0; i < items.length; i++) ...[
                  Positioned(
                    left: points[i].dx - nodeRadius,
                    top: points[i].dy - nodeRadius,
                    child: _buildPathNode(context, items[i], i),
                  ),
                ],
                if (_activePopoverIndex != null) ...[
                  Builder(
                    builder: (context) {
                      final idx = _activePopoverIndex!;
                      final item = items[idx];
                      final client = item['client'] as Map<String, dynamic>? ?? {};
                      final name = client['name'] ?? 'Cliente';

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

class DuolingoPathPainter extends CustomPainter {
  final List<Offset> points;
  DuolingoPathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cp1 = Offset(p0.dx, (p0.dy + p1.dy) / 2);
      final cp2 = Offset(p1.dx, (p0.dy + p1.dy) / 2);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

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

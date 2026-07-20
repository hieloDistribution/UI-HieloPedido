import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';
import 'admin_assign_agenda_view.dart';

class AdminProveedoresView extends StatefulWidget {
  final Function(int)? onViewOnMap;
  const AdminProveedoresView({super.key, this.onViewOnMap});

  @override
  State<AdminProveedoresView> createState() => _AdminProveedoresViewState();
}

class _AdminProveedoresViewState extends State<AdminProveedoresView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchRepartidoresLocations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final repartidores = provider.repartidores;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Proveedores',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gestión de repartidores y distribuidores',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
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
                            'Total Proveedores',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          HugeIcon(icon: HugeIcons.strokeRoundedTruck, color: const Color(0xFF4F46E5), size: 18),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${repartidores.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Lista de Proveedores',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          repartidores.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedTruck,
                          color: const Color(0xFFCBD5E1),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay proveedores registrados',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: repartidores.map((rep) {
                    final lastSeenStr = (rep['lastLocationUpdated'] ?? rep['last_location_updated']) as String?;
                    bool isOnline = false;
                    if (lastSeenStr != null) {
                      try {
                        final lastSeen = DateTime.parse(lastSeenStr);
                        isOnline = DateTime.now().toUtc().difference(lastSeen).inSeconds <= 60;
                      } catch (_) {}
                    }

                    final String name = rep['full_name'] ?? rep['fullName'] ?? 'Proveedor';
                    final String vehicle = rep['tipo_vehiculo'] ?? 'Moto';
                    final String patente = rep['matricula'] ?? 'S/M';
                    final String address = rep['address'] ?? 'Ubicación desconocida';
                    final String displayAddress = isOnline ? address : 'Última ubicación: $address';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          buildAvatarHelper(
                            name,
                            rep['avatar_url'] as String?,
                            radius: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isOnline ? 'En línea' : 'Desconectado',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedCar03,
                                      color: const Color(0xFF64748B),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$vehicle • Patente: $patente',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF94A3B8),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        displayAddress,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                          fontStyle: isOnline ? FontStyle.normal : FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(12),
                            child: IconButton(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCalendar04,
                                color: Color(0xFF4F46E5),
                                size: 18,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminAssignAgendaView(preventista: rep),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            child: IconButton(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedMapPin,
                                color: Color(0xFF0F172A),
                                size: 18,
                              ),
                              onPressed: () {
                                if (widget.onViewOnMap != null) {
                                  provider.selectRepartidorForMap(rep);
                                  widget.onViewOnMap!(2); // Switch to the Map tab
                                }
                              },
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
  }
}

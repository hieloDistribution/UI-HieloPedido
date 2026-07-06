import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';

class AdminMapView extends StatefulWidget {
  const AdminMapView({super.key});

  @override
  State<AdminMapView> createState() => _AdminMapViewState();
}

class _AdminMapViewState extends State<AdminMapView> {
  Timer? _timer;
  final MapController _mapController = MapController();
  Map<String, dynamic>? _selectedRepartidor;
  bool _hasCentered = false;

  @override
  void initState() {
    super.initState();
    // Poll driver positions every 10 seconds while Admin is viewing this tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchRepartidoresLocations();
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchRepartidoresLocations();
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
    final repartidores = provider.repartidores
        .where((r) => r['last_latitude'] != null && r['last_longitude'] != null)
        .toList();

    // Auto-center on first load if drivers are available
    if (repartidores.isNotEmpty && !_hasCentered) {
      _hasCentered = true;
      final lat = repartidores.first['last_latitude'] as double;
      final lng = repartidores.first['last_longitude'] as double;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(lat, lng), 14.0);
      });
    }

    final markers = repartidores.map((r) {
      final lat = r['last_latitude'] as double;
      final lng = r['last_longitude'] as double;
      final email = r['email'] as String? ?? 'Sin email';
      final isSelected =
          _selectedRepartidor != null && _selectedRepartidor!['id'] == r['id'];

      return Marker(
        point: LatLng(lat, lng),
        width: 75,
        height: 75,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedRepartidor = r;
            });
            _mapController.move(LatLng(lat, lng), 15.0);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing circular profile picture
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F172A),
                  border: Border.all(
                    color: isSelected ? Colors.cyanAccent : Colors.tealAccent,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isSelected ? Colors.cyanAccent : Colors.tealAccent)
                              .withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: buildAvatarHelper(
                  r['full_name'] ?? email,
                  r['avatar_url'] as String?,
                  radius: 18,
                  fontSize: 11,
                ),
              ),
              // Pointer pin
              CustomPaint(
                size: const Size(10, 8),
                painter: TrianglePainter(
                  color: isSelected ? Colors.cyanAccent : Colors.tealAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // FlutterMap Layer
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(-26.18500, -58.17417),
                initialZoom: 13.0,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.empresa.order_flow',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // Header floating bar with title and refresh button
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rastreo de Repartidores',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        repartidores.isEmpty
                            ? 'Esperando señales GPS...'
                            : '${repartidores.length} activos en el mapa',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                    onPressed: () {
                      provider.fetchRepartidoresLocations();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Actualizando ubicaciones...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Horizontal sliding list of active drivers
          if (repartidores.isNotEmpty)
            Positioned(
              bottom: 110,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: repartidores.length,
                  itemBuilder: (context, index) {
                    final r = repartidores[index];
                    final email = r['email'] as String? ?? 'Sin email';
                    final lat = r['last_latitude'] as double;
                    final lng = r['last_longitude'] as double;
                    final isSelected =
                        _selectedRepartidor != null &&
                        _selectedRepartidor!['id'] == r['id'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRepartidor = r;
                        });
                        _mapController.move(LatLng(lat, lng), 15.0);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.cyanAccent.withOpacity(0.15)
                              : const Color(0xFF1E293B).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.cyanAccent
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                           children: [
                            buildAvatarHelper(
                              r['full_name'] ?? email,
                              r['avatar_url'] as String?,
                              radius: 16,
                              fontSize: 10,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  email.split('@').first,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Ver en mapa',
                                  style: GoogleFonts.outfit(
                                    color: isSelected
                                        ? Colors.cyanAccent
                                        : Colors.grey,
                                    fontSize: 10,
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
              ),
            ),

          // Detail Card for Selected Driver (Approximate address, coordinates, name)
          if (_selectedRepartidor != null)
            Positioned(
              bottom: 190,
              left: 16,
              right: 16,
              child: Card(
                color: const Color(0xFF1E293B).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.cyanAccent, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          buildAvatarHelper(
                            _selectedRepartidor!['full_name'] ??
                                _selectedRepartidor!['email'],
                            _selectedRepartidor!['avatar_url'] as String?,
                            radius: 22,
                            fontSize: 14,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedRepartidor!['full_name'] ??
                                      _selectedRepartidor!['email'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _selectedRepartidor!['email'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedRepartidor = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.cyanAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Calle aproximada:',
                                  style: GoogleFonts.outfit(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedRepartidor!['address'] ??
                                      'Obteniendo dirección...',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

// Custom painter for map pin pointers
class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

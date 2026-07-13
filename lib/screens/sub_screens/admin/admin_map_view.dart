import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _googleMapController;
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
    int counter = 0;
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {});
        counter += 2;
        if (counter >= 20) {
          counter = 0;
          Provider.of<OrderProvider>(
            context,
            listen: false,
          ).fetchRepartidoresLocations();
        }
      }
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
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.0),
        );
      });
    }

    final Set<Marker> markers = repartidores.map((r) {
      final lat = r['last_latitude'] as double;
      final lng = r['last_longitude'] as double;
      final email = r['email'] as String? ?? 'Sin email';
      final String driverUserId = r['user_id'] as String? ?? email;
      final isDriverOnline = r['is_online'] as bool? ?? false;
      final isSelected = _selectedRepartidor != null &&
          _selectedRepartidor!['user_id'] == r['user_id'];

      return Marker(
        markerId: MarkerId(driverUserId),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected
              ? BitmapDescriptor.hueYellow
              : (isDriverOnline ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueRed),
        ),
        infoWindow: InfoWindow(
          title: r['full_name'] ?? email,
          snippet: isDriverOnline ? 'En línea' : 'Desconectado',
        ),
        onTap: () {
          setState(() {
            _selectedRepartidor = r;
          });
          _googleMapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.0),
          );
        },
      );
    }).toSet();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // GoogleMap Layer
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-26.18500, -58.17417),
                zoom: 13.0,
              ),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              markers: markers,
              onMapCreated: (controller) {
                _googleMapController = controller;
              },
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

                    // Eval conexión del preventista
                    bool isDriverOnline = false;
                    final lastSeenStr = r['last_seen_at'] as String?;
                    if (lastSeenStr != null) {
                      try {
                        final lastSeen = DateTime.parse(lastSeenStr);
                        final difference = DateTime.now().toUtc().difference(lastSeen);
                        isDriverOnline = difference.inSeconds <= 30;
                      } catch (_) {
                        isDriverOnline = false;
                      }
                    }

                    Widget avatarWidget = buildAvatarHelper(
                      r['full_name'] ?? email,
                      r['avatar_url'] as String?,
                      radius: 16,
                      fontSize: 10,
                    );

                    if (!isDriverOnline) {
                      avatarWidget = ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                        ]),
                        child: avatarWidget,
                      );
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRepartidor = r;
                        });
                        _googleMapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.0),
                        );
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
                              : isDriverOnline
                                  ? const Color(0xFF1E293B).withOpacity(0.9)
                                  : const Color(0xFF0F172A).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.cyanAccent
                                : isDriverOnline
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.white.withOpacity(0.04),
                          ),
                        ),
                        child: Row(
                           children: [
                            avatarWidget,
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

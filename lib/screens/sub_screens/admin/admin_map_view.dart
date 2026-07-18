import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../providers/order_provider.dart';
import '../../../core/network/api_client.dart';

class AdminMapView extends StatefulWidget {
  const AdminMapView({super.key});

  @override
  State<AdminMapView> createState() => _AdminMapViewState();
}

class _AdminMapViewState extends State<AdminMapView> {
  static const Color indigoCustom = Color(0xFF4F46E5);
  GoogleMapController? _googleMapController;
  Map<String, dynamic>? _selectedCliente;
  Map<String, dynamic>? _selectedRepartidor;
  BitmapDescriptor? _storeMarkerIcon;
  final Map<String, BitmapDescriptor> _repartidorIcons = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createStoreMarkerIcon();
      final op = Provider.of<OrderProvider>(context, listen: false);
      op.fetchClientes();
      op.fetchRepartidoresLocations();
      op.fetchAdminAgendasToday();
      op.fetchAdminOrders();
    });
  }

  Future<void> _createStoreMarkerIcon() async {
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -200,
        top: -200,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 32,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 2,
                  top: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedStore03,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 11,
                  top: 26,
                  child: CustomPaint(
                    size: const Size(10, 8),
                    painter: _TrianglePainter(color: const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (key.currentContext != null) break;
    }

    try {
      if (key.currentContext != null) {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          _storeMarkerIcon = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error creating marker icon: $e');
    }

    entry.remove();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    
    // Auto-focus on selected repartidor from providers list
    final selectedRepForMap = provider.selectedRepartidorForMap;
    if (selectedRepForMap != null) {
      final double? lat = selectedRepForMap['lastLatitude'] as double? ?? selectedRepForMap['last_latitude'] as double?;
      final double? lng = selectedRepForMap['lastLongitude'] as double? ?? selectedRepForMap['last_longitude'] as double?;
      if (lat != null && lng != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _googleMapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0),
          );
          provider.selectRepartidorForMap(null);
        });
      }
    }

    final clientes = provider.clientes
        .where((c) => c['latitude'] != null && c['longitude'] != null)
        .toList();

    final Set<Marker> markers = {};

    for (final c in clientes) {
      final lat = c['latitude'] as double;
      final lng = c['longitude'] as double;
      final id = c['id'] as String;
      final name = c['name'] as String? ?? 'Sucursal';
      final owner = c['ownerName'] as String? ?? c['owner_name'] as String? ?? '';
      final isSelected = _selectedCliente != null && _selectedCliente!['id'] == c['id'];

      markers.add(
        Marker(
          markerId: MarkerId('client_$id'),
          position: LatLng(lat, lng),
          icon: _storeMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: _storeMarkerIcon != null ? const Offset(0.5, 0.9) : const Offset(0.5, 1),
          infoWindow: InfoWindow(
            title: name,
            snippet: owner.isNotEmpty ? 'Dueño: $owner' : null,
          ),
          onTap: () {
            setState(() {
              _selectedCliente = c;
            });
            _googleMapController?.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.0),
            );
          },
        ),
      );
    }

    final repartidores = provider.repartidores;
    for (final r in repartidores) {
      final double? lat = r['lastLatitude'] as double? ?? r['last_latitude'] as double?;
      final double? lng = r['lastLongitude'] as double? ?? r['last_longitude'] as double?;
      if (lat == null || lng == null) continue;

      final lastSeenStr = (r['lastLocationUpdated'] ?? r['last_location_updated']) as String?;
      bool isOnline = false;
      if (lastSeenStr != null) {
        try {
          final lastSeen = DateTime.parse(lastSeenStr);
          isOnline = DateTime.now().toUtc().difference(lastSeen).inSeconds <= 60;
        } catch (_) {}
      }

      final String repId = (r['id'] ?? '').toString();
      final String avatarUrl = r['avatarUrl'] as String? ?? r['avatar_url'] as String? ?? '';
      final String cacheKey = '${repId}_${avatarUrl}_$isOnline';

      BitmapDescriptor? customIcon = _repartidorIcons[cacheKey];
      if (customIcon == null) {
        _createRepartidorMarkerIcon(r, isOnline).then((icon) {
          if (mounted) {
            setState(() {
              _repartidorIcons[cacheKey] = icon;
            });
          }
        });
      }

      markers.add(
        Marker(
          markerId: MarkerId('repartidor_$repId'),
          position: LatLng(lat, lng),
          icon: customIcon ?? BitmapDescriptor.defaultMarkerWithHue(
            isOnline ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueRed,
          ),
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: r['full_name'] ?? r['fullName'] ?? 'Repartidor',
            snippet: '${r['tipo_vehiculo'] ?? 'Vehículo'} • ${isOnline ? 'En línea' : 'Desconectado'}',
          ),
          onTap: () {
            setState(() {
              _selectedCliente = null;
              _selectedRepartidor = r;
            });
            _googleMapController?.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.0),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-26.18500, -58.17417),
              zoom: 12.0,
            ),
            zoomControlsEnabled: true,
            myLocationButtonEnabled: false,
            markers: markers,
            onMapCreated: (controller) {
              _googleMapController = controller;
              controller.setMapStyle('''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0f172a"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#94a3b8"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#0f172a"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#334155"
      }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#1e293b"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0f172a"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1e293b"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#64748b"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1e293b"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#94a3b8"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#334155"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#020617"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#475569"
      }
    ]
  }
]
              ''');
            },
          ),

          if (_selectedCliente != null)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedStore03,
                            color: Colors.greenAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCliente!['name'] ?? 'Sucursal',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _selectedCliente!['ownerName'] ?? _selectedCliente!['owner_name'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _selectedCliente = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white70, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    _infoRow(Icons.badge_outlined, 'DNI/CUIT', _selectedCliente!['taxId'] ?? '-'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.phone_outlined, 'Celular', _selectedCliente!['phone'] ?? '-'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.location_on_outlined, 'Dirección', _selectedCliente!['address'] ?? ''),
                  ],
                ),
              ),
            ),

          if (_selectedRepartidor != null)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: Builder(
                builder: (context) {
                  final currentRep = _selectedRepartidor!;
                  bool isOnline = false;
                  double distance = 0.0;

                  final lastSeenStr = (currentRep['lastLocationUpdated'] ?? currentRep['last_location_updated']) as String?;
                  if (lastSeenStr != null) {
                    try {
                      final lastSeen = DateTime.parse(lastSeenStr);
                      isOnline = DateTime.now().toUtc().difference(lastSeen).inSeconds <= 60;
                    } catch (_) {}
                  }

                  final selectedAgenda = provider.adminAgendasToday.firstWhere(
                    (a) => a['preventista'] != null && (a['preventista']['id'] ?? '').toString() == currentRep['id']?.toString(),
                    orElse: () => {},
                  );

                  if (selectedAgenda.isNotEmpty && selectedAgenda['items'] != null) {
                    final completedCount = (selectedAgenda['items'] as List)
                        .where((it) => it['status'] == 'COMPLETADO')
                        .length;
                    distance = completedCount == 0 ? 0.0 : (completedCount * 2.8 + 1.5);
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: indigoCustom, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                                image: currentRep['avatarUrl'] != null || currentRep['avatar_url'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(currentRep['avatarUrl'] ?? currentRep['avatar_url']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: currentRep['avatarUrl'] == null && currentRep['avatar_url'] == null
                                  ? const Center(
                                      child: Icon(Icons.person, color: Colors.white70),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentRep['full_name'] ?? currentRep['fullName'] ?? 'Preventista',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isOnline ? Colors.greenAccent : Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOnline ? 'En línea' : 'Desconectado',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _selectedRepartidor = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white70, size: 16),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _metricBox('Recorrido', '${distance.toStringAsFixed(1)} km', Icons.directions_run),
                            _metricBox('Vehículo', currentRep['tipo_vehiculo'] ?? 'Ninguno', Icons.local_shipping_outlined),
                            _metricBox('Matrícula', currentRep['matricula'] ?? 'S/M', Icons.pin_outlined),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Agenda y Visitas de Hoy',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (selectedAgenda.isEmpty || selectedAgenda['items'] == null || (selectedAgenda['items'] as List).isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No tiene visitas planificadas para hoy.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.openSans(color: Colors.grey, fontSize: 11),
                            ),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 150),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: (selectedAgenda['items'] as List).length,
                              itemBuilder: (context, idx) {
                                final item = selectedAgenda['items'][idx];
                                final client = item['client'] as Map<String, dynamic>? ?? {};
                                final clientName = client['name'] ?? 'Cliente';
                                final isItemCompleted = item['status'] == 'COMPLETADO';

                                // Find client orders taken by this preventista today
                                final clientOrders = provider.adminOrders.where((o) =>
                                    (o['user_id'] == client['id'] || o['client_name'] == clientName) &&
                                    o['repartidor_id']?.toString() == currentRep['id']?.toString()
                                ).toList();

                                String orderDetails = '';
                                if (clientOrders.isNotEmpty) {
                                  orderDetails = clientOrders.map((o) => o['product_name'] ?? '').join(', ');
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.storefront_outlined, color: Colors.greenAccent, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              clientName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (orderDetails.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Pedido: $orderDetails',
                                                style: GoogleFonts.openSans(
                                                  fontSize: 10,
                                                  color: Colors.greenAccent,
                                                ),
                                              ),
                                            ] else if (isItemCompleted && item['notes'] != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Nota: ${item['notes']}',
                                                style: GoogleFonts.openSans(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isItemCompleted ? const Color(0xFF065F46) : Colors.white12,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isItemCompleted ? 'Visitado' : 'Pendiente',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isItemCompleted ? Colors.greenAccent : Colors.white60,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.greenAccent, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.greenAccent, size: 16),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<ui.Image?> _loadAvatarImage(String path) async {
    try {
      ImageProvider provider;
      if (path.startsWith('assets/')) {
        provider = AssetImage(path);
      } else if (path.startsWith('/api/')) {
        provider = NetworkImage('${ApiClient.orderBaseUrl}$path');
      } else if (path.startsWith('/') || path.startsWith('file://') || path.contains('cache')) {
        provider = FileImage(File(path));
      } else {
        provider = NetworkImage(path);
      }

      final Completer<ui.Image> completer = Completer();
      final ImageStream stream = provider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo imageInfo, bool synchronousCall) {
          completer.complete(imageInfo.image);
          stream.removeListener(listener);
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          debugPrint('Error loading avatar image stream for marker: $exception');
          completer.completeError(exception);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      return await completer.future;
    } catch (e) {
      debugPrint('Failed to load avatar image for marker: $e');
      return null;
    }
  }

  Future<BitmapDescriptor> _createRepartidorMarkerIcon(Map<String, dynamic> r, bool isOnline) async {
    final double size = 64.0;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint borderPaint = Paint()
      ..color = isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Path path = Path();
    path.moveTo(size / 2 - 8, size / 2 + 15);
    path.lineTo(size / 2 + 8, size / 2 + 15);
    path.lineTo(size / 2, size + 5);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 1.5)), Paint()..color = Colors.black26..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 + 1, Paint()..color = Colors.black12..style = PaintingStyle.fill);

    canvas.drawPath(path, borderPaint);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, whitePaint);

    final String? avatarUrl = r['avatarUrl'] as String? ?? r['avatar_url'] as String?;
    ui.Image? avatarImage;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarImage = await _loadAvatarImage(avatarUrl);
    }

    if (avatarImage != null) {
      final double radius = size / 2 - 4;
      final Rect imageRect = Rect.fromCircle(center: Offset(size / 2, size / 2), radius: radius);
      canvas.save();
      canvas.clipPath(Path()..addOval(imageRect));

      paintImage(
        canvas: canvas,
        rect: imageRect,
        image: avatarImage,
        fit: BoxFit.cover,
      );
      canvas.restore();
    } else {
      final String name = r['full_name'] ?? r['fullName'] ?? 'R';
      final String initials = name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase();
      final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: initials,
        style: GoogleFonts.inter(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size / 2 - textPainter.width / 2, size / 2 - textPainter.height / 2),
      );
    }

    final ui.Image markerImage = await pictureRecorder.endRecording().toImage(size.toInt(), (size + 10).toInt());
    final ByteData? byteData = await markerImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

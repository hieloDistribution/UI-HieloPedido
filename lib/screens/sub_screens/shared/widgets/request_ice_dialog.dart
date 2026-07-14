import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../providers/order_provider.dart';
import 'success_overlay_dialog.dart';

Future<String> _reverseGeocode(double lat, double lng) async {
  try {
    final response = await http.get(
      Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'),
      headers: {'User-Agent': 'order_flow_app'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'] as String? ?? 'Dirección seleccionada';
    }
  } catch (e) {
    debugPrint('Error reverse geocoding: $e');
  }
  return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
}

Future<Position?> _getCurrentPosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return null;
  }
  
  if (permission == LocationPermission.deniedForever) return null;

  return await Geolocator.getCurrentPosition();
}

void _showMapLocationPickerDialog(
  BuildContext context,
  LatLng initialCenter,
  Function(LatLng point, String address) onLocationPicked,
) {
  LatLng? selectedPoint;
  bool isSearching = false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setMapState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              height: 500,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialCenter,
                      zoom: 15.0,
                    ),
                    onTap: (LatLng point) {
                      setMapState(() {
                        selectedPoint = point;
                      });
                    },
                    markers: selectedPoint == null
                        ? {}
                        : {
                            Marker(
                              markerId: const MarkerId('selected'),
                              position: selectedPoint!,
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                            ),
                          },
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Toca el mapa para ubicar la entrega',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedPoint == null || isSearching
                                ? null
                                : () async {
                                    setMapState(() {
                                      isSearching = true;
                                    });
                                    final address = await _reverseGeocode(
                                      selectedPoint!.latitude,
                                      selectedPoint!.longitude,
                                    );
                                    onLocationPicked(selectedPoint!, address);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: isSearching
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Confirmar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showRequestIceDialog(
  BuildContext context,
  OrderProvider provider, {
  String? productId,
  String? productName,
  double? productPrice,
}) {
  final name = productName ?? 'Bolsa de Hielo Premium 5kg';
  final price = productPrice ?? 15000.0;
  int quantity = 1;
  final metadata = provider.currentUser?.userMetadata;
  final addressController = TextEditingController(
    text: metadata?['direccion'] ?? metadata?['direccion_defecto'] ?? '',
  );
  final phoneController = TextEditingController(
    text: metadata?['phone'] ?? metadata?['celular'] ?? '',
  );
  String? selectedRepartidorId;
  String paymentMethod = 'efectivo'; // Default payment method

  double? selectedLatitude;
  double? selectedLongitude;
  bool isLocating = false;

  // Prefetch drivers
  provider.fetchRepartidoresLocations();

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final currencyFormatter = NumberFormat.simpleCurrency(
            locale: 'es_PY',
            name: 'Gs',
            decimalDigits: 0,
          );
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            title: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.cyan, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Solicitar Hielo',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Precio: ${currencyFormatter.format(price)} por unidad',
                    style: GoogleFonts.openSans(
                      color: Colors.teal,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),

                  // Quantity Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cantidad:',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              if (quantity > 1) {
                                setDialogState(() => quantity--);
                              }
                            },
                          ),
                          Text(
                            '$quantity',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              setDialogState(() => quantity++);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Payment Method Section
                  Text(
                    'Medio de Pago:',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.payments_outlined,
                            color: paymentMethod == 'efectivo' ? Colors.white : Colors.black87,
                            size: 18,
                          ),
                          label: Text(
                            'Efectivo',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: paymentMethod == 'efectivo' ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: paymentMethod == 'efectivo',
                          selectedColor: Colors.black,
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => paymentMethod = 'efectivo');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.account_balance_outlined,
                            color: paymentMethod == 'transferencia' ? Colors.white : Colors.black87,
                            size: 18,
                          ),
                          label: Text(
                            'Transferencia',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: paymentMethod == 'transferencia' ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: paymentMethod == 'transferencia',
                          selectedColor: Colors.black,
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => paymentMethod = 'transferencia');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location Picker Section
                  Text(
                    'Ubicación de Entrega:',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Current Location Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLocating
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isLocating = true;
                                  });
                                  final pos = await _getCurrentPosition();
                                  if (pos != null) {
                                    final addr = await _reverseGeocode(pos.latitude, pos.longitude);
                                    setDialogState(() {
                                      selectedLatitude = pos.latitude;
                                      selectedLongitude = pos.longitude;
                                      addressController.text = addr;
                                    });
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('No se pudo obtener la ubicación GPS.'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                  setDialogState(() {
                                    isLocating = false;
                                  });
                                },
                          icon: isLocating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
                                )
                              : const Icon(Icons.my_location, size: 16, color: Colors.cyan),
                          label: Text(
                            'Actual GPS',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Map Selection Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final initialCenter = LatLng(
                              selectedLatitude ?? -26.19861,
                              selectedLongitude ?? -58.14722,
                            );
                            _showMapLocationPickerDialog(
                              context,
                              initialCenter,
                              (point, address) {
                                setDialogState(() {
                                  selectedLatitude = point.latitude;
                                  selectedLongitude = point.longitude;
                                  addressController.text = address;
                                });
                              },
                            );
                          },
                          icon: const Icon(Icons.map_outlined, size: 16, color: Colors.cyan),
                          label: Text(
                            'Buscar en Mapa',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Address Input Text Area
                  TextField(
                    controller: addressController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Dirección Detallada',
                      labelStyle: const TextStyle(color: Color(0xFF64748B)),
                      suffixIcon: selectedLatitude != null
                          ? const Icon(Icons.check_circle_outline, color: Colors.green, size: 20)
                          : null,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phone Input
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: 'Teléfono de Contacto',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Repartidor Selector Dropdown (Escucha cambios de OrderProvider reactivamente)
                  Consumer<OrderProvider>(
                    builder: (context, orderProvider, child) {
                      return DropdownButtonFormField<String?>(
                        value: selectedRepartidorId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          labelText: 'Repartidor Preferido (Opcional)',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.cyan),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Cualquier repartidor disponible',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                          ...orderProvider.repartidores.map((driver) {
                            return DropdownMenuItem<String?>(
                              value: driver['id'] as String?,
                              child: Text(
                                '${driver['full_name'] ?? "Repartidor"} (${driver['tipo_vehiculo'] ?? "Moto"})',
                                style: const TextStyle(color: Colors.black87),
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedRepartidorId = val;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final addr = addressController.text.trim();
                  final ph = phoneController.text.trim();
                  if (addr.isEmpty || ph.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor completa todos los campos'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  // Validar reglas de negocio (peso mínimo, stock, ruta) antes
                  // de tocar la red. Buscamos el producto en el catálogo real
                  // para tener weightKg/stock; si no está (no se cargó el
                  // catálogo), omitimos la validación cliente y dejamos que
                  // el backend responda.
                  final product = provider.catalogProducts.firstWhere(
                    (p) => p['id'] == productId,
                    orElse: () => const <String, dynamic>{},
                  );
                  if (product.isNotEmpty) {
                    final v = OrderProvider.validateOrder(
                      product: product,
                      quantity: quantity,
                    );
                    if (!v.ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(v.message!),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }
                  }

                  final err = await provider.addClientOrder(
                    name,
                    quantity,
                    price,
                    addr,
                    ph,
                    productId: productId ?? 'hielo_bag',
                    preferredRepartidorId: selectedRepartidorId,
                    paymentMethod: paymentMethod,
                    latitude: selectedLatitude,
                    longitude: selectedLongitude,
                  );
                  if (err != null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    showPremiumSuccessDialog(
                      context,
                      title: 'Pedido Solicitado',
                      message: 'Tu pedido se ha registrado correctamente y el preventista de la zona será alertado.',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Confirmar Pedido',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

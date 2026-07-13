import 'dart:ui' show ImageFilter;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';
import '../shared/widgets/success_overlay_dialog.dart';

// --- IceProduct model for Carousel ---
class IceProduct {
  final String id;
  final String name;
  final String weight;
  final double price;
  final String description;
  final List<String> features;
  final String promoBadge;
  final String businessRecommendation;

  const IceProduct({
    required this.id,
    required this.name,
    required this.weight,
    required this.price,
    required this.description,
    required this.features,
    required this.promoBadge,
    required this.businessRecommendation,
  });
}

class ClienteComprasView extends StatefulWidget {
  const ClienteComprasView({super.key});

  @override
  State<ClienteComprasView> createState() => _ClienteComprasViewState();
}

class _ClienteComprasViewState extends State<ClienteComprasView> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  double _pageOffset = 0.0;

  final List<IceProduct> _staticProducts = const [
    IceProduct(
      id: "PROD-ICE-002",
      name: "Bolsa de Hielo Premium 5kg",
      weight: "5 kg",
      price: 1500.0,
      description:
          "Hielo de agua purificada, filtrado por ósmosis inversa. Cilindros compactos y cristalinos de larga duración, ideales para la conservación en heladeras comerciales.",
      features: [
        "Rolito Macizo",
        "Purificación por Ósmosis",
        "Bolsa Hermética Reforzada",
      ],
      promoBadge: "Más Vendido",
      businessRecommendation:
          "Ideal para tu tienda: Formato de alta rotación. Recomendado para autoservicios y minimárquets por su fácil almacenamiento y demanda diaria constante.",
    ),
    IceProduct(
      id: "PROD-ICE-003",
      name: "Bolsa de Hielo Familiar 10kg",
      weight: "10 kg",
      price: 2500.0,
      description:
          "La medida perfecta para abastecimiento a gran escala. Hielo de alta densidad que mantiene el frío por mucho más tiempo, optimizando el rendimiento de conservadoras industriales.",
      features: [
        "Formato Ahorro Mayorista",
        "Ideal para Gastronomía",
        "Cristalino de Larga Duración",
      ],
      promoBadge: "Mejor Valor",
      businessRecommendation:
          "Optimizado para tu local: Margen de ganancia maximizado. El favorito de restaurantes, bares y depósitos por su excelente rendimiento térmico por kilo.",
    ),
    IceProduct(
      id: "PROD-ICE-004",
      name: "Hielo Triturado Premium 8kg",
      weight: "8 kg",
      price: 2000.0,
      description:
          "Especialmente diseñado para coctelería, jugos y enfriamiento instantáneo de barras. Granulación uniforme de fácil manejo para despacho inmediato.",
      features: [
        "Textura Especial Barra",
        "Fácil de Servir",
        "Enfriamiento de Alta Velocidad",
      ],
      promoBadge: "Especial Barra",
      businessRecommendation:
          "Recomendado para tu rubro: Producto de nicho premium. Excelente opción si tu comercio cuenta con barra de tragos o expendio de jugos frescos.",
    ),
  ];

  List<IceProduct> _getProducts(OrderProvider orderProvider) {
    if (orderProvider.catalogProducts.isNotEmpty) {
      return orderProvider.catalogProducts.map((item) {
        final id = item['id'] as String? ?? '';
        final name = item['name'] as String? ?? 'Hielo';
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final weightKg = (item['weightKg'] as num?)?.toDouble() ?? 5.0;

        String description = "Hielo de agua purificada, filtrado por ósmosis inversa. Cilindros compactos y cristalinos de larga duración.";
        String weight = "${weightKg.toStringAsFixed(0)} kg";
        List<String> features = ["Hielo Cristalino", "Agua Purificada"];
        String promoBadge = "Destacado";
        String businessRecommendation = "Recomendado para todo tipo de comercios.";

        if (id == 'PROD-ICE-001') {
          description = 'Saco de 10 kg con 5 bolsas individuales de 2 kg. Perfecto para enfriadores medianos y venta directa.';
          weight = '10 kg';
          features = ['Bolsas individuales', 'Fácil dosificación', 'Ideal para camping'];
          promoBadge = 'Familiar';
          businessRecommendation = 'Recomendado para almacenes y minimercados con alta rotación.';
        } else if (id == 'PROD-ICE-002') {
          description = 'Bolsa de cubos macizos de 5 kg. Hielo cristalino de disolución lenta.';
          weight = '5 kg';
          features = ['Disolución lenta', '100% agua filtrada', 'Cubos macizos'];
          promoBadge = 'Más Vendido';
          businessRecommendation = 'Recomendado para bares, restaurantes y boliches.';
        } else if (id == 'PROD-ICE-003') {
          description = 'Bolsa de hielo molido de 10 kg. Hielo de alta densidad que mantiene el frío por mucho más tiempo.';
          weight = '10 kg';
          features = ['Enfriado rápido', 'Fácil de moldear', 'Ideal para coctelería'];
          promoBadge = 'Especial Tragos';
          businessRecommendation = 'Excelente opción para coctelería fina y expendio de jugos.';
        } else if (id == 'PROD-ICE-004') {
          description = 'Bolsa de hielo en escamas de 15 kg. Excelente cobertura para exhibición de productos.';
          weight = '15 kg';
          features = ['Gran superficie de contacto', 'Ideal pescaderías', 'Duradero'];
          promoBadge = 'Industrial';
          businessRecommendation = 'Recomendado para pescaderías, buffets y eventos gastronómicos.';
        } else if (id == 'hielo_bag') {
          description = 'Bolsa de Hielo Estándar de 5 kg. Versátil y práctica.';
          weight = '5 kg';
          features = ['Fácil manejo', 'Hielo cristalino'];
          promoBadge = 'Estándar';
          businessRecommendation = 'La opción más versátil para tener stock en cualquier momento.';
        }

        return IceProduct(
          id: id,
          name: name,
          weight: weight,
          price: price,
          description: description,
          features: features,
          promoBadge: promoBadge,
          businessRecommendation: businessRecommendation,
        );
      }).toList();
    }
    return _staticProducts;
  }

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _pageOffset = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getCurrentPage(List<IceProduct> products) =>
      _pageOffset.round().clamp(0, products.length - 1);

  // Helper de Geocodificación Inversa
  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
        ),
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

  // Helper de Geolocalización GPS
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

  // Sub-pantalla interactiva de Mapa tipo UBER para elegir Ubicación
  void _openMapPicker(
    BuildContext context,
    Function(LatLng) onLocationSelected,
  ) {
    LatLng centerPosition = const LatLng(-26.18500, -58.17417);

    showNavigatorScreen(BuildContext ctx) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Mueve el mapa',
            style: GoogleFonts.outfit(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: centerPosition,
                zoom: 15.0,
              ),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              onCameraMove: (position) {
                centerPosition = position.target;
              },
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: const Icon(
                  Icons.location_on,
                  size: 45,
                  color: Colors.cyan,
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    onLocationSelected(centerPosition);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirmar este punto 📍',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => showNavigatorScreen(context)),
    );
  }

  // --- Modal Bottom Sheet Premium de Solicitud ---
  void _openRequestIceView(
    BuildContext context,
    OrderProvider provider,
    IceProduct product,
  ) {
    provider.fetchRepartidoresLocations();

    int orderQuantity = 1;
    String? preferredDriverId;

    LatLng? selectedCoordinates;
    if (provider.businessLatitude != null &&
        provider.businessLongitude != null) {
      selectedCoordinates = LatLng(
        provider.businessLatitude!,
        provider.businessLongitude!,
      );
    }

    String addressText = provider.currentUser?.userMetadata?['direccion'] ?? '';
    String paymentMethod = 'efectivo';
    bool isLocating = false;
    bool forceCustomLocation = false;

    final phoneController = TextEditingController(
      text:
          provider.currentUser?.userMetadata?['phone'] ??
          provider.currentUser?.userMetadata?['celular'] ??
          '',
    );
    final addressController = TextEditingController(text: addressText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currencyFormatter = NumberFormat.simpleCurrency(
              locale: 'es_PY',
              name: 'Gs',
              decimalDigits: 0,
            );

            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmar Compra Mayorista',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.name} • ${currencyFormatter.format(product.price)}',
                      style: GoogleFonts.openSans(
                        color: Colors.cyan.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),

                    // Cantidad
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cantidad de Bolsas:',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.black87,
                              ),
                              onPressed: () => orderQuantity > 1
                                  ? setModalState(() => orderQuantity--)
                                  : null,
                            ),
                            Text(
                              '$orderQuantity',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.black87,
                              ),
                              onPressed: () =>
                                  setModalState(() => orderQuantity++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Medio de pago
                    Text(
                      'Medio de Pago:',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            avatar: Icon(
                              Icons.payments_outlined,
                              color: paymentMethod == 'efectivo'
                                  ? Colors.white
                                  : Colors.black87,
                              size: 18,
                            ),
                            label: Text(
                              'Efectivo',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: paymentMethod == 'efectivo'
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            selected: paymentMethod == 'efectivo',
                            selectedColor: Colors.black,
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (selected) {
                              if (selected)
                                setModalState(() => paymentMethod = 'efectivo');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            avatar: Icon(
                              Icons.account_balance_outlined,
                              color: paymentMethod == 'transferencia'
                                  ? Colors.white
                                  : Colors.black87,
                              size: 18,
                            ),
                            label: Text(
                              'Transferencia',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: paymentMethod == 'transferencia'
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            selected: paymentMethod == 'transferencia',
                            selectedColor: Colors.black,
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (selected) {
                              if (selected)
                                setModalState(
                                  () => paymentMethod = 'transferencia',
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: 'Teléfono del Local',
                        labelStyle: TextStyle(color: Color(0xFF64748B)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Destino de Carga:',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (provider.businessLatitude != null &&
                        provider.businessLongitude != null &&
                        !forceCustomLocation) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.15),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.storefront,
                                  color: Colors.teal,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    provider.businessName ??
                                        'Tu Tienda Mayorista Registrada',
                                    // CORREGIDO: Se quitó el caracter extraño por 'fontWeight' limpio
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'El despacho se enviará de forma inmutable a las coordenadas geográficas de tu local para evitar errores de envío.',
                              style: GoogleFonts.openSans(
                                fontSize: 11,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => setModalState(
                                () => forceCustomLocation = true,
                              ),
                              child: Text(
                                'Cambiar punto de entrega (Solo por esta vez) 🔄',
                                style: GoogleFonts.outfit(
                                  color: Colors.cyan.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isLocating
                                  ? null
                                  : () async {
                                      setModalState(() => isLocating = true);
                                      final pos = await _getCurrentPosition();
                                      if (pos != null) {
                                        final addr = await _reverseGeocode(
                                          pos.latitude,
                                          pos.longitude,
                                        );
                                        setModalState(() {
                                          selectedCoordinates = LatLng(
                                            pos.latitude,
                                            pos.longitude,
                                          );
                                          addressText = addr;
                                          addressController.text = addr;
                                        });
                                      } else {
                                        const fallback = LatLng(
                                          -26.18500,
                                          -58.17417,
                                        );
                                        final addr = await _reverseGeocode(
                                          fallback.latitude,
                                          fallback.longitude,
                                        );
                                        setModalState(() {
                                          selectedCoordinates = fallback;
                                          addressText = addr;
                                          addressController.text = addr;
                                        });
                                      }
                                      setModalState(() => isLocating = false);
                                    },
                              icon: isLocating
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.cyan,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location,
                                      size: 16,
                                      color: Colors.cyan,
                                    ),
                              label: Text(
                                'GPS Actual',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _openMapPicker(context, (
                                  LatLng location,
                                ) async {
                                  setModalState(
                                    () => selectedCoordinates = location,
                                  );
                                  final addr = await _reverseGeocode(
                                    location.latitude,
                                    location.longitude,
                                  );
                                  setModalState(() {
                                    addressText = addr;
                                    addressController.text = addr;
                                  });
                                });
                              },
                              icon: const Icon(
                                Icons.map_outlined,
                                size: 16,
                                color: Colors.cyan,
                              ),
                              label: Text(
                                'Mapa Alternativo',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    TextField(
                      controller: addressController,
                      readOnly:
                          provider.businessLatitude != null &&
                          provider.businessLongitude != null &&
                          !forceCustomLocation,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Dirección Detallada de Entrega',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        suffixIcon: selectedCoordinates != null
                            ? const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 20,
                              )
                            : null,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyan),
                        ),
                      ),
                      onChanged: (val) {
                        addressText = val;
                      },
                    ),
                    const SizedBox(height: 20),

                    // CORREGIDO: Se quitó el caracter extraño por 'fontWeight' limpio
                    Text(
                      'Selecciona tu Repartidor Preferido (Opcional):',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 85,
                      child: Consumer<OrderProvider>(
                        builder: (context, orderProvider, child) {
                          return ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              GestureDetector(
                                onTap: () => setModalState(
                                  () => preferredDriverId = null,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  width: 140,
                                  decoration: BoxDecoration(
                                    color: preferredDriverId == null
                                        ? Colors.cyan.withOpacity(0.05)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: preferredDriverId == null
                                          ? Colors.cyan
                                          : const Color(0xFFE2E8F0),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.flash_on,
                                        size: 20,
                                        color: Colors.cyan,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Asignación veloz',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              ...orderProvider.repartidores.map((driver) {
                                final driverId = driver['id'] as String?;
                                final driverName =
                                    driver['full_name'] as String? ?? 'Chofer';
                                final driverVehicle =
                                    driver['tipo_vehiculo'] as String? ??
                                    'Moto';
                                final driverAvatar =
                                    driver['avatar_url'] as String?;
                                final isSelected =
                                    preferredDriverId == driverId;

                                return GestureDetector(
                                  onTap: () => setModalState(
                                    () => preferredDriverId = driverId,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.cyan.withOpacity(0.05)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.cyan
                                            : const Color(0xFFE2E8F0),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        buildAvatarHelper(
                                          driverName,
                                          driverAvatar,
                                          radius: 20,
                                          fontSize: 12,
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              driverName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              'Vehículo: $driverVehicle',
                                              style: GoogleFonts.openSans(
                                                fontSize: 11,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final ph = phoneController.text.trim();
                          final addr = addressController.text.trim();
                          if (ph.isEmpty || addr.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Por favor, completa el teléfono y la dirección de entrega.',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(context);

                          try {
                            await provider.addClientOrder(
                              product.name,
                              orderQuantity,
                              product.price,
                              addr,
                              ph,
                              productId: product.id,
                              preferredRepartidorId: preferredDriverId,
                              paymentMethod: paymentMethod,
                              latitude: selectedCoordinates?.latitude,
                              longitude: selectedCoordinates?.longitude,
                            );

                            if (context.mounted) {
                              showPremiumSuccessDialog(
                                context,
                                title: 'Compra Confirmada',
                                message: 'Tu pedido de $orderQuantity bolsas (${product.name}) se ha registrado con éxito. 🚀',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showPremiumErrorDialog(
                                context,
                                title: 'Error al solicitar pedido',
                                message: e.toString().replaceAll('Exception: ', '').trim(),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Confirmar Compra',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final currencyFormatter = NumberFormat.simpleCurrency(
      locale: 'es_PY',
      name: 'Gs',
      decimalDigits: 0,
    );
    final products = _getProducts(provider);
    final currentPage = _getCurrentPage(products);
    final activeProduct = products[currentPage];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Catálogo de Distribución',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 380,
              child: PageView.builder(
                controller: _pageController,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  double difference = index - _pageOffset;
                  double scale = (1 - (difference.abs() * 0.15)).clamp(
                    0.8,
                    1.0,
                  );
                  double rotation = difference.clamp(-1.0, 1.0) * -0.2;
                  double translation = difference * -20.0;
                  double blurValue = (difference.abs() * 3.0).clamp(0.0, 3.0);

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..translate(translation, 0.0, 0.0)
                      ..scale(scale)
                      ..rotateY(rotation),
                    alignment: Alignment.center,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: blurValue,
                        sigmaY: blurValue,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 310,
                            height: 310,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.cyan.withOpacity(0.18),
                                  Colors.cyan.withOpacity(0.02),
                                  Colors.transparent,
                                ],
                                stops: const [0.4, 0.8, 1.0],
                              ),
                            ),
                          ),
                          Image.asset(
                            'assets/hielo.png',
                            height: 360,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(products.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentPage == index ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentPage == index
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flash_on,
                            size: 16,
                            color: Colors.cyan,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚡ PROMO: ${activeProduct.promoBadge}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan.shade900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activeProduct.name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            activeProduct.weight,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.cyan.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.analytics_outlined,
                            color: Colors.cyan,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeProduct.businessRecommendation,
                              style: GoogleFonts.openSans(
                                fontSize: 12,
                                color: const Color(0xFF334155),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      activeProduct.description,
                      style: GoogleFonts.openSans(
                        color: const Color(0xFF475569),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...activeProduct.features.map((feature) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.cyan,
                              size: 15,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              feature,
                              style: GoogleFonts.openSans(
                                color: const Color(0xFF334155),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(color: Color(0xFFE2E8F0), height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Precio de Lista',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              currencyFormatter.format(activeProduct.price),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => _openRequestIceView(
                            context,
                            provider,
                            activeProduct,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'COMPRAR',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

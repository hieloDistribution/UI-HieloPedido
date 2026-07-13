import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';
import '../shared/widgets/success_overlay_dialog.dart';

class CreateOrderView extends StatefulWidget {
  const CreateOrderView({super.key});

  @override
  State<CreateOrderView> createState() => _CreateOrderViewState();
}

class _CreateOrderViewState extends State<CreateOrderView> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();

  // Enriquecemos el catálogo con descripciones, imágenes y etiquetas analíticas
  final List<Map<String, dynamic>> _catalog = [
    {
      'id': 'PROD-ICE-001',
      'name': 'Bolsa Hielo Cubos 2kg',
      'price': 120.00,
      'image': 'assets/hielo.png',
      'description':
          'Cilindros compactos de agua purificada por ósmosis inversa. Ideal para conservar el frío de forma individual.',
      'recommendation':
          'Alta Rotación: Este establecimiento solicita con alta frecuencia el formato de 2kg para stock diario.',
    },
    {
      'id': 'PROD-ICE-002',
      'name': 'Bolsa Hielo Cubos 5kg',
      'price': 250.00,
      'image': 'assets/hielo.png',
      'description':
          'Formato estándar familiar y comercial. Rolitos macizos cristalinos de larga duración optimizados para conservadoras.',
      'recommendation':
          'Compra Frecuente: Formato preferido por este local en compras de fin de semana para abastecer su depósito.',
    },
    {
      'id': 'PROD-ICE-003',
      'name': 'Bolsa Hielo Molido 10kg',
      'price': 450.00,
      'image': 'assets/hielo.png',
      'description':
          'Hielo triturado premium uniforme de fácil manipulación, ideal para barras de tragos, licuados y coctelería profesional.',
      'recommendation':
          'Sugerencia Comercial: Recomendado si el local cuenta con expendio de bebidas preparadas o eventos activos.',
    },
    {
      'id': 'PROD-ICE-004',
      'name': 'Bolsa Hielo Escamas 15kg',
      'price': 600.00,
      'image': 'assets/hielo.png',
      'description':
          'Formato industrial de enfriamiento instantáneo en escamas. Diseñado para alta gastronomía y mantención a gran escala.',
      'recommendation':
          'Pedido Especial: Ideal para optimizar el espacio de cámaras de frío industriales si el comercio lo requiere.',
    },
  ];

  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedShop;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<OrderProvider>(context, listen: false).fetchClienteShops();
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() &&
        _selectedProduct != null &&
        _selectedShop != null) {
      final double? price = double.tryParse(_priceController.text);
      if (price == null || price <= 0) return;

      final provider = Provider.of<OrderProvider>(context, listen: false);
      final shopName =
          _selectedShop!['nombre_comercial'] ??
          (_selectedShop!['profiles'] != null
              ? _selectedShop!['profiles']['full_name']
              : null) ??
          'Cliente';

      try {
        provider.addOrder(
          shopName,
          _selectedProduct!['id'] as String,
          _selectedProduct!['name'] as String,
          _quantity,
          price,
          deliveryLatitude: _selectedShop!['latitud_comercial'],
          deliveryLongitude: _selectedShop!['longitud_comercial'],
          deliveryAddress: _selectedShop!['direccion'],
          clientUserId: _selectedShop!['profile_id'],
          clientPhone: _selectedShop!['profiles'] != null
              ? _selectedShop!['profiles']['celular']
              : null,
        );

        showPremiumSuccessDialog(
          context,
          title: 'Venta Registrada',
          message: provider.isOnline
              ? 'La venta mayorista ha sido sincronizada correctamente con la nube.'
              : 'La venta ha sido guardada localmente y se sincronizará automáticamente al recuperar conexión.',
        );

        setState(() {
          _selectedShop = null;
          _priceController.clear();
          _searchController.clear();
          _selectedProduct = null;
          _quantity = 1;
        });
      } catch (e) {
        showPremiumErrorDialog(
          context,
          title: 'Error al registrar venta',
          message: e.toString().replaceAll('Exception: ', '').trim(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Despacho Manual',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. SELECCIONADOR DE LOCALES MAYORISTAS ---
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedShop,
                dropdownColor: Colors.white,
                style: GoogleFonts.outfit(color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Establecimiento Mayorista',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  floatingLabelStyle: const TextStyle(color: Colors.black),
                  prefixIcon: const Icon(
                    Icons.storefront,
                    color: Color(0xFF475569),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                ),
                items: provider.clienteShops.map((shop) {
                  final bName =
                      shop['nombre_comercial'] ??
                      shop['business_name'] ??
                      'Local Sin Nombre';
                  final oName = shop['profiles'] != null
                      ? (shop['profiles']['full_name'] ?? 'Propietario')
                      : 'Propietario';
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: shop,
                    child: Text('$bName (Dueño: $oName)'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedShop = val),
                validator: (val) =>
                    val == null ? 'Selecciona un establecimiento' : null,
              ),
              const SizedBox(height: 16),

              // --- 2. TARJETA MINIMALISTA DE IDENTIDAD COMERCIAL ---
              if (_selectedShop != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.teal.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          buildAvatarHelper(
                            _selectedShop!['profiles'] != null
                                ? (_selectedShop!['profiles']['full_name'] ??
                                      'Cliente')
                                : 'Cliente',
                            _selectedShop!['profiles'] != null
                                ? (_selectedShop!['profiles']['avatar_url']
                                      as String?)
                                : null,
                            radius: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedShop!['nombre_comercial'] ??
                                      _selectedShop!['business_name'] ??
                                      'Comercio Registrado',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Propietario: ${_selectedShop!['profiles'] != null ? (_selectedShop!['profiles']['full_name'] ?? "No especificado") : "No especificado"}',
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() {
                              _selectedShop = null;
                              _searchController.clear();
                            }),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Color(0xFFF1F5F9), thickness: 1),
                      ),
                      _buildInfoRow(
                        Icons.email_outlined,
                        "Correo:",
                        _selectedShop!['profiles'] != null
                            ? (_selectedShop!['profiles']['email'] ?? "S/D")
                            : "S/D",
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        Icons.badge_outlined,
                        "DNI / RUT:",
                        _selectedShop!['dni'] ?? "S/D",
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        Icons.pin_drop_outlined,
                        "Dirección comercial:",
                        _selectedShop!['direccion'] ??
                            "Dirección comercial fija en ruta",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // --- 3. CONFIGURACIÓN DEL DESPACHO DE PRODUCTO ---
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedProduct,
                dropdownColor: Colors.white,
                style: GoogleFonts.outfit(color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Formato de Hielo',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  floatingLabelStyle: const TextStyle(color: Colors.black),
                  prefixIcon: const Icon(
                    Icons.ac_unit,
                    color: Color(0xFF475569),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                ),
                items: _catalog.map((prod) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: prod,
                    child: Text(
                      '${prod['name']} (Precio de lista: \$${prod['price']})',
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedProduct = val;
                    if (val != null) {
                      _priceController.text = (val['price'] as double)
                          .toStringAsFixed(2);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // --- 4. NUEVA TARJETA PREDICTIVA DE PRODUCTO RECOMENDADO (MINIMALISTA ESTILO CLIENTE) ---
              if (_selectedProduct != null) ...[
                Container(
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
                        children: [
                          Image.asset(
                            _selectedProduct!['image'] as String,
                            height: 50,
                            width: 50,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedProduct!['name'] as String,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedProduct!['description'] as String,
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Alerta inteligente de compra frecuente del local
                      if (_selectedShop != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            color: Color(0xFFF1F5F9),
                            thickness: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.cyan.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.analytics_outlined,
                                color: Colors.cyan,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedProduct!['recommendation'] as String,
                                  style: GoogleFonts.openSans(
                                    fontSize: 11,
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Selector de Cantidad Fino y Minimalista
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bolsas a Entregar:',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF475569),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Color(0xFF475569),
                          ),
                          onPressed: () {
                            if (_quantity > 1) setState(() => _quantity--);
                          },
                        ),
                        Text(
                          '$_quantity',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF475569),
                          ),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Input de Precio Pactado Mayorista
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Precio Pactado Final (\$)',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  floatingLabelStyle: const TextStyle(color: Colors.black),
                  prefixIcon: const Icon(
                    Icons.monetization_on_outlined,
                    color: Color(0xFF475569),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return 'Introduce el precio pactado';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Botón "Registrar Venta" Directo en Negro
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'REGISTRAR VENTA',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.openSans(
            fontSize: 12,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

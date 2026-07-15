import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/order_provider.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../shared/widgets/build_avatar_helper.dart';
import '../shared/widgets/success_overlay_dialog.dart';

class CreateOrderView extends StatefulWidget {
  const CreateOrderView({super.key});

  @override
  State<CreateOrderView> createState() => _CreateOrderViewState();
}

class _CreateOrderViewState extends State<CreateOrderView> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedShop;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final p = Provider.of<OrderProvider>(context, listen: false);
      // First attempt — usually succeeds because _bootstrap already ran.
      await p.fetchClienteShops();
      await p.fetchCatalog();
      // Defensive retry: if shops are still empty after a short delay,
      // try once more. Catches edge cases where the first request raced
      // a token refresh or the bootstrap was still in flight.
      if (mounted && p.clienteShops.isEmpty) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await p.fetchClienteShops();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null || _selectedShop == null) return;

    final provider = Provider.of<OrderProvider>(context, listen: false);
    final v = OrderProvider.validateOrder(
      product: _selectedProduct!,
      quantity: _quantity,
    );
    if (!v.ok) {
      _snack(v.message!, isError: true);
      return;
    }

    final shopName = _selectedShop!['name'] ?? 'Cliente';
    final price = (_selectedProduct!['price'] as num).toDouble();

    final err = await provider.addOrder(
      shopName,
      _selectedProduct!['id'] as String,
      _selectedProduct!['name'] as String,
      _quantity,
      price,
      deliveryLatitude: _selectedShop!['latitude'] != null
          ? (_selectedShop!['latitude'] as num).toDouble()
          : null,
      deliveryLongitude: _selectedShop!['longitude'] != null
          ? (_selectedShop!['longitude'] as num).toDouble()
          : null,
      deliveryAddress: _selectedShop!['address'],
      clientUserId: _selectedShop!['id'],
      clientPhone: _selectedShop!['phone'],
    );

    if (err != null) {
      _snack(err, isError: true);
      return;
    }

    if (!mounted) return;
    showPremiumSuccessDialog(
      context,
      title: 'Venta Registrada',
      message: provider.isOnline
          ? 'Sincronizada con el backend (${v.totalKg.toStringAsFixed(1)} kg).'
          : 'Guardada localmente; se sincronizará al recuperar conexión.',
    );
    setState(() {
      _selectedShop = null;
      _searchController.clear();
      _selectedProduct = null;
      _quantity = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final currencyFormatter = NumberFormat.simpleCurrency(
      locale: 'es_PY',
      name: 'Gs',
      decimalDigits: 0,
    );

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
              DropdownButtonFormField<String>(
                value: _selectedShop?['id'] as String?,
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
                  final id = shop['id'] as String? ?? '';
                  final bName = shop['name'] ?? 'Local Sin Nombre';
                  final ruc = shop['tax_id'] ?? 'S/D';
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text('$bName (RUC: $ruc)'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedShop = provider.clienteShops.firstWhere(
                      (s) => s['id'] == val,
                      orElse: () => <String, dynamic>{},
                    );
                  });
                },
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
                            _selectedShop!['name'] ?? 'Cliente',
                            null,
                            radius: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedShop!['name'] ?? 'Comercio Registrado',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Celular: ${_selectedShop!['phone'] ?? "No especificado"}',
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
                        _selectedShop!['email'] ?? "S/D",
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        Icons.badge_outlined,
                        "DNI / RUC:",
                        _selectedShop!['tax_id'] ?? "S/D",
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        Icons.pin_drop_outlined,
                        "Dirección comercial:",
                        _selectedShop!['address'] ??
                            "Dirección comercial fija en ruta",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // --- 3. CONFIGURACIÓN DEL DESPACHO DE PRODUCTO (catálogo real) ---
              if (provider.catalogProducts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cargando catálogo desde el backend…',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedProduct?['id'] as String?,
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
                  items: provider.catalogProducts.map((prod) {
                    final id = prod['id'] as String;
                    final name = prod['name'] as String? ?? 'Producto';
                    final price = (prod['price'] as num?)?.toDouble() ?? 0;
                    final weight = (prod['weightKg'] as num?)?.toDouble() ?? 0;
                    final stock = (prod['stock'] as num?)?.toInt() ?? 0;
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        '$name • ${weight.toStringAsFixed(0)}kg • Stock $stock • ${currencyFormatter.format(price)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProduct = provider.catalogProducts.firstWhere(
                        (p) => p['id'] == val,
                        orElse: () => <String, dynamic>{},
                      );
                    });
                  },
                  validator: (val) =>
                      val == null ? 'Selecciona un producto' : null,
                ),
              const SizedBox(height: 16),

              // --- 4. RESUMEN DEL PRODUCTO SELECCIONADO ---
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
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.ac_unit,
                              size: 28,
                              color: Color(0xFF0284C7),
                            ),
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
                                  'Peso unitario: ${((_selectedProduct!['weightKg'] as num).toDouble()).toStringAsFixed(1)} kg • Stock disponible: ${(_selectedProduct!['stock'] as num).toInt()}',
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Precio de lista: ${currencyFormatter.format((_selectedProduct!['price'] as num).toDouble())}',
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: const Color(0xFF0284C7),
                                    fontWeight: FontWeight.w600,
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
                const SizedBox(height: 16),
              ],

              // Selector de Cantidad editable (campo numérico + +/−)
              QuantityStepper(
                value: _quantity,
                onChanged: (v) => setState(() => _quantity = v),
                label: 'Bolsas a Entregar:',
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

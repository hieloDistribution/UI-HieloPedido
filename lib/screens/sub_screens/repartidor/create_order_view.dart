import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/success_overlay_dialog.dart';

class CreateOrderView extends StatefulWidget {
  final String? prefilledClientId;
  final String? agendaItemId;
  const CreateOrderView({super.key, this.prefilledClientId, this.agendaItemId});

  @override
  State<CreateOrderView> createState() => _CreateOrderViewState();
}

class _CreateOrderViewState extends State<CreateOrderView> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color indigoCustom = Color(0xFF4F46E5);

  final List<Map<String, dynamic>> _catalog = [
    {
      'id': 'PROD-ICE-001',
      'name': 'Bolsa Hielo Cubos 2kg',
      'price': 120.00,
      'image': 'assets/hielo.png',
      'description': 'Cilindros compactos de agua purificada por ósmosis inversa. Ideal para conservar el frío.',
    },
    {
      'id': 'PROD-ICE-002',
      'name': 'Bolsa Hielo Cubos 5kg',
      'price': 250.00,
      'image': 'assets/hielo.png',
      'description': 'Formato estándar familiar y comercial. Rolitos macizos de larga duración.',
    },
    {
      'id': 'PROD-ICE-003',
      'name': 'Bolsa Hielo Molido 10kg',
      'price': 450.00,
      'image': 'assets/hielo.png',
      'description': 'Hielo triturado premium uniforme de fácil manipulación, ideal para licuados y coctelería.',
    },
    {
      'id': 'PROD-ICE-004',
      'name': 'Bolsa Hielo Escamas 15kg',
      'price': 600.00,
      'image': 'assets/hielo.png',
      'description': 'Formato industrial de enfriamiento instantáneo en escamas para alta gastronomía.',
    },
  ];

  // Mapa de cantidad seleccionada por producto ID
  final Map<String, int> _selectedQuantities = {};
  Map<String, dynamic>? _selectedShop;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Inicializar cantidades a 0
    for (var prod in _catalog) {
      _selectedQuantities[prod['id']] = 0;
    }

    Future.microtask(() async {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      await provider.fetchClienteShops();
      if (widget.prefilledClientId != null) {
        final match = provider.clienteShops.firstWhere(
          (shop) => shop['id'] == widget.prefilledClientId,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          setState(() {
            _selectedShop = match;
          });
        }
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    double total = 0.0;
    for (var prod in _catalog) {
      final qty = _selectedQuantities[prod['id']] ?? 0;
      total += (prod['price'] as double) * qty;
    }
    return total;
  }

  void _submit() {
    if (_selectedShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un cliente.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List<Map<String, dynamic>> selectedItems = [];
    for (var prod in _catalog) {
      final qty = _selectedQuantities[prod['id']] ?? 0;
      if (qty > 0) {
        selectedItems.add({
          'productId': prod['id'],
          'productName': prod['name'],
          'quantity': qty,
          'price': prod['price'],
        });
      }
    }

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona al menos un formato de hielo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = Provider.of<OrderProvider>(context, listen: false);
    final shopName = _selectedShop!['nombre_comercial'] ?? 'Cliente';

    // Resumen amigable del producto
    final productNameSummary = selectedItems
        .map((it) => '${it['productName'].toString().replaceAll('Bolsa Hielo ', '')} (x${it['quantity']})')
        .join(', ');

    try {
      provider.addOrder(
        shopName,
        jsonEncode(selectedItems), // Guardamos el JSON de los hielos en productId
        productNameSummary,
        1, // Cantidad base 1, el detalle va en la lista interna
        _totalAmount,
        deliveryLatitude: _selectedShop!['latitud_comercial'],
        deliveryLongitude: _selectedShop!['longitud_comercial'],
        deliveryAddress: _selectedShop!['direccion'],
        clientUserId: _selectedShop!['profile_id'],
        clientPhone: _selectedShop!['celular'],
      );

      if (widget.agendaItemId != null) {
        provider.completeAgendaItem(widget.agendaItemId!, 'Pedido tomado desde el formulario');
      }

      showPremiumSuccessDialog(
        context,
        title: 'Venta Registrada',
        message: provider.isOnline
            ? 'La venta mayorista ha sido sincronizada correctamente con la nube.'
            : 'La venta ha sido guardada localmente y se sincronizará automáticamente al recuperar conexión.',
      );

      setState(() {
        if (widget.prefilledClientId == null) {
          _selectedShop = null;
        }
        _searchController.clear();
        for (var prod in _catalog) {
          _selectedQuantities[prod['id']] = 0;
        }
      });
    } catch (e) {
      showPremiumErrorDialog(
        context,
        title: 'Error al registrar venta',
        message: e.toString().replaceAll('Exception: ', '').trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);

    // Filtrar clientes
    final filteredShops = provider.clienteShops.where((shop) {
      final bName = (shop['nombre_comercial'] ?? '').toString().toLowerCase();
      final oName = (shop['full_name'] ?? '').toString().toLowerCase();
      return bName.contains(_searchQuery) || oName.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: slate50,
      appBar: AppBar(
        title: Text(
          'Registrar Pedido',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: slate900,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: slate900),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- SECCIÓN 1: IDENTIFICACIÓN DEL CLIENTE (Directo sin tarjeta redundante) ---
                    if (_selectedShop != null) ...[
                      Text(
                        'Datos del Cliente',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: slate700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Ficha limpia de datos directos (sin encapsular en tarjeta repetitiva, al lado del icono)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: slate100,
                              shape: BoxShape.circle,
                            ),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedStore03,
                              color: indigoCustom,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedShop!['nombre_comercial'] ?? 'Comercio',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: slate900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dueño: ${_selectedShop!['full_name'] ?? "No especificado"}',
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: slate700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cel: ${_selectedShop!['celular'] != '' ? _selectedShop!['celular'] : "No especificado"}',
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: slate700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Calle: ${_selectedShop!['direccion'] ?? "No especificada"}',
                                  style: GoogleFonts.openSans(
                                    fontSize: 12,
                                    color: slate700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.prefilledClientId == null)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: slate400,
                              ),
                              onPressed: () => setState(() {
                                _selectedShop = null;
                                _searchController.clear();
                              }),
                            ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Buscar Cliente Mayorista',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: slate700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        style: GoogleFonts.outfit(color: slate900),
                        decoration: InputDecoration(
                          hintText: 'Buscar por negocio o nombre del dueño...',
                          hintStyle: GoogleFonts.openSans(color: slate400, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: slate400),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: slate200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: indigoCustom, width: 1.5),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: slate200),
                          ),
                          child: filteredShops.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'Ningún cliente coincide con la búsqueda.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.openSans(color: slate400, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: filteredShops.length,
                                  itemBuilder: (context, index) {
                                    final shop = filteredShops[index];
                                    final bName = shop['nombre_comercial'] ?? 'Sin negocio';
                                    final oName = shop['full_name'] ?? 'Propietario';
                                    return ListTile(
                                      leading: const HugeIcon(
                                        icon: HugeIcons.strokeRoundedStore03,
                                        color: slate400,
                                        size: 20,
                                      ),
                                      title: Text(
                                        bName,
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: slate900),
                                      ),
                                      subtitle: Text(
                                        'Dueño: $oName',
                                        style: GoogleFonts.openSans(fontSize: 12, color: slate700),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedShop = shop;
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // --- SECCIÓN 2: FORMATOS DE HIELO EN TARJETAS HORIZONTALES (SELECCIÓN MÚLTIPLE) ---
                    Text(
                      'Formatos de Hielo',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: slate700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _catalog.length,
                      itemBuilder: (context, index) {
                        final prod = _catalog[index];
                        final String pId = prod['id'] as String;
                        final int qty = _selectedQuantities[pId] ?? 0;
                        final bool isSelected = qty > 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? indigoCustom : slate200,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? indigoCustom.withOpacity(0.04) : Colors.black.withOpacity(0.01),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Image
                              Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: slate50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.asset(
                                  prod['image'],
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // Right Column: Details & Selection Controls
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prod['name'],
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: slate900,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: indigoCustom,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        prod['description'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.openSans(
                                          fontSize: 11,
                                          color: slate400,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Controles +/- o botón agregar
                                          if (!isSelected)
                                            SizedBox(
                                              height: 28,
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedQuantities[pId] = 1;
                                                  });
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: slate200),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                ),
                                                child: Text(
                                                  'Agregar',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: indigoCustom,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedQuantities[pId] = qty - 1;
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: slate200),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.remove, size: 14, color: slate700),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                                  child: Text(
                                                    '$qty',
                                                    style: GoogleFonts.outfit(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: slate900,
                                                    ),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedQuantities[pId] = qty + 1;
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: slate200),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.add, size: 14, color: slate700),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          // Precio o subtotal
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Precio: \$${prod['price'].toStringAsFixed(2)}',
                                                style: GoogleFonts.openSans(
                                                  fontSize: 10,
                                                  color: slate400,
                                                ),
                                              ),
                                              if (isSelected)
                                                Text(
                                                  'Subtotal: \$${((prod['price'] as double) * qty).toStringAsFixed(2)}',
                                                  style: GoogleFonts.outfit(
                                                    color: indigoCustom,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // --- SECCIÓN INFERIOR: MONTO TOTAL FIJO (Solo lectura) Y REGISTRO ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: slate200),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monto Total Pactado:',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: slate700,
                        ),
                      ),
                      Text(
                        '\$${_totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: indigoCustom,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
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
          ],
        ),
      ),
    );
  }
}

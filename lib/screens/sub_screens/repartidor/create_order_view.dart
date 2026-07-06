import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/order_provider.dart';

class CreateOrderView extends StatefulWidget {
  const CreateOrderView({super.key});

  @override
  State<CreateOrderView> createState() => _CreateOrderViewState();
}

class _CreateOrderViewState extends State<CreateOrderView> {
  final _formKey = GlobalKey<FormState>();
  final _clientController = TextEditingController();
  final _priceController = TextEditingController();

  final List<Map<String, dynamic>> _catalog = [
    {'id': 'PROD-ICE-001', 'name': 'Bolsa Hielo Cubos 2kg', 'price': 120.00},
    {'id': 'PROD-ICE-002', 'name': 'Bolsa Hielo Cubos 5kg', 'price': 250.00},
    {'id': 'PROD-ICE-003', 'name': 'Bolsa Hielo Molido 10kg', 'price': 450.00},
    {'id': 'PROD-ICE-004', 'name': 'Bolsa Hielo Escamas 15kg', 'price': 600.00},
  ];

  Map<String, dynamic>? _selectedProduct;
  int _quantity = 1;

  @override
  void dispose() {
    _clientController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _selectedProduct != null) {
      final double? price = double.tryParse(_priceController.text);
      if (price == null || price <= 0) return;

      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.addOrder(
        _clientController.text.trim(),
        _selectedProduct!['id'] as String,
        _selectedProduct!['name'] as String,
        _quantity,
        price,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.isOnline
                ? 'Pedido registrado y subido.'
                : 'Pedido guardado localmente (sin internet).',
          ),
          backgroundColor: provider.isOnline
              ? Colors.green
              : Colors.amber.shade900,
        ),
      );

      setState(() {
        _clientController.clear();
        _priceController.clear();
        _selectedProduct = null;
        _quantity = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Nuevo Pedido',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.icecream,
                      color: Colors.cyanAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formulario de Distribución',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Registra ventas de bolsas de hielo al instante',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Client Name
              TextFormField(
                controller: _clientController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre del Cliente',
                  labelStyle: const TextStyle(color: Colors.white70),
                  floatingLabelStyle: const TextStyle(color: Colors.cyanAccent),
                  prefixIcon: const Icon(
                    Icons.person,
                    color: Colors.cyanAccent,
                  ),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.cyanAccent,
                      width: 2,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return 'Por favor introduce el nombre';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Catalog dropdown
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedProduct,
                dropdownColor: const Color(0xFF1E293B),
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Producto (Hielo)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  floatingLabelStyle: const TextStyle(color: Colors.cyanAccent),
                  prefixIcon: const Icon(
                    Icons.ac_unit,
                    color: Colors.cyanAccent,
                  ),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.cyanAccent,
                      width: 2,
                    ),
                  ),
                ),
                items: _catalog.map((prod) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: prod,
                    child: Text('${prod['name']} (\$${prod['price']})'),
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
              const SizedBox(height: 20),

              // Quantity Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cantidad:',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.cyanAccent,
                        ),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Text(
                        '$_quantity',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.cyanAccent,
                        ),
                        onPressed: () {
                          setState(() => _quantity++);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Price input (prefilled)
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Precio Pactado (\$)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  floatingLabelStyle: const TextStyle(color: Colors.cyanAccent),
                  prefixIcon: const Icon(
                    Icons.monetization_on,
                    color: Colors.cyanAccent,
                  ),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.cyanAccent,
                      width: 2,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return 'Por favor introduce el precio';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Register Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'REGISTRAR PEDIDO',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

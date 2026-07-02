import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/order_provider.dart';
import '../core/theme/colors.dart';

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientController = TextEditingController();
  
  // Real products catalog seeded in the Spring Boot backend
  final List<Map<String, dynamic>> _catalog = [
    {'id': 'PROD-ICE-001', 'name': 'Bolsa Hielo Cubos 2kg', 'price': 120.00},
    {'id': 'PROD-ICE-002', 'name': 'Bolsa Hielo Cubos 5kg', 'price': 250.00},
    {'id': 'PROD-ICE-003', 'name': 'Bolsa Hielo Molido 10kg', 'price': 450.00},
    {'id': 'PROD-ICE-004', 'name': 'Bolsa Hielo Escamas 15kg', 'price': 600.00},
  ];

  Map<String, dynamic>? _selectedProduct;
  int _quantity = 1;
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _clientController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submitOrder() {
    if (_formKey.currentState!.validate() && _selectedProduct != null) {
      final double? price = double.tryParse(_priceController.text);
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingresá un precio válido.'),
            backgroundColor: TailwindColors.rose600,
          ),
        );
        return;
      }

      // Add order using provider with real catalog IDs
      context.read<OrderProvider>().addOrder(
            _clientController.text.trim(),
            _selectedProduct!['id'] as String,
            _selectedProduct!['name'] as String,
            _quantity,
            price,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                context.read<OrderProvider>().isOnline
                    ? 'Pedido enviado y sincronizado.'
                    : 'Pedido guardado en local (sin conexión).',
              ),
            ],
          ),
          backgroundColor: context.read<OrderProvider>().isOnline
              ? TailwindColors.emerald600
              : TailwindColors.amber600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pop(context);
    } else if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, seleccioná un producto.'),
          backgroundColor: TailwindColors.rose600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TailwindColors.slate50,
      appBar: AppBar(
        title: const Text('Nuevo Pedido'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TailwindColors.indigo50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TailwindColors.indigo100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: TailwindColors.indigo600, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crear Pedido de Venta',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: TailwindColors.indigo900,
                                    fontSize: 16,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Los datos se guardan al instante. Si estás offline, se enviarán al servidor automáticamente al volver a tener conexión.',
                              style: TextStyle(color: TailwindColors.indigo700, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 24),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TailwindColors.slate200),
                    boxShadow: [
                      BoxShadow(
                        color: TailwindColors.slate900.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client Name Input
                      const Text(
                        'Nombre del Cliente',
                        style: TextStyle(fontWeight: FontWeight.w600, color: TailwindColors.slate700),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _clientController,
                        decoration: const InputDecoration(
                          hintText: 'Ej. Juan Pérez',
                          prefixIcon: Icon(Icons.person_outline, color: TailwindColors.slate400, size: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresá el nombre del cliente';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Product Selection Dropdown
                      const Text(
                        'Producto',
                        style: TextStyle(fontWeight: FontWeight.w600, color: TailwindColors.slate700),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedProduct,
                        hint: const Text('Seleccionar producto'),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.inventory_2_outlined, color: TailwindColors.slate400, size: 20),
                        ),
                        items: _catalog.map((Map<String, dynamic> product) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: product,
                            child: Text(product['name'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProduct = value;
                            if (value != null) {
                              // Autopopulate price from catalog
                              _priceController.text = (value['price'] as double).toStringAsFixed(2);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Quantity and Price Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quantity selector
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cantidad',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: TailwindColors.slate700),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: TailwindColors.slate200),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        onPressed: _quantity > 1
                                            ? () => setState(() => _quantity--)
                                            : null,
                                        icon: const Icon(Icons.remove, size: 16),
                                        color: TailwindColors.indigo600,
                                      ),
                                      Text(
                                        '$_quantity',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: TailwindColors.slate800,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() => _quantity++),
                                        icon: const Icon(Icons.add, size: 16),
                                        color: TailwindColors.indigo600,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Price field
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Precio Unitario (\$)',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: TailwindColors.slate700),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    hintText: '0.00',
                                    prefixIcon: Icon(Icons.attach_money, color: TailwindColors.slate400, size: 20),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Requerido';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Número inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 450.ms, delay: 100.ms).slideY(begin: 0.1),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TailwindColors.indigo600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Guardar Pedido',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

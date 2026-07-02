import 'dart:convert';

class OrderModel {
  final String clientOrderId; // UUID generated on the client
  final String clientName;
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final DateTime createdAt;
  final int isSynced; // 0 = Pending, 1 = Synced

  OrderModel({
    required this.clientOrderId,
    required this.clientName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.createdAt,
    this.isSynced = 0,
  });

  // Calculate total price
  double get total => price * quantity;

  // Convert to Map for SQLite database insertion
  Map<String, dynamic> toMap() {
    return {
      'client_order_id': clientOrderId,
      'client_name': clientName,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  // Convert Map from SQLite database to OrderModel
  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      clientOrderId: map['client_order_id'] as String,
      clientName: map['client_name'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: map['is_synced'] as int,
    );
  }

  // Format payload JSON string as expected by the backend
  String toJsonPayload() {
    final payloadMap = {
      'clientOrderId': clientOrderId,
      'clientId': clientName, // mapped to clientName inputted in UI
      'salespersonId': 'VENDEDOR-001', // Predeterminado según el contexto
      // Formato yyyy-MM-ddTHH:mm:ss esperado por Spring Boot
      'createdAt': createdAt.toIso8601String().split('.').first,
      'totalAmount': total,
      'items': [
        {
          'productId': productId,
          'quantity': quantity,
          'price': price,
        }
      ]
    };
    return jsonEncode(payloadMap);
  }

  // Create a copy with modified values
  OrderModel copyWith({
    String? clientOrderId,
    String? clientName,
    String? productId,
    String? productName,
    int? quantity,
    double? price,
    DateTime? createdAt,
    int? isSynced,
  }) {
    return OrderModel(
      clientOrderId: clientOrderId ?? this.clientOrderId,
      clientName: clientName ?? this.clientName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

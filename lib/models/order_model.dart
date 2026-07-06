import 'dart:convert';

class OrderModel {
  final String clientOrderId; // UUID generated on the client
  final String userId; // Supabase user ID who created the order
  final String clientName;
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final DateTime createdAt;
  final int isSynced; // 0 = Pending, 1 = Synced
  
  // Delivery tracking details
  final String status;
  final String? repartidorId;
  final String? verificationCode;
  final String? deliveryAddress;
  final String? clientPhone;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;

  // New fields
  final String paymentMethod; // 'efectivo' or 'transferencia'
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? clientAvatarUrl;

  OrderModel({
    required this.clientOrderId,
    required this.userId,
    required this.clientName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.createdAt,
    this.isSynced = 0,
    this.status = 'pendiente',
    this.repartidorId,
    this.verificationCode,
    this.deliveryAddress,
    this.clientPhone,
    this.acceptedAt,
    this.deliveredAt,
    this.paymentMethod = 'efectivo',
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.clientAvatarUrl,
  });

  // Calculate total price
  double get total => price * quantity;

  // Convert to Map for SQLite database insertion and Supabase
  Map<String, dynamic> toMap() {
    return {
      'client_order_id': clientOrderId,
      'user_id': userId,
      'client_name': clientName,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
      'status': status,
      'repartidor_id': repartidorId,
      'verification_code': verificationCode,
      'delivery_address': deliveryAddress,
      'client_phone': clientPhone,
      'accepted_at': acceptedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'payment_method': paymentMethod,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'client_avatar_url': clientAvatarUrl,
    };
  }

  // Convert Map from SQLite database/Supabase to OrderModel
  factory OrderModel.fromMap(Map<String, dynamic> map) {
    // Parse client avatar URL from either direct column (SQLite) or profiles relation (Supabase join query)
    String? avatarUrl = map['client_avatar_url'] as String?;
    if (avatarUrl == null && map['profiles'] != null) {
      final profiles = map['profiles'];
      if (profiles is Map<String, dynamic>) {
        avatarUrl = profiles['avatar_url'] as String?;
      } else if (profiles is List && profiles.isNotEmpty) {
        avatarUrl = profiles[0]['avatar_url'] as String?;
      }
    }

    return OrderModel(
      clientOrderId: map['client_order_id'] as String,
      userId: map['user_id'] as String? ?? '',
      clientName: map['client_name'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: map['is_synced'] as int? ?? 0,
      status: map['status'] as String? ?? 'pendiente',
      repartidorId: map['repartidor_id'] as String?,
      verificationCode: map['verification_code'] as String?,
      deliveryAddress: map['delivery_address'] as String?,
      clientPhone: map['client_phone'] as String?,
      acceptedAt: map['accepted_at'] != null ? DateTime.parse(map['accepted_at'] as String) : null,
      deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at'] as String) : null,
      paymentMethod: map['payment_method'] as String? ?? 'efectivo',
      deliveryLatitude: map['delivery_latitude'] != null ? (map['delivery_latitude'] as num).toDouble() : null,
      deliveryLongitude: map['delivery_longitude'] != null ? (map['delivery_longitude'] as num).toDouble() : null,
      clientAvatarUrl: avatarUrl,
    );
  }

  // Create a copy with modified values
  OrderModel copyWith({
    String? clientOrderId,
    String? userId,
    String? clientName,
    String? productId,
    String? productName,
    int? quantity,
    double? price,
    DateTime? createdAt,
    int? isSynced,
    String? status,
    String? repartidorId,
    String? verificationCode,
    String? deliveryAddress,
    String? clientPhone,
    DateTime? acceptedAt,
    DateTime? deliveredAt,
    String? paymentMethod,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? clientAvatarUrl,
  }) {
    return OrderModel(
      clientOrderId: clientOrderId ?? this.clientOrderId,
      userId: userId ?? this.userId,
      clientName: clientName ?? this.clientName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      status: status ?? this.status,
      repartidorId: repartidorId ?? this.repartidorId,
      verificationCode: verificationCode ?? this.verificationCode,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      clientPhone: clientPhone ?? this.clientPhone,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      clientAvatarUrl: clientAvatarUrl ?? this.clientAvatarUrl,
    );
  }
}

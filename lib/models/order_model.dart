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
  // Delivery tracking details
  final String status;
  final String? repartidorId;
  final String? repartidorName;
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
   final String? receivedBy; // Name of person who physically received the bags

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
     this.repartidorName,
     this.verificationCode,
     this.deliveryAddress,
     this.clientPhone,
     this.acceptedAt,
     this.deliveredAt,
     this.paymentMethod = 'efectivo',
     this.deliveryLatitude,
     this.deliveryLongitude,
     this.clientAvatarUrl,
     this.receivedBy,
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
      'repartidor_name': repartidorName,
      'verification_code': verificationCode,
      'delivery_address': deliveryAddress,
      'client_phone': clientPhone,
      'accepted_at': acceptedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'payment_method': paymentMethod,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'client_avatar_url': clientAvatarUrl,
      'received_by': receivedBy,
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

    final String clientOrderId = (map['client_order_id'] ?? map['clientOrderId'] ?? map['id'] ?? '') as String;
    final String userId = (map['user_id'] ?? map['client_id'] ?? map['clientId'] ?? '') as String;
    final String clientName = (map['client_name'] ?? map['clientName'] ?? 'Cliente') as String;
    
    String productId = (map['product_id'] ?? map['productId'] ?? 'hielo_bag') as String;
    String productName = (map['product_name'] ?? map['productName'] ?? 'Bolsa de Hielo') as String;
    int quantity = (map['quantity'] ?? 1) as int;
    double price = ((map['price'] ?? map['totalAmount'] ?? map['total_amount'] ?? 0.0) as num).toDouble();

    if (map['items'] != null && (map['items'] as List).isNotEmpty) {
      final item = (map['items'] as List).first as Map<String, dynamic>;
      productId = (item['product_id'] ?? item['productId'] ?? productId) as String;
      quantity = (item['quantity'] ?? quantity) as int;
      price = ((item['price'] ?? price) as num).toDouble();
      
      if (productId == 'PROD-ICE-001') productName = 'Hielo Rolito 2kg';
      if (productId == 'PROD-ICE-002') productName = 'Hielo Rolito 5kg';
      if (productId == 'PROD-ICE-003') productName = 'Hielo Rolito 10kg';
      if (productId == 'PROD-ICE-004') productName = 'Hielo Escama 15kg';
    }

    final String createdAtStr = (map['created_at'] ?? map['createdAt']) as String;
    final DateTime createdAt = DateTime.parse(
      createdAtStr.endsWith('Z') ? createdAtStr : '${createdAtStr}Z',
    ).toLocal();

    final int isSynced = (map['is_synced'] ?? map['isSynced'] ?? 0) as int;
    
    String status = (map['status'] ?? 'pendiente') as String;
    final sUpper = status.toUpperCase();
    if (sUpper == 'PENDING') status = 'pendiente';
    else if (sUpper == 'ACCEPTED') status = 'aceptado';
    else if (sUpper == 'DISPATCHED') status = 'en_camino';
    else if (sUpper == 'DELIVERED') status = 'entregado';
    else if (sUpper == 'CANCELLED') status = 'cancelado';

    String? repartidorId = (map['repartidor_id'] ?? map['repartidorId'] ?? map['delivery_driver_id'] ?? map['deliveryDriverId']) as String?;
    if (repartidorId == null) {
      final possibleRepartidor = (map['salespersonId'] ?? map['salesperson_id']) as String?;
      if (possibleRepartidor != null && possibleRepartidor != userId) {
        repartidorId = possibleRepartidor;
      }
    }
    if (repartidorId == null && map['deliveryDriver'] != null) {
      repartidorId = (map['deliveryDriver']['id'] ?? map['deliveryDriver']['userId']) as String?;
    }

    String? repartidorName = (map['repartidor_name'] ?? map['repartidorName']) as String?;
    if (repartidorName == null && map['deliveryDriver'] != null) {
      repartidorName = map['deliveryDriver']['displayName'] as String?;
    }

    final String? verificationCode = (map['verification_code'] ?? map['verificationCode']) as String?;
    final String? deliveryAddress = (map['delivery_address'] ?? map['deliveryAddress']) as String?;
    final String? clientPhone = (map['client_phone'] ?? map['clientPhone']) as String?;

    final String? acceptedAtStr = (map['accepted_at'] ?? map['acceptedAt']) as String?;
    final DateTime? acceptedAt = acceptedAtStr != null
        ? DateTime.parse(acceptedAtStr.endsWith('Z') ? acceptedAtStr : '${acceptedAtStr}Z').toLocal()
        : null;

    final String? deliveredAtStr = (map['delivered_at'] ?? map['deliveredAt']) as String?;
    final DateTime? deliveredAt = deliveredAtStr != null
        ? DateTime.parse(deliveredAtStr.endsWith('Z') ? deliveredAtStr : '${deliveredAtStr}Z').toLocal()
        : null;

    final String paymentMethod = (map['payment_method'] ?? map['paymentMethod'] ?? 'efectivo') as String;

    final double? deliveryLatitude = map['delivery_latitude'] != null
        ? (map['delivery_latitude'] as num).toDouble()
        : map['deliveryLatitude'] != null
            ? (map['deliveryLatitude'] as num).toDouble()
            : null;

    final double? deliveryLongitude = map['delivery_longitude'] != null
        ? (map['delivery_longitude'] as num).toDouble()
        : map['deliveryLongitude'] != null
            ? (map['deliveryLongitude'] as num).toDouble()
            : null;

    final String? receivedBy = (map['received_by'] ?? map['receivedBy']) as String?;

    return OrderModel(
      clientOrderId: clientOrderId,
      userId: userId,
      clientName: clientName,
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      createdAt: createdAt,
      isSynced: isSynced,
      status: status,
      repartidorId: repartidorId,
      repartidorName: repartidorName,
      verificationCode: verificationCode,
      deliveryAddress: deliveryAddress,
      clientPhone: clientPhone,
      acceptedAt: acceptedAt,
      deliveredAt: deliveredAt,
      paymentMethod: paymentMethod,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      clientAvatarUrl: avatarUrl,
      receivedBy: receivedBy,
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
     String? repartidorName,
     String? verificationCode,
     String? deliveryAddress,
     String? clientPhone,
     DateTime? acceptedAt,
     DateTime? deliveredAt,
     String? paymentMethod,
     double? deliveryLatitude,
     double? deliveryLongitude,
     String? clientAvatarUrl,
     String? receivedBy,
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
       repartidorName: repartidorName ?? this.repartidorName,
       verificationCode: verificationCode ?? this.verificationCode,
       deliveryAddress: deliveryAddress ?? this.deliveryAddress,
       clientPhone: clientPhone ?? this.clientPhone,
       acceptedAt: acceptedAt ?? this.acceptedAt,
       deliveredAt: deliveredAt ?? this.deliveredAt,
       paymentMethod: paymentMethod ?? this.paymentMethod,
       deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
       deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
       clientAvatarUrl: clientAvatarUrl ?? this.clientAvatarUrl,
       receivedBy: receivedBy ?? this.receivedBy,
     );
   }
}

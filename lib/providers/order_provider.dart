import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/auth/token_storage.dart';
import '../core/database/db_helper.dart';
import '../core/network/api_client.dart';
import '../core/realtime/orders_socket.dart';
import '../models/order_model.dart';

/// Validation result for [OrderProvider.validateOrder].
typedef OrderValidation = ({bool ok, String? message, double totalKg});

/// Single source of truth for the Flutter UI. All data flows from the
/// Java backend (sync-service :8081, order-service :8082); no direct
/// Supabase calls remain in this provider.
class OrderProvider with ChangeNotifier {
  // --- Domain lists ----------------------------------------------------
  final List<OrderModel> _orders = [];
  List<Map<String, dynamic>> _adminOrders = [];
  final List<Map<String, dynamic>> _repartidores = [];
  List<Map<String, dynamic>> _catalogProducts = [];
  List<Map<String, dynamic>> _clienteShops = [];
  final List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _adminAgendasToday = [];
  final List<Map<String, dynamic>> _userAgendas = [];

  // --- Admin profile (for the repartidor's agenda greeting banner) -----
  String _adminName = 'Administrador';
  String? _adminAvatarUrl;
  Map<String, dynamic>? _selectedRepartidorForMap;

  // --- Business rules (mirror OrderService.java MIN_ORDER_WEIGHT_KG / MAX_ROUTE_WEIGHT_KG) ---
  static const double kMinOrderWeightKg = 100.0;
  static const double kMaxRouteWeightKg = 5000.0;

  // --- UI / state flags ------------------------------------------------
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = true;
  int _pendingSyncCount = 0;
  bool _isHydrated = false;
  String _userRole = 'repartidor'; // 'admin' | 'repartidor' | 'cliente'

  // --- Identity (from TokenStorage /users/me) --------------------------
  String? _userId;
  String? _email;
  String? _fullName;
  String? _avatarUrl;
  String? _phone;
  String? _dni;
  String? _vendorId;
  String? _businessName;
  double? _businessLat;
  double? _businessLng;
  String? _businessAddress;

  // --- Realtime / gps --------------------------------------------------
  Timer? _locationTimer;
  Timer? _silentPollTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<OrderRealtimeEvent>? _wsEventSubscription;
  Position? _currentRepartidorPosition;
  OrderModel? _incomingOrderAlert;
  final Set<String> _rejectedOrderIds = {};

  // --- Locally-cached for widget access -------------------------------
  final DbHelper _db = DbHelper.instance;
  final Set<String> _ratedOrderIds = {};

  // --- Public getters ---------------------------------------------------
  List<OrderModel> get orders => _orders;
  List<Map<String, dynamic>> get adminOrders => _adminOrders;
  List<Map<String, dynamic>> get repartidores => _repartidores;
  List<Map<String, dynamic>> get catalogProducts => _catalogProducts;
  List<Map<String, dynamic>> get clienteShops => _clienteShops;
  List<Map<String, dynamic>> get clientes => _clientes;
  List<Map<String, dynamic>> get adminAgendasToday => _adminAgendasToday;
  List<Map<String, dynamic>> get userAgendas => _userAgendas;
  String get adminName => _adminName;
  String? get adminAvatarUrl => _adminAvatarUrl;
  Map<String, dynamic>? get selectedRepartidorForMap => _selectedRepartidorForMap;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  int get pendingSyncCount => _pendingSyncCount;
  String get userRole => _userRole;
  String? get currentUserAvatarUrl => _avatarUrl;
  String? get currentUserFullName => _fullName;
  String? get currentUserCelular => _phone;
  String? get vendorId => _vendorId;
  String? get currentUserEmail => _email;
  String? get currentUserId => _userId;
  String? get businessName => _businessName;
  double? get businessLatitude => _businessLat;
  double? get businessLongitude => _businessLng;
  String? get businessAddress => _businessAddress;
  Position? get currentRepartidorPosition => _currentRepartidorPosition;
  OrderModel? get incomingOrderAlert => _incomingOrderAlert;
  Set<String> get ratedOrderIds => _ratedOrderIds;
  bool get isHydrated => _isHydrated;

  /// Convenience "current user" object for legacy widget code that did
  /// `provider.currentUser?.id`. We expose the JWT subject as `id` and the
  /// cached email/full_name for parity with the previous Supabase User.
  /// `userMetadata` mirrors the fields that used to live in
  /// `auth.users.user_metadata` (Supabase) so legacy widgets keep working.
  CurrentUser? get currentUser {
    if (_userId == null) return null;
    return CurrentUser(
      id: _userId!,
      email: _email,
      fullName: _fullName,
      userMetadata: {
        'full_name': _fullName,
        'avatar_url': _avatarUrl,
        'phone': _phone,
        'celular': _phone,
        'dni': _dni,
        'direccion': _businessAddress,
        'direccion_defecto': _businessAddress,
        'nombre_comercial': _businessName,
        'latitud_comercial': _businessLat,
        'longitud_comercial': _businessLng,
      },
    );
  }

  // --- Lifecycle --------------------------------------------------------
  OrderProvider() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _hydrateFromTokenStorage();
    _checkInitialConnection();
    _startConnectivityListener();
    _subscribeToRealtime();

    if (await TokenStorage.instance.isAuthenticated()) {
      await refreshUserRole();
      if (_userRole == 'admin') {
        await fetchAdminOrders();
        await fetchRepartidoresLocations();
      } else {
        await loadOrders();
        await fetchClienteShops();
        _startLocationReporting();
      }
    }
  }

  Future<void> _hydrateFromTokenStorage() async {
    final profile = await TokenStorage.instance.getProfile();
    _userId = profile['user_id'];
    _email = profile['email'];
    _userRole = profile['role'] ?? 'repartidor';
    _fullName = profile['full_name'];
    _avatarUrl = profile['avatar_url'];
    final token = await TokenStorage.instance.getAccessToken();
    if (token != null && token.isNotEmpty) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
          _vendorId = decoded['vendor_id'] as String?;
        }
      } catch (e) {
        debugPrint('Error decodificando JWT en bootstrap: $e');
      }
    }
    _isHydrated = true;
    notifyListeners();
  }

  // --- Connectivity -----------------------------------------------------
  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final prevOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();
    if (!prevOnline && _isOnline) {
      syncUnsyncedOrders();
    }
  }

  // --- Realtime ---------------------------------------------------------
  void _subscribeToRealtime() {
    _wsEventSubscription?.cancel();
    _wsEventSubscription = OrdersSocket.instance.events.listen(_handleRealtimeEvent);
    OrdersSocket.instance.connect();
  }

  void _handleRealtimeEvent(OrderRealtimeEvent evt) {
    switch (evt.type) {
      case 'order.created':
      case 'order.updated':
        loadOrders();
        if (_userRole == 'admin') fetchAdminOrders();
        break;
      case 'order.deleted':
        loadOrders();
        break;
      case 'driver.location':
        if (_userRole == 'admin' || _userRole == 'cliente') {
          fetchRepartidoresLocations();
        }
        break;
    }
  }

  // --- Authentication ---------------------------------------------------
  Future<void> loginWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await ApiClient.instance.post('sync', '/api/v1/auth/login', {
        'email': email,
        'password': password,
      }, false); // no enviar token previo en llamadas de auth pública
      if (resp.statusCode != 200) {
        final body = _decode(resp.body);
        throw Exception(body['error'] ?? 'login_failed');
      }
      await _ingestAuthResponse(resp.body);
      await refreshUserRole();
      await _postLoginBootstrap();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? avatarUrl,
    String? dni,
    String? direccion,
    String? celular,
    String? nombreComercial,
    double? latitudComercial,
    double? longitudComercial,
    String? tipoVehiculo,
    String? matricula,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'role': role,
        'full_name': fullName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (dni != null) 'dni': dni,
        if (celular != null) 'phone': celular,
        if (nombreComercial != null) 'business_name': nombreComercial,
        if (latitudComercial != null) 'business_lat': latitudComercial,
        if (longitudComercial != null) 'business_lng': longitudComercial,
        if (direccion != null) 'business_address': direccion,
        // type_vehicle + matricula are stored on delivery_drivers by an
        // out-of-band sync job (or future V6 migration); the backend
        // currently keeps them client-side until the repartidor profile
        // is provisioned by an admin.
      };
      final resp = await ApiClient.instance.post('sync', '/api/v1/auth/signup', body, false); // no enviar token previo
      if (resp.statusCode != 201) {
        final err = _decode(resp.body);
        throw Exception(err['error'] ?? err['message'] ?? 'signup_failed');
      }
      await _ingestAuthResponse(resp.body);
      await refreshUserRole();
      await _postLoginBootstrap();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ingestAuthResponse(String body) async {
    final json = _decode(body);
    final token = json['access_token'] as String;
    await TokenStorage.instance.save(
      accessToken: token,
      refreshToken: json['refresh_token'] as String,
      expiresInSeconds: (json['expires_in'] as num?)?.toInt() ?? 900,
      userId: '',
      email: '',
      role: '',
    );
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
        _vendorId = decoded['vendor_id'] as String?;
      }
    } catch (e) {
      debugPrint('Error decodificando JWT en login/signup: $e');
    }
  }

  Future<void> refreshUserRole() async {
    if (!await TokenStorage.instance.isAuthenticated()) return;
    try {
      final resp = await ApiClient.instance.get('sync', '/api/v1/users/me');
      if (resp.statusCode != 200) {
        debugPrint('refreshUserRole failed: ${resp.statusCode}');
        return;
      }
      final json = _decode(resp.body);
      _userId = json['id'] as String?;
      _email = json['email'] as String?;
      _userRole = (json['role'] as String?) ?? 'repartidor';
      _fullName = json['full_name'] as String?;
      _avatarUrl = json['avatar_url'] as String?;
      _phone = json['phone'] as String?;
      _dni = json['dni'] as String?;
      _vendorId = json['vendor_id'] as String?;
      _businessName = json['business_name'] as String?;
      _businessLat = (json['business_lat'] as num?)?.toDouble();
      _businessLng = (json['business_lng'] as num?)?.toDouble();
      _businessAddress = json['business_address'] as String?;

      await TokenStorage.instance.updateProfile(
        fullName: _fullName,
        avatarUrl: _avatarUrl,
      );

      // Persist user_id/email/role back into storage so the rest of the
      // app reads a consistent snapshot even before /me completes.
      await TokenStorage.instance.save(
        accessToken: (await TokenStorage.instance.getAccessToken())!,
        refreshToken: (await TokenStorage.instance.getRefreshToken())!,
        expiresInSeconds: 900,
        userId: _userId ?? '',
        email: _email ?? '',
        role: _userRole,
        fullName: _fullName,
        avatarUrl: _avatarUrl,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('refreshUserRole error: $e');
    }
  }

  Future<void> updateCurrentUserAvatar(String newAvatarUrl) async {
    try {
      final resp = await ApiClient.instance.patch('sync', '/api/v1/users/me', {
        'avatar_url': newAvatarUrl,
      });
      if (resp.statusCode == 200) {
        _avatarUrl = newAvatarUrl;
        await TokenStorage.instance.updateProfile(avatarUrl: newAvatarUrl);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('updateCurrentUserAvatar error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      final refresh = await TokenStorage.instance.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        try {
          await ApiClient.instance.post('sync', '/api/v1/auth/logout', {
            'refresh_token': refresh,
          }, false); // logout es público — no enviar token expirado
        } catch (_) {/* best-effort */}
      }
      _stopLocationReporting();
      _stopSilentPolling();
      await OrdersSocket.instance.disconnect();
      await TokenStorage.instance.clear();
      await _db.clearAllOrders();
      await _db.clearAllMutations();
      _orders.clear();
      _adminOrders.clear();
      _repartidores.clear();
      _clienteShops.clear();
      _userId = _email = _fullName = _avatarUrl = _phone = _dni = _vendorId = null;
      _businessName = _businessAddress = null;
      _businessLat = _businessLng = null;
      _userRole = 'repartidor';
      _incomingOrderAlert = null;
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _postLoginBootstrap() async {
    OrdersSocket.instance.connect();
    if (_userRole == 'admin') {
      await fetchAdminOrders();
      await fetchRepartidoresLocations();
    } else {
      await loadOrders();
      await fetchClienteShops();
      syncUnsyncedOrders();
      _startLocationReporting();
    }
  }

  // --- GPS --------------------------------------------------------------
  void _startLocationReporting() {
    _locationTimer?.cancel();
    if (_userId == null || _userRole != 'repartidor') return;
    _reportCurrentLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _reportCurrentLocation();
    });
  }

  void _stopLocationReporting() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _reportCurrentLocation() async {
    if (_userId == null || !_isOnline) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _currentRepartidorPosition = position;
      await ApiClient.instance.patch(
        'sync',
        '/api/v1/users/me/location',
        {'latitude': position.latitude, 'longitude': position.longitude},
      );
    } catch (e) {
      debugPrint('GPS report error: $e');
    }
  }

  // --- Catalog ----------------------------------------------------------
  Future<void> fetchCatalog() async {
    if (!_isOnline) return;
    try {
      final resp = await ApiClient.instance.get('order', '/api/v1/orders/catalog');
      if (resp.statusCode == 200) {
        _catalogProducts = (jsonDecode(resp.body) as List)
            .map((item) => (item as Map).cast<String, dynamic>())
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchCatalog error: $e');
    }
  }

  /// Pure validator: same rules as backend `OrderService.saveOrder`.
  /// Returns `ok=false` with a human-readable Spanish message when any rule
  /// is violated. Does NOT touch DB / network / state.
  ///
  /// `static` so it can be unit-tested without triggering the constructor's
  /// network bootstrap.
  static OrderValidation validateOrder({
    required Map<String, dynamic> product,
    required int quantity,
  }) {
    final weight = ((product['weightKg'] ?? 0) as num).toDouble();
    final stock = (product['stock'] ?? 0) as int;
    final totalKg = weight * quantity;

    if (quantity <= 0) {
      return (ok: false, message: 'Cantidad inválida', totalKg: totalKg);
    }
    if (weight <= 0) {
      return (ok: false, message: 'Producto sin peso definido', totalKg: totalKg);
    }
    if (quantity > stock) {
      return (
        ok: false,
        message: 'Stock insuficiente ($stock disponibles)',
        totalKg: totalKg,
      );
    }
    if (totalKg < kMinOrderWeightKg) {
      return (
        ok: false,
        message:
            'Pedido mínimo ${kMinOrderWeightKg.toInt()}kg (actual: ${totalKg.toStringAsFixed(1)}kg)',
        totalKg: totalKg,
      );
    }
    if (totalKg > kMaxRouteWeightKg) {
      return (
        ok: false,
        message:
            'Máximo por ruta ${kMaxRouteWeightKg.toInt()}kg (actual: ${totalKg.toStringAsFixed(1)}kg)',
        totalKg: totalKg,
      );
    }
    return (ok: true, message: null, totalKg: totalKg);
  }

  // --- Orders -----------------------------------------------------------
  Future<void> fetchOrdersFromBackend({bool silent = false}) async {
    if (_userId == null || !_isOnline) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final resp = await ApiClient.instance.get('order', '/api/v1/orders');
      if (resp.statusCode == 200) {
        final list = (jsonDecode(resp.body) as List)
            .map((o) => OrderModel.fromMap((o as Map).cast<String, dynamic>()))
            .toList();
        await _db.cacheOrders(list);
        final local = await _db.getAllOrders();
        final unsynced = local.where((o) => o.isSynced == 0).toList();
        final Map<String, OrderModel> combined = {
          for (var o in list) o.clientOrderId: o,
          for (var o in unsynced) o.clientOrderId: o,
        };
        final result = combined.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _orders
          ..clear()
          ..addAll(result);
      } else {
        debugPrint('fetchOrdersFromBackend error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('fetchOrdersFromBackend error: $e');
    } finally {
      if (!silent) _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders() async {
    if (_userId == null) return;
    if (_isOnline) {
      await fetchOrdersFromBackend();
      await fetchCatalog();
      final pending = await _db.getPendingMutations();
      _pendingSyncCount = pending.length;
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
      try {
        final all = await _db.getAllOrders();
        _orders
          ..clear()
          ..addAll(all);
        final pending = await _db.getPendingMutations();
        _pendingSyncCount = pending.length;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<String?> addClientOrder(
    String productName,
    int quantity,
    double price,
    String address,
    String phone, {
    required String productId,
    String? preferredRepartidorId,
    String paymentMethod = 'efectivo',
    double? latitude,
    double? longitude,
  }) async {
    if (_userId == null) return 'Sesión inválida';
    final order = OrderModel(
      clientOrderId: _uuid(),
      userId: _userId!,
      clientName: _fullName ?? _email ?? 'Cliente',
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      createdAt: DateTime.now(),
      isSynced: 0,
      status: 'pendiente',
      repartidorId: preferredRepartidorId,
      verificationCode: (Random().nextInt(9000) + 1000).toString(),
      deliveryAddress: address,
      clientPhone: phone,
      paymentMethod: paymentMethod,
      deliveryLatitude: latitude,
      deliveryLongitude: longitude,
    );
    await _db.insertOrder(order);
    _orders.insert(0, order);
    notifyListeners();
    if (!_isOnline) return null; // queda pendiente en outbox para próximo sync
    final err = await _syncOne(order.clientOrderId);
    if (err != null) {
      await _rollbackOrder(order.clientOrderId);
    }
    return err;
  }

  Future<String?> addOrder(
    String clientName,
    String productId,
    String productName,
    int quantity,
    double price, {
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryAddress,
    String? clientUserId,
    String? clientPhone,
  }) async {
    if (_userId == null) return 'Sesión inválida';
    final order = OrderModel(
      clientOrderId: _uuid(),
      userId: clientUserId ?? _userId!,
      clientName: clientName,
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      status: clientUserId != null ? 'en_camino' : 'pendiente',
      repartidorId: clientUserId != null ? _userId : null,
      verificationCode: (Random().nextInt(9000) + 1000).toString(),
      clientPhone: clientPhone,
      paymentMethod: 'efectivo',
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      deliveryAddress: deliveryAddress,
      createdAt: DateTime.now(),
      isSynced: 0,
    );
    await _db.insertOrder(order);
    _orders.insert(0, order);
    notifyListeners();
    if (!_isOnline) return null;
    final err = await _syncOne(order.clientOrderId);
    if (err != null) {
      await _rollbackOrder(order.clientOrderId);
    }
    return err;
  }

  Future<void> _rollbackOrder(String clientOrderId) async {
    _orders.removeWhere((o) => o.clientOrderId == clientOrderId);
    await _db.deleteOrder(clientOrderId);
    notifyListeners();
  }

  Future<bool> acceptOrder(String clientOrderId) async {
    if (_userId == null) return false;
    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return false;
    if (!_isOnline) {
      final updated = _orders[index].copyWith(
        status: 'aceptado',
        repartidorId: _userId,
        acceptedAt: DateTime.now(),
        isSynced: 0,
      );
      await _db.updateOrder(updated);
      _orders[index] = updated;
      notifyListeners();
      return true;
    }
    try {
      final resp = await ApiClient.instance.post(
          'order', '/api/v1/orders/$clientOrderId/accept', const {});
      if (resp.statusCode == 200) {
        final updated = OrderModel.fromMap(_decode(resp.body));
        await _db.updateOrder(updated);
        _orders[index] = updated;
        notifyListeners();
        return true;
      }
      throw Exception(resp.body);
    } catch (e) {
      debugPrint('acceptOrder error: $e');
      rethrow;
    }
  }

  Future<void> startDelivery(String clientOrderId) async {
    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return;
    if (!_isOnline) {
      final updated = _orders[index].copyWith(status: 'en_camino', isSynced: 0);
      await _db.updateOrder(updated);
      _orders[index] = updated;
      notifyListeners();
      return;
    }
    try {
      final resp = await ApiClient.instance.post(
          'order', '/api/v1/orders/$clientOrderId/dispatch', const {});
      if (resp.statusCode == 200) {
        final updated = OrderModel.fromMap(_decode(resp.body));
        await _db.updateOrder(updated);
        _orders[index] = updated;
        notifyListeners();
      } else {
        throw Exception(resp.body);
      }
    } catch (e) {
      debugPrint('startDelivery error: $e');
      rethrow;
    }
  }

  Future<bool> confirmDelivery(
      String clientOrderId, String code, String receivedBy) async {
    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return false;
    final order = _orders[index];
    if (order.verificationCode != code) return false;
    if (!_isOnline) {
      final updated = order.copyWith(
        status: 'entregado',
        deliveredAt: DateTime.now(),
        receivedBy: receivedBy,
        isSynced: 0,
      );
      await _db.updateOrder(updated);
      _orders[index] = updated;
      notifyListeners();
      return true;
    }
    try {
      Position? position = _currentRepartidorPosition;
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 3),
          );
        } catch (_) {/* fallback below */}
      }
      final query = StringBuffer('/api/v1/orders/$clientOrderId/deliver?code=$code');
      if (position != null) {
        query.write('&lat=${position.latitude}&lon=${position.longitude}');
      }
      final resp = await ApiClient.instance.post('order', query.toString(), const {});
      if (resp.statusCode == 200) {
        final updated = OrderModel.fromMap(_decode(resp.body))
            .copyWith(receivedBy: receivedBy);
        await _db.updateOrder(updated);
        _orders[index] = updated;
        notifyListeners();
        return true;
      }
      throw Exception(resp.body);
    } catch (e) {
      debugPrint('confirmDelivery error: $e');
      rethrow;
    }
  }

  Future<void> deleteOrder(String clientOrderId) async {
    if (!_isOnline) {
      await _db.deleteOrder(clientOrderId);
      _orders.removeWhere((o) => o.clientOrderId == clientOrderId);
      notifyListeners();
      return;
    }
    try {
      final resp = await ApiClient.instance
          .delete('order', '/api/v1/orders/$clientOrderId');
      if (resp.statusCode == 200) {
        await _db.deleteOrder(clientOrderId);
        _orders.removeWhere((o) => o.clientOrderId == clientOrderId);
        notifyListeners();
      } else {
        throw Exception(resp.body);
      }
    } catch (e) {
      debugPrint('deleteOrder error: $e');
      rethrow;
    }
  }

  // --- Outbox sync -----------------------------------------------------
  Future<void> syncUnsyncedOrders() async {
    if (_isSyncing || !_isOnline || _userId == null) return;
    final pending = await _db.getPendingMutations();
    _pendingSyncCount = pending.length;
    if (pending.isEmpty) {
      notifyListeners();
      return;
    }
    _isSyncing = true;
    notifyListeners();

    try {
      final body = pending.map(_mapMutation).toList();

      final resp = await ApiClient.instance.post('sync', '/api/v1/sync', body);
      if (resp.statusCode == 200) {
        final json = _decode(resp.body);
        final processedIds = (json['processedMutationIds'] as List?)?.cast<String>() ?? const <String>[];
        if (processedIds.isNotEmpty) {
          await _db.deleteMutations(processedIds);
          final orderIds = pending
              .where((m) => processedIds.contains(m['id'] as String))
              .map((m) => m['entity_id'] as String)
              .toList();
          await _db.markOrdersAsSynced(orderIds);
          await loadOrders();
          if (_userRole == 'admin') await fetchAdminOrders();
        }
      } else {
        debugPrint('sync error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('syncUnsyncedOrders error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Maps a raw outbox row (SQLite) into the JSON shape the sync-service
  /// expects. Extracted so [_syncOne] can reuse it for single-mutation sync.
  Map<String, dynamic> _mapMutation(Map<String, dynamic> m) {
    final mutationId = m['id'] as String;
    final entityType = (m['entity_type'] as String? ?? 'ORDER').toUpperCase();
    final entityId = m['entity_id'] as String;
    final operation = (m['operation'] as String).toUpperCase();
    final payloadStr = m['payload'] as String;
    String mappedPayload = payloadStr;
    if (entityType == 'ORDER') {
      try {
        final orderMap = _decode(payloadStr);
        final price = ((orderMap['price'] ?? 0.0) as num).toDouble();
        final quantity = (orderMap['quantity'] ?? 1) as int;
        final total = price * quantity;
        String status = 'PENDING';
        switch (orderMap['status']) {
          case 'aceptado':
            status = 'ACCEPTED';
            break;
          case 'en_camino':
            status = 'DISPATCHED';
            break;
          case 'entregado':
            status = 'DELIVERED';
            break;
          case 'cancelado':
            status = 'CANCELLED';
            break;
        }
        final salespersonId = _userRole == 'vendedor'
            ? (_vendorId ?? orderMap['repartidor_id'] ?? orderMap['user_id'])
            : (orderMap['repartidor_id'] ?? orderMap['user_id']);

        final javaOrder = <String, dynamic>{
          'clientOrderId': orderMap['client_order_id'],
          'clientId': orderMap['user_id'],
          'salespersonId': salespersonId,
          'createdAt': orderMap['created_at'],
          'totalAmount': total,
          if (orderMap['delivery_latitude'] != null)
            'deliveryLatitude': orderMap['delivery_latitude'],
          if (orderMap['delivery_longitude'] != null)
            'deliveryLongitude': orderMap['delivery_longitude'],
          if (orderMap['delivery_address'] != null)
            'deliveryAddress': orderMap['delivery_address'],
          if (orderMap['verification_code'] != null)
            'verificationCode': orderMap['verification_code'],
          'status': status,
          'items': [
            {
              'productId': orderMap['product_id'] ?? 'hielo_bag',
              'quantity': quantity,
              'price': price,
            }
          ],
        };
        mappedPayload = jsonEncode(javaOrder);
      } catch (e) {
        debugPrint('payload mapping error: $e');
      }
    }
    return {
      'id': mutationId,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': mappedPayload,
      'timestamp': m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Sync a single order's mutation. Returns:
  ///   - null on success (server accepted the mutation, OR network error so
  ///     the order stays in the outbox for the next retry).
  ///   - a Spanish user-facing error message when the server explicitly
  ///     rejected the mutation (4xx/5xx, or 200 with `success=false`).
  ///
  /// Designed to be awaited by [addOrder] / [addClientOrder] so the caller
  /// can rollback the optimistic local row only when the server actually
  /// said "no", not when the network blipped.
  Future<String?> _syncOne(String clientOrderId) async {
    final pending = await _db.getPendingMutations();
    final ours = pending.where((m) => m['entity_id'] == clientOrderId).toList();
    if (ours.isEmpty) return null;
    http.Response resp;
    try {
      final body = ours.map(_mapMutation).toList();
      resp = await ApiClient.instance.post('sync', '/api/v1/sync', body);
    } on Exception {
      // Network / DNS / timeout → keep the mutation pending, no rollback.
      return null;
    }
    if (resp.statusCode == 200) {
      final json = _decode(resp.body);
      final processedIds =
          (json['processedMutationIds'] as List?)?.cast<String>() ?? const <String>[];
      final ourId = ours.first['id'] as String;
      if (processedIds.contains(ourId)) {
        await _db.deleteMutations(processedIds);
        await _db.markOrdersAsSynced([clientOrderId]);
        return null;
      }
      // 200 with success=false → backend rejected (business rule, stock, etc.)
      return (json['message'] as String?) ?? 'El backend rechazó el pedido';
    }
    // 4xx / 5xx → backend explicitly rejected, extract error code.
    if (resp.body.isEmpty) return 'Error ${resp.statusCode}';
    try {
      final errJson = _decode(resp.body);
      final code = errJson['error'] as String? ?? '';
      switch (code) {
        case 'token_expired':
          return 'Tu sesión expiró. Cerrá y volvé a iniciar sesión.';
        case 'token_invalid':
          return 'Sesión inválida. Iniciá sesión nuevamente.';
        case 'no_token':
          return 'No autenticado. Iniciá sesión.';
        case 'order_service_unavailable':
          return 'El servidor de pedidos no está disponible. Intentá más tarde.';
        default:
          return errJson['message'] as String? ?? resp.body;
      }
    } catch (_) {
      return resp.body;
    }
  }

  // --- Admin ------------------------------------------------------------
  Future<void> fetchAdminOrders() async {
    if (_userId == null || _userRole != 'admin') return;
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await ApiClient.instance.get('order', '/api/v1/orders');
      if (resp.statusCode == 200) {
        final list = (jsonDecode(resp.body) as List)
            .map((o) => (o as Map).cast<String, dynamic>())
            .toList();
        _adminOrders = list.map((o) {
          final clientId = o['clientId']?.toString() ?? '';
          double price = 0.0;
          int quantity = 1;
          String productName = 'Bolsa de Hielo';
          if (o['items'] is List && (o['items'] as List).isNotEmpty) {
            final item = (o['items'] as List).first as Map;
            price = ((item['price'] ?? 0.0) as num).toDouble();
            quantity = (item['quantity'] ?? 1) as int;
            final pid = (item['productId'] ?? '').toString();
            if (pid == 'PROD-ICE-001') productName = 'Hielo Rolito 2kg';
            if (pid == 'PROD-ICE-002') productName = 'Hielo Rolito 5kg';
            if (pid == 'PROD-ICE-003') productName = 'Hielo Rolito 10kg';
            if (pid == 'PROD-ICE-004') productName = 'Hielo Escama 15kg';
          }
          String mappedStatus = 'pendiente';
          switch (o['status']) {
            case 'PENDING':
              mappedStatus = 'pendiente';
              break;
            case 'ACCEPTED':
              mappedStatus = 'aceptado';
              break;
            case 'DISPATCHED':
              mappedStatus = 'en_camino';
              break;
            case 'DELIVERED':
              mappedStatus = 'entregado';
              break;
            case 'CANCELLED':
              mappedStatus = 'cancelado';
              break;
          }
          return <String, dynamic>{
            'client_order_id': o['clientOrderId'],
            'user_id': clientId,
            'client_name': 'Cliente',
            'product_name': productName,
            'quantity': quantity,
            'price': price,
            'created_at': o['createdAt'],
            'status': mappedStatus,
            'repartidor_id': o['deliveryDriver'] is Map ? o['deliveryDriver']['id'] : o['salespersonId'],
            'verification_code': o['verificationCode'],
            'delivery_address': o['deliveryAddress'],
            'client_phone': o['clientPhone'],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('fetchAdminOrders error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Drivers ----------------------------------------------------------
  Future<void> fetchRepartidoresLocations() async {
    if (_userId == null || !_isOnline) return;
    if (_userRole != 'admin' && _userRole != 'cliente') return;
    try {
      final resp = await ApiClient.instance.get('order', '/api/v1/drivers');
      if (resp.statusCode == 200) {
        final list = (jsonDecode(resp.body) as List)
            .map((d) => (d as Map).cast<String, dynamic>())
            .toList();
        _repartidores
          ..clear()
          ..addAll(list);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchRepartidoresLocations error: $e');
    }
  }

  Future<void> submitDriverReview(String driverId, double rating, {String? orderId, String? comment}) async {
    try {
      final resp = await ApiClient.instance.post(
        'order',
        '/api/v1/drivers/$driverId/reviews',
        {
          'order_id': orderId ?? _uuid(),
          'rating': rating.toInt(),
          if (comment != null) 'comment': comment,
        },
      );
      if (resp.statusCode == 201) {
        await fetchRepartidoresLocations();
      }
    } catch (e) {
      debugPrint('submitDriverReview error: $e');
      rethrow;
    }
  }

  // --- Clients ----------------------------------------------------------
  Future<void> fetchClienteShops() async {
    // Note: no early-return on _userId == null — let the request hit the
    // backend and let the api_client 401-handler deal with auth issues.
    // The previous guard caused a silent no-op whenever this raced the
    // bootstrap, leaving the dropdown permanently empty.
    try {
      final resp = await ApiClient.instance.get('order', '/api/v1/clients');
      if (resp.statusCode == 200) {
        _clienteShops = (jsonDecode(resp.body) as List)
            .map((c) => (c as Map).cast<String, dynamic>())
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchClienteShops error: $e');
    }
  }

  /// Cached list of clients used by admin/assignment flows (separate from
  /// _clienteShops to avoid forcing legacy cliente dropdown code to handle
  /// the shape returned by the agendas/clientes endpoints).
  Future<void> fetchClientes() async {
    if (_userId == null || !_isOnline) return;
    try {
      final resp = await ApiClient.instance.get('order', '/api/v1/clients');
      if (resp.statusCode == 200) {
        _clientes
          ..clear()
          ..addAll((jsonDecode(resp.body) as List)
              .map((c) => (c as Map).cast<String, dynamic>()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchClientes error: $e');
    }
  }

  // --- Agendas / Preventistas ------------------------------------------
  /// Loads the admin's profile (used as the greeting avatar in the
  /// repartidor agenda screen). Tolerant of offline — keeps the previous
  /// values on failure.
  Future<void> fetchAdminProfile() async {
    if (_userId == null || !_isOnline) return;
    try {
      final resp = await ApiClient.instance.get('order', '/api/v1/preventistas/admin');
      if (resp.statusCode == 200) {
        final data = _decode(resp.body);
        _adminName = (data['fullName'] ?? data['full_name'] ?? 'Administrador').toString();
        _adminAvatarUrl = (data['avatarUrl'] ?? data['avatar_url']) as String?;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchAdminProfile error: $e');
    }
  }

  /// Public alias of [refreshUserRole] for screen code that wants to make
  /// the intent explicit (e.g. the repartidor agenda refreshes the user's
  /// profile in parallel with admin profile / agenda fetches).
  Future<void> fetchCurrentUserProfile() => refreshUserRole();

  /// Admin view: list of agendas scheduled for today, grouped by preventista.
  Future<void> fetchAdminAgendasToday() async {
    if (_userId == null || !_isOnline) return;
    try {
      final resp = await ApiClient.instance.get('order', '/api/v1/agendas/today');
      if (resp.statusCode == 200) {
        _adminAgendasToday = (jsonDecode(resp.body) as List)
            .map((a) => (a as Map).cast<String, dynamic>())
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchAdminAgendasToday error: $e');
    }
  }

  /// Repartidor view: list of agendas assigned to the current user.
  Future<void> fetchUserAgendas() async {
    if (_userId == null) return;
    if (!_isOnline) {
      notifyListeners();
      return;
    }
    try {
      final resp =
          await ApiClient.instance.get('order', '/api/v1/agendas/preventista/$_userId');
      if (resp.statusCode == 200) {
        _userAgendas
          ..clear()
          ..addAll((jsonDecode(resp.body) as List)
              .map((a) => (a as Map).cast<String, dynamic>()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchUserAgendas error: $e');
    }
  }

  /// Admin assigns a route agenda to a preventista for a given date.
  /// Returns `true` only when the backend acknowledges with 201.
  Future<bool> assignAgenda({
    required String preventistaId,
    required DateTime date,
    required List<String> clientIds,
  }) async {
    if (_userId == null || !_isOnline) return false;
    try {
      final formatted =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final resp = await ApiClient.instance.post('order', '/api/v1/agendas', {
        'preventistaId': preventistaId,
        'date': formatted,
        'clientIds': clientIds,
      });
      if (resp.statusCode == 201) {
        await fetchAdminAgendasToday();
        return true;
      }
      debugPrint('assignAgenda rejected: ${resp.statusCode} ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('assignAgenda error: $e');
      return false;
    }
  }

  /// Repartidor accepts an agenda. Optimistic local update, then sync.
  Future<void> acceptAgenda(String agendaId) async {
    if (_userId == null) return;
    final idx = _userAgendas.indexWhere((a) => a['id'] == agendaId);
    if (idx != -1) {
      _userAgendas[idx] = {..._userAgendas[idx], 'status': 'ACEPTADA'};
      notifyListeners();
    }
    if (!_isOnline) return;
    try {
      await ApiClient.instance.post(
          'order', '/api/v1/agendas/$agendaId/status', {'status': 'ACEPTADA'});
      await fetchUserAgendas();
    } catch (e) {
      debugPrint('acceptAgenda error: $e');
    }
  }

  /// Repartidor rejects an agenda. Optimistic local update, then sync.
  Future<void> rejectAgenda(String agendaId) async {
    if (_userId == null) return;
    final idx = _userAgendas.indexWhere((a) => a['id'] == agendaId);
    if (idx != -1) {
      _userAgendas[idx] = {..._userAgendas[idx], 'status': 'RECHAZADA'};
      notifyListeners();
    }
    if (!_isOnline) return;
    try {
      await ApiClient.instance.post(
          'order', '/api/v1/agendas/$agendaId/status', {'status': 'RECHAZADA'});
      await fetchUserAgendas();
    } catch (e) {
      debugPrint('rejectAgenda error: $e');
    }
  }

  /// Mark a repartidor so the map view can focus on it (used by the admin
  /// "Proveedores" screen when the user taps the map icon).
  void selectRepartidorForMap(Map<String, dynamic>? repartidor) {
    _selectedRepartidorForMap = repartidor;
    notifyListeners();
  }

  // --- Silent polling (fallback while WS reconnects) --------------------
  void _startSilentPolling() {
    _silentPollTimer?.cancel();
    _silentPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isOnline && _orders.isNotEmpty) {
        fetchOrdersFromBackend(silent: true);
      }
    });
  }

  void _stopSilentPolling() {
    _silentPollTimer?.cancel();
    _silentPollTimer = null;
  }

  // --- Incoming order alert (proximity check, kept for UX) ---------------
  void rejectIncomingOrder(String orderId) {
    _rejectedOrderIds.add(orderId);
    if (_incomingOrderAlert?.clientOrderId == orderId) {
      _incomingOrderAlert = null;
    }
    notifyListeners();
  }

  void clearIncomingOrderAlert() {
    _incomingOrderAlert = null;
    notifyListeners();
  }

  void markOrderAsRated(String orderId) {
    _ratedOrderIds.add(orderId);
    notifyListeners();
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  String generateUuid() => _uuid();

  // --- Helpers ----------------------------------------------------------
  String _uuid() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final buf = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buf.write('-');
      buf.write(hex(bytes[i]));
    }
    return buf.toString();
  }

  Map<String, dynamic> _decode(String body) {
    return (jsonDecode(body) as Map).cast<String, dynamic>();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _wsEventSubscription?.cancel();
    _stopLocationReporting();
    _stopSilentPolling();
    super.dispose();
  }
}

/// Lightweight replacement for the previous `Supabase.User` object exposed
/// via `currentUser`. Holds only the fields widgets need.
class CurrentUser {
  final String id;
  final String? email;
  final String? fullName;
  final Map<String, dynamic>? userMetadata;
  const CurrentUser({required this.id, this.email, this.fullName, this.userMetadata});
}
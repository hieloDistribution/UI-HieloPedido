import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/database/db_helper.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  List<OrderModel> _orders = [];
  List<Map<String, dynamic>> _adminOrders = [];
  List<Map<String, dynamic>> _repartidores = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = true;
  String _userRole = 'repartidor'; // 'repartidor', 'admin', 'cliente'
  Timer? _locationTimer;

  final DbHelper _db = DbHelper.instance;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  StreamSubscription<AuthState>? _authStateSubscription;

  List<OrderModel> get orders => _orders;
  List<Map<String, dynamic>> get adminOrders => _adminOrders;
  List<Map<String, dynamic>> get repartidores => _repartidores;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  String get userRole => _userRole;
  String? _currentUserAvatarUrl;
  String? get currentUserAvatarUrl => _currentUserAvatarUrl;
  String? _currentUserFullName;
  String? get currentUserFullName => _currentUserFullName;
  int _pendingSyncCount = 0;
  int get pendingSyncCount => _pendingSyncCount;

  final Set<String> _ratedOrderIds = {};
  Set<String> get ratedOrderIds => _ratedOrderIds;

  void markOrderAsRated(String orderId) {
    _ratedOrderIds.add(orderId);
    notifyListeners();
  }

  User? get currentUser => Supabase.instance.client.auth.currentUser;

  OrderProvider() {
    _init();
  }

  Future<void> _init() async {
    await _checkInitialConnection();
    _startConnectivityListener();
    _startSupabaseAuthListener();
    
    // Initial role and data load if already logged in
    if (currentUser != null) {
      await refreshUserRole();
      if (_userRole == 'admin') {
        await fetchAdminOrders();
        await fetchRepartidoresLocations();
      } else {
        await loadOrders();
        _startLocationReporting();
      }
    }
  }

  // --- Connectivity Management ---
  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final prevOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();

    if (!prevOnline && _isOnline) {
      syncUnsyncedOrders();
    }
  }

  // --- Supabase Authentication ---
  void _startSupabaseAuthListener() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) && session != null) {
        await refreshUserRole();
        if (_userRole == 'admin') {
          await fetchAdminOrders();
          await fetchRepartidoresLocations();
        } else {
          await loadOrders();
          syncUnsyncedOrders();
          _startLocationReporting();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _orders = [];
        _adminOrders = [];
        _repartidores = [];
        _userRole = 'repartidor';
        _stopLocationReporting();
        notifyListeners();
      }
    });
  }

  Future<void> refreshUserRole() async {
    if (currentUser == null) return;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role, avatar_url, full_name')
          .eq('id', currentUser!.id)
          .maybeSingle();
      
      if (response != null) {
        if (response['role'] != null) {
          final r = response['role'] as String;
          if (r == 'distributor') {
            _userRole = 'repartidor';
          } else {
            _userRole = r;
          }
        }
        _currentUserAvatarUrl = response['avatar_url'] as String?;
        _currentUserFullName = response['full_name'] as String?;
      } else {
        _userRole = 'repartidor';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      _userRole = 'repartidor';
    }
  }

  Future<void> updateCurrentUserAvatar(String newAvatarUrl) async {
    if (currentUser == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': newAvatarUrl})
          .eq('id', currentUser!.id);
      
      _currentUserAvatarUrl = newAvatarUrl;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating user avatar: $e');
      rethrow;
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    String fullName,
    String role,
    String? avatarUrl, {
    String? dni,
    String? direccion,
    String? celular,
    String? tipoVehiculo,
    String? matricula,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
          'avatar_url': avatarUrl,
          'dni': dni,
          'direccion': direccion,
          'direccion_defecto': direccion, // duplicate just in case
          'phone': celular,
          'tipo_vehiculo': tipoVehiculo,
          'matricula': matricula,
        },
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.hielopedido://login-callback',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      _stopLocationReporting();
      await Supabase.instance.client.auth.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- GPS Location Tracking for Drivers (Repartidor) ---
  void _startLocationReporting() {
    _locationTimer?.cancel();
    if (currentUser == null || _userRole != 'repartidor') return;

    // Report immediately
    _reportCurrentLocation();

    // Report every 3 minutes
    _locationTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _reportCurrentLocation();
    });
  }

  void _stopLocationReporting() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _reportCurrentLocation() async {
    if (currentUser == null || !_isOnline) return;
    try {
      // Check location services and permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Save GPS coordinates to public.profiles
      await Supabase.instance.client.from('profiles').update({
        'last_latitude': position.latitude,
        'last_longitude': position.longitude,
      }).eq('id', currentUser!.id);

      debugPrint('GPS de Repartidor reportado: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error reportando GPS de repartidor: $e');
    }
  }

  // --- Real-time Repartidores GPS locations for Admin ---
  Future<void> fetchRepartidoresLocations() async {
    if (currentUser == null || !_isOnline) return;
    if (_userRole != 'admin' && _userRole != 'cliente') return;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, email, full_name, role, last_latitude, last_longitude, avatar_url, repartidor_details(tipo_vehiculo, matricula, stars)')
          .or('role.eq.repartidor,role.eq.distributor');
      
      if (response != null) {
        final rawList = List<Map<String, dynamic>>.from(response);
        final List<Map<String, dynamic>> updatedList = [];
 
        for (var r in rawList) {
          final lat = r['last_latitude'];
          final lng = r['last_longitude'];
          String address = 'Ubicación desconocida';
 
          if (lat != null && lng != null) {
            // Check if we already have the address cached for this lat/lng to avoid spamming the free API
            final cached = _repartidores.firstWhere(
              (x) => x['id'] == r['id'] && x['last_latitude'] == lat && x['last_longitude'] == lng,
              orElse: () => {},
            );
 
            if (cached.isNotEmpty && cached['address'] != null) {
              address = cached['address'] as String;
            } else {
              try {
                // Fetch address from Nominatim (OpenStreetMap Free Reverse Geocoding)
                final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
                final getRes = await http.get(url, headers: {
                  'User-Agent': 'HieloPedidoApp/1.0 (maxcer234@gmail.com)'
                });
                if (getRes.statusCode == 200) {
                  final data = jsonDecode(getRes.body);
                  final addr = data['address'];
                  if (addr != null) {
                    final street = addr['road'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? '';
                    final houseNumber = addr['house_number'] ?? '';
                    final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';
                    if (street.isNotEmpty) {
                      address = street + (houseNumber.isNotEmpty ? ' $houseNumber' : '') + (city.isNotEmpty ? ', $city' : '');
                    } else {
                      address = data['display_name'] ?? 'Ubicación desconocida';
                    }
                  }
                }
              } catch (geoError) {
                debugPrint('Error en geocodificación reversa: $geoError');
              }
            }
          }
 
          final details = r['repartidor_details'];
          Map<String, dynamic>? detailsMap;
          if (details is Map) {
            detailsMap = Map<String, dynamic>.from(details);
          } else if (details is List && details.isNotEmpty) {
            detailsMap = Map<String, dynamic>.from(details.first);
          }
          final tipoVehiculo = detailsMap?['tipo_vehiculo'] ?? 'Moto';
          final matricula = detailsMap?['matricula'] ?? 'S/M';
          final stars = (detailsMap?['stars'] ?? 5.0) as num;
 
          updatedList.add({
            ...r,
            'address': address,
            'tipo_vehiculo': tipoVehiculo,
            'matricula': matricula,
            'stars': stars,
          });
        }
 
        _repartidores = updatedList;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al obtener posiciones GPS de repartidores: $e');
    }
  }

  // --- Distributor/Repartidor Orders (SQLite + Supabase Sync) ---
  Future<void> fetchOrdersFromSupabase() async {
    if (currentUser == null || !_isOnline) return;
    _isLoading = true;
    notifyListeners();
    try {
      final supabaseClient = Supabase.instance.client;
      dynamic response;
      if (userRole == 'cliente') {
        response = await supabaseClient
            .from('orders')
            .select('*, profiles!user_id(avatar_url)')
            .eq('user_id', currentUser!.id)
            .order('created_at', ascending: false);
      } else if (userRole == 'repartidor') {
        response = await supabaseClient
            .from('orders')
            .select('*, profiles!user_id(avatar_url)')
            .or('status.eq.pendiente,repartidor_id.eq.${currentUser!.id}')
            .order('created_at', ascending: false);
      } else {
        response = await supabaseClient
            .from('orders')
            .select('*, profiles!user_id(avatar_url)')
            .order('created_at', ascending: false);
      }

      final List<dynamic> data = response as List<dynamic>;
      final fetchedOrders = data.map((o) => OrderModel.fromMap(o as Map<String, dynamic>)).toList();
      
      // Save locally to cache
      await _db.cacheOrders(fetchedOrders);
      
      _orders = fetchedOrders;
    } catch (e) {
      debugPrint('Error fetching orders from Supabase: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders() async {
    if (currentUser == null) return;
    if (_isOnline) {
      await fetchOrdersFromSupabase();
      final pending = await _db.getPendingMutations();
      _pendingSyncCount = pending.length;
    } else {
      _isLoading = true;
      notifyListeners();
      try {
        final allOrders = await _db.getAllOrders();
        if (userRole == 'cliente') {
          _orders = allOrders.where((o) => o.userId == currentUser!.id).toList();
        } else if (userRole == 'repartidor') {
          _orders = allOrders.where((o) => o.status == 'pendiente' || o.repartidorId == currentUser!.id).toList();
        } else {
          _orders = allOrders;
        }
        final pending = await _db.getPendingMutations();
        _pendingSyncCount = pending.length;
      } catch (e) {
        debugPrint('Error loading orders: $e');
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> addClientOrder(
    String productName,
    int quantity,
    double price,
    String address,
    String phone, {
    String? preferredRepartidorId,
    String paymentMethod = 'efectivo',
    double? latitude,
    double? longitude,
  }) async {
    if (currentUser == null) return;

    final clientOrderId = generateUuid();
    final code = (Random().nextInt(9000) + 1000).toString(); // 4-digit code
    final newOrder = OrderModel(
      clientOrderId: clientOrderId,
      userId: currentUser!.id,
      clientName: currentUserFullName ?? currentUser!.email ?? 'Cliente',
      productId: 'hielo_bag',
      productName: productName,
      quantity: quantity,
      price: price,
      createdAt: DateTime.now(),
      isSynced: 0,
      status: 'pendiente',
      repartidorId: preferredRepartidorId,
      verificationCode: code,
      deliveryAddress: address,
      clientPhone: phone,
      paymentMethod: paymentMethod,
      deliveryLatitude: latitude,
      deliveryLongitude: longitude,
    );

    await _db.insertOrder(newOrder);
    _orders.insert(0, newOrder);
    notifyListeners();

    if (_isOnline) {
      syncUnsyncedOrders();
    }
  }

  Future<void> addOrder(String clientName, String productId, String productName, int quantity, double price) async {
    if (currentUser == null) return;

    final clientOrderId = generateUuid();
    final newOrder = OrderModel(
      clientOrderId: clientOrderId,
      userId: currentUser!.id,
      clientName: clientName,
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      createdAt: DateTime.now(),
      isSynced: 0,
    );

    await _db.insertOrder(newOrder);
    _orders.insert(0, newOrder);
    notifyListeners();

    if (_isOnline) {
      syncUnsyncedOrders();
    }
  }

  Future<void> acceptOrder(String clientOrderId) async {
    if (currentUser == null) return;

    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return;

    final updated = _orders[index].copyWith(
      status: 'aceptado',
      repartidorId: currentUser!.id,
      acceptedAt: DateTime.now(),
      isSynced: 0,
    );

    await _db.updateOrder(updated);
    _orders[index] = updated;
    notifyListeners();

    if (_isOnline) {
      syncUnsyncedOrders();
    }
  }

  Future<void> startDelivery(String clientOrderId) async {
    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return;

    final updated = _orders[index].copyWith(
      status: 'en_camino',
      isSynced: 0,
    );

    await _db.updateOrder(updated);
    _orders[index] = updated;
    notifyListeners();

    if (_isOnline) {
      syncUnsyncedOrders();
    }
  }

  Future<bool> confirmDelivery(String clientOrderId, String code) async {
    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.verificationCode != code) {
      return false; // Code mismatch
    }

    final updated = order.copyWith(
      status: 'entregado',
      deliveredAt: DateTime.now(),
      isSynced: 0,
    );

    await _db.updateOrder(updated);
    _orders[index] = updated;
    notifyListeners();

    if (_isOnline) {
      syncUnsyncedOrders();
    }
    return true;
  }

  Future<void> deleteOrder(String clientOrderId) async {
    await _db.deleteOrder(clientOrderId);
    _orders.removeWhere((o) => o.clientOrderId == clientOrderId);
    notifyListeners();

    if (_isOnline) {
      syncUnsyncedOrders();
    }
  }

  Future<void> syncUnsyncedOrders() async {
    if (_isSyncing || !_isOnline || currentUser == null) return;

    final pendingMutations = await _db.getPendingMutations();
    _pendingSyncCount = pendingMutations.length;
    if (pendingMutations.isEmpty) {
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    debugPrint('Starting synchronization of ${pendingMutations.length} mutations to Supabase...');

    final List<String> successfullySyncedMutationIds = [];
    final List<String> successfullySyncedOrderIds = [];

    try {
      final supabaseClient = Supabase.instance.client;

      for (final m in pendingMutations) {
        final mutationId = m['id'] as String;
        final orderId = m['entity_id'] as String;
        final operation = m['operation'] as String;
        final payloadStr = m['payload'] as String;

        bool success = false;

        try {
          if (operation == 'CREATE') {
            final Map<String, dynamic> orderMap = jsonDecode(payloadStr);
            // Remove local flag field
            orderMap.remove('is_synced');
            
            // Insert directly to Supabase Orders
            await supabaseClient.from('orders').upsert(orderMap);
            success = true;
          } else if (operation == 'DELETE') {
            await supabaseClient.from('orders').delete().eq('client_order_id', orderId);
            success = true;
          }
        } catch (dbError) {
          debugPrint('Error syncing single mutation $mutationId: $dbError');
          if (dbError.toString().contains('409') || dbError.toString().contains('unique_violation')) {
            success = true;
          }
        }

        if (success) {
          successfullySyncedMutationIds.add(mutationId);
          if (operation == 'CREATE') {
            successfullySyncedOrderIds.add(orderId);
          }
        } else {
          debugPrint('Sync loop paused at mutation $mutationId due to server/network issue.');
          break;
        }
      }

      if (successfullySyncedMutationIds.isNotEmpty) {
        await _db.deleteMutations(successfullySyncedMutationIds);
        await _db.markOrdersAsSynced(successfullySyncedOrderIds);
        await loadOrders();
        
        // If we are admin, refresh dashboard as well
        if (_userRole == 'admin') {
          await fetchAdminOrders();
        }
      }
    } catch (e) {
      debugPrint('Sync process encountered an exception: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- Admin Methods ---
  Future<void> fetchAdminOrders() async {
    if (currentUser == null || _userRole != 'admin') return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select('*, profiles!user_id(email, full_name, avatar_url)');
      
      _adminOrders = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching admin orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Driver Review / Stars Update ---
  Future<void> submitDriverReview(String driverId, double rating) async {
    try {
      final supabaseClient = Supabase.instance.client;
      await supabaseClient
          .from('repartidor_details')
          .update({'stars': rating})
          .eq('profile_id', driverId);
      
      // Refresh driver info to show updated rating in client UI
      await fetchRepartidoresLocations();
    } catch (e) {
      debugPrint('Error al guardar reseña del repartidor: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _authStateSubscription?.cancel();
    _stopLocationReporting();
    super.dispose();
  }
}

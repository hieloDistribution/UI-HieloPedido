import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/database/db_helper.dart';
import '../core/network/api_client.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  List<OrderModel> _orders = [];
  List<Map<String, dynamic>> _adminOrders = [];
  List<Map<String, dynamic>> _repartidores = [];
  List<Map<String, dynamic>> _catalogProducts = [];
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
  List<Map<String, dynamic>> get catalogProducts => _catalogProducts;
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

  String? _businessName;
  double? _businessLatitude;
  double? _businessLongitude;
  String? _businessAddress;
  String? _currentUserCelular;

  String? get businessName => _businessName;
  double? get businessLatitude => _businessLatitude;
  double? get businessLongitude => _businessLongitude;
  String? get businessAddress => _businessAddress;
  String? get currentUserCelular => _currentUserCelular;

  final Set<String> _ratedOrderIds = {};
  Set<String> get ratedOrderIds => _ratedOrderIds;

  Timer? _dispatchCheckTimer;
  Timer? _silentPollTimer;
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _profilesChannel;
  Position? _currentRepartidorPosition;
  Position? get currentRepartidorPosition => _currentRepartidorPosition;
  OrderModel? _incomingOrderAlert;
  OrderModel? get incomingOrderAlert => _incomingOrderAlert;
  final Set<String> _rejectedOrderIds = {};

  // Helper experto para generar UUIDs válidos nativamente sin dependencias externas corruptas
  String generateUuid() {
    final random = Random();
    final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // versión 4
    values[8] = (values[8] & 0x3f) | 0x80; // variante
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < values.length; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final prevOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();

    if (prevOnline && !_isOnline) {
      _recordDisconnectionTime();
    }

    if (!prevOnline && _isOnline) {
      syncUnsyncedOrders();
      _reportReconnectionAndAudit();
    }
  }

  Future<void> _recordDisconnectionTime() async {
    if (currentUser == null || userRole != 'repartidor') return;
    try {
      final nowStr = DateTime.now().toIso8601String();
      await _db.insertLocalAudit(nowStr);
      debugPrint('Auditoría Offline: Corte registrado localmente a las $nowStr');
    } catch (e) {
      debugPrint('Error recording offline audit start: $e');
    }
  }

  Future<void> _reportReconnectionAndAudit() async {
    if (currentUser == null || userRole != 'repartidor') return;
    try {
      final localAudits = await _db.getLocalAudits();
      if (localAudits.isEmpty) return;

      final now = DateTime.now();

      for (final audit in localAudits) {
        final id = audit['id'] as int;
        final disconnectedAtStr = audit['disconnected_at'] as String;
        final disconnectedAt = DateTime.parse(disconnectedAtStr);

        final durationMin = now.difference(disconnectedAt).inMinutes;

        final String mutationId = generateUuid();
        final Map<String, dynamic> auditPayload = {
          'driverId': currentUser!.id,
          'disconnectedAt': disconnectedAt.toUtc().toIso8601String(),
          'reconnectedAt': now.toUtc().toIso8601String(),
          'durationMinutes': durationMin,
        };

        await _db.insertMutation(
          id: mutationId,
          entityType: 'AUDIT',
          entityId: currentUser!.id,
          operation: 'CREATE',
          payload: jsonEncode(auditPayload),
        );

        await _db.deleteLocalAudit(id);
        debugPrint('Auditoría Offline: Encolada para sincronización. Corte: $disconnectedAtStr. Duración: $durationMin min.');
      }

      if (_isOnline) {
        syncUnsyncedOrders();
      }
    } catch (e) {
      debugPrint('Error reporting offline audit: $e');
    }
  }

  // --- Supabase Authentication ---
  void _startSupabaseAuthListener() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) async {
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          if ((event == AuthChangeEvent.signedIn ||
                  event == AuthChangeEvent.initialSession) &&
              session != null) {
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
          .select('role, avatar_url, full_name, celular, last_latitude, last_longitude')
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
        _currentUserCelular = response['celular'] as String?;

        final lat = response['last_latitude'];
        final lng = response['last_longitude'];
        if (lat != null && lng != null) {
          _currentRepartidorPosition = Position(
            latitude: (lat as num).toDouble(),
            longitude: (lng as num).toDouble(),
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
        }

        if (_userRole == 'cliente') {
          final clientDetails = await Supabase.instance.client
              .from('cliente_details')
              .select('nombre_comercial, latitud_comercial, longitud_comercial, direccion')
              .eq('profile_id', currentUser!.id)
              .maybeSingle();
          if (clientDetails != null) {
            _businessName = clientDetails['nombre_comercial'] as String?;
            _businessLatitude = (clientDetails['latitud_comercial'] as num?)?.toDouble();
            _businessLongitude = (clientDetails['longitud_comercial'] as num?)?.toDouble();
            _businessAddress = clientDetails['direccion'] as String?;
          }
        }
      } else {
        _userRole = 'repartidor';
      }
      notifyListeners();
      _startOrdersRealtimeSync();
      _startProfilesRealtimeSync();
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
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
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
    String? nombreComercial,
    double? latitudComercial,
    double? longitudComercial,
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
          'direccion_defecto': direccion,
          'phone': celular,
          'nombre_comercial': nombreComercial,
          'latitud_comercial': latitudComercial,
          'longitud_comercial': longitudComercial,
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
      _stopOrdersRealtimeSync();
      await _db.clearAllOrders();
      _orders = [];
      _incomingOrderAlert = null;
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

    _reportCurrentLocation();

    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
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

      _currentRepartidorPosition = position;

      await Supabase.instance.client
          .from('profiles')
          .update({
            'last_latitude': position.latitude,
            'last_longitude': position.longitude,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', currentUser!.id);

      debugPrint(
        'GPS de Repartidor reportado: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error reportando GPS de repartidor: $e');
    }
  }

  void _startOrdersRealtimeSync() {
    _ordersChannel?.unsubscribe();
    if (currentUser == null) return;

    _ordersChannel = Supabase.instance.client
        .channel('order_schema:orders_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'order_schema',
          table: 'orders',
          callback: (payload) async {
            debugPrint('Supabase Realtime: Nuevo pedido insertado');
            final newRecord = payload.newRecord;
            if (newRecord != null) {
              final order = OrderModel.fromMap(newRecord);
              
              // Verify relevance
              if (_userRole == 'cliente' && order.userId != currentUser!.id) return;
              if (_userRole == 'repartidor' && order.repartidorId != currentUser!.id && order.status != 'pendiente') return;

              final index = _orders.indexWhere((o) => o.clientOrderId == order.clientOrderId);
              if (index == -1) {
                await _db.insertOrder(order);
                _orders.insert(0, order);
                notifyListeners();

                // Trigger proximity check for drivers
                if (_userRole == 'repartidor') {
                  _evaluateIncomingOrderForAlert(order);
                }
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'order_schema',
          table: 'orders',
          callback: (payload) async {
            debugPrint('Supabase Realtime: Pedido actualizado');
            final newRecord = payload.newRecord;
            if (newRecord != null) {
              final order = OrderModel.fromMap(newRecord);
              
              // Verify relevance
              if (_userRole == 'cliente' && order.userId != currentUser!.id) return;
              if (_userRole == 'repartidor') {
                final isCurrentlyInList = _orders.any((o) => o.clientOrderId == order.clientOrderId);
                final isRelevantToMe = order.repartidorId == currentUser!.id || order.status == 'pendiente';
                if (!isCurrentlyInList && !isRelevantToMe) {
                  return;
                }
              }

              final index = _orders.indexWhere((o) => o.clientOrderId == order.clientOrderId);
              if (index != -1) {
                _orders[index] = order;
                await _db.updateOrder(order);
                notifyListeners();

                // Clear proximity alert if order is no longer pending
                if (order.status != 'pendiente' && _incomingOrderAlert?.clientOrderId == order.clientOrderId) {
                  _incomingOrderAlert = null;
                  notifyListeners();
                }
              } else {
                // If it is now relevant (e.g. driver accepted it or client created it)
                await _db.insertOrder(order);
                _orders.insert(0, order);
                notifyListeners();

                if (_userRole == 'repartidor' && order.status == 'pendiente') {
                  _evaluateIncomingOrderForAlert(order);
                }
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'order_schema',
          table: 'orders',
          callback: (payload) async {
            debugPrint('Supabase Realtime: Pedido eliminado');
            final oldRecord = payload.oldRecord;
            if (oldRecord != null) {
              final clientOrderId = oldRecord['client_order_id'] as String?;
              if (clientOrderId != null) {
                _orders.removeWhere((o) => o.clientOrderId == clientOrderId);
                await _db.deleteOrder(clientOrderId);
                notifyListeners();

                if (_incomingOrderAlert?.clientOrderId == clientOrderId) {
                  _incomingOrderAlert = null;
                  notifyListeners();
                }
              }
            }
          },
        );

    _ordersChannel!.subscribe();

    // Start periodic check for radius expansion
    if (_userRole == 'repartidor') {
      _dispatchCheckTimer?.cancel();
      _dispatchCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _checkExistingPendingOrdersForAlert();
      });
    }

    _startSilentPolling();
  }

  void _startSilentPolling() {
    _silentPollTimer?.cancel();
    _silentPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (currentUser == null || !_isOnline) return;

      // Only poll if there is at least one active (non-finalized) order in the list
      final hasActiveOrder = _orders.any((o) =>
          o.status == 'pendiente' ||
          o.status == 'aceptado' ||
          o.status == 'en_camino');

      if (hasActiveOrder) {
        await fetchOrdersFromBackend(silent: true);
      }
    });
  }

  void _stopSilentPolling() {
    _silentPollTimer?.cancel();
    _silentPollTimer = null;
  }

  void _stopOrdersRealtimeSync() {
    _ordersChannel?.unsubscribe();
    _ordersChannel = null;
    _profilesChannel?.unsubscribe();
    _profilesChannel = null;
    _dispatchCheckTimer?.cancel();
    _dispatchCheckTimer = null;
    _incomingOrderAlert = null;
    _rejectedOrderIds.clear();
    _stopSilentPolling();
  }

  void _startProfilesRealtimeSync() {
    _profilesChannel?.unsubscribe();
    if (currentUser == null) return;
    if (_userRole != 'admin' && _userRole != 'cliente') return;

    _profilesChannel = Supabase.instance.client
        .channel('public:profiles_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) async {
            debugPrint('Supabase Realtime: Perfil actualizado');
            final newRecord = payload.newRecord;
            if (newRecord != null) {
              final String profileId = newRecord['id'] as String;
              final String role = newRecord['role'] as String? ?? 'repartidor';
              
              if (role == 'repartidor' || role == 'distributor') {
                final idx = _repartidores.indexWhere((r) => r['id'] == profileId);
                if (idx != -1) {
                  final oldRep = _repartidores[idx];
                  final newLat = newRecord['last_latitude'] as double?;
                  final newLng = newRecord['last_longitude'] as double?;
                  
                  String address = oldRep['address'] ?? 'Ubicación desconocida';
                  if (newLat != null && newLng != null &&
                      (oldRep['last_latitude'] != newLat || oldRep['last_longitude'] != newLng)) {
                    _geocodeAddressInBackground(profileId, newLat, newLng);
                  }

                  _repartidores[idx] = {
                    ...oldRep,
                    ...newRecord,
                    'address': address,
                  };
                  notifyListeners();
                } else {
                  fetchRepartidoresLocations();
                }
              }
            }
          },
        );

    _profilesChannel!.subscribe();
  }

  Future<void> _geocodeAddressInBackground(String profileId, double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final getRes = await http.get(
        url,
        headers: {
          'User-Agent': 'HieloPedidoApp/1.0 (maxcer234@gmail.com)',
        },
      );
      if (getRes.statusCode == 200) {
        final data = jsonDecode(getRes.body);
        final addr = data['address'];
        String address = 'Ubicación desconocida';
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
        final idx = _repartidores.indexWhere((r) => r['id'] == profileId);
        if (idx != -1) {
          _repartidores[idx]['address'] = address;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error en geocodificación en background: $e');
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371; // km
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  void _evaluateIncomingOrderForAlert(OrderModel order) {
    if (currentUser == null || _userRole != 'repartidor') return;
    if (order.status != 'pendiente') return;
    if (_rejectedOrderIds.contains(order.clientOrderId)) return;
    if (_incomingOrderAlert?.clientOrderId == order.clientOrderId) return;

    final isAssignedToMe = order.repartidorId == currentUser!.id;
    final isAssignedToSomeoneElse = order.repartidorId != null && order.repartidorId != currentUser!.id;
    final elapsedSec = DateTime.now().difference(order.createdAt).inSeconds;

    if (isAssignedToSomeoneElse) {
      // Si está asignado a otro repartidor en particular, no me alertes hasta después de 30 segundos
      if (elapsedSec < 30) {
        return;
      }
    }

    if (isAssignedToMe) {
      // Si fue asignado específicamente a mí, alertar de inmediato ignorando distancia y GPS
      _incomingOrderAlert = order;
      notifyListeners();
      return;
    }

    final driverLat = _currentRepartidorPosition?.latitude;
    final driverLng = _currentRepartidorPosition?.longitude;
    final orderLat = order.deliveryLatitude;
    final orderLng = order.deliveryLongitude;

    if (driverLat == null || driverLng == null || orderLat == null || orderLng == null) return;

    final distance = calculateDistance(driverLat, driverLng, orderLat, orderLng);

    double threshold = 3.0; // 3 km inicial
    if (elapsedSec >= 90) {
      threshold = 9999.0;
    } else if (elapsedSec >= 60) {
      threshold = 10.0;
    } else if (elapsedSec >= 30) {
      threshold = 6.0;
    }

    if (distance <= threshold) {
      _incomingOrderAlert = order;
      notifyListeners();
    }
  }

  void _checkExistingPendingOrdersForAlert() {
    if (currentUser == null || _userRole != 'repartidor') return;
    if (_incomingOrderAlert != null) return;

    for (final order in _orders) {
      _evaluateIncomingOrderForAlert(order);
    }
  }

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

  // --- Real-time Repartidores GPS locations for Admin ---
  Future<void> fetchRepartidoresLocations() async {
    if (currentUser == null || !_isOnline) return;
    if (_userRole != 'admin' && _userRole != 'cliente') return;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select(
            'id, email, full_name, role, last_latitude, last_longitude, avatar_url, last_seen_at, repartidor_details(tipo_vehiculo, matricula, stars)',
          )
          .or('role.eq.repartidor,role.eq.distributor');

      if (response != null) {
        final rawList = List<Map<String, dynamic>>.from(response);
        final List<Map<String, dynamic>> updatedList = [];

        for (var r in rawList) {
          final lat = r['last_latitude'];
          final lng = r['last_longitude'];
          String address = 'Ubicación desconocida';

          if (lat != null && lng != null) {
            final cached = _repartidores.firstWhere(
              (x) =>
                  x['id'] == r['id'] &&
                  x['last_latitude'] == lat &&
                  x['last_longitude'] == lng,
              orElse: () => {},
            );

            if (cached.isNotEmpty && cached['address'] != null) {
              address = cached['address'] as String;
            } else {
              try {
                final url = Uri.parse(
                  'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
                );
                final getRes = await http.get(
                  url,
                  headers: {
                    'User-Agent': 'HieloPedidoApp/1.0 (maxcer234@gmail.com)',
                  },
                );
                if (getRes.statusCode == 200) {
                  final data = jsonDecode(getRes.body);
                  final addr = data['address'];
                  if (addr != null) {
                    final street =
                        addr['road'] ??
                        addr['suburb'] ??
                        addr['neighbourhood'] ??
                        '';
                    final houseNumber = addr['house_number'] ?? '';
                    final city =
                        addr['city'] ?? addr['town'] ?? addr['village'] ?? '';
                    if (street.isNotEmpty) {
                      address =
                          street +
                          (houseNumber.isNotEmpty ? ' $houseNumber' : '') +
                          (city.isNotEmpty ? ', $city' : '');
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
  Future<void> fetchOrdersFromBackend({bool silent = false}) async {
    if (currentUser == null || !_isOnline) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final response = await ApiClient.get('order', '/api/v1/orders');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fetchedOrders = data
            .map((o) => OrderModel.fromMap(o as Map<String, dynamic>))
            .toList();

        await _db.cacheOrders(fetchedOrders);

        // Merge pending local unsynced orders so they remain visible in history
        final localOrders = await _db.getAllOrders();
        final unsynced = localOrders.where((o) => o.isSynced == 0).toList();

        // Filter local unsynced orders by role
        List<OrderModel> roleUnsynced = [];
        if (userRole == 'cliente') {
          roleUnsynced = unsynced.where((o) => o.userId == currentUser!.id).toList();
        } else if (userRole == 'repartidor') {
          roleUnsynced = unsynced.where((o) => o.status == 'pendiente' || o.repartidorId == currentUser!.id).toList();
        } else {
          roleUnsynced = unsynced;
        }

        // Combine lists, preferring the local/outbox version for matching client_order_id
        final Map<String, OrderModel> combined = {};
        for (var o in fetchedOrders) {
          combined[o.clientOrderId] = o;
        }
        for (var o in roleUnsynced) {
          combined[o.clientOrderId] = o;
        }

        final resultList = combined.values.toList();
        resultList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        _orders = resultList;
      } else {
        debugPrint('Error fetching orders from backend: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching orders from backend: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchCatalog() async {
    if (!_isOnline) return;
    try {
      final response = await ApiClient.get('order', '/api/v1/orders/catalog');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _catalogProducts = data.map((item) {
          return {
            'id': item['id'],
            'name': item['name'],
            'price': ((item['price'] ?? 0.0) as num).toDouble(),
            'stock': item['stock'] ?? 0,
            'weightKg': ((item['weightKg'] ?? 0.0) as num).toDouble(),
          };
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching catalog from backend: $e');
    }
  }

  Future<void> loadOrders() async {
    if (currentUser == null) return;
    if (_isOnline) {
      await fetchOrdersFromBackend();
      await fetchCatalog();
      final pending = await _db.getPendingMutations();
      _pendingSyncCount = pending.length;
    } else {
      _isLoading = true;
      notifyListeners();
      try {
        final allOrders = await _db.getAllOrders();
        if (userRole == 'cliente') {
          _orders = allOrders
              .where((o) => o.userId == currentUser!.id)
              .toList();
        } else if (userRole == 'repartidor') {
          _orders = allOrders
              .where(
                (o) =>
                    o.status == 'pendiente' ||
                    o.repartidorId == currentUser!.id,
              )
              .toList();
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

  double getProductWeightKg(String productName) {
    final name = productName.toLowerCase();
    if (name.contains('15kg') || name.contains('15 kg')) return 15.0;
    if (name.contains('5kg') || name.contains('5 kg')) return 5.0;
    return 10.0; // Default to 10kg
  }

  Future<void> addClientOrder(
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
    if (currentUser == null) return;

    final double newOrderWeight = getProductWeightKg(productName) * quantity;

    if (preferredRepartidorId != null) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final currentRouteWeight = _orders
          .where((o) => o.repartidorId == preferredRepartidorId && o.createdAt.isAfter(startOfDay))
          .fold<double>(0.0, (sum, o) => sum + (getProductWeightKg(o.productName) * o.quantity));

      if (currentRouteWeight + newOrderWeight > 5000.0) {
        throw Exception("El preventista seleccionado no tiene capacidad en su ruta de hoy. Capacidad disponible: ${(5000.0 - currentRouteWeight).toStringAsFixed(1)} kg.");
      }
    }

    final clientOrderId = generateUuid();
    final code = (Random().nextInt(9000) + 1000).toString();
    final newOrder = OrderModel(
      clientOrderId: clientOrderId,
      userId: currentUser!.id,
      clientName: currentUserFullName ?? currentUser!.email ?? 'Cliente',
      productId: productId,
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

  Future<void> addOrder(
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
    if (currentUser == null) return;

    final double newOrderWeight = getProductWeightKg(productName) * quantity;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final currentRouteWeight = _orders
        .where((o) => o.repartidorId == currentUser!.id && o.createdAt.isAfter(startOfDay))
        .fold<double>(0.0, (sum, o) => sum + (getProductWeightKg(o.productName) * o.quantity));

    if (currentRouteWeight + newOrderWeight > 5000.0) {
      throw Exception("Supera la capacidad máxima de tu ruta de preventa para hoy (5000 kg). Capacidad disponible: ${(5000.0 - currentRouteWeight).toStringAsFixed(1)} kg.");
    }

    final clientOrderId = generateUuid();
    final otpCode = (Random().nextInt(9000) + 1000).toString(); // Generar OTP

    final newOrder = OrderModel(
      clientOrderId: clientOrderId,
      userId: clientUserId ?? currentUser!.id,
      clientName: clientName,
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      status: clientUserId != null ? 'en_camino' : 'pendiente',
      repartidorId: clientUserId != null ? currentUser!.id : null,
      verificationCode: otpCode,
      clientPhone: clientPhone,
      paymentMethod: 'efectivo',
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      deliveryAddress: deliveryAddress,
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

  Future<bool> acceptOrder(String clientOrderId) async {
    if (currentUser == null) return false;

    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return false;

    final order = _orders[index];
    final double orderWeight = getProductWeightKg(order.productName) * order.quantity;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final currentRouteWeight = _orders
        .where((o) => o.repartidorId == currentUser!.id && o.createdAt.isAfter(startOfDay))
        .fold<double>(0.0, (sum, o) => sum + (getProductWeightKg(o.productName) * o.quantity));

    if (currentRouteWeight + orderWeight > 5000.0) {
      throw Exception("No puedes aceptar este pedido. Supera tu capacidad máxima de ruta diaria de 5000 kg. Capacidad disponible: ${(5000.0 - currentRouteWeight).toStringAsFixed(1)} kg.");
    }

    if (_isOnline) {
      try {
        final response = await ApiClient.post('order', '/api/v1/orders/$clientOrderId/accept', {});
        if (response.statusCode == 200) {
          final updated = OrderModel.fromMap(jsonDecode(response.body));
          await _db.updateOrder(updated);
          _orders[index] = updated;
          notifyListeners();
          return true;
        } else {
          throw Exception(response.body);
        }
      } catch (e) {
        debugPrint('Error accepting order on backend: $e');
        rethrow;
      }
    } else {
      final updated = order.copyWith(
        status: 'aceptado',
        repartidorId: currentUser!.id,
        acceptedAt: DateTime.now(),
        isSynced: 0,
      );

      await _db.updateOrder(updated);
      _orders[index] = updated;
      notifyListeners();
      return true;
    }
  }

  Future<void> startDelivery(String clientOrderId) async {
    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return;

    if (_isOnline) {
      try {
        final response = await ApiClient.post('order', '/api/v1/orders/$clientOrderId/dispatch', {});
        if (response.statusCode == 200) {
          final updated = OrderModel.fromMap(jsonDecode(response.body));
          await _db.updateOrder(updated);
          _orders[index] = updated;
          notifyListeners();
        } else {
          throw Exception(response.body);
        }
      } catch (e) {
        debugPrint('Error starting delivery on backend: $e');
        rethrow;
      }
    } else {
      final updated = _orders[index].copyWith(status: 'en_camino', isSynced: 0);
      await _db.updateOrder(updated);
      _orders[index] = updated;
      notifyListeners();
    }
  }

  Future<bool> confirmDelivery(String clientOrderId, String code, String receivedBy) async {
    final index = _orders.indexWhere((o) => o.clientOrderId == clientOrderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.verificationCode != code) {
      return false;
    }

    if (_isOnline) {
      try {
        Position? position = _currentRepartidorPosition;
        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 3),
            );
          } catch (_) {}
        }

        String path = '/api/v1/orders/$clientOrderId/deliver?code=$code';
        if (position != null) {
          path += '&lat=${position.latitude}&lon=${position.longitude}';
        }

        final response = await ApiClient.post('order', path, {});
        if (response.statusCode == 200) {
          final updated = OrderModel.fromMap(jsonDecode(response.body)).copyWith(receivedBy: receivedBy);
          await _db.updateOrder(updated);
          _orders[index] = updated;
          notifyListeners();
          return true;
        } else {
          throw Exception(response.body);
        }
      } catch (e) {
        debugPrint('Error confirming delivery on backend: $e');
        rethrow;
      }
    } else {
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
  }

  Future<void> deleteOrder(String clientOrderId) async {
    if (_isOnline) {
      try {
        final response = await ApiClient.delete('order', '/api/v1/orders/$clientOrderId');
        if (response.statusCode == 200) {
          await _db.deleteOrder(clientOrderId);
          _orders.removeWhere((o) => o.clientOrderId == clientOrderId);
          notifyListeners();
        } else {
          throw Exception(response.body);
        }
      } catch (e) {
        debugPrint('Error deleting order on backend: $e');
        rethrow;
      }
    } else {
      await _db.deleteOrder(clientOrderId);
      _orders.removeWhere((o) => o.clientOrderId == clientOrderId);
      notifyListeners();
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

    debugPrint(
      'Starting synchronization of ${pendingMutations.length} mutations to Java sync-service...',
    );

    try {
      final List<Map<String, dynamic>> body = pendingMutations.map((m) {
        final mutationId = m['id'] as String;
        final entityType = m['entity_type'] as String? ?? 'ORDER';
        final entityId = m['entity_id'] as String;
        final operation = m['operation'] as String;
        final payloadStr = m['payload'] as String;
        
        String mappedPayload = payloadStr;
        if (entityType.toUpperCase() == 'ORDER') {
          try {
            final Map<String, dynamic> orderMap = jsonDecode(payloadStr);
            final double price = ((orderMap['price'] ?? 0.0) as num).toDouble();
            final int quantity = (orderMap['quantity'] ?? 1) as int;
            final double totalAmount = price * quantity;

            String mappedStatus = 'PENDING';
            final String? flutterStatus = orderMap['status'];
            if (flutterStatus == 'pendiente') mappedStatus = 'PENDING';
            else if (flutterStatus == 'aceptado') mappedStatus = 'ACCEPTED';
            else if (flutterStatus == 'en_camino') mappedStatus = 'DISPATCHED';
            else if (flutterStatus == 'entregado') mappedStatus = 'DELIVERED';
            else if (flutterStatus == 'cancelado') mappedStatus = 'CANCELLED';

            final Map<String, dynamic> javaOrder = {
              'clientOrderId': orderMap['client_order_id'],
              'clientId': orderMap['user_id'],
              'salespersonId': orderMap['repartidor_id'] ?? orderMap['user_id'],
              'createdAt': orderMap['created_at'],
              'totalAmount': totalAmount,
              'deliveryLatitude': orderMap['delivery_latitude'],
              'deliveryLongitude': orderMap['delivery_longitude'],
              'deliveryAddress': orderMap['delivery_address'],
              'verificationCode': orderMap['verification_code'],
              'status': mappedStatus,
              'items': [
                {
                  'productId': orderMap['product_id'] ?? 'hielo_bag',
                  'quantity': quantity,
                  'price': price
                }
              ]
            };
            mappedPayload = jsonEncode(javaOrder);
          } catch (e) {
            debugPrint('Error mapping order payload to camelCase: $e');
          }
        }

        return {
          'id': mutationId,
          'entityType': entityType.toUpperCase(),
          'entityId': entityId,
          'operation': operation.toUpperCase(),
          'payload': mappedPayload,
          'timestamp': m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        };
      }).toList();

      final response = await ApiClient.post('sync', '/api/v1/sync', body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> processedIds = responseData['processedMutationIds'] ?? [];

        if (processedIds.isNotEmpty) {
          final List<String> successfullySyncedMutationIds = List<String>.from(processedIds);
          final List<String> successfullySyncedOrderIds = pendingMutations
              .where((m) => successfullySyncedMutationIds.contains(m['id']))
              .map((m) => m['entity_id'] as String)
              .toList();

          await _db.deleteMutations(successfullySyncedMutationIds);
          await _db.markOrdersAsSynced(successfullySyncedOrderIds);
          await loadOrders();

          if (_userRole == 'admin') {
            await fetchAdminOrders();
          }
        }
      } else {
        debugPrint('Sync failed with status code: ${response.statusCode} - ${response.body}');
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
      final response = await ApiClient.get('order', '/api/v1/orders');
      if (response.statusCode == 200) {
        final List<dynamic> ordersData = jsonDecode(response.body);
        
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, email, full_name, avatar_url');
            
        final Map<String, dynamic> profilesMap = {
          for (var p in profilesResponse as List) p['id'] as String: p
        };

        _adminOrders = ordersData.map<Map<String, dynamic>>((o) {
          final clientId = o['clientId'] as String? ?? '';
          final profile = profilesMap[clientId];
          
          double price = 0.0;
          int quantity = 1;
          String productName = 'Bolsa de Hielo';
          
          if (o['items'] != null && (o['items'] as List).isNotEmpty) {
            final item = (o['items'] as List).first;
            price = ((item['price'] ?? 0.0) as num).toDouble();
            quantity = (item['quantity'] ?? 1) as int;
            final productId = item['productId'] as String? ?? '';
            if (productId == 'PROD-ICE-001') productName = 'Hielo Rolito 2kg';
            if (productId == 'PROD-ICE-002') productName = 'Hielo Rolito 5kg';
            if (productId == 'PROD-ICE-003') productName = 'Hielo Rolito 10kg';
            if (productId == 'PROD-ICE-004') productName = 'Hielo Escama 15kg';
          }

          String mappedStatus = 'pendiente';
          final String? javaStatus = o['status'];
          if (javaStatus == 'PENDING') mappedStatus = 'pendiente';
          else if (javaStatus == 'ACCEPTED') mappedStatus = 'aceptado';
          else if (javaStatus == 'DISPATCHED') mappedStatus = 'en_camino';
          else if (javaStatus == 'DELIVERED') mappedStatus = 'entregado';
          else if (javaStatus == 'CANCELLED') mappedStatus = 'cancelado';

          return {
            'client_order_id': o['clientOrderId'],
            'user_id': clientId,
            'client_name': profile?['full_name'] ?? 'Cliente',
            'product_name': productName,
            'quantity': quantity,
            'price': price,
            'created_at': o['createdAt'],
            'status': mappedStatus,
            'repartidor_id': o['deliveryDriver']?['id'] ?? o['salespersonId'],
            'verification_code': o['verificationCode'],
            'delivery_address': o['deliveryAddress'],
            'client_phone': o['clientPhone'],
            'profiles': profile,
          };
        }).toList();
      }
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

      await fetchRepartidoresLocations();
    } catch (e) {
      debugPrint('Error al guardar reseña del repartidor: $e');
    }
  }

  List<Map<String, dynamic>> _clienteShops = [];
  List<Map<String, dynamic>> get clienteShops => _clienteShops;

  Future<void> fetchClienteShops() async {
    if (currentUser == null) return;
    try {
      final response = await Supabase.instance.client
          .from('cliente_details')
          .select('*, profiles:profile_id(full_name, avatar_url, email, celular)');
      
      _clienteShops = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching cliente shops: $e');
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

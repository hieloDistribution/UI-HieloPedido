import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/database/db_helper.dart';
import '../core/network/api_client.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  List<OrderModel> _orders = [];
  List<Map<String, dynamic>> _adminOrders = [];
  List<Map<String, dynamic>> _repartidores = [];
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _catalogProducts = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = true;
  String _userRole = 'repartidor'; // 'repartidor', 'admin', 'cliente'
  Timer? _locationTimer;
  bool _isGpsReportingEnabled = true;
  bool get isGpsReportingEnabled => _isGpsReportingEnabled;
  Map<String, dynamic>? _todayAgenda;
  Map<String, dynamic>? get todayAgenda => _todayAgenda;
  List<Map<String, dynamic>> _userAgendas = [];
  List<Map<String, dynamic>> get userAgendas => _userAgendas;

  final DbHelper _db = DbHelper.instance;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  List<OrderModel> get orders => _orders;
  List<Map<String, dynamic>> get adminOrders => _adminOrders;
  List<Map<String, dynamic>> get repartidores => _repartidores;
  List<Map<String, dynamic>> _adminAgendasToday = [];
  List<Map<String, dynamic>> get adminAgendasToday => _adminAgendasToday;
  List<Map<String, dynamic>> get clientes => _clientes;
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

   String? _adminAvatarUrl;
   String _adminName = 'Administrador de Ventas';
   String? get adminAvatarUrl => _adminAvatarUrl;
   String get adminName => _adminName;

   final Set<String> _ratedOrderIds = {};
   Set<String> get ratedOrderIds => _ratedOrderIds;

  Timer? _dispatchCheckTimer;
  Timer? _silentPollTimer;
  Timer? _ordersPollTimer;
  Timer? _profilesPollTimer;
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

  User? _currentUser;
  User? get currentUser => _currentUser;

  OrderProvider() {
    _init();
  }

  Future<void> _init() async {
    await _checkInitialConnection();
    _startConnectivityListener();
    await _loadSession();

    if (currentUser != null) {
      await refreshUserRole();
      if (_userRole == 'admin') {
        await fetchAdminOrders();
        await fetchRepartidoresLocations();
        await fetchAdminAgendasToday();
      } else {
        await loadOrders();
        await fetchTodayAgenda();
        await fetchUserAgendas();
        await fetchAdminProfile();
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
    // Bypassed for Backend Authentication
  }

  Future<void> refreshUserRole() async {
    if (currentUser == null) return;
    try {
      final r = currentUser!.role;
      if (r == 'admin') {
        _userRole = 'admin';
      } else {
        _userRole = 'repartidor';
      }
      _currentUserAvatarUrl = currentUser!.userMetadata['avatar_url'] as String?;
      _currentUserFullName = currentUser!.fullName;
      _currentUserCelular = currentUser!.userMetadata['celular'] as String?;
      _isGpsReportingEnabled = currentUser!.userMetadata['gps_reporting_enabled'] as bool? ?? true;

      notifyListeners();
      _startOrdersRealtimeSync();
      _startProfilesRealtimeSync();

      // Fetch latest profile from DB to ensure avatar/details are synced
      fetchCurrentUserProfile();
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      _userRole = 'repartidor';
    }
  }

  Future<void> fetchCurrentUserProfile() async {
    if (currentUser == null) return;
    try {
      final response = await ApiClient.get('order', '/api/v1/preventistas/${currentUser!.id}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? avatarUrl = data['avatarUrl'] ?? data['avatar_url'];
        final String? fullName = data['fullName'] ?? data['full_name'];
        final String? phone = data['phone'] ?? data['celular'];
        final String? tipoVehiculo = data['tipoVehiculo'] ?? data['tipo_vehiculo'];
        final String? matricula = data['matricula'];

        if (avatarUrl != null) {
          _currentUserAvatarUrl = avatarUrl;
          currentUser!.userMetadata['avatar_url'] = avatarUrl;
        }
        if (fullName != null) {
          _currentUserFullName = fullName;
          currentUser!.userMetadata['full_name'] = fullName;
        }
        if (phone != null) {
          _currentUserCelular = phone;
          currentUser!.userMetadata['celular'] = phone;
        }

        _currentUser = User(
          id: currentUser!.id,
          email: currentUser!.email,
          fullName: fullName ?? currentUser!.fullName,
          role: currentUser!.role,
          token: currentUser!.token,
          phone: phone ?? currentUser!.phone,
          tipoVehiculo: tipoVehiculo ?? currentUser!.tipoVehiculo,
          matricula: matricula ?? currentUser!.matricula,
          userMetadata: currentUser!.userMetadata,
        );

        await _saveSession(_currentUser!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
    }
  }

  Future<void> updateCurrentUserAvatar(String newAvatarUrl) async {
    if (currentUser == null) return;
    try {
      _currentUser = User(
        id: currentUser!.id,
        email: currentUser!.email,
        fullName: currentUser!.fullName,
        role: currentUser!.role,
        token: currentUser!.token,
        phone: currentUser!.phone,
        tipoVehiculo: currentUser!.tipoVehiculo,
        matricula: currentUser!.matricula,
        userMetadata: {
          ...currentUser!.userMetadata,
          'avatar_url': newAvatarUrl,
        },
      );
      await _saveSession(_currentUser!);
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
      final response = await ApiClient.post(
        'order',
        '/api/v1/auth/login',
        {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode != 200) {
        String errMsg = 'Error de inicio de sesión';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['message'] != null) {
            errMsg = errBody['message'];
          }
        } catch (_) {}
        throw Exception(errMsg);
      }

      final data = jsonDecode(response.body);
      final String token = data['token'];
      final String id = data['userId'] ?? data['id'] ?? '';
      final String emailRes = data['email'];
      final String fullName = data['fullName'] ?? '';
      final String role = data['role'] ?? 'PREVENTISTA';
      final String? phone = data['phone'];
      final String? tipoVehiculo = data['tipoVehiculo'];
      final String? matricula = data['matricula'];
      final String? avatarUrl = data['avatarUrl'] ?? data['avatar_url'];

      ApiClient.token = token;

      _currentUser = User(
        id: id,
        email: emailRes,
        fullName: fullName,
        role: role == 'ADMIN' ? 'admin' : 'repartidor',
        token: token,
        phone: phone,
        tipoVehiculo: tipoVehiculo,
        matricula: matricula,
        userMetadata: {
          'full_name': fullName,
          'role': role == 'ADMIN' ? 'admin' : 'repartidor',
          'celular': phone,
          'avatar_url': avatarUrl,
        },
      );

      _currentUserAvatarUrl = avatarUrl;
      await _saveSession(_currentUser!);

      notifyListeners();

      await refreshUserRole();
      if (_userRole == 'admin') {
        await fetchAdminOrders();
        await fetchRepartidoresLocations();
        await fetchAdminAgendasToday();
      } else {
        await loadOrders();
        await fetchTodayAgenda();
        await fetchUserAgendas();
        await fetchAdminProfile();
        _startLocationReporting();
      }
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
      // 1. Registrar primero en el backend Spring Boot
      final response = await ApiClient.post(
        'order',
        '/api/v1/auth/register-preventista',
        {
          'email': email,
          'password': password,
          'fullName': fullName,
          'phone': celular,
          'tipoVehiculo': tipoVehiculo,
          'matricula': matricula,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        String errMsg = 'Error de registro en el backend';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['message'] != null) {
            errMsg = errBody['message'];
          }
        } catch (_) {}
        throw Exception(errMsg);
      }

      // El rol cliente ha sido removido y RLS está desactivado,
      // así que no necesitamos registrar en Supabase Auth.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    throw Exception('El inicio de sesión con Google no está disponible en este momento.');
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (currentUser != null && _userRole == 'repartidor') {
        try {
          await ApiClient.post('order', '/api/v1/preventistas/${currentUser!.id}/offline', {});
        } catch (e) {
          debugPrint('Error reporting offline status: $e');
        }
      }

      _currentUser = null;
      _userRole = 'repartidor';
      _todayAgenda = null;
      _userAgendas = [];
      _adminName = 'Administrador de Ventas';
      _adminAvatarUrl = null;
      _repartidores = [];
      _clientes = [];
      _orders = [];
      _adminOrders = [];
      _adminAgendasToday = [];
      _currentUserAvatarUrl = null;
      _currentUserFullName = null;
      ApiClient.token = null;

      await _clearSession();
      _stopLocationReporting();
      _stopOrdersRealtimeSync();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- GPS Location Tracking for Drivers (Repartidor) ---
  void _startLocationReporting() {
    _locationTimer?.cancel();
    if (currentUser == null || _userRole != 'repartidor' || !_isGpsReportingEnabled) return;

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

      final response = await ApiClient.post(
        'order',
        '/api/v1/preventistas/${currentUser!.id}/location',
        {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );

      if (response.statusCode == 200) {
        debugPrint(
          'GPS de Repartidor reportado al backend: ${position.latitude}, ${position.longitude}',
        );
      } else {
        debugPrint(
          'Error reportando GPS de repartidor al backend: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error reportando GPS de repartidor: $e');
    }
  }

  void _startOrdersRealtimeSync() {
    _ordersPollTimer?.cancel();
    if (currentUser == null) return;

    _ordersPollTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (_userRole == 'admin') {
        await fetchAdminOrders();
        await fetchAdminAgendasToday();
      } else {
        await fetchOrdersFromBackend(silent: true);
        await fetchTodayAgenda();
        await fetchUserAgendas();
      }
    });
  }

  void _stopOrdersRealtimeSync() {
    _ordersPollTimer?.cancel();
    _ordersPollTimer = null;
    _profilesPollTimer?.cancel();
    _profilesPollTimer = null;
    _dispatchCheckTimer?.cancel();
    _dispatchCheckTimer = null;
    _rejectedOrderIds.clear();
  }

  void _startProfilesRealtimeSync() {
    _profilesPollTimer?.cancel();
    if (currentUser == null) return;
    if (_userRole != 'admin') return;

    _profilesPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await fetchRepartidoresLocations();
    });
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
      if (elapsedSec < 30) {
        return;
      }
    }

    if (isAssignedToMe) {
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

  Future<void> fetchRepartidoresLocations() async {
    if (currentUser == null || !_isOnline) return;
    if (_userRole != 'admin') return;
    try {
      final response = await ApiClient.get('order', '/api/v1/preventistas');

      if (response.statusCode == 200) {
        final rawList = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        final List<Map<String, dynamic>> updatedList = [];

        for (var r in rawList) {
          final lat = r['lastLatitude'] ?? r['last_latitude'];
          final lng = r['lastLongitude'] ?? r['last_longitude'];
          String address = 'Ubicación desconocida';

          if (lat != null && lng != null) {
            final cached = _repartidores.firstWhere(
              (x) =>
                  x['id'] == r['id'] &&
                  (x['lastLatitude'] ?? x['last_latitude']) == lat &&
                  (x['lastLongitude'] ?? x['last_longitude']) == lng,
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
          final tipoVehiculo = r['tipoVehiculo'] ?? r['tipo_vehiculo'] ?? 'Moto';
          final matricula = r['matricula'] ?? 'S/M';
          final stars = 5.0;

          updatedList.add({
            ...r,
            'address': address,
            'tipo_vehiculo': tipoVehiculo,
            'matricula': matricula,
            'avatar_url': r['avatarUrl'] ?? r['avatar_url'],
            'stars': stars,
          });
        }

        _repartidores = updatedList;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching repartidores locations: $e');
    }
  }

  Future<void> fetchClientes() async {
    if (currentUser == null || !_isOnline) return;
    try {
      final response = await ApiClient.get('order', '/api/v1/clients');
      if (response.statusCode == 200) {
        _clientes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching clientes: $e');
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

  double getProductWeightKg(String productName, {String? productId}) {
    if (productId != null && productId.startsWith('[')) {
      try {
        final List<dynamic> list = jsonDecode(productId);
        double totalWeight = 0.0;
        for (var it in list) {
          final String name = (it['productName'] ?? '').toString().toLowerCase();
          final int qty = (it['quantity'] ?? 0) as int;
          double unitWeight = 10.0;
          if (name.contains('2kg') || name.contains('2 kg')) unitWeight = 2.0;
          else if (name.contains('5kg') || name.contains('5 kg')) unitWeight = 5.0;
          else if (name.contains('10kg') || name.contains('10 kg')) unitWeight = 10.0;
          else if (name.contains('15kg') || name.contains('15 kg')) unitWeight = 15.0;
          totalWeight += unitWeight * qty;
        }
        // Since we return the total order weight, we divide by quantity (which is 1)
        return totalWeight;
      } catch (e) {
        debugPrint('Error computing multi-item weight: $e');
      }
    }
    final name = productName.toLowerCase();
    if (name.contains('2kg') || name.contains('2 kg')) return 2.0;
    if (name.contains('5kg') || name.contains('5 kg')) return 5.0;
    if (name.contains('15kg') || name.contains('15 kg')) return 15.0;
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

    final double newOrderWeight = getProductWeightKg(productName, productId: productId) * quantity;

    if (preferredRepartidorId != null) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final currentRouteWeight = _orders
          .where((o) => o.repartidorId == preferredRepartidorId && o.createdAt.isAfter(startOfDay))
          .fold<double>(0.0, (sum, o) => sum + (getProductWeightKg(o.productName, productId: o.productId) * o.quantity));

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

    final double newOrderWeight = getProductWeightKg(productName, productId: productId) * quantity;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final currentRouteWeight = _orders
        .where((o) => o.repartidorId == currentUser!.id && o.createdAt.isAfter(startOfDay))
        .fold<double>(0.0, (sum, o) => sum + (getProductWeightKg(o.productName, productId: o.productId) * o.quantity));

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
    final double orderWeight = getProductWeightKg(order.productName, productId: order.productId) * order.quantity;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final currentRouteWeight = _orders
        .where((o) => o.repartidorId == currentUser!.id && o.createdAt.isAfter(startOfDay))
        .fold<double>(0.0, (sum, o) => sum + (getProductWeightKg(o.productName, productId: o.productId) * o.quantity));

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
              'items': (() {
                final prodId = orderMap['product_id'] as String? ?? 'hielo_bag';
                if (prodId.startsWith('[')) {
                  try {
                    final List<dynamic> itemsList = jsonDecode(prodId);
                    return itemsList.map((it) => {
                      'productId': it['productId'] ?? 'hielo_bag',
                      'productName': it['productName'] ?? 'Bolsa de Hielo',
                      'quantity': (it['quantity'] ?? 1) as int,
                      'price': ((it['price'] ?? 0.0) as num).toDouble(),
                    }).toList();
                  } catch (_) {}
                }
                return [
                  {
                    'productId': prodId,
                    'productName': orderMap['product_name'] ?? 'Bolsa de Hielo',
                    'quantity': quantity,
                    'price': price
                  }
                ];
              })()
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
              .where((m) =>
                  successfullySyncedMutationIds.contains(m['id']) &&
                  (m['entity_type'] ?? 'ORDER').toUpperCase() == 'ORDER')
              .map((m) => m['entity_id'] as String)
              .toList();

          await _db.deleteMutations(successfullySyncedMutationIds);
          if (successfullySyncedOrderIds.isNotEmpty) {
            await _db.markOrdersAsSynced(successfullySyncedOrderIds);
            await loadOrders();
          }

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
        debugPrint('ADMIN ORDERS BODY: ${response.body}');
        
        final preventistasRes = await ApiClient.get('order', '/api/v1/preventistas');
        final Map<String, dynamic> profilesMap = {};
        if (preventistasRes.statusCode == 200) {
          final List<dynamic> prevList = jsonDecode(preventistasRes.body);
          for (var p in prevList) {
            profilesMap[p['id'] as String] = {
              'id': p['id'],
              'email': p['email'],
              'full_name': p['fullName'] ?? p['email'],
              'avatar_url': p['avatarUrl'],
            };
          }
        }

        _adminOrders = ordersData.map<Map<String, dynamic>>((o) {
          final clientObj = o['client'] as Map<String, dynamic>?;
          final clientId = clientObj != null ? (clientObj['id'] as String? ?? '') : '';
          final clientName = clientObj != null ? (clientObj['name'] as String? ?? 'Cliente') : 'Cliente';
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
            'client_name': clientName,
            'product_name': productName,
            'quantity': quantity,
            'price': price,
            'created_at': o['createdAt'],
            'status': mappedStatus,
            'repartidor_id': o['deliveryDriver']?['id'] ?? o['salespersonId'],
            'preventista_id': o['preventista'] != null ? (o['preventista']['id'] as String? ?? '') : '',
            'verification_code': o['verificationCode'],
            'delivery_address': o['deliveryAddress'],
            'client_phone': o['clientPhone'],
            'profiles': profile,
            'items': o['items'] != null ? (o['items'] as List).map((i) {
              final String rawName = i['productName'] ?? i['product_name'] ?? 'Bolsa de Hielo';
              if (rawName.startsWith('[')) {
                try {
                  final decoded = jsonDecode(rawName);
                  if (decoded is List) {
                    return decoded.map((e) => {
                      'product_name': e['productName'] ?? e['product_name'] ?? 'Bolsa de Hielo',
                      'quantity': e['quantity'] ?? 1,
                      'price': ((e['price'] ?? 0.0) as num).toDouble(),
                    }).toList();
                  }
                } catch (_) {}
              }
              return [{
                'product_name': rawName,
                'quantity': i['quantity'] ?? 1,
                'price': ((i['price'] ?? 0.0) as num).toDouble(),
              }];
            }).expand((x) => x).toList() : [],
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
    // Supabase has been removed and backend doesn't support stars yet
    debugPrint('Reseña del repartidor $driverId con calificación $rating guardada localmente.');
  }

  List<Map<String, dynamic>> _clienteShops = [];
  List<Map<String, dynamic>> get clienteShops => _clienteShops;

  Future<void> fetchClienteShops() async {
    if (currentUser == null) return;
    try {
      final response = await ApiClient.get('order', '/api/v1/clients');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Map<String, dynamic>> mappedShops = data.map<Map<String, dynamic>>((c) {
          return {
            'id': c['id'],
            'profile_id': c['id'],
            'nombre_comercial': c['name'],
            'direccion': c['address'],
            'latitud_comercial': c['latitude'],
            'longitud_comercial': c['longitude'],
            'celular': c['phone'] ?? '',
            'ruc_dni': c['taxId'] ?? c['tax_id'] ?? '',
            'full_name': c['ownerName'] ?? c['owner_name'] ?? c['name'],
          };
        }).toList();

        _clienteShops = mappedShops;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching cliente shops: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _stopLocationReporting();
    super.dispose();
  }

  // --- Session persistence helpers ---
  Future<void> _saveSession(User user) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/session.json');
      await file.writeAsString(jsonEncode({
        'id': user.id,
        'email': user.email,
        'fullName': user.fullName,
        'role': user.role,
        'token': user.token,
        'phone': user.phone,
        'tipoVehiculo': user.tipoVehiculo,
        'matricula': user.matricula,
        'userMetadata': user.userMetadata,
      }));
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Future<void> _loadSession() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/session.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _currentUser = User(
          id: data['id'],
          email: data['email'],
          fullName: data['fullName'],
          role: data['role'],
          token: data['token'],
          phone: data['phone'],
          tipoVehiculo: data['tipoVehiculo'],
          matricula: data['matricula'],
          userMetadata: Map<String, dynamic>.from(data['userMetadata'] ?? {}),
        );
        ApiClient.token = _currentUser!.token;
      }
    } catch (e) {
      debugPrint('Error loading session: $e');
    }
  }

  Map<String, dynamic>? _selectedRepartidorForMap;
  Map<String, dynamic>? get selectedRepartidorForMap => _selectedRepartidorForMap;

  void selectRepartidorForMap(Map<String, dynamic>? repartidor) {
    _selectedRepartidorForMap = repartidor;
    notifyListeners();
  }

  Future<void> toggleGpsReporting(bool enabled) async {
    _isGpsReportingEnabled = enabled;
    notifyListeners();
    if (!enabled) {
      _stopLocationReporting();
    } else {
      _startLocationReporting();
    }
    if (currentUser != null) {
      _currentUser = User(
        id: currentUser!.id,
        email: currentUser!.email,
        fullName: currentUser!.fullName,
        role: currentUser!.role,
        token: currentUser!.token,
        phone: currentUser!.phone,
        tipoVehiculo: currentUser!.tipoVehiculo,
        matricula: currentUser!.matricula,
        userMetadata: {
          ...currentUser!.userMetadata,
          'gps_reporting_enabled': enabled,
        },
      );
      await _saveSession(_currentUser!);
    }
  }

  Future<String> _uploadAvatarFile(String localPath) async {
    try {
      final baseUrl = ApiClient.orderBaseUrl;
      final uri = Uri.parse('$baseUrl/api/v1/auth/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', localPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] ?? '';
      } else {
        throw Exception('File upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error uploading avatar file: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    required String celular,
    String? avatarUrl,
    String? tipoVehiculo,
    String? matricula,
  }) async {
    if (currentUser == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      String finalAvatarUrl = avatarUrl ?? currentUserAvatarUrl ?? '';
      if (finalAvatarUrl.isNotEmpty && (finalAvatarUrl.startsWith('/') || finalAvatarUrl.startsWith('file://') || finalAvatarUrl.contains('cache'))) {
        finalAvatarUrl = await _uploadAvatarFile(finalAvatarUrl);
      }

      final response = await ApiClient.post(
        'order',
        '/api/v1/preventistas/${currentUser!.id}/profile',
        {
          'fullName': fullName,
          'email': email,
          'avatarUrl': finalAvatarUrl,
          'phone': celular,
          'tipoVehiculo': tipoVehiculo,
          'matricula': matricula,
        },
      );

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body);
        
        _currentUser = User(
          id: currentUser!.id,
          email: updatedData['email'] ?? email,
          fullName: updatedData['fullName'] ?? fullName,
          role: currentUser!.role,
          token: currentUser!.token,
          phone: updatedData['phone'] ?? celular,
          tipoVehiculo: updatedData['tipoVehiculo'] ?? tipoVehiculo,
          matricula: updatedData['matricula'] ?? matricula,
          userMetadata: {
            ...currentUser!.userMetadata,
            'celular': updatedData['phone'] ?? celular,
            'avatar_url': updatedData['avatarUrl'] ?? finalAvatarUrl,
          },
        );

        await _saveSession(_currentUser!);
        
        _currentUserAvatarUrl = _currentUser!.userMetadata['avatar_url'] as String?;
        _currentUserFullName = _currentUser!.fullName;
        _currentUserCelular = celular;

        notifyListeners();
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAdminProfile() async {
    try {
      final response = await ApiClient.get('order', '/api/v1/preventistas/admin');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _adminName = data['fullName'] ?? 'Administrador de Ventas';
        _adminAvatarUrl = data['avatarUrl'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching admin profile from backend: $e');
    }
  }

  Future<void> fetchAdminAgendasToday() async {
    if (currentUser == null || !_isOnline) return;
    try {
      final response = await ApiClient.get('order', '/api/v1/agendas/today');
      if (response.statusCode == 200) {
        _adminAgendasToday = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching admin agendas today: $e');
    }
  }

  Future<void> fetchTodayAgenda() async {
    if (currentUser == null) return;
    if (_isOnline) {
      try {
        final response = await ApiClient.get('order', '/api/v1/agendas/preventista/${currentUser!.id}/today');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _todayAgenda = data;
          await _saveLocalAgenda(data);
        } else if (response.statusCode == 204) {
          _todayAgenda = null;
          await _clearLocalAgenda();
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error fetching today agenda: $e');
        _todayAgenda = await _loadLocalAgenda();
        notifyListeners();
      }
    } else {
      _todayAgenda = await _loadLocalAgenda();
      notifyListeners();
    }
  }

  Future<void> fetchUserAgendas() async {
    if (currentUser == null) return;
    if (_isOnline) {
      try {
        final response = await ApiClient.get('order', '/api/v1/agendas/preventista/${currentUser!.id}');
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          _userAgendas = List<Map<String, dynamic>>.from(data);
          await _saveLocalUserAgendas(_userAgendas);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error fetching user agendas: $e');
        _userAgendas = await _loadLocalUserAgendas();
        notifyListeners();
      }
    } else {
      _userAgendas = await _loadLocalUserAgendas();
      notifyListeners();
    }
  }

  Future<void> rejectAgenda(String agendaId) async {
    if (currentUser == null) return;

    final idx = _userAgendas.indexWhere((a) => a['id'] == agendaId);
    if (idx != -1) {
      _userAgendas[idx]['status'] = 'RECHAZADA';
      await _saveLocalUserAgendas(_userAgendas);
      notifyListeners();
    }

    if (_todayAgenda != null && _todayAgenda!['id'] == agendaId) {
      _todayAgenda!['status'] = 'RECHAZADA';
      await _saveLocalAgenda(_todayAgenda!);
      notifyListeners();
    }

    if (_isOnline) {
      try {
        await ApiClient.post('order', '/api/v1/agendas/$agendaId/status', {'status': 'RECHAZADA'});
      } catch (e) {
        debugPrint('Error sending reject status to server: $e');
      }
    }
  }

  Future<void> completeAgendaItemForAgenda(String agendaId, String itemId, String notes) async {
    final aIdx = _userAgendas.indexWhere((a) => a['id'] == agendaId);
    if (aIdx != -1) {
      final agenda = Map<String, dynamic>.from(_userAgendas[aIdx]);
      final items = List<Map<String, dynamic>>.from(agenda['items'] ?? []);
      final idx = items.indexWhere((i) => i['id'] == itemId);
      if (idx != -1) {
        items[idx]['status'] = 'COMPLETADO';
        items[idx]['notes'] = notes;
        items[idx]['completedAt'] = DateTime.now().toUtc().toIso8601String();
        agenda['items'] = items;

        final allCompleted = items.every((i) => i['status'] == 'COMPLETADO');
        if (allCompleted) {
          agenda['status'] = 'COMPLETADA';
        }
        _userAgendas[aIdx] = agenda;
        await _saveLocalUserAgendas(_userAgendas);
        
        if (_todayAgenda != null && _todayAgenda!['id'] == agendaId) {
          _todayAgenda = agenda;
          await _saveLocalAgenda(_todayAgenda!);
        }
        notifyListeners();
      }
    }

    if (_isOnline) {
      try {
        await ApiClient.post('order', '/api/v1/agendas/items/$itemId/complete', {'notes': notes});
      } catch (e) {
        debugPrint('Error completing item on server: $e');
      }
    }
  }

  Future<void> _saveLocalUserAgendas(List<Map<String, dynamic>> agendas) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user_agendas.json');
      await file.writeAsString(jsonEncode(agendas));
    } catch (e) {
      debugPrint('Error saving local user agendas: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadLocalUserAgendas() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user_agendas.json');
      if (await file.exists()) {
        final List<dynamic> data = jsonDecode(await file.readAsString());
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('Error loading local user agendas: $e');
    }
    return [];
  }

  Future<void> acceptAgenda(String agendaId) async {
    if (currentUser == null) return;

    final idx = _userAgendas.indexWhere((a) => a['id'] == agendaId);
    if (idx != -1) {
      _userAgendas[idx]['status'] = 'ACEPTADA';
      await _saveLocalUserAgendas(_userAgendas);
      notifyListeners();
    }

    if (_todayAgenda != null && _todayAgenda!['id'] == agendaId) {
      _todayAgenda!['status'] = 'ACEPTADA';
      await _saveLocalAgenda(_todayAgenda!);
      notifyListeners();
    }

    if (_isOnline) {
      try {
        await ApiClient.post('order', '/api/v1/agendas/$agendaId/status', {'status': 'ACEPTADA'});
      } catch (e) {
        debugPrint('Error sending accept status to server, queueing mutation: $e');
        await _queueAgendaMutation(agendaId, 'UPDATE', '{"status": "ACEPTADA"}');
      }
    } else {
      await _queueAgendaMutation(agendaId, 'UPDATE', '{"status": "ACEPTADA"}');
    }
  }

  Future<void> completeAgendaItem(String itemId, String notes) async {
    // Find which agenda contains this itemId in _userAgendas
    String? foundAgendaId;
    for (var agenda in _userAgendas) {
      final List items = agenda['items'] as List? ?? [];
      final hasItem = items.any((i) => i['id'] == itemId);
      if (hasItem) {
        foundAgendaId = agenda['id'];
        break;
      }
    }

    if (foundAgendaId != null) {
      await completeAgendaItemForAgenda(foundAgendaId, itemId, notes);
    } else {
      if (_todayAgenda != null && _todayAgenda!['items'] != null) {
        final items = List<Map<String, dynamic>>.from(_todayAgenda!['items']);
        final idx = items.indexWhere((i) => i['id'] == itemId);
        if (idx != -1) {
          items[idx]['status'] = 'COMPLETADO';
          items[idx]['notes'] = notes;
          items[idx]['completedAt'] = DateTime.now().toUtc().toIso8601String();
          _todayAgenda!['items'] = items;

          final allCompleted = items.every((i) => i['status'] == 'COMPLETADO');
          if (allCompleted) {
            _todayAgenda!['status'] = 'COMPLETADA';
          }
          await _saveLocalAgenda(_todayAgenda!);
          notifyListeners();
        }
      }

      if (_isOnline) {
        try {
          await ApiClient.post('order', '/api/v1/agendas/items/$itemId/complete', {'notes': notes});
        } catch (e) {
          debugPrint('Error sending complete item status to server, queueing mutation: $e');
          await _queueAgendaItemMutation(itemId, 'UPDATE', jsonEncode({'status': 'COMPLETADO', 'notes': notes}));
        }
      } else {
        await _queueAgendaItemMutation(itemId, 'UPDATE', jsonEncode({'status': 'COMPLETADO', 'notes': notes}));
      }
    }
  }

  Future<bool> assignAgenda({
    required String preventistaId,
    required DateTime date,
    required List<String> clientIds,
  }) async {
    if (currentUser == null || !_isOnline) return false;
    try {
      final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final response = await ApiClient.post('order', '/api/v1/agendas', {
        'preventistaId': preventistaId,
        'date': formattedDate,
        'clientIds': clientIds,
      });
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error assigning agenda: $e');
      return false;
    }
  }

  Future<void> _queueAgendaMutation(String agendaId, String operation, String payload) async {
    final mutationId = generateUuid();
    await _db.insertMutation(
      id: mutationId,
      entityType: 'AGENDA',
      entityId: agendaId,
      operation: operation,
      payload: payload,
    );
    _pendingSyncCount = (await _db.getPendingMutations()).length;
    notifyListeners();
  }

  Future<void> _queueAgendaItemMutation(String itemId, String operation, String payload) async {
    final mutationId = generateUuid();
    await _db.insertMutation(
      id: mutationId,
      entityType: 'AGENDA_ITEM',
      entityId: itemId,
      operation: operation,
      payload: payload,
    );
    _pendingSyncCount = (await _db.getPendingMutations()).length;
    notifyListeners();
  }

  Future<void> _saveLocalAgenda(Map<String, dynamic> agenda) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/today_agenda.json');
      await file.writeAsString(jsonEncode(agenda));
    } catch (e) {
      debugPrint('Error saving local agenda: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadLocalAgenda() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/today_agenda.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading local agenda: $e');
    }
    return null;
  }

  Future<void> _clearLocalAgenda() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/today_agenda.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing local agenda: $e');
    }
  }

  Future<void> _clearLocalUserAgendas() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user_agendas.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing local user agendas: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/session.json');
      if (await file.exists()) {
        await file.delete();
      }
      await _clearLocalAgenda();
      await _clearLocalUserAgendas();
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }
}

class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String token;
  final String? phone;
  final String? tipoVehiculo;
  final String? matricula;
  final Map<String, dynamic> userMetadata;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.token,
    this.phone,
    this.tipoVehiculo,
    this.matricula,
    required this.userMetadata,
  });
}

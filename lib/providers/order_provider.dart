import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/db_helper.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  List<OrderModel> _orders = [];
  List<Map<String, dynamic>> _adminOrders = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = true;
  String _userRole = 'distributor'; // 'distributor' or 'admin'

  final DbHelper _db = DbHelper.instance;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  StreamSubscription<AuthState>? _authStateSubscription;

  List<OrderModel> get orders => _orders;
  List<Map<String, dynamic>> get adminOrders => _adminOrders;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  String get userRole => _userRole;

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
      } else {
        await loadOrders();
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

      if (event == AuthChangeEvent.signedIn && session != null) {
        await refreshUserRole();
        if (_userRole == 'admin') {
          await fetchAdminOrders();
        } else {
          await loadOrders();
          syncUnsyncedOrders();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _orders = [];
        _adminOrders = [];
        _userRole = 'distributor';
        notifyListeners();
      }
    });
  }

  Future<void> refreshUserRole() async {
    if (currentUser == null) return;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', currentUser!.id)
          .maybeSingle();
      
      if (response != null && response['role'] != null) {
        _userRole = response['role'] as String;
      } else {
        _userRole = 'distributor'; // Fallback
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      _userRole = 'distributor'; // Default
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

  Future<void> signUpWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signUp(email: email, password: password);
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
      await Supabase.instance.client.auth.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Distributor Orders (SQLite + Supabase Sync) ---
  Future<void> loadOrders() async {
    if (currentUser == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      // Local SQLite filter by logged-in user id
      final allOrders = await _db.getAllOrders();
      _orders = allOrders.where((o) => o.userId == currentUser!.id).toList();
    } catch (e) {
      debugPrint('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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

    // Save atomically in SQLite (orders + outbox CREATE mutation)
    await _db.insertOrder(newOrder);
    _orders.insert(0, newOrder);
    notifyListeners();

    // Try sync immediately if online
    if (_isOnline) {
      syncUnsyncedOrders();
    }
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
    if (pendingMutations.isEmpty) return;

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
          // If already exists or deleted on server, we can skip it to avoid getting stuck
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
          .select('*, profiles(email, full_name)');
      
      _adminOrders = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching admin orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

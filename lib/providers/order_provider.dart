import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../core/config/supabase_config.dart';
import '../core/database/db_helper.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = true;

  final DbHelper _db = DbHelper.instance;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  double _syncProgress = 0.0;
  double get syncProgress => _syncProgress;

  OrderProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadOrders();
    await _checkInitialConnection();
    _startConnectivityListener();
  }

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

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      _orders = await _db.getAllOrders();
    } catch (e) {
      debugPrint('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add Order (UUID primary key and Transactional Outbox write)
  Future<void> addOrder(String clientName, String productId, String productName, int quantity, double price) async {
    final clientOrderId = generateUuid();
    
    final newOrder = OrderModel(
      clientOrderId: clientOrderId,
      clientName: clientName,
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      createdAt: DateTime.now(),
      isSynced: 0,
    );

    // Save atomically in local DB (inserts order and PENDING CREATE mutation in outbox)
    await _db.insertOrder(newOrder);
    _orders.insert(0, newOrder);
    notifyListeners();

    // Trigger sync automatically if online
    if (_isOnline) {
      syncUnsyncedOrders();
    }
  }

  // Synchronize all pending mutations directly to Supabase REST API
  Future<void> syncUnsyncedOrders() async {
    if (_isSyncing || !_isOnline) return;

    final pendingMutations = await _db.getPendingMutations();
    if (pendingMutations.isEmpty) return;

    _isSyncing = true;
    _syncProgress = 0.0;
    notifyListeners();

    debugPrint('Starting synchronization of ${pendingMutations.length} mutations to Supabase...');

    final List<String> successfullySyncedMutationIds = [];
    final List<String> successfullySyncedOrderIds = [];

    try {
      for (final m in pendingMutations) {
        final mutationId = m['id'] as String;
        final orderId = m['entity_id'] as String;
        final operation = m['operation'] as String;
        final payloadStr = m['payload'] as String;

        bool success = false;

        if (operation == 'CREATE') {
          // Perform HTTP POST to Supabase REST API
          final response = await http.post(
            Uri.parse('${SupabaseConfig.url}/rest/v1/orders'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            },
            body: payloadStr, // Flat JSON string containing order columns
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 201 || response.statusCode == 200 || response.statusCode == 204) {
            success = true;
          } else if (response.statusCode == 409) {
            // 409 Conflict means it already exists in Supabase (idempotency safety)
            success = true;
          } else {
            debugPrint('Failed to insert order to Supabase: Status ${response.statusCode}, Body: ${response.body}');
          }
        } else if (operation == 'DELETE') {
          // Perform HTTP DELETE to Supabase REST API
          final response = await http.delete(
            Uri.parse('${SupabaseConfig.url}/rest/v1/orders?client_order_id=eq.$orderId'),
            headers: {
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            },
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 204 || response.statusCode == 200) {
            success = true;
          } else {
            debugPrint('Failed to delete order from Supabase: Status ${response.statusCode}, Body: ${response.body}');
          }
        }

        if (success) {
          successfullySyncedMutationIds.add(mutationId);
          if (operation == 'CREATE') {
            successfullySyncedOrderIds.add(orderId);
          }
        } else {
          // Break synchronization loop upon first error to maintain sequential integrity
          debugPrint('Stopping sync due to failure in mutation $mutationId.');
          break;
        }
      }

      if (successfullySyncedMutationIds.isNotEmpty) {
        // 1. Purge successful mutations from local outbox table
        await _db.deleteMutations(successfullySyncedMutationIds);
        
        // 2. Mark local orders as synced in SQLite
        await _db.markOrdersAsSynced(successfullySyncedOrderIds);
        
        // Reload from SQLite to update UI
        await loadOrders();
        debugPrint('Sync completed. ${successfullySyncedMutationIds.length} mutations resolved.');
      }
    } catch (e) {
      debugPrint('Sync failed with connection error: $e');
    } finally {
      _isSyncing = false;
      _syncProgress = 0.0;
      notifyListeners();
    }
  }

  // Delete Order (Queue DELETE mutation in outbox)
  Future<void> deleteOrder(String clientOrderId) async {
    // Delete local SQLite record and queue DELETE mutation in outbox
    await _db.deleteOrder(clientOrderId);
    _orders.removeWhere((o) => o.clientOrderId == clientOrderId);
    notifyListeners();

    // Trigger sync automatically to delete on the server
    if (_isOnline) {
      syncUnsyncedOrders();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}

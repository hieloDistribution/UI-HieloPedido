import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../core/database/db_helper.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = true;

  final DbHelper _db = DbHelper.instance;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  // The local IP address of your PC running the backend services
  static const String _syncApiUrl = 'http://192.168.0.16:8081/api/v1/sync';

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

  // Synchronize all pending mutations using Transactional Outbox Pattern
  Future<void> syncUnsyncedOrders() async {
    if (_isSyncing || !_isOnline) return;

    final pendingMutations = await _db.getPendingMutations();
    if (pendingMutations.isEmpty) return;

    _isSyncing = true;
    _syncProgress = 0.0;
    notifyListeners();

    debugPrint('Starting synchronization of ${pendingMutations.length} mutations...');

    try {
      // Map database rows to MutationDto schema expected by Sync Service
      final payloadList = pendingMutations.map((m) {
        return {
          'id': m['id'],
          'entityType': m['entity_type'],
          'entityId': m['entity_id'],
          'operation': m['operation'],
          'payload': m['payload'],
          'timestamp': m['timestamp'],
        };
      }).toList();

      // Perform POST request to Spring Boot sync-service
      final response = await http.post(
        Uri.parse(_syncApiUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(payloadList),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final bool success = responseData['success'] ?? false;
        final List<dynamic> processedIds = responseData['processedIds'] ?? [];

        if (success && processedIds.isNotEmpty) {
          // Identify which orders and mutations were processed successfully
          final List<String> successfullySyncedMutationIds = List<String>.from(processedIds);
          
          final List<String> successfullySyncedOrderIds = pendingMutations
              .where((m) => successfullySyncedSyncedIds(m, successfullySyncedMutationIds))
              .map((m) => m['entity_id'] as String)
              .toList();

          // 1. Purge successful mutations from outbox table
          await _db.deleteMutations(successfullySyncedMutationIds);
          
          // 2. Mark local orders as synced in SQLite
          await _db.markOrdersAsSynced(successfullySyncedOrderIds);
          
          // Reload from SQLite to update UI
          await loadOrders();
          debugPrint('Sync completed. ${processedIds.length} mutations resolved.');
        }
      } else {
        debugPrint('Sync failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sync failed with connection error: $e');
    } finally {
      _isSyncing = false;
      _syncProgress = 0.0;
      notifyListeners();
    }
  }

  bool successfullySyncedSyncedIds(Map<String, dynamic> mutation, List<String> processedIds) {
    return processedIds.contains(mutation['id']);
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

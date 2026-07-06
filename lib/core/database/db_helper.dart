import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/order_model.dart';

// Standalone RFC4122 v4 UUID generator (no third-party dependencies required)
String generateUuid() {
  final random = Random();
  const hexDigits = '0123456789abcdef';
  final chars = List<String>.generate(36, (i) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      return '-';
    } else if (i == 14) {
      return '4';
    } else if (i == 19) {
      return hexDigits[random.nextInt(4) + 8];
    } else {
      return hexDigits[random.nextInt(16)];
    }
  });
  return chars.join();
}

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  // In-memory fallbacks for Web platform testing
  final List<Map<String, dynamic>> _webOrders = [];
  final List<Map<String, dynamic>> _webOutbox = [];

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite database cannot be accessed directly on Web. Use CRUD methods instead.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('orders_v6.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Orders table
    await db.execute('''
      CREATE TABLE orders (
        client_order_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        client_name TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL,
        status TEXT DEFAULT 'pendiente',
        repartidor_id TEXT,
        verification_code TEXT,
        delivery_address TEXT,
        client_phone TEXT,
        accepted_at TEXT,
        delivered_at TEXT,
        payment_method TEXT DEFAULT 'efectivo',
        delivery_latitude REAL,
        delivery_longitude REAL,
        client_avatar_url TEXT
      )
    ''');

    // 2. Transactional Outbox table
    await db.execute('''
      CREATE TABLE outbox (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT DEFAULT 'PENDING'
      )
    ''');
  }

  // --- Transactional Outbox Writes ---

  // Insert Order and its Outbox mutation atomically
  Future<void> insertOrder(OrderModel order) async {
    final mutationId = generateUuid();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload = jsonEncode(order.toMap());

    if (kIsWeb) {
      _webOrders.add(order.toMap());
      _webOutbox.add({
        'id': mutationId,
        'entity_type': 'ORDER',
        'entity_id': order.clientOrderId,
        'operation': 'CREATE',
        'payload': payload,
        'timestamp': timestamp,
        'status': 'PENDING',
      });
    } else {
      final db = await database;
      await db.transaction((txn) async {
        // Insert order
        await txn.insert('orders', order.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        // Insert mutation to outbox
        await txn.insert('outbox', {
          'id': mutationId,
          'entity_type': 'ORDER',
          'entity_id': order.clientOrderId,
          'operation': 'CREATE',
          'payload': payload,
          'timestamp': timestamp,
          'status': 'PENDING',
        });
      });
    }
  }

  // Update Order and queue its CREATE/UPSERT mutation in outbox
  Future<void> updateOrder(OrderModel order) async {
    final mutationId = generateUuid();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload = jsonEncode(order.toMap());

    if (kIsWeb) {
      final index = _webOrders.indexWhere((o) => o['client_order_id'] == order.clientOrderId);
      if (index != -1) {
        _webOrders[index] = order.toMap();
      }
      _webOutbox.add({
        'id': mutationId,
        'entity_type': 'ORDER',
        'entity_id': order.clientOrderId,
        'operation': 'CREATE',
        'payload': payload,
        'timestamp': timestamp,
        'status': 'PENDING',
      });
    } else {
      final db = await database;
      await db.transaction((txn) async {
        // Update order
        await txn.insert('orders', order.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        // Insert mutation to outbox
        await txn.insert('outbox', {
          'id': mutationId,
          'entity_type': 'ORDER',
          'entity_id': order.clientOrderId,
          'operation': 'CREATE',
          'payload': payload,
          'timestamp': timestamp,
          'status': 'PENDING',
        });
      });
    }
  }

  // Read All Orders
  Future<List<OrderModel>> getAllOrders() async {
    if (kIsWeb) {
      final sortedList = List<Map<String, dynamic>>.from(_webOrders)
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return sortedList.map((map) => OrderModel.fromMap(map)).toList();
    } else {
      final db = await database;
      final result = await db.query('orders', orderBy: 'created_at DESC');
      return result.map((map) => OrderModel.fromMap(map)).toList();
    }
  }

  // Delete Order and queue its DELETE mutation in outbox
  Future<void> deleteOrder(String clientOrderId) async {
    final mutationId = generateUuid();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (kIsWeb) {
      _webOrders.removeWhere((o) => o['client_order_id'] == clientOrderId);
      _webOutbox.add({
        'id': mutationId,
        'entity_type': 'ORDER',
        'entity_id': clientOrderId,
        'operation': 'DELETE',
        'payload': '', // No payload needed for delete operations
        'timestamp': timestamp,
        'status': 'PENDING',
      });
    } else {
      final db = await database;
      await db.transaction((txn) async {
        // Delete order physically from local SQLite immediately
        await txn.delete('orders', where: 'client_order_id = ?', whereArgs: [clientOrderId]);
        // Insert DELETE mutation to outbox so it syncs to backend database
        await txn.insert('outbox', {
          'id': mutationId,
          'entity_type': 'ORDER',
          'entity_id': clientOrderId,
          'operation': 'DELETE',
          'payload': '',
          'timestamp': timestamp,
          'status': 'PENDING',
        });
      });
    }
  }

  // --- Outbox Sync Methods ---

  // Get all pending mutations sorted by timestamp
  Future<List<Map<String, dynamic>>> getPendingMutations() async {
    if (kIsWeb) {
      return _webOutbox.where((m) => m['status'] == 'PENDING').toList()
        ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    } else {
      final db = await database;
      return await db.query('outbox', where: 'status = ?', whereArgs: ['PENDING'], orderBy: 'timestamp ASC');
    }
  }

  // Purge/delete resolved mutations from the outbox
  Future<void> deleteMutations(List<String> mutationIds) async {
    if (mutationIds.isEmpty) return;
    if (kIsWeb) {
      _webOutbox.removeWhere((m) => mutationIds.contains(m['id']));
    } else {
      final db = await database;
      final placeholders = List.filled(mutationIds.length, '?').join(',');
      await db.delete('outbox', where: "id IN ($placeholders)", whereArgs: mutationIds);
    }
  }

  // Mark local orders as synced
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    if (orderIds.isEmpty) return;
    if (kIsWeb) {
      for (var id in orderIds) {
        final index = _webOrders.indexWhere((o) => o['client_order_id'] == id);
        if (index != -1) {
          final updatedMap = Map<String, dynamic>.from(_webOrders[index]);
          updatedMap['is_synced'] = 1;
          _webOrders[index] = updatedMap;
        }
      }
    } else {
      final db = await database;
      final placeholders = List.filled(orderIds.length, '?').join(',');
      await db.rawUpdate(
        'UPDATE orders SET is_synced = 1 WHERE client_order_id IN ($placeholders)',
        orderIds,
      );
    }
  }

  // Cache fetched orders locally
  Future<void> cacheOrders(List<OrderModel> orders) async {
    if (kIsWeb || orders.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final order in orders) {
        final localOrder = order.copyWith(isSynced: 1);
        await txn.insert('orders', localOrder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // Close DB connection
  Future close() async {
    if (kIsWeb) return;
    final db = await database;
    db.close();
  }
}

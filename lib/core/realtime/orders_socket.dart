import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/token_storage.dart';

/// Typed events emitted by the backend's WebSocket channel at /ws.
/// Mirrors the JSON envelope broadcasted by OrdersWebSocketHandler.
class OrderRealtimeEvent {
  final String type; // 'order.created' | 'order.updated' | 'order.deleted' | 'driver.location'
  final Map<String, dynamic> data;

  const OrderRealtimeEvent(this.type, this.data);

  static OrderRealtimeEvent? tryParse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (type == null) return null;
      return OrderRealtimeEvent(type, data);
    } catch (_) {
      return null;
    }
  }
}

/// WebSocket client that connects to ws(s)://<host>/ws?token=<access_token>.
/// Reconnects on close (exponential backoff capped at 30s). Exposes a
/// broadcast Stream<OrderRealtimeEvent> for the OrderProvider to consume.
class OrdersSocket {
  OrdersSocket._();
  static final OrdersSocket instance = OrdersSocket._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _disposed = false;

  final StreamController<OrderRealtimeEvent> _events =
      StreamController<OrderRealtimeEvent>.broadcast();

  Stream<OrderRealtimeEvent> get events => _events.stream;

  String _wsHost() {
    return kIsWeb ? 'localhost' : '10.0.2.2';
  }

  Future<void> connect() async {
    if (_disposed) return;
    final token = await TokenStorage.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('OrdersSocket: no token, skipping connect');
      return;
    }
    _retryAttempt = 0;
    _open(token);
  }

  void _open(String token) {
    final uri = Uri.parse('ws://${_wsHost()}:8081/ws?token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (msg) {
          if (msg is! String) return;
          final evt = OrderRealtimeEvent.tryParse(msg);
          if (evt != null) _events.add(evt);
        },
        onError: (e) {
          debugPrint('OrdersSocket error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('OrdersSocket closed');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
      debugPrint('OrdersSocket connected to $uri');
    } catch (e) {
      debugPrint('OrdersSocket connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _retryAttempt = (_retryAttempt + 1).clamp(1, 6);
    final delaySec = [1, 2, 5, 10, 20, 30][_retryAttempt - 1];
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySec), () => connect());
  }

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _events.close();
  }
}
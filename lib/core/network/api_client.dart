import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/token_storage.dart';

/// HTTP client used by every provider/repository that talks to the Java
/// backend (sync-service on :8081 and order-service on :8082).
///
/// Responsibilities:
///  - Inject the JWT access_token from TokenStorage on every request.
///  - On 401, attempt a single refresh-token rotation and retry.
///  - Expose plain get/post/patch/delete wrappers; the provider layer
///    knows nothing about Supabase, JWT, or refresh logic.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // Loopback IP for the Android emulator is 10.0.2.2 (resolves to the host).
  // On web we use localhost; on a physical device swap to your LAN IP.
  String _host() => kIsWeb ? 'localhost' : '10.0.2.2';

  Uri _uri(String service, String path) {
    final port = service == 'sync' ? '8081' : '8082';
    return Uri.parse('http://${_host()}:$port$path');
  }

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await TokenStorage.instance.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<http.Response> _send(
    String method,
    String service,
    String path, {
    Object? body,
    bool retryOn401 = true,
    bool withAuth = true,
  }) async {
    final uri = _uri(service, path);
    final headers = await _headers(withAuth: withAuth);
    http.Response resp;
    switch (method) {
      case 'GET':
        resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
        break;
      case 'POST':
        resp = await http
            .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(const Duration(seconds: 15));
        break;
      case 'PATCH':
        resp = await http
            .patch(uri, headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(const Duration(seconds: 15));
        break;
      case 'DELETE':
        resp = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
        break;
      default:
        throw ArgumentError('Unsupported method $method');
    }
    if (resp.statusCode == 401 && retryOn401 && withAuth) {
      final rotated = await _tryRefresh();
      if (rotated) {
        return _send(method, service, path, body: body, retryOn401: false, withAuth: withAuth);
      } else {
        await TokenStorage.instance.clear();
      }
    }
    return resp;
  }

  Future<bool> _tryRefresh() async {
    final refresh = await TokenStorage.instance.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    final uri = _uri('sync', '/api/v1/auth/refresh');
    try {
      final resp = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refresh}))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return false;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      await TokenStorage.instance.updateAccessToken(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresInSeconds: (json['expires_in'] as num?)?.toInt() ?? 900,
      );
      return true;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> get(String service, String path, {bool withAuth = true}) =>
      _send('GET', service, path, withAuth: withAuth);

  Future<http.Response> post(String service, String path, [Object? body, bool withAuth = true]) =>
      _send('POST', service, path, body: body, withAuth: withAuth);

  Future<http.Response> patch(String service, String path, [Object? body]) =>
      _send('PATCH', service, path, body: body);

  Future<http.Response> delete(String service, String path) =>
      _send('DELETE', service, path);
}
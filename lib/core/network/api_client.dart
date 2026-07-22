import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiClient {
  static String? token;

  // IP local de la computadora (Wi-Fi) para que funcione en dispositivos físicos reales y emuladores
  static String _host = '192.168.1.4';

  static String get syncBaseUrl => 'http://$_host:8080';
  static String get orderBaseUrl => 'http://$_host:8080';

  static Future<void> initialize() async {
    if (kIsWeb) {
      _host = 'localhost';
      return;
    }
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        if (!androidInfo.isPhysicalDevice) {
          _host = '10.0.2.2';
          debugPrint('ApiClient: Detectado Emulador Android, usando host $_host');
          return;
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        if (!iosInfo.isPhysicalDevice) {
          _host = 'localhost';
          debugPrint('ApiClient: Detectado Emulador iOS, usando host $_host');
          return;
        }
      }
    } catch (e) {
      debugPrint('Error detectando dispositivo en ApiClient: $e');
    }
    _host = '192.168.1.4';
    debugPrint('ApiClient: Detectado Dispositivo Físico, usando host $_host');
  }

  static Future<Map<String, String>> _headers() async {
    final authHeader = token != null ? 'Bearer $token' : '';
    return {'Content-Type': 'application/json', 'Authorization': authHeader};
  }

  static Future<http.Response> get(String service, String path) async {
    final baseUrl = service == 'sync' ? syncBaseUrl : orderBaseUrl;
    final url = Uri.parse('$baseUrl$path');
    debugPrint('ApiClient GET: $url');
    final response = await http
        .get(url, headers: await _headers())
        .timeout(const Duration(seconds: 10));
    debugPrint('ApiClient GET [$url] -> Status ${response.statusCode}');
    return response;
  }

  static Future<http.Response> post(
    String service,
    String path,
    dynamic body,
  ) async {
    final baseUrl = service == 'sync' ? syncBaseUrl : orderBaseUrl;
    final url = Uri.parse('$baseUrl$path');
    debugPrint('ApiClient POST: $url');
    final response = await http
        .post(url, headers: await _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    debugPrint('ApiClient POST [$url] -> Status ${response.statusCode}: ${response.body}');
    return response;
  }

  static Future<http.Response> delete(String service, String path) async {
    final baseUrl = service == 'sync' ? syncBaseUrl : orderBaseUrl;
    final url = Uri.parse('$baseUrl$path');
    debugPrint('ApiClient DELETE: $url');
    final response = await http
        .delete(url, headers: await _headers())
        .timeout(const Duration(seconds: 10));
    debugPrint('ApiClient DELETE [$url] -> Status ${response.statusCode}');
    return response;
  }
}

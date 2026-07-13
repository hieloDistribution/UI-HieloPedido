import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  // IP local de la computadora (Wi-Fi) para que funcione en dispositivos físicos reales y emuladores
  static final String _host = kIsWeb ? 'localhost' : '192.168.1.4';

  static final String syncBaseUrl = 'http://$_host:8081';
  static final String orderBaseUrl = 'http://$_host:8082';

  static Future<Map<String, String>> _headers() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String service, String path) async {
    final baseUrl = service == 'sync' ? syncBaseUrl : orderBaseUrl;
    final url = Uri.parse('$baseUrl$path');
    debugPrint('ApiClient GET: $url');
    return http.get(url, headers: await _headers());
  }

  static Future<http.Response> post(String service, String path, dynamic body) async {
    final baseUrl = service == 'sync' ? syncBaseUrl : orderBaseUrl;
    final url = Uri.parse('$baseUrl$path');
    debugPrint('ApiClient POST: $url');
    return http.post(url, headers: await _headers(), body: jsonEncode(body));
  }

  static Future<http.Response> delete(String service, String path) async {
    final baseUrl = service == 'sync' ? syncBaseUrl : orderBaseUrl;
    final url = Uri.parse('$baseUrl$path');
    debugPrint('ApiClient DELETE: $url');
    return http.delete(url, headers: await _headers());
  }
}

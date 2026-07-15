import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT pair (access + refresh) issued by the sync-service,
/// along with the minimum profile snapshot needed to render the UI before
/// the first /api/v1/users/me fetch resolves.
///
/// All values live in the platform keystore (Keychain on iOS, EncryptedSharedPreferences
/// on Android). If you need to inspect them locally, use `adb shell run-as`.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _access = 'auth.access_token';
  static const _refresh = 'auth.refresh_token';
  static const _expiresAt = 'auth.expires_at_ms';
  static const _userId = 'auth.user_id';
  static const _email = 'auth.email';
  static const _role = 'auth.role';
  static const _fullName = 'auth.full_name';
  static const _avatarUrl = 'auth.avatar_url';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedAccess;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
    required String userId,
    required String email,
    required String role,
    String? fullName,
    String? avatarUrl,
  }) async {
    final expiresAtMs = DateTime.now()
        .add(Duration(seconds: expiresInSeconds))
        .millisecondsSinceEpoch;
    await Future.wait([
      _storage.write(key: _access, value: accessToken),
      _storage.write(key: _refresh, value: refreshToken),
      _storage.write(key: _expiresAt, value: expiresAtMs.toString()),
      _storage.write(key: _userId, value: userId),
      _storage.write(key: _email, value: email),
      _storage.write(key: _role, value: role),
      if (fullName != null) _storage.write(key: _fullName, value: fullName),
      if (avatarUrl != null) _storage.write(key: _avatarUrl, value: avatarUrl),
    ]);
    _cachedAccess = accessToken;
  }

  Future<void> updateAccessToken({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
  }) async {
    final expiresAtMs = DateTime.now()
        .add(Duration(seconds: expiresInSeconds))
        .millisecondsSinceEpoch;
    await Future.wait([
      _storage.write(key: _access, value: accessToken),
      _storage.write(key: _refresh, value: refreshToken),
      _storage.write(key: _expiresAt, value: expiresAtMs.toString()),
    ]);
    _cachedAccess = accessToken;
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    if (fullName != null) {
      await _storage.write(key: _fullName, value: fullName);
    }
    if (avatarUrl != null) {
      await _storage.write(key: _avatarUrl, value: avatarUrl);
    }
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccess != null) return _cachedAccess;
    final v = await _storage.read(key: _access);
    _cachedAccess = v;
    return v;
  }

  String? get cachedAccessToken => _cachedAccess;

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refresh);
  }

  Future<int?> getExpiresAtMs() async {
    final v = await _storage.read(key: _expiresAt);
    return v == null ? null : int.tryParse(v);
  }

  Future<Map<String, String?>> getProfile() async {
    final entries = await Future.wait([
      _storage.read(key: _userId),
      _storage.read(key: _email),
      _storage.read(key: _role),
      _storage.read(key: _fullName),
      _storage.read(key: _avatarUrl),
    ]);
    return {
      'user_id': entries[0],
      'email': entries[1],
      'role': entries[2],
      'full_name': entries[3],
      'avatar_url': entries[4],
    };
  }

  Future<bool> isAuthenticated() async {
    final t = await getAccessToken();
    return t != null && t.isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.deleteAll();
    _cachedAccess = null;
  }

  /// Diagnostic dump. Never log this in production.
  String debugDump() {
    return jsonEncode({
      'has_access': _cachedAccess != null,
      'role': _storage.toString(),
    });
  }
}
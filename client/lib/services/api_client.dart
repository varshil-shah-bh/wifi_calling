import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Thin HTTP layer that owns the JWT pair and transparently refreshes it once on a 401.
class ApiClient {
  ApiClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  final http.Client _http = http.Client();

  String? accessToken;
  String? _refreshToken;

  void Function()? onSessionExpired;

  bool get hasSession => _refreshToken != null;

  Future<void> loadTokens() async {
    accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
  }

  Future<void> saveTokens(String access, String refresh) async {
    accessToken = access;
    _refreshToken = refresh;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clearTokens() async {
    accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool allowRetry = true,
  }) async {
    final response = await _raw(method, path, body: body, authenticated: authenticated);

    if (response.statusCode == 401 && authenticated && allowRetry) {
      if (await _refresh()) {
        return _send(method, path, body: body, authenticated: true, allowRetry: false);
      }
      await clearTokens();
      onSessionExpired?.call();
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        (decoded['error'] as String?) ?? 'Request failed (${response.statusCode})',
      );
    }
    return decoded;
  }

  Future<http.Response> _raw(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authenticated && accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final encoded = body == null ? null : jsonEncode(body);

    return switch (method) {
      'GET' => _http.get(uri, headers: headers),
      'POST' => _http.post(uri, headers: headers, body: encoded),
      _ => throw UnsupportedError('Unsupported method $method'),
    };
  }

  Future<bool> _refresh() async {
    if (_refreshToken == null) return false;
    final response = await _raw(
      'POST',
      '/api/auth/refresh',
      body: {'refreshToken': _refreshToken},
      authenticated: false,
    );
    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
    return true;
  }
}

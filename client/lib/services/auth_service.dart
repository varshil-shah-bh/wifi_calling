import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'api_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthService extends ChangeNotifier {
  AuthService(this._api) {
    _api.onSessionExpired = () {
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    };
  }

  final ApiClient _api;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get accessToken => _api.accessToken;

  Future<void> bootstrap() async {
    await _api.loadTokens();
    if (!_api.hasSession) {
      _set(AuthStatus.unauthenticated, null);
      return;
    }
    try {
      final data = await _api.get('/api/auth/me');
      _set(AuthStatus.authenticated, AppUser.fromJson(data['user'] as Map<String, dynamic>));
    } on Exception {
      await _api.clearTokens();
      _set(AuthStatus.unauthenticated, null);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) =>
      _authenticate('/api/auth/register', {
        'name': name,
        'email': email,
        'password': password,
      });

  Future<void> login({required String email, required String password}) =>
      _authenticate('/api/auth/login', {'email': email, 'password': password});

  Future<void> logout() async {
    await _api.clearTokens();
    _set(AuthStatus.unauthenticated, null);
  }

  Future<List<AppUser>> fetchUsers() async {
    final data = await _api.get('/api/users');
    return (data['users'] as List<dynamic>)
        .map((u) => AppUser.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<void> _authenticate(String path, Map<String, dynamic> body) async {
    final data = await _api.post(path, body: body, authenticated: false);
    await _api.saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
    _set(AuthStatus.authenticated, AppUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  void _set(AuthStatus status, AppUser? user) {
    _status = status;
    _user = user;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/user.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String get userRole => _user?.role ?? '';

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      logger.d('AuthProvider: Attempting login for $email');
      final response = await ApiService.login(email, password);
      logger.d('AuthProvider: API response received: $response');

      // Safe parsing
      final userData = response['user'];
      if (userData == null) {
        throw Exception('No user data in response');
      }

      logger.d('AuthProvider: Creating user from: $userData');
      _user = User.fromJson(userData);
      logger.d('AuthProvider: User created successfully: ${_user?.name}');
    } catch (error) {
      logger.d('AuthProvider: Login error: $error');
      _user = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await ApiService.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiService.clearAuthToken();
    _user = null;
    notifyListeners();
  }

  Future<void> autoLogin() async {
    // This would check for existing token and validate it
    // For simplicity, we'll just check if we have a user
    // In a real app, you'd validate the token with the server
  }
}

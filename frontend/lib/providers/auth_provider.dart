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
  int get userId => _user?.id ?? 0;

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
    required String phone,
    required String studentId,
    required String institution,
    required String educationLevel,
    required String semester,
    required String department,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      logger.d('AuthProvider: Attempting registration for $email');

      // SECURITY FIX: Force borrower role for public registration
      const secureRole = 'borrower';

      logger.d('AuthProvider: Registering as borrower (forced)');

      // FIXED: Send all enhanced user information
      await ApiService.register(
        name: name,
        email: email,
        password: password,
        role: secureRole,
        phone: phone,
        studentId: studentId,
        institution: institution,
        educationLevel: educationLevel,
        semester: semester,
        department: department,
      );

      logger.d('AuthProvider: Registration successful for $email');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Admin-only staff registration
  Future<void> registerStaff({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      logger.d('AuthProvider: Attempting staff registration for $email');

      // Validate role for staff creation
      if (role != 'technician' && role != 'admin') {
        throw Exception(
            'Only technician or admin roles can be created by admins');
      }

      // Check if current user is admin
      if (_user?.role != 'admin') {
        throw Exception('Only admins can create staff accounts');
      }

      await ApiService.createStaffUser({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      });

      logger.d('AuthProvider: Staff registration successful for $email');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      logger.d('AuthProvider: Logging out user ${_user?.name}');
      await ApiService.clearAuthToken();
      _user = null;
      logger.d('AuthProvider: Logout successful');
    } catch (error) {
      logger.e('AuthProvider: Logout error: $error');
      _user = null; // Clear user anyway
    } finally {
      notifyListeners();
    }
  }

  Future<void> autoLogin() async {
    try {
      logger.d('AuthProvider: Attempting auto-login');

      // Check for existing token
      final token = await ApiService.getAuthToken();
      if (token == null) {
        logger.d('AuthProvider: No token found');
        return;
      }

      // Validate token with server
      final userData = await ApiService.getCurrentUser();
      if (userData != null) {
        _user = User.fromJson(userData);
        logger.d('AuthProvider: Auto-login successful for ${_user?.name}');
      } else {
        logger.d('AuthProvider: Token invalid, clearing');
        await ApiService.clearAuthToken();
        _user = null;
      }
    } catch (error) {
      logger.e('AuthProvider: Auto-login error: $error');
      await ApiService.clearAuthToken();
      _user = null;
    } finally {
      notifyListeners();
    }
  }
}

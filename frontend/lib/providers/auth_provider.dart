import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/user.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String get userRole => _user?.role ?? '';
  int get userId => _user?.id ?? 0;
  String? get errorMessage => _errorMessage;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      logger.d('AuthProvider: Attempting login for $email');

      // Validate input
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

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

      _errorMessage = null;
    } catch (error) {
      logger.d('AuthProvider: Login error: $error');
      _user = null;
      _errorMessage = error.toString();
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
    _errorMessage = null;
    notifyListeners();

    try {
      logger.d('AuthProvider: Attempting registration for $email');

      // ✅ Validate input
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('All fields are required');
      }

      // ✅ Validate email format (institutional .edu emails)
      if (!email.toLowerCase().endsWith('.edu')) {
        throw Exception(
            'Please use your institutional email (ending with .edu)');
      }

      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        throw Exception('Please enter a valid email address');
      }

      // ✅ Validate password strength
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      // SECURITY FIX: Force borrower role for public registration
      const secureRole = 'borrower';

      logger.d('AuthProvider: Registering as borrower (forced)');

      await ApiService.register(
        name: name,
        email: email,
        password: password,
        role: secureRole, // Always use borrower role for public registration
      );

      logger.d('AuthProvider: Registration successful for $email');
      _errorMessage = null;
    } catch (error) {
      logger.e('AuthProvider: Registration error: $error');
      _errorMessage = error.toString();
      rethrow;
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
    _errorMessage = null;
    notifyListeners();

    try {
      logger.d('AuthProvider: Attempting staff registration for $email');

      // Validate input
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('All fields are required');
      }

      // Validate role for staff creation
      if (role != 'technician' && role != 'admin') {
        throw Exception(
            'Only technician or admin roles can be created by admins');
      }

      // Check if current user is admin
      if (_user?.role != 'admin') {
        throw Exception('Only admins can create staff accounts');
      }

      // Validate email format
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        throw Exception('Please enter a valid email address');
      }

      // Validate password strength
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      await ApiService.createStaffUser({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      });

      logger.d('AuthProvider: Staff registration successful for $email');
      _errorMessage = null;
    } catch (error) {
      logger.e('AuthProvider: Staff registration error: $error');
      _errorMessage = error.toString();
      rethrow;
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
      _errorMessage = null;
      logger.d('AuthProvider: Logout successful');
    } catch (error) {
      logger.e('AuthProvider: Logout error: $error');
      _user = null; // Clear user anyway
      _errorMessage = error.toString();
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
        _errorMessage = null;
        logger.d('AuthProvider: Auto-login successful for ${_user?.name}');
      } else {
        logger.d('AuthProvider: Token invalid, clearing');
        await ApiService.clearAuthToken();
        _user = null;
        _errorMessage = null;
      }
    } catch (error) {
      logger.e('AuthProvider: Auto-login error: $error');
      await ApiService.clearAuthToken();
      _user = null;
      _errorMessage = error.toString();
    } finally {
      notifyListeners();
    }
  }

  // ✅ NEW: Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ✅ NEW: Check if user has specific role
  bool hasRole(String role) {
    return _user?.role == role;
  }

  // ✅ NEW: Check if user is admin
  bool get isAdmin => _user?.role == 'admin';

  // ✅ NEW: Check if user is technician
  bool get isTechnician => _user?.role == 'technician';

  // ✅ NEW: Check if user is borrower
  bool get isBorrower => _user?.role == 'borrower';

  // ✅ NEW: Get user name
  String get userName => _user?.name ?? 'Guest';

  // ✅ NEW: Get user email
  String get userEmail => _user?.email ?? '';
}

import 'dart:convert';
import 'package:chemlab_frontend/models/lecture_schedule.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chemlab_frontend/models/user.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/models/borrowing.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class ApiService {
  static const String baseUrl =
      'https://chemlab-management-system-production.up.railway.app';
  static const String _authTokenKey = 'auth_token';

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
  }

  static Map<String, String> getHeaders([String? token]) {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Auth endpoints
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    logger.d('=== API SERVICE LOGIN ATTEMPT ===');
    logger.d('Email: $email');

    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: getHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    logger.d('=== API RESPONSE ===');
    logger.d('Status: ${response.statusCode}');
    logger.d('Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      logger.d('=== PARSED DATA ===');
      logger.d('Data: $data');
      logger.d('Token type: ${data['token'].runtimeType}');
      logger.d('User data type: ${data['user'].runtimeType}');
      logger.d('User data: ${data['user']}');

      if (data['user'] != null) {
        logger.d('User fields:');
        (data['user'] as Map).forEach((key, value) {
          logger.d('  $key: $value (type: ${value.runtimeType})');
        });
      }

      await saveAuthToken(data['token']);
      return data;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  // SECURE REGISTRATION - Only allows borrower registration
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    // SECURITY FIX: Only allow borrower registration through public endpoint
    const secureRole = 'borrower'; // Force borrower role

    logger.d('=== API SERVICE REGISTER ATTEMPT ===');
    logger.d('Name: $name');
    logger.d('Email: $email');
    logger.d('Role (forced): $secureRole');

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: getHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': secureRole, // Always use borrower role
      }),
    );

    logger.d('=== REGISTRATION RESPONSE ===');
    logger.d('Status: ${response.statusCode}');
    logger.d('Body: ${response.body}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      logger.d('=== REGISTRATION SUCCESS ===');
      logger.d('Data: $data');
      return data;
    } else {
      logger.e('Registration failed: ${response.body}');
      throw Exception('Registration failed: ${response.body}');
    }
  }

  // ADMIN-ONLY STAFF REGISTRATION
  static Future<User> createStaffUser(Map<String, dynamic> userData) async {
    final token = await getAuthToken();

    // Validate role for staff creation
    if (userData['role'] != 'technician' && userData['role'] != 'admin') {
      throw Exception(
          'Only technician or admin roles can be created by admins');
    }

    logger.d('=== API SERVICE CREATE STAFF USER ===');
    logger.d('Staff user  $userData');

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/staff'), // Admin-only endpoint
      headers: getHeaders(token),
      body: jsonEncode(userData),
    );

    logger.d('=== STAFF USER CREATION RESPONSE ===');
    logger.d('Status: ${response.statusCode}');
    logger.d('Body: ${response.body}');

    if (response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      logger.d('Staff user creation successful, response: $responseData');
      return User.fromJson(responseData['user']);
    } else if (response.statusCode == 403) {
      throw Exception('Permission denied: Admin access required');
    } else {
      logger.e('Staff user creation failed: ${response.body}');
      throw Exception('Failed to create staff user: ${response.body}');
    }
  }

  // User endpoints
  static Future<List<User>> getUsers() async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  static Future<User> getUser(int id) async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users/$id'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 403) {
      throw Exception('Permission denied: Access to user data denied');
    } else if (response.statusCode == 404) {
      throw Exception('User not found');
    } else {
      throw Exception('Failed to load user: ${response.body}');
    }
  }

  static Future<User> createUser(Map<String, dynamic> userData) async {
    final token = await getAuthToken();

    // SECURITY: Force role to 'borrower' for public creation
    final secureUserData = {
      ...userData,
      'role': 'borrower', // Always force borrower role
    };

    logger.d('=== API SERVICE CREATE USER (BORROWER ONLY) ===');
    logger.d('User data (role forced to borrower): $secureUserData');

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'), // Use public registration endpoint
      headers: getHeaders(token),
      body: jsonEncode(secureUserData),
    );

    logger.d('=== USER CREATION RESPONSE ===');
    logger.d('Status: ${response.statusCode}');
    logger.d('Body: ${response.body}');

    if (response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      logger.d('User creation successful, response: $responseData');
      return User.fromJson(responseData['user']);
    } else if (response.statusCode == 403) {
      throw Exception(
          'Permission denied: Only admins can create staff accounts');
    } else {
      logger.e('User creation failed: ${response.body}');
      throw Exception('Failed to create user: ${response.body}');
    }
  }

  static Future<User> updateUser(int id, Map<String, dynamic> userData) async {
    final token = await getAuthToken();
    final response = await http.put(
      Uri.parse('$baseUrl/users/$id'),
      headers: getHeaders(token),
      body: jsonEncode(userData),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 403) {
      throw Exception('Permission denied: Cannot update user data');
    } else if (response.statusCode == 404) {
      throw Exception('User not found');
    } else {
      throw Exception('Failed to update user: ${response.body}');
    }
  }

  static Future<void> deleteUser(int id) async {
    final token = await getAuthToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$id'),
      headers: getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }

  // Chemical endpoints
  static Future<List<Chemical>> getChemicals(
      {Map<String, dynamic>? filters}) async {
    final token = await getAuthToken();
    final queryParams = filters?.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
            .join('&') ??
        '';
    final url =
        '$baseUrl/chemicals${queryParams.isNotEmpty ? '?$queryParams' : ''}';

    final response = await http.get(
      Uri.parse(url),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Chemical.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load chemicals');
    }
  }

  static Future<Chemical> createChemical(
      Map<String, dynamic> chemicalData) async {
    try {
      logger.d('=== API SERVICE CREATE CHEMICAL ===');
      logger.d('Chemical data being sent: $chemicalData');

      // Log specific field types
      chemicalData.forEach((key, value) {
        logger.d('  $key: $value (type: ${value.runtimeType})');
      });

      final token = await getAuthToken();
      logger.d('Auth token: $token');

      final response = await http.post(
        Uri.parse('$baseUrl/chemicals'),
        headers: getHeaders(token),
        body: jsonEncode(chemicalData),
      );

      logger.d('API Response Status: ${response.statusCode}');
      logger.d('API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        logger.d('Chemical creation successful, response: $responseData');
        return Chemical.fromJson(responseData);
      } else {
        logger.e(
            'Chemical creation failed with status ${response.statusCode}: ${response.body}');
        throw Exception('Failed to create chemical: ${response.body}');
      }
    } catch (error) {
      logger.e('=== API SERVICE CREATE CHEMICAL ERROR ===');
      logger.e('Error: $error');
      logger.e('Error type: ${error.runtimeType}');
      rethrow;
    }
  }

  static Future<Chemical> updateChemical(
      int id, Map<String, dynamic> chemicalData) async {
    final token = await getAuthToken();
    final response = await http.put(
      Uri.parse('$baseUrl/chemicals/$id'),
      headers: getHeaders(token),
      body: jsonEncode(chemicalData),
    );

    if (response.statusCode == 200) {
      return Chemical.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update chemical: ${response.body}');
    }
  }

  static Future<void> deleteChemical(int id) async {
    final token = await getAuthToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/chemicals/$id'),
      headers: getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete chemical');
    }
  }

  // Equipment endpoints
  static Future<List<Equipment>> getEquipment() async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/equipment'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Equipment.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load equipment');
    }
  }

  static Future<Equipment> createEquipment(
      Map<String, dynamic> equipmentData) async {
    final token = await getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/equipment'),
      headers: getHeaders(token),
      body: jsonEncode(equipmentData),
    );

    if (response.statusCode == 201) {
      return Equipment.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create equipment: ${response.body}');
    }
  }

  static Future<Equipment> updateEquipment(
      int id, Map<String, dynamic> equipmentData) async {
    final token = await getAuthToken();
    final response = await http.put(
      Uri.parse('$baseUrl/equipment/$id'),
      headers: getHeaders(token),
      body: jsonEncode(equipmentData),
    );

    if (response.statusCode == 200) {
      return Equipment.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update equipment: ${response.body}');
    }
  }

  static Future<void> deleteEquipment(int id) async {
    final token = await getAuthToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/equipment/$id'),
      headers: getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete equipment');
    }
  }

  // Borrowing endpoints
  static Future<List<Borrowing>> getBorrowings({String? status}) async {
    final token = await getAuthToken();
    final queryParams = status != null ? '?status=$status' : '';
    final response = await http.get(
      Uri.parse('$baseUrl/borrowings$queryParams'),
      headers: getHeaders(token),
    );

    logger.d('Borrowings request to: $baseUrl/borrowings$queryParams');
    logger.d('Borrowings response status: ${response.statusCode}');
    logger.d('Borrowings response body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Borrowing.fromJson(json)).toList();
    } else if (response.statusCode == 403) {
      throw Exception(
          'Permission denied: You do not have access to borrowings');
    } else if (response.statusCode == 401) {
      throw Exception('Authentication required: Please log in again');
    } else {
      throw Exception(
          'Failed to load borrowings (Status: ${response.statusCode}): ${response.body}');
    }
  }

  static Future<Borrowing> createBorrowing(
      Map<String, dynamic> borrowingData) async {
    final token = await getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/borrowings'),
      headers: getHeaders(token),
      body: jsonEncode(borrowingData),
    );

    if (response.statusCode == 201) {
      return Borrowing.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create borrowing request: ${response.body}');
    }
  }

  // Enhanced borrowing status update with technician/admin support
  static Future<Borrowing> updateBorrowingStatus(int id, String status,
      {String? notes, String? rejectionReason}) async {
    final token = await getAuthToken();

    // Prepare the request body with all possible fields
    final requestBody = {
      'status': status,
      if (notes != null) 'notes': notes,
      if (rejectionReason != null && status == 'rejected')
        'rejection_reason': rejectionReason,
    };

    logger.d('Updating borrowing status for ID: $id');
    logger.d('Request body: $requestBody');

    final response = await http.put(
      Uri.parse('$baseUrl/borrowings/$id/status'),
      headers: getHeaders(token),
      body: jsonEncode(requestBody),
    );

    logger
        .d('Update status response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      return Borrowing.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update borrowing status: ${response.body}');
    }
  }

  // Get pending requests count for dashboard alerts
  static Future<int> getPendingRequestsCount() async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/borrowings/pending/count'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['count'];
    } else {
      // Return 0 instead of throwing error for graceful degradation
      return 0;
    }
  }

  // Get pending requests for review
  static Future<List<Borrowing>> getPendingRequests() async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/borrowings/pending'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Borrowing.fromJson(json)).toList();
    } else {
      // Return empty list instead of throwing error for graceful degradation
      return [];
    }
  }

  // Lecture Schedule endpoints
  static Future<List<LectureSchedule>> getLectureSchedules(
      {String? status, String? date}) async {
    final token = await getAuthToken();
    final queryParams = [];
    if (status != null) queryParams.add('status=$status');
    if (date != null) queryParams.add('date=$date');
    final queryString =
        queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

    final response = await http.get(
      Uri.parse('$baseUrl/lecture-schedules$queryString'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => LectureSchedule.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load lecture schedules');
    }
  }

  static Future<LectureSchedule> getLectureSchedule(int id) async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/lecture-schedules/$id'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final rawData = jsonDecode(response.body);
      logger.d('Raw lecture schedule  $rawData');

      // Debug the chemical and equipment data types
      logger.d('Chemicals type: ${rawData['required_chemicals'].runtimeType}');
      logger.d('Chemicals value: ${rawData['required_chemicals']}');
      logger.d('Equipment type: ${rawData['required_equipment'].runtimeType}');
      logger.d('Equipment value: ${rawData['required_equipment']}');

      return LectureSchedule.fromJson(rawData);
    } else {
      throw Exception('Failed to load lecture schedule');
    }
  }

  // ✅ FIXED createLectureSchedule method with proper JSON handling
  static Future<LectureSchedule> createLectureSchedule(
      Map<String, dynamic> scheduleData) async {
    final token = await getAuthToken();

    // Handle arrays properly - if already strings, don't re-encode
    final formattedData = {
      ...scheduleData,
      'required_chemicals':
          _formatArrayData(scheduleData['required_chemicals']),
      'required_equipment':
          _formatArrayData(scheduleData['required_equipment']),
    };

    logger.d('=== API SERVICE CREATE LECTURE SCHEDULE ===');
    logger.d('Original schedule  $scheduleData');
    logger.d('Formatted schedule  $formattedData');

    final response = await http.post(
      Uri.parse('$baseUrl/lecture-schedules'),
      headers: getHeaders(token),
      body: jsonEncode(formattedData),
    );

    logger.d('API Response Status: ${response.statusCode}');
    logger.d('API Response Body: ${response.body}');

    if (response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      logger.d('Lecture schedule creation successful, response: $responseData');
      return LectureSchedule.fromJson(responseData);
    } else {
      logger.e(
          'Lecture schedule creation failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Failed to create lecture schedule: ${response.body}');
    }
  }

  // ✅ FIXED updateLectureSchedule method with proper JSON handling
  static Future<LectureSchedule> updateLectureSchedule(
      int id, Map<String, dynamic> updateData) async {
    final token = await getAuthToken();

    // Handle arrays properly - if already strings, don't re-encode
    final formattedData = {
      ...updateData,
      'required_chemicals': _formatArrayData(updateData['required_chemicals']),
      'required_equipment': _formatArrayData(updateData['required_equipment']),
    };

    final response = await http.put(
      Uri.parse('$baseUrl/lecture-schedules/$id'),
      headers: getHeaders(token),
      body: jsonEncode(formattedData),
    );

    if (response.statusCode == 200) {
      return LectureSchedule.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update lecture schedule: ${response.body}');
    }
  }

  // ✅ Helper method to format array data properly
  static String _formatArrayData(dynamic data) {
    if (data == null) {
      return '[]';
    }

    if (data is String) {
      // Already a JSON string, return as-is
      return data;
    }

    if (data is List) {
      // Convert List to JSON string
      return jsonEncode(data);
    }

    // Fallback
    return '[]';
  }

  static Future<void> deleteLectureSchedule(int id) async {
    final token = await getAuthToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/lecture-schedules/$id'),
      headers: getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete lecture schedule');
    }
  }

  // Report endpoints
  static Future<Map<String, dynamic>> getMonthlyReport() async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/reports/monthly'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // Return empty map instead of throwing error for graceful degradation
      return {};
    }
  }

  // Alert endpoints
  static Future<List<dynamic>> getAlerts() async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/alerts'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // Return empty list instead of throwing error for graceful degradation
      return [];
    }
  }

  // Add this method to ApiService class:
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getAuthToken();
    if (token == null) return null;

    try {
      logger.d('=== API SERVICE GET CURRENT USER ===');
      logger.d('Auth token: $token');

      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: getHeaders(token),
      );

      logger.d('API Response Status: ${response.statusCode}');
      logger.d('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        logger.d('Current user data: $userData');
        return userData;
      } else if (response.statusCode == 401) {
        logger.d('Token invalid or expired');
        await clearAuthToken();
        return null;
      } else {
        logger.e('Failed to get current user: ${response.body}');
        return null;
      }
    } catch (error) {
      logger.e('=== API SERVICE GET CURRENT USER ERROR ===');
      logger.e('Error: $error');
      logger.e('Error type: ${error.runtimeType}');
      await clearAuthToken();
      return null;
    }
  }
}

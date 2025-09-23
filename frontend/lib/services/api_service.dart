import 'dart:convert';
import 'package:chemlab_frontend/models/lecture_schedule.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chemlab_frontend/models/user.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/models/borrowing.dart';
import 'package:chemlab_frontend/models/pdf_filter_options.dart';
import 'package:chemlab_frontend/models/equipment_pdf_filter_options.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

var logger = Logger();

class ApiService {
  // ✅ FIXED: Removed extra spaces from baseUrl
  static const String baseUrl = 'http://localhost:5000/api';
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

  // ✅ ADD: Password Change Method
  static Future<void> changePassword(Map<String, dynamic> passwordData) async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: getHeaders(token),
      body: jsonEncode(passwordData),
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 401) {
      throw Exception('Current password is incorrect');
    } else {
      throw Exception('Failed to change password: ${response.body}');
    }
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

  // ✅ ENHANCED SECURE REGISTRATION - With all institutional fields
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    // New institutional fields
    required String phone,
    required String studentId,
    required String institution,
    required String department,
    required String educationLevel,
    required String semester,
    required String role,
  }) async {
    // SECURITY FIX: Only allow borrower registration through public endpoint
    const secureRole = 'borrower'; // Force borrower role

    logger.d('=== API SERVICE ENHANCED REGISTER ATTEMPT ===');
    logger.d('Name: $name');
    logger.d('Email: $email');
    logger.d('Phone: $phone');
    logger.d('Student ID: $studentId');
    logger.d('Institution: $institution');
    logger.d('Department: $department');
    logger.d('Education Level: $educationLevel');
    logger.d('Semester: $semester');
    logger.d('Role (forced): $secureRole');

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: getHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'studentId': studentId,
        'institution': institution,
        'department': department,
        'educationLevel': educationLevel,
        'semester': semester,
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
    logger.d('Staff user data: $userData');

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
      logger.d('Raw lecture schedule data: $rawData');

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
    logger.d('Original schedule data: $scheduleData');
    logger.d('Formatted schedule data: $formattedData');

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

  // Generate and download monthly report PDF
  static Future<void> generateMonthlyReportPDF() async {
    final token = await getAuthToken();

    logger.d('Generating monthly report PDF');

    final response = await http.get(
      Uri.parse('$baseUrl/reports/pdf'),
      headers: getHeaders(token),
    );

    logger.d('Monthly report PDF response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      logger.d('Monthly report PDF bytes received: ${bytes.length} bytes');

      if (bytes.isEmpty) {
        throw Exception('Received empty PDF file');
      }

      // Save and open the PDF
      await _savePdfFileDesktop(bytes);
    } else {
      logger.e('Monthly report PDF generation failed: ${response.body}');
      throw Exception(
          'Failed to generate monthly report PDF: ${response.body}');
    }
  }

  // Generate and download monthly report CSV
  static Future<void> generateMonthlyReportCSV() async {
    final token = await getAuthToken();

    logger.d('Generating monthly report CSV');

    final response = await http.get(
      Uri.parse('$baseUrl/reports/csv'),
      headers: getHeaders(token),
    );

    logger.d('Monthly report CSV response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final csvContent = response.body;
      logger.d(
          'Monthly report CSV content received: ${csvContent.length} characters');

      if (csvContent.isEmpty) {
        throw Exception('Received empty CSV file');
      }

      // Save the CSV file
      await _saveCsvFileDesktop(csvContent);
    } else {
      logger.e('Monthly report CSV generation failed: ${response.body}');
      throw Exception(
          'Failed to generate monthly report CSV: ${response.body}');
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

  static Future<Borrowing> markBorrowingAsReturned(
      int borrowingId, Map<String, dynamic> returnData) async {
    final token = await getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/borrowings/$borrowingId/return'),
      headers: getHeaders(token),
      body: jsonEncode(returnData),
    );

    if (response.statusCode == 200) {
      return Borrowing.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to mark borrowing as returned: ${response.body}');
    }
  }

  // Add this method to get active borrowings
  static Future<List<Borrowing>> getActiveBorrowings() async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/borrowings/active'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Borrowing.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load active borrowings');
    }
  }

  // Delete borrowing request - Admin/Technician only
  static Future<Map<String, dynamic>> deleteBorrowing(int borrowingId) async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    logger.d('=== API SERVICE DELETE BORROWING ===');
    logger.d('Borrowing ID: $borrowingId');

    final response = await http.delete(
      Uri.parse('$baseUrl/borrowings/$borrowingId'),
      headers: getHeaders(token),
    );

    logger.d('Delete borrowing response status: ${response.statusCode}');
    logger.d('Delete borrowing response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      logger.d('Borrowing deleted successfully: ${data['message']}');
      return data;
    } else if (response.statusCode == 403) {
      throw Exception(
          'Permission denied: You do not have permission to delete this request');
    } else if (response.statusCode == 404) {
      throw Exception('Borrowing not found or cannot be deleted');
    } else {
      logger.e('Failed to delete borrowing: ${response.body}');
      throw Exception('Failed to delete borrowing: ${response.body}');
    }
  }

  // ✅ CHATBOT METHODS - Fixed and properly integrated

  static Future<List<dynamic>> getChatQuickActions(String userRole) async {
    final token = await getAuthToken();

    final response = await http.get(
      Uri.parse('$baseUrl/chat/quick-actions/$userRole'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['actions'];
    } else {
      throw Exception('Failed to load quick actions');
    }
  }

  // ✅ CHATBOT SEND MESSAGE METHOD - For chatbot functionality
  static Future<Map<String, dynamic>> sendChatbotMessage(
      String message, int userId, String userRole) async {
    final token = await getAuthToken();

    final response = await http.post(
      Uri.parse('$baseUrl/chat/message'),
      headers: getHeaders(token),
      body: jsonEncode({
        'message': message,
        'userId': userId,
        'userRole': userRole,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send chat message');
    }
  }

  // ✅ LIVE CHAT METHODS - For admin-to-user communication
  static Future<Map<String, dynamic>> startLiveChat(int userId,
      {String? title}) async {
    final token = await getAuthToken();

    final response = await http.post(
      Uri.parse('$baseUrl/chat/live-chat/start'),
      headers: getHeaders(token),
      body: jsonEncode({
        'userId': userId,
        'title': title ?? 'Live Support',
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to start live chat: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> sendLiveChatMessage(
      int conversationId, String message) async {
    final token = await getAuthToken();

    final response = await http.post(
      Uri.parse('$baseUrl/chat/live-chat/message'),
      headers: getHeaders(token),
      body: jsonEncode({
        'conversationId': conversationId,
        'message': message,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send live chat message: ${response.body}');
    }
  }

  static Future<List<dynamic>> getLiveChatConversations() async {
    final token = await getAuthToken();

    final response = await http.get(
      Uri.parse('$baseUrl/chat/live-chat/conversations'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['conversations'];
    } else {
      throw Exception(
          'Failed to load live chat conversations: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getLiveChatMessages(
      int conversationId) async {
    final token = await getAuthToken();

    final response = await http.get(
      Uri.parse('$baseUrl/chat/live-chat/messages/$conversationId'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load live chat messages: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> closeLiveChatConversation(
      int conversationId) async {
    final token = await getAuthToken();

    final response = await http.put(
      Uri.parse('$baseUrl/chat/live-chat/conversations/$conversationId/close'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          'Failed to close live chat conversation: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> deleteLiveChatConversation(
      int conversationId) async {
    final token = await getAuthToken();

    final response = await http.delete(
      Uri.parse('$baseUrl/chat/live-chat/conversations/$conversationId'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          'Failed to delete live chat conversation: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> deleteLiveChatMessage(
      int messageId) async {
    final token = await getAuthToken();

    final response = await http.delete(
      Uri.parse('$baseUrl/chat/live-chat/messages/$messageId'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete live chat message: ${response.body}');
    }
  }

  // New: Get chat conversations for authenticated user
  static Future<List<dynamic>> getChatConversations() async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    logger.d('=== API SERVICE GET CHAT CONVERSATIONS ===');

    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: getHeaders(token),
    );

    logger.d('Get conversations response status: ${response.statusCode}');
    logger.d('Get conversations response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      logger.d('Chat conversations loaded: ${data.length} conversations');
      return data;
    } else {
      logger.e('Failed to get chat conversations: ${response.body}');
      throw Exception('Failed to load chat conversations: ${response.body}');
    }
  }

  // New: Get messages for a specific conversation
  static Future<List<dynamic>> getChatMessages(int conversationId) async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    logger.d('=== API SERVICE GET CHAT MESSAGES ===');
    logger.d('Conversation ID: $conversationId');

    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
      headers: getHeaders(token),
    );

    logger.d('Get messages response status: ${response.statusCode}');
    logger.d('Get messages response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      logger.d('Chat messages loaded: ${data.length} messages');
      return data;
    } else {
      logger.e('Failed to get chat messages: ${response.body}');
      throw Exception('Failed to load chat messages: ${response.body}');
    }
  }

  // New: Send message in a chat conversation (1:1 chat, not chatbot)
  static Future<Map<String, dynamic>> sendChatMessage(
      int conversationId, String message) async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    logger.d('=== API SERVICE SEND CHAT MESSAGE ===');
    logger.d('Conversation ID: $conversationId');
    logger.d('Message: $message');

    final response = await http.post(
      Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
      headers: getHeaders(token),
      body: jsonEncode({
        'message': message,
        'messageType': 'text',
      }),
    );

    logger.d('Send message response status: ${response.statusCode}');
    logger.d('Send message response body: ${response.body}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      logger.d('Chat message sent successfully: ${data['id']}');
      return data;
    } else {
      logger.e('Failed to send chat message: ${response.body}');
      throw Exception('Failed to send chat message: ${response.body}');
    }
  }

  // New: Create chat conversation between technician and borrower
  static Future<Map<String, dynamic>> createChatConversation(
      int targetUserId) async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    logger.d('=== API SERVICE CREATE CHAT CONVERSATION ===');
    logger.d('Target user ID: $targetUserId');

    final response = await http.post(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: getHeaders(token),
      body: jsonEncode({
        'targetUserId': targetUserId,
      }),
    );

    logger.d('Create conversation response status: ${response.statusCode}');
    logger.d('Create conversation response body: ${response.body}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      logger.d(
          'Chat conversation created successfully: ${data['conversation']['id']}');
      return data;
    } else {
      logger.e('Failed to create chat conversation: ${response.body}');
      throw Exception('Failed to create chat conversation: ${response.body}');
    }
  }

  // Replace the existing method in ApiService
  static Future<void> generateChemicalsPDF(PdfFilterOptions options) async {
    final token = await getAuthToken();

    logger.d('Generating PDF with options: ${options.toJson()}');

    final response = await http.post(
      Uri.parse('$baseUrl/chemicals/generate-pdf'),
      headers: getHeaders(token),
      body: jsonEncode(options.toJson()),
    );

    logger.d('PDF Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      logger.d('PDF bytes received: ${bytes.length} bytes');

      if (bytes.isEmpty) {
        throw Exception('Received empty PDF file');
      }

      // Save PDF to Downloads folder
      await _savePdfToDownloads(bytes);
    } else {
      logger.e('PDF generation failed: ${response.body}');
      throw Exception('Failed to generate PDF: ${response.body}');
    }
  }

  static Future<void> _savePdfToDownloads(Uint8List bytes) async {
    try {
      // Get Downloads directory path
      String downloadsPath;

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        downloadsPath = '$userProfile\\Downloads';
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        downloadsPath = '$home/Downloads';
      } else {
        // Fallback to documents directory
        final directory = await getApplicationDocumentsDirectory();
        downloadsPath = directory.path;
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'chemical-inventory-$timestamp.pdf';
      final filePath = '$downloadsPath${Platform.pathSeparator}$fileName';

      // Write PDF to file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      logger.d('PDF saved to: $filePath');

      // Try to open the PDF
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (error) {
      logger.e('Error saving PDF: $error');
      rethrow;
    }
  }

  // Add this method to ApiService class:
  static Future<void> generateEquipmentPDF(
      EquipmentPdfFilterOptions options) async {
    final token = await getAuthToken();

    logger.d('Generating Equipment PDF with options: ${options.toJson()}');

    final response = await http.post(
      Uri.parse('$baseUrl/equipment/generate-pdf'),
      headers: getHeaders(token),
      body: jsonEncode(options.toJson()),
    );

    logger.d('Equipment PDF Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      logger.d('Equipment PDF bytes received: ${bytes.length} bytes');

      if (bytes.isEmpty) {
        throw Exception('Received empty PDF file');
      }

      // Save and open the PDF (reuse the same method as chemicals)
      await _savePdfFileDesktop(bytes);
    } else {
      logger.e('Equipment PDF generation failed: ${response.body}');
      throw Exception('Failed to generate Equipment PDF: ${response.body}');
    }
  }

  static Future<void> _savePdfFileDesktop(Uint8List bytes) async {
    try {
      // Get Downloads directory path
      String downloadsPath;

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        downloadsPath = '$userProfile\\Downloads';
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        downloadsPath = '$home/Downloads';
      } else {
        // Fallback to documents directory
        final directory = await getApplicationDocumentsDirectory();
        downloadsPath = directory.path;
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'equipment-inventory-$timestamp.pdf';
      final filePath = '$downloadsPath${Platform.pathSeparator}$fileName';

      // Write PDF to file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      logger.d('Equipment PDF saved to: $filePath');

      // Try to open the PDF
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (error) {
      logger.e('Error saving Equipment PDF: $error');
      rethrow;
    }
  }

  // Alert Action Methods
  static Future<void> orderSupplies(
      int chemicalId, int quantity, String notes) async {
    final token = await getAuthToken();

    logger.d(
        'Ordering supplies for chemical $chemicalId, quantity: $quantity, notes: $notes');

    final response = await http.post(
      Uri.parse('$baseUrl/alerts/chemical/$chemicalId/order-supplies'),
      headers: getHeaders(token),
      body: jsonEncode({
        'quantity': quantity,
        'notes': notes,
      }),
    );

    logger.d('Order supplies response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      logger.d('Supplies ordered successfully');
    } else {
      logger.e('Failed to order supplies: ${response.body}');
      throw Exception('Failed to order supplies: ${response.body}');
    }
  }

  static Future<void> sendBorrowingReminder(
      int borrowingId, String message) async {
    final token = await getAuthToken();

    logger.d('Sending reminder for borrowing $borrowingId, message: $message');

    final response = await http.post(
      Uri.parse('$baseUrl/alerts/borrowing/$borrowingId/send-reminder'),
      headers: getHeaders(token),
      body: jsonEncode({
        'message': message,
      }),
    );

    logger.d('Send reminder response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      logger.d('Reminder sent successfully');
    } else {
      logger.e('Failed to send reminder: ${response.body}');
      throw Exception('Failed to send reminder: ${response.body}');
    }
  }

  static Future<void> scheduleEquipmentMaintenance(
      int equipmentId, String scheduledDate, String notes) async {
    final token = await getAuthToken();

    logger.d(
        'Scheduling maintenance for equipment $equipmentId, date: $scheduledDate, notes: $notes');

    final response = await http.post(
      Uri.parse('$baseUrl/alerts/equipment/$equipmentId/schedule-maintenance'),
      headers: getHeaders(token),
      body: jsonEncode({
        'scheduledDate': scheduledDate,
        'notes': notes,
      }),
    );

    logger.d('Schedule maintenance response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      logger.d('Maintenance scheduled successfully');
    } else {
      logger.e('Failed to schedule maintenance: ${response.body}');
      throw Exception('Failed to schedule maintenance: ${response.body}');
    }
  }

  static Future<void> markAlertResolved(int alertId, String alertType) async {
    final token = await getAuthToken();

    logger.d('Marking alert $alertId of type $alertType as resolved');

    final response = await http.put(
      Uri.parse('$baseUrl/alerts/$alertId/resolve'),
      headers: getHeaders(token),
      body: jsonEncode({
        'alertType': alertType,
      }),
    );

    logger.d('Mark alert resolved response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      logger.d('Alert marked as resolved successfully');
    } else {
      logger.e('Failed to mark alert as resolved: ${response.body}');
      throw Exception('Failed to mark alert as resolved: ${response.body}');
    }
  }

  static Future<void> _saveCsvFileDesktop(String csvContent) async {
    try {
      // Get Downloads directory path
      String downloadsPath;

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        downloadsPath = '$userProfile\\Downloads';
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        downloadsPath = '$home/Downloads';
      } else {
        // Fallback to documents directory
        final directory = await getApplicationDocumentsDirectory();
        downloadsPath = directory.path;
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'monthly-report-$timestamp.csv';
      final filePath = '$downloadsPath${Platform.pathSeparator}$fileName';

      // Write CSV to file
      final file = File(filePath);
      await file.writeAsString(csvContent);

      logger.d('CSV saved to: $filePath');

      // Try to open the CSV file
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (error) {
      logger.e('Error saving CSV: $error');
      rethrow;
    }
  }
}

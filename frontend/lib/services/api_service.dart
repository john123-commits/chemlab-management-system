import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chemlab_frontend/models/user.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/models/borrowing.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class ApiService {
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

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: getHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Registration failed: ${response.body}');
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

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Borrowing.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load borrowings');
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

  static Future<Borrowing> updateBorrowingStatus(int id, String status,
      {String? notes}) async {
    final token = await getAuthToken();
    final response = await http.put(
      Uri.parse('$baseUrl/borrowings/$id/status'),
      headers: getHeaders(token),
      body: jsonEncode({
        'status': status,
        'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      return Borrowing.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update borrowing status: ${response.body}');
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
      throw Exception('Failed to load monthly report');
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
      throw Exception('Failed to load alerts');
    }
  }
}

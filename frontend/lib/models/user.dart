import 'package:chemlab_frontend/services/api_service.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;
  // New institutional fields
  final String? phone;
  final String? studentId;
  final String? institution;
  final String? department;
  final String? educationLevel;
  final String? semester;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.phone,
    this.studentId,
    this.institution,
    this.department,
    this.educationLevel,
    this.semester,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    logger.d('User.fromJson received: $json'); // Debug line

    return User(
      id: json['id'] is int ? json['id'] : 0,
      name: json['name'] is String ? json['name'] : 'Unknown User',
      email: json['email'] is String ? json['email'] : 'unknown@example.com',
      role: json['role'] is String ? json['role'] : 'borrower',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      // New institutional fields
      phone: json['phone'] is String ? json['phone'] : null,
      studentId: json['student_id'] is String ? json['student_id'] : null,
      institution: json['institution'] is String ? json['institution'] : null,
      department: json['department'] is String ? json['department'] : null,
      educationLevel:
          json['education_level'] is String ? json['education_level'] : null,
      semester: json['semester'] is String ? json['semester'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'phone': phone,
      'student_id': studentId,
      'institution': institution,
      'department': department,
      'education_level': educationLevel,
      'semester': semester,
    };
  }
}

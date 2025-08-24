import 'dart:convert';
import 'package:intl/intl.dart';

class LectureSchedule {
  final int id;
  final int? adminId;
  final int? technicianId;
  final String title;
  final String description;
  final List<dynamic> requiredChemicals;
  final List<dynamic> requiredEquipment;
  final DateTime scheduledDate;
  final String scheduledTime;
  final int? duration;
  final String priority;
  final String status;
  final String? technicianNotes;
  final String? rejectionReason;
  final DateTime? confirmationDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? adminName;
  final String? technicianName;
  final String? adminEmail;
  final String? technicianEmail;

  // Add student information fields
  final String? university;
  final String? educationLevel;
  final String? registrationNumber;
  final String? studentNumber;
  final int? currentYear;
  final String? semester;
  final String? borrowerEmailContact;
  final String? borrowerContact;

  LectureSchedule({
    required this.id,
    this.adminId,
    this.technicianId,
    required this.title,
    required this.description,
    required this.requiredChemicals,
    required this.requiredEquipment,
    required this.scheduledDate,
    required this.scheduledTime,
    this.duration,
    required this.priority,
    required this.status,
    this.technicianNotes,
    this.rejectionReason,
    this.confirmationDate,
    required this.createdAt,
    required this.updatedAt,
    this.adminName,
    this.technicianName,
    this.adminEmail,
    this.technicianEmail,
    // Add student information fields
    this.university,
    this.educationLevel,
    this.registrationNumber,
    this.studentNumber,
    this.currentYear,
    this.semester,
    this.borrowerEmailContact,
    this.borrowerContact,
  });

  factory LectureSchedule.fromJson(Map<String, dynamic> json) {
    // Safely parse required chemicals with maximum compatibility
    List<dynamic> chemicals = [];
    var rawChemicals = json['required_chemicals'];

    if (rawChemicals != null) {
      try {
        if (rawChemicals is String) {
          String cleanStr = rawChemicals.trim();
          if (cleanStr.isNotEmpty && cleanStr != '[]' && cleanStr != 'null') {
            // Handle various JSON string formats
            if (cleanStr.startsWith('"') &&
                cleanStr.endsWith('"') &&
                cleanStr.length > 1) {
              cleanStr = cleanStr.substring(1, cleanStr.length - 1);
              cleanStr = cleanStr.replaceAll('\\"', '"');
            }

            dynamic parsed = jsonDecode(cleanStr);
            // Handle double-encoded JSON
            if (parsed is String) {
              parsed = jsonDecode(parsed);
            }
            if (parsed is List) {
              chemicals = parsed;
            }
          }
        } else if (rawChemicals is List) {
          chemicals = List<dynamic>.from(rawChemicals);
        }
      } catch (e) {
        print('Chemicals parsing error: $e');
        chemicals = [];
      }
    }

    // Safely parse required equipment with maximum compatibility
    List<dynamic> equipment = [];
    var rawEquipment = json['required_equipment'];

    if (rawEquipment != null) {
      try {
        if (rawEquipment is String) {
          String cleanStr = rawEquipment.trim();
          if (cleanStr.isNotEmpty && cleanStr != '[]' && cleanStr != 'null') {
            // Handle various JSON string formats
            if (cleanStr.startsWith('"') &&
                cleanStr.endsWith('"') &&
                cleanStr.length > 1) {
              cleanStr = cleanStr.substring(1, cleanStr.length - 1);
              cleanStr = cleanStr.replaceAll('\\"', '"');
            }

            dynamic parsed = jsonDecode(cleanStr);
            // Handle double-encoded JSON
            if (parsed is String) {
              parsed = jsonDecode(parsed);
            }
            if (parsed is List) {
              equipment = parsed;
            }
          }
        } else if (rawEquipment is List) {
          equipment = List<dynamic>.from(rawEquipment);
        }
      } catch (e) {
        print('Equipment parsing error: $e');
        equipment = [];
      }
    }

    return LectureSchedule(
      id: json['id'] is int ? json['id'] : 0,
      adminId: json['admin_id'] is int ? json['admin_id'] : null,
      technicianId: json['technician_id'] is int ? json['technician_id'] : null,
      title: json['title'] is String ? json['title'] : '',
      description: json['description'] is String ? json['description'] : '',
      requiredChemicals: chemicals,
      requiredEquipment: equipment,
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'] is String
              ? json['scheduled_date']
              : json['scheduled_date'].toString())
          : DateTime.now(),
      scheduledTime:
          json['scheduled_time'] is String ? json['scheduled_time'] : '00:00',
      duration: json['duration'] is int
          ? json['duration']
          : (json['duration'] is String
              ? int.tryParse(json['duration'])
              : null),
      priority: json['priority'] is String ? json['priority'] : 'normal',
      status: json['status'] is String ? json['status'] : 'pending',
      technicianNotes:
          json['technician_notes'] is String ? json['technician_notes'] : null,
      rejectionReason:
          json['rejection_reason'] is String ? json['rejection_reason'] : null,
      confirmationDate: json['confirmation_date'] != null
          ? DateTime.parse(json['confirmation_date'] is String
              ? json['confirmation_date']
              : json['confirmation_date'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] is String
              ? json['created_at']
              : json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] is String
              ? json['updated_at']
              : json['updated_at'].toString())
          : DateTime.now(),
      adminName: json['admin_name'] is String ? json['admin_name'] : null,
      technicianName:
          json['technician_name'] is String ? json['technician_name'] : null,
      adminEmail: json['admin_email'] is String ? json['admin_email'] : null,
      technicianEmail:
          json['technician_email'] is String ? json['technician_email'] : null,
      // Add student information fields
      university: json['university'] is String ? json['university'] : null,
      educationLevel:
          json['education_level'] is String ? json['education_level'] : null,
      registrationNumber: json['registration_number'] is String
          ? json['registration_number']
          : null,
      studentNumber:
          json['student_number'] is String ? json['student_number'] : null,
      currentYear: json['current_year'] is int
          ? json['current_year']
          : (json['current_year'] is String
              ? int.tryParse(json['current_year'])
              : null),
      semester: json['semester'] is String ? json['semester'] : null,
      borrowerEmailContact:
          json['borrower_email'] is String ? json['borrower_email'] : null,
      borrowerContact:
          json['borrower_contact'] is String ? json['borrower_contact'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    // ✅ FIX: Check the actual type before calling methods
    String chemicalsData;
    if (requiredChemicals is String) {
      chemicalsData = requiredChemicals as String;
    } else {
      chemicalsData =
          requiredChemicals.isEmpty ? '[]' : jsonEncode(requiredChemicals);
    }

    String equipmentData;
    if (requiredEquipment is String) {
      equipmentData = requiredEquipment as String;
    } else {
      equipmentData =
          requiredEquipment.isEmpty ? '[]' : jsonEncode(requiredEquipment);
    }

    return {
      'id': id,
      'admin_id': adminId,
      'technician_id': technicianId,
      'title': title,
      'description': description,
      'required_chemicals': chemicalsData,
      'required_equipment': equipmentData,
      'scheduled_date': DateFormat('yyyy-MM-dd').format(scheduledDate),
      'scheduled_time': scheduledTime,
      'duration': duration,
      'priority': priority,
      'status': status,
      'technician_notes': technicianNotes,
      'rejection_reason': rejectionReason,
      'confirmation_date': confirmationDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'admin_name': adminName,
      'technician_name': technicianName,
      'admin_email': adminEmail,
      'technician_email': technicianEmail,
      // Add student information fields
      'university': university,
      'education_level': educationLevel,
      'registration_number': registrationNumber,
      'student_number': studentNumber,
      'current_year': currentYear,
      'semester': semester,
      'borrower_email': borrowerEmailContact,
      'borrower_contact': borrowerContact,
    };
  }
}

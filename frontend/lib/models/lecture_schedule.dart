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
  final DateTime? confirmationDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? adminName;
  final String? technicianName;
  final String? adminEmail;
  final String? technicianEmail;

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
    this.confirmationDate,
    required this.createdAt,
    required this.updatedAt,
    this.adminName,
    this.technicianName,
    this.adminEmail,
    this.technicianEmail,
  });

  factory LectureSchedule.fromJson(Map<String, dynamic> json) {
    // Safely parse required chemicals
    List<dynamic> chemicals = [];
    if (json['required_chemicals'] != null) {
      try {
        if (json['required_chemicals'] is String) {
          chemicals = jsonDecode(json['required_chemicals']);
        } else if (json['required_chemicals'] is List) {
          chemicals = json['required_chemicals'];
        }
      } catch (e) {
        chemicals = [];
      }
    }

    // Safely parse required equipment
    List<dynamic> equipment = [];
    if (json['required_equipment'] != null) {
      try {
        if (json['required_equipment'] is String) {
          equipment = jsonDecode(json['required_equipment']);
        } else if (json['required_equipment'] is List) {
          equipment = json['required_equipment'];
        }
      } catch (e) {
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_id': adminId,
      'technician_id': technicianId,
      'title': title,
      'description': description,
      // ✅ FIX: Properly encode arrays as JSON strings
      'required_chemicals': jsonEncode(requiredChemicals),
      'required_equipment': jsonEncode(requiredEquipment),
      'scheduled_date': DateFormat('yyyy-MM-dd').format(scheduledDate),
      'scheduled_time': scheduledTime,
      'duration': duration,
      'priority': priority,
      'status': status,
      'technician_notes': technicianNotes,
      'confirmation_date': confirmationDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'admin_name': adminName,
      'technician_name': technicianName,
      'admin_email': adminEmail,
      'technician_email': technicianEmail,
    };
  }
}

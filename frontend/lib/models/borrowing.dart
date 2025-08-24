import 'dart:convert';
import 'package:logger/logger.dart';

final logger = Logger();

class Borrowing {
  final int id;
  final int borrowerId;
  final String borrowerName;
  final String borrowerEmail;
  final int? technicianId;
  final String? technicianName;
  final DateTime? technicianApprovedAt;
  final int? adminId;
  final String? adminName;
  final DateTime? adminApprovedAt;
  final List<dynamic> chemicals;
  final List<dynamic> equipment;
  final String purpose;
  final String researchDetails;
  final DateTime borrowDate;
  final DateTime returnDate;
  final DateTime visitDate;
  final String visitTime;
  final String status;
  final String? notes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ✅ NEW: Return confirmation fields
  final bool returned;
  final DateTime? actualReturnDate;
  final Map<String, dynamic>? equipmentCondition;
  final String? returnNotes;
  final int? returnConfirmedBy;

  // Add student information fields
  final String? university;
  final String? educationLevel;
  final String? registrationNumber;
  final String? studentNumber;
  final int? currentYear;
  final String? semester;
  final String? borrowerEmailContact;
  final String? borrowerContact;

  Borrowing({
    required this.id,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowerEmail,
    this.technicianId,
    this.technicianName,
    this.technicianApprovedAt,
    this.adminId,
    this.adminName,
    this.adminApprovedAt,
    required this.chemicals,
    required this.equipment,
    required this.purpose,
    required this.researchDetails,
    required this.borrowDate,
    required this.returnDate,
    required this.visitDate,
    required this.visitTime,
    required this.status,
    this.notes,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    // ✅ NEW: Return confirmation fields
    this.returned = false,
    this.actualReturnDate,
    this.equipmentCondition,
    this.returnNotes,
    this.returnConfirmedBy,
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

  factory Borrowing.fromJson(Map<String, dynamic> json) {
    // ✅ Handle equipment condition parsing
    Map<String, dynamic>? equipmentCondition;
    if (json['equipment_condition'] != null) {
      try {
        if (json['equipment_condition'] is String) {
          equipmentCondition = jsonDecode(json['equipment_condition']);
        } else if (json['equipment_condition'] is Map) {
          equipmentCondition = json['equipment_condition'];
        }
      } catch (e) {
        logger.d('Error parsing equipment condition: $e');
      }
    }

    return Borrowing(
      id: json['id'],
      borrowerId: json['borrower_id'],
      borrowerName: json['borrower_name'] ?? '',
      borrowerEmail: json['borrower_email'] ?? '',
      technicianId: json['technician_id'],
      technicianName: json['technician_name'],
      technicianApprovedAt: json['technician_approved_at'] != null
          ? DateTime.parse(json['technician_approved_at'])
          : null,
      adminId: json['admin_id'],
      adminName: json['admin_name'],
      adminApprovedAt: json['admin_approved_at'] != null
          ? DateTime.parse(json['admin_approved_at'])
          : null,
      chemicals: json['chemicals'] ?? [],
      equipment: json['equipment'] ?? [],
      purpose: json['purpose'],
      researchDetails: json['research_details'],
      borrowDate: DateTime.parse(json['borrow_date']),
      returnDate: DateTime.parse(json['return_date']),
      visitDate: DateTime.parse(json['visit_date']),
      visitTime: json['visit_time'],
      status: json['status'],
      notes: json['notes'],
      rejectionReason: json['rejection_reason'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['created_at']),
      // ✅ NEW: Return confirmation fields
      returned: json['returned'] ?? false,
      actualReturnDate: json['actual_return_date'] != null
          ? DateTime.parse(json['actual_return_date'])
          : null,
      equipmentCondition: equipmentCondition,
      returnNotes: json['return_notes'],
      returnConfirmedBy: json['return_confirmed_by'],
      // Add student information fields
      university: json['university'],
      educationLevel: json['education_level'],
      registrationNumber: json['registration_number'],
      studentNumber: json['student_number'],
      currentYear: json['current_year'],
      semester: json['semester'],
      borrowerEmailContact: json['borrower_email'],
      borrowerContact: json['borrower_contact'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'borrower_id': borrowerId,
      'borrower_name': borrowerName,
      'borrower_email': borrowerEmail,
      'technician_id': technicianId,
      'technician_name': technicianName,
      'technician_approved_at': technicianApprovedAt?.toIso8601String(),
      'admin_id': adminId,
      'admin_name': adminName,
      'admin_approved_at': adminApprovedAt?.toIso8601String(),
      'chemicals': chemicals,
      'equipment': equipment,
      'purpose': purpose,
      'research_details': researchDetails,
      'borrow_date': borrowDate.toIso8601String(),
      'return_date': returnDate.toIso8601String(),
      'visit_date': visitDate.toIso8601String(),
      'visit_time': visitTime,
      'status': status,
      'notes': notes,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // ✅ NEW: Return confirmation fields
      'returned': returned,
      'actual_return_date': actualReturnDate?.toIso8601String(),
      'equipment_condition':
          equipmentCondition != null ? jsonEncode(equipmentCondition) : null,
      'return_notes': returnNotes,
      'return_confirmed_by': returnConfirmedBy,
      // Add student information fields
      'university': university,
      'education_level': educationLevel,
      'registration_number': registrationNumber,
      'student_number': studentNumber,
      'current_year': currentYear,
      'semester': semester,
      // ignore: equal_keys_in_map
      'borrower_email': borrowerEmailContact,
      'borrower_contact': borrowerContact,
    };
  }
}

class LectureSchedule {
  final int id;
  final int adminId;
  final int technicianId;
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
  final String adminName;
  final String technicianName;

  LectureSchedule({
    required this.id,
    required this.adminId,
    required this.technicianId,
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
    required this.adminName,
    required this.technicianName,
  });

  factory LectureSchedule.fromJson(Map<String, dynamic> json) {
    return LectureSchedule(
      id: json['id'] as int? ?? 0,
      adminId: json['admin_id'] as int? ?? 0,
      technicianId: json['technician_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requiredChemicals: json['required_chemicals'] ?? [],
      requiredEquipment: json['required_equipment'] ?? [],
      scheduledDate: DateTime.parse(json['scheduled_date']),
      scheduledTime: json['scheduled_time'] as String? ?? '00:00',
      duration: json['duration'] as int?,
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'pending',
      technicianNotes: json['technician_notes'] as String?,
      confirmationDate: json['confirmation_date'] != null
          ? DateTime.parse(json['confirmation_date'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      adminName: json['admin_name'] as String? ?? 'Unknown',
      technicianName: json['technician_name'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_id': adminId,
      'technician_id': technicianId,
      'title': title,
      'description': description,
      'required_chemicals': requiredChemicals,
      'required_equipment': requiredEquipment,
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
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
    };
  }
}

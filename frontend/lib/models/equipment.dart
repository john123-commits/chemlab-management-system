class Equipment {
  final int id;
  final String name;
  final String category;
  final String condition;
  final DateTime lastMaintenanceDate;
  final String location;
  final int maintenanceSchedule;
  final DateTime createdAt;

  Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.condition,
    required this.lastMaintenanceDate,
    required this.location,
    required this.maintenanceSchedule,
    required this.createdAt,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      condition: json['condition'],
      lastMaintenanceDate: DateTime.parse(json['last_maintenance_date']),
      location: json['location'],
      maintenanceSchedule: json['maintenance_schedule'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'condition': condition,
      'last_maintenance_date': lastMaintenanceDate.toIso8601String(),
      'location': location,
      'maintenance_schedule': maintenanceSchedule,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

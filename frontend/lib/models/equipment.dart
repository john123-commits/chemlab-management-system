class Equipment {
  final int id;
  final String name;
  final String category;
  final String condition;
  final DateTime lastMaintenanceDate;
  final String location;
  final int maintenanceSchedule;
  final DateTime createdAt;
  // Enhanced fields
  final String? serialNumber;
  final String? manufacturer;
  final String? model;
  final DateTime? purchaseDate;
  final DateTime? warrantyExpiry;
  final DateTime? calibrationDate;
  final DateTime? nextCalibrationDate;

  Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.condition,
    required this.lastMaintenanceDate,
    required this.location,
    required this.maintenanceSchedule,
    required this.createdAt,
    this.serialNumber,
    this.manufacturer,
    this.model,
    this.purchaseDate,
    this.warrantyExpiry,
    this.calibrationDate,
    this.nextCalibrationDate,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] is int ? json['id'] : 0,
      name: json['name'] is String ? json['name'] : 'Unknown',
      category: json['category'] is String ? json['category'] : 'Unknown',
      condition: json['condition'] is String ? json['condition'] : 'Unknown',
      lastMaintenanceDate: json['last_maintenance_date'] != null
          ? DateTime.parse(json['last_maintenance_date'] as String)
          : DateTime.now(),
      location: json['location'] is String ? json['location'] : 'Unknown',
      maintenanceSchedule: json['maintenance_schedule'] is int
          ? json['maintenance_schedule']
          : 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      // Enhanced fields
      serialNumber: json['serial_number'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      purchaseDate: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'] as String)
          : null,
      warrantyExpiry: json['warranty_expiry'] != null
          ? DateTime.parse(json['warranty_expiry'] as String)
          : null,
      calibrationDate: json['calibration_date'] != null
          ? DateTime.parse(json['calibration_date'] as String)
          : null,
      nextCalibrationDate: json['next_calibration_date'] != null
          ? DateTime.parse(json['next_calibration_date'] as String)
          : null,
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
      // Enhanced fields
      'serial_number': serialNumber,
      'manufacturer': manufacturer,
      'model': model,
      'purchase_date': purchaseDate?.toIso8601String(),
      'warranty_expiry': warrantyExpiry?.toIso8601String(),
      'calibration_date': calibrationDate?.toIso8601String(),
      'next_calibration_date': nextCalibrationDate?.toIso8601String(),
    };
  }
}

import 'package:logger/logger.dart';

var logger = Logger();

class Chemical {
  final int id;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final String storageLocation;
  final DateTime expiryDate;
  final String? safetyDataSheet;
  final DateTime createdAt;

  Chemical({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    required this.expiryDate,
    this.safetyDataSheet,
    required this.createdAt,
  });

  factory Chemical.fromJson(Map<String, dynamic> json) {
    logger.d('Chemical.fromJson called with: $json');

    // Handle quantity properly - it comes as string from backend
    double parseQuantity(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Chemical(
      id: json['id'] is int ? json['id'] : 0,
      name: json['name'] is String ? json['name'] : 'Unknown',
      category: json['category'] is String ? json['category'] : 'Unknown',
      quantity: parseQuantity(json['quantity']),
      unit: json['unit'] is String ? json['unit'] : 'Unknown',
      storageLocation: json['storage_location'] is String
          ? json['storage_location']
          : 'Unknown',
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : DateTime.now(),
      safetyDataSheet: json['safety_data_sheet'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'storage_location': storageLocation,
      'expiry_date': expiryDate.toIso8601String(),
      'safety_data_sheet': safetyDataSheet,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

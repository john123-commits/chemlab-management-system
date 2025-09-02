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
  // Enhanced fields
  final String? cNumber;
  final String? molecularFormula;
  final double? molecularWeight;
  final String? phicalState;
  final String? color;
  final double? density;
  final String? meltingPoint;
  final String? boilingPoint;
  final String? solubility;
  final String? storageConditions;
  final String? hazardClass;
  final String? safetyPrecautions;
  final String? safetyInfo;
  final String? msdsLink;

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
    this.cNumber,
    this.molecularFormula,
    this.molecularWeight,
    this.phicalState,
    this.color,
    this.density,
    this.meltingPoint,
    this.boilingPoint,
    this.solubility,
    this.storageConditions,
    this.hazardClass,
    this.safetyPrecautions,
    this.safetyInfo,
    this.msdsLink,
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

    // Handle double values safely
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
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
      // Enhanced fields
      cNumber: json['c_number'] as String?,
      molecularFormula: json['molecular_formula'] as String?,
      molecularWeight: parseDouble(json['molecular_weight']),
      phicalState: json['phical_state'] as String?,
      color: json['color'] as String?,
      density: parseDouble(json['density']),
      meltingPoint: json['melting_point'] as String?,
      boilingPoint: json['boiling_point'] as String?,
      solubility: json['solubility'] as String?,
      storageConditions: json['storage_conditions'] as String?,
      hazardClass: json['hazard_class'] as String?,
      safetyPrecautions: json['safety_precautions'] as String?,
      safetyInfo: json['safety_info'] as String?,
      msdsLink: json['msds_link'] as String?,
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
      // Enhanced fields
      'c_number': cNumber,
      'molecular_formula': molecularFormula,
      'molecular_weight': molecularWeight,
      'phical_state': phicalState,
      'color': color,
      'density': density,
      'melting_point': meltingPoint,
      'boiling_point': boilingPoint,
      'solubility': solubility,
      'storage_conditions': storageConditions,
      'hazard_class': hazardClass,
      'safety_precautions': safetyPrecautions,
      'safety_info': safetyInfo,
      'msds_link': msdsLink,
    };
  }
}

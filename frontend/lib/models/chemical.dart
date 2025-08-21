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
    return Chemical(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      quantity: json['quantity'].toDouble(),
      unit: json['unit'],
      storageLocation: json['storage_location'],
      expiryDate: DateTime.parse(json['expiry_date']),
      safetyDataSheet: json['safety_data_sheet'],
      createdAt: DateTime.parse(json['created_at']),
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

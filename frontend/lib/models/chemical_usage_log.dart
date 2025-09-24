class ChemicalUsageLog {
  final int id;
  final int chemicalId;
  final int userId;
  final double quantityUsed;
  final double remainingQuantity;
  final DateTime usageDate;
  final String? purpose;
  final String? notes;
  final String? experimentReference;
  final String? userName;
  final String? chemicalName;
  final String? unit;
  final DateTime createdAt;

  ChemicalUsageLog({
    required this.id,
    required this.chemicalId,
    required this.userId,
    required this.quantityUsed,
    required this.remainingQuantity,
    required this.usageDate,
    this.purpose,
    this.notes,
    this.experimentReference,
    this.userName,
    this.chemicalName,
    this.unit,
    required this.createdAt,
  });

  factory ChemicalUsageLog.fromJson(Map<String, dynamic> json) {
    return ChemicalUsageLog(
      id: json['id'] ?? 0,
      chemicalId: json['chemical_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      quantityUsed: (json['quantity_used'] as num?)?.toDouble() ?? 0.0,
      remainingQuantity:
          (json['remaining_quantity'] as num?)?.toDouble() ?? 0.0,
      usageDate: json['usage_date'] != null
          ? DateTime.parse(json['usage_date'])
          : DateTime.now(),
      purpose: json['purpose'],
      notes: json['notes'],
      experimentReference: json['experiment_reference'],
      userName: json['user_name'],
      chemicalName: json['chemical_name'],
      unit: json['unit'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

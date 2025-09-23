class EquipmentPdfFilterOptions {
  // Content sections
  bool includeBasicInfo;
  bool includeMaintenanceInfo;
  bool includeCalibrationInfo;
  bool includePurchaseWarranty;
  bool includeManufacturerInfo;

  // Filtering options
  String selectedCategory;
  String selectedCondition;
  bool maintenanceDueOnly;
  bool calibrationDueOnly;
  bool warrantyExpiringOnly;
  int maintenanceDueWithin; // days
  int calibrationDueWithin; // days
  String searchQuery;

  // Additional options
  bool includeStatistics;
  bool showStatusColors;

  EquipmentPdfFilterOptions({
    this.includeBasicInfo = true,
    this.includeMaintenanceInfo = true,
    this.includeCalibrationInfo = true,
    this.includePurchaseWarranty = false,
    this.includeManufacturerInfo = true,
    this.selectedCategory = 'All',
    this.selectedCondition = 'All',
    this.maintenanceDueOnly = false,
    this.calibrationDueOnly = false,
    this.warrantyExpiringOnly = false,
    this.maintenanceDueWithin = 30,
    this.calibrationDueWithin = 30,
    this.searchQuery = '',
    this.includeStatistics = true,
    this.showStatusColors = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'includeBasicInfo': includeBasicInfo,
      'includeMaintenanceInfo': includeMaintenanceInfo,
      'includeCalibrationInfo': includeCalibrationInfo,
      'includePurchaseWarranty': includePurchaseWarranty,
      'includeManufacturerInfo': includeManufacturerInfo,
      'category': selectedCategory,
      'condition': selectedCondition,
      'maintenanceDueOnly': maintenanceDueOnly,
      'calibrationDueOnly': calibrationDueOnly,
      'warrantyExpiringOnly': warrantyExpiringOnly,
      'maintenanceDueWithin': maintenanceDueWithin,
      'calibrationDueWithin': calibrationDueWithin,
      'search': searchQuery,
      'includeStatistics': includeStatistics,
      'showStatusColors': showStatusColors,
    };
  }

  factory EquipmentPdfFilterOptions.fromJson(Map<String, dynamic> json) {
    return EquipmentPdfFilterOptions(
      includeBasicInfo: json['includeBasicInfo'] ?? true,
      includeMaintenanceInfo: json['includeMaintenanceInfo'] ?? true,
      includeCalibrationInfo: json['includeCalibrationInfo'] ?? true,
      includePurchaseWarranty: json['includePurchaseWarranty'] ?? false,
      includeManufacturerInfo: json['includeManufacturerInfo'] ?? true,
      selectedCategory: json['category'] ?? 'All',
      selectedCondition: json['condition'] ?? 'All',
      maintenanceDueOnly: json['maintenanceDueOnly'] ?? false,
      calibrationDueOnly: json['calibrationDueOnly'] ?? false,
      warrantyExpiringOnly: json['warrantyExpiringOnly'] ?? false,
      maintenanceDueWithin: json['maintenanceDueWithin'] ?? 30,
      calibrationDueWithin: json['calibrationDueWithin'] ?? 30,
      searchQuery: json['search'] ?? '',
      includeStatistics: json['includeStatistics'] ?? true,
      showStatusColors: json['showStatusColors'] ?? true,
    );
  }

  EquipmentPdfFilterOptions copyWith({
    bool? includeBasicInfo,
    bool? includeMaintenanceInfo,
    bool? includeCalibrationInfo,
    bool? includePurchaseWarranty,
    bool? includeManufacturerInfo,
    String? selectedCategory,
    String? selectedCondition,
    bool? maintenanceDueOnly,
    bool? calibrationDueOnly,
    bool? warrantyExpiringOnly,
    int? maintenanceDueWithin,
    int? calibrationDueWithin,
    String? searchQuery,
    bool? includeStatistics,
    bool? showStatusColors,
  }) {
    return EquipmentPdfFilterOptions(
      includeBasicInfo: includeBasicInfo ?? this.includeBasicInfo,
      includeMaintenanceInfo:
          includeMaintenanceInfo ?? this.includeMaintenanceInfo,
      includeCalibrationInfo:
          includeCalibrationInfo ?? this.includeCalibrationInfo,
      includePurchaseWarranty:
          includePurchaseWarranty ?? this.includePurchaseWarranty,
      includeManufacturerInfo:
          includeManufacturerInfo ?? this.includeManufacturerInfo,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedCondition: selectedCondition ?? this.selectedCondition,
      maintenanceDueOnly: maintenanceDueOnly ?? this.maintenanceDueOnly,
      calibrationDueOnly: calibrationDueOnly ?? this.calibrationDueOnly,
      warrantyExpiringOnly: warrantyExpiringOnly ?? this.warrantyExpiringOnly,
      maintenanceDueWithin: maintenanceDueWithin ?? this.maintenanceDueWithin,
      calibrationDueWithin: calibrationDueWithin ?? this.calibrationDueWithin,
      searchQuery: searchQuery ?? this.searchQuery,
      includeStatistics: includeStatistics ?? this.includeStatistics,
      showStatusColors: showStatusColors ?? this.showStatusColors,
    );
  }
}

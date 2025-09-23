class PdfFilterOptions {
  // Content sections
  bool includeBasicInfo;
  bool includePhysicalProperties;
  bool includeStorageSafety;
  bool includeStockAnalysis;
  bool includeDocuments;

  // Filtering options
  String selectedCategory;
  bool lowStockOnly;
  int expiringSoon; // days
  String searchQuery;

  // Additional options
  bool includeStatistics;
  bool showQRCodes;

  PdfFilterOptions({
    this.includeBasicInfo = true,
    this.includePhysicalProperties = true,
    this.includeStorageSafety = true,
    this.includeStockAnalysis = false,
    this.includeDocuments = false,
    this.selectedCategory = 'All',
    this.lowStockOnly = false,
    this.expiringSoon = 0,
    this.searchQuery = '',
    this.includeStatistics = true,
    this.showQRCodes = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'includeBasicInfo': includeBasicInfo,
      'includePhysicalProperties': includePhysicalProperties,
      'includeStorageSafety': includeStorageSafety,
      'includeStockAnalysis': includeStockAnalysis,
      'includeDocuments': includeDocuments,
      'category': selectedCategory,
      'lowStockOnly': lowStockOnly,
      'expiringSoon': expiringSoon,
      'search': searchQuery,
      'includeStatistics': includeStatistics,
      'showQRCodes': showQRCodes,
    };
  }

  factory PdfFilterOptions.fromJson(Map<String, dynamic> json) {
    return PdfFilterOptions(
      includeBasicInfo: json['includeBasicInfo'] ?? true,
      includePhysicalProperties: json['includePhysicalProperties'] ?? true,
      includeStorageSafety: json['includeStorageSafety'] ?? true,
      includeStockAnalysis: json['includeStockAnalysis'] ?? false,
      includeDocuments: json['includeDocuments'] ?? false,
      selectedCategory: json['category'] ?? 'All',
      lowStockOnly: json['lowStockOnly'] ?? false,
      expiringSoon: json['expiringSoon'] ?? 0,
      searchQuery: json['search'] ?? '',
      includeStatistics: json['includeStatistics'] ?? true,
      showQRCodes: json['showQRCodes'] ?? false,
    );
  }

  PdfFilterOptions copyWith({
    bool? includeBasicInfo,
    bool? includePhysicalProperties,
    bool? includeStorageSafety,
    bool? includeStockAnalysis,
    bool? includeDocuments,
    String? selectedCategory,
    bool? lowStockOnly,
    int? expiringSoon,
    String? searchQuery,
    bool? includeStatistics,
    bool? showQRCodes,
  }) {
    return PdfFilterOptions(
      includeBasicInfo: includeBasicInfo ?? this.includeBasicInfo,
      includePhysicalProperties:
          includePhysicalProperties ?? this.includePhysicalProperties,
      includeStorageSafety: includeStorageSafety ?? this.includeStorageSafety,
      includeStockAnalysis: includeStockAnalysis ?? this.includeStockAnalysis,
      includeDocuments: includeDocuments ?? this.includeDocuments,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      expiringSoon: expiringSoon ?? this.expiringSoon,
      searchQuery: searchQuery ?? this.searchQuery,
      includeStatistics: includeStatistics ?? this.includeStatistics,
      showQRCodes: showQRCodes ?? this.showQRCodes,
    );
  }
}

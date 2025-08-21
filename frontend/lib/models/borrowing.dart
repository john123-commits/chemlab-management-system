class Borrowing {
  final int id;
  final int borrowerId;
  final String borrowerName;
  final String borrowerEmail;
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
  final DateTime createdAt;
  final DateTime updatedAt;

  Borrowing({
    required this.id,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowerEmail,
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
    required this.createdAt,
    required this.updatedAt,
  });

  factory Borrowing.fromJson(Map<String, dynamic> json) {
    return Borrowing(
      id: json['id'],
      borrowerId: json['borrower_id'],
      borrowerName: json['borrower_name'] ?? '',
      borrowerEmail: json['borrower_email'] ?? '',
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
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'borrower_id': borrowerId,
      'borrower_name': borrowerName,
      'borrower_email': borrowerEmail,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

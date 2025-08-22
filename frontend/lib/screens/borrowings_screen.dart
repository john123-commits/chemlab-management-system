import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/models/borrowing.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/borrowing_form_screen.dart';
import 'package:intl/intl.dart';

class BorrowingsScreen extends StatefulWidget {
  const BorrowingsScreen({super.key});

  @override
  State<BorrowingsScreen> createState() => _BorrowingsScreenState();
}

class _BorrowingsScreenState extends State<BorrowingsScreen> {
  List<Borrowing> _borrowings = [];
  String _selectedStatus = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBorrowings();
  }

  Future<void> _loadBorrowings() async {
    try {
      final status = _selectedStatus == 'All' ? null : _selectedStatus;
      final borrowings = await ApiService.getBorrowings(status: status);
      if (mounted) {
        setState(() {
          _borrowings = borrowings;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load borrowings: ${error.toString()}')),
        );
      }
    }
  }

  Future<void> _refreshBorrowings() async {
    await _loadBorrowings();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        actions: [
          if (userRole != 'admin' && userRole != 'technician')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BorrowingFormScreen(),
                  ),
                ).then((result) {
                  if (result == true) {
                    _loadBorrowings();
                  }
                });
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBorrowings,
        child: Column(
          children: [
            // Status Filter
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(value: 'returned', child: Text('Returned')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                      _loadBorrowings();
                    });
                  }
                },
              ),
            ),

            // Borrowings List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _borrowings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No borrowings found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const BorrowingFormScreen(),
                                    ),
                                  ).then((result) {
                                    if (result == true) {
                                      _loadBorrowings();
                                    }
                                  });
                                },
                                child: const Text('Request Borrowing'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _borrowings.length,
                          itemBuilder: (context, index) {
                            final borrowing = _borrowings[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Request Header
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            borrowing.purpose,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                                borrowing.status),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            borrowing.status.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Borrower Info (for admin/technician)
                                    if (userRole == 'admin' ||
                                        userRole == 'technician') ...[
                                      Text(
                                        'Borrower: ${borrowing.borrowerName}',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],

                                    // Dates
                                    Text(
                                      'Visit: ${DateFormat('MMM dd, yyyy').format(borrowing.visitDate)} at ${borrowing.visitTime}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Return: ${DateFormat('MMM dd, yyyy').format(borrowing.returnDate)}',
                                      style: TextStyle(
                                        color: borrowing.returnDate.compareTo(
                                                        DateTime.now()) <
                                                    0 &&
                                                borrowing.status == 'approved'
                                            ? Colors.red
                                            : Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Chemicals List
                                    if (borrowing.chemicals.isNotEmpty) ...[
                                      const Text(
                                        'Chemicals:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...borrowing.chemicals.map((chemical) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              left: 8.0, bottom: 2.0),
                                          child: Text(
                                            '• ${chemical['name']} (${chemical['quantity']} ${chemical['unit']})',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      const SizedBox(height: 8),
                                    ],

                                    // Equipment List
                                    if (borrowing.equipment.isNotEmpty) ...[
                                      const Text(
                                        'Equipment:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...borrowing.equipment.map((equipment) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              left: 8.0, bottom: 2.0),
                                          child: Text(
                                            '• ${equipment['name']} (Qty: ${equipment['quantity']})',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],

                                    // Notes (if any)
                                    if (borrowing.notes != null &&
                                        borrowing.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.yellow[50],
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: Colors.yellow[200]!),
                                        ),
                                        child: Text(
                                          'Notes: ${borrowing.notes}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'returned':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }
}

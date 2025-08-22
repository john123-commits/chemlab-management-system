import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/models/borrowing.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/borrowing_form_screen.dart';
import 'package:chemlab_frontend/screens/borrowing_details_screen.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class BorrowingsScreen extends StatefulWidget {
  const BorrowingsScreen({super.key});

  @override
  State<BorrowingsScreen> createState() => _BorrowingsScreenState();
}

class _BorrowingsScreenState extends State<BorrowingsScreen> {
  List<Borrowing> _borrowings = [];
  String _selectedStatus = 'All';
  bool _isLoading = true;
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBorrowings();
    _checkPendingRequests(); // Check for pending requests if admin/technician
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

  Future<void> _checkPendingRequests() async {
    final userRole = Provider.of<AuthProvider>(context, listen: false).userRole;
    if (userRole == 'admin' || userRole == 'technician') {
      try {
        final count = await ApiService.getPendingRequestsCount();
        if (mounted) {
          setState(() {
            _pendingRequestsCount = count;
          });

          // Show notification if there are pending requests
          if (count > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You have $count pending requests to review'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (error) {
        // Silently ignore errors for this notification
        logger.d('Error checking pending requests: $error');
      }
    }
  }

  Future<void> _refreshBorrowings() async {
    await _loadBorrowings();
    await _checkPendingRequests();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;
    final isStaff = userRole == 'admin' || userRole == 'technician';

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaff ? 'Borrowing Requests' : 'My Requests'),
        actions: [
          if (!isStaff)
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
          // Refresh button for staff
          if (isStaff)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshBorrowings,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBorrowings,
        child: Column(
          children: [
            // Pending Requests Alert for Admin/Technician
            if (isStaff && _pendingRequestsCount > 0) ...[
              Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_pendingRequestsCount pending request${_pendingRequestsCount == 1 ? '' : 's'} to review',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadBorrowings,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ],

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
                                isStaff
                                    ? Icons.assignment_outlined
                                    : Icons.assignment_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isStaff
                                    ? 'No borrowing requests found'
                                    : 'No borrowings found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (!isStaff)
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
                              child: InkWell(
                                onTap: () {
                                  // Navigate to borrowing details screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BorrowingDetailsScreen(
                                              borrowing: borrowing),
                                    ),
                                  ).then((updatedBorrowing) {
                                    if (updatedBorrowing != null) {
                                      _loadBorrowings(); // Refresh the list
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (isStaff) ...[
                                        Text(
                                          'Borrower: ${borrowing.borrowerName}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],

                                      // Approval Info
                                      if (borrowing.technicianName != null) ...[
                                        Text(
                                          'Technician: ${borrowing.technicianName}',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      if (borrowing.adminName != null) ...[
                                        Text(
                                          'Admin: ${borrowing.adminName}',
                                          style: TextStyle(
                                            color: Colors.blue[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
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

                                      // Rejection Reason (if any)
                                      if (borrowing.rejectionReason != null &&
                                          borrowing
                                              .rejectionReason!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: Colors.red[200]!),
                                          ),
                                          child: Text(
                                            'Rejection Reason: ${borrowing.rejectionReason}',
                                            style: TextStyle(
                                              color: Colors.red[800],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Add Request Button for Borrowers (at bottom)
            if (!isStaff)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
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
                  icon: const Icon(Icons.add),
                  label: const Text('Request Borrowing'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
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

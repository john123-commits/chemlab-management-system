import 'package:chemlab_frontend/screens/borrowing_details_screen.dart';
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
      setState(() {
        _borrowings = borrowings;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load borrowings')),
      );
    }
  }

  Future<void> _refreshBorrowings() async {
    await _loadBorrowings();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;

    return RefreshIndicator(
      onRefresh: _refreshBorrowings,
      child: Column(
        children: [
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
                setState(() {
                  _selectedStatus = value!;
                  _loadBorrowings();
                });
              },
            ),
          ),
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
                            if (userRole != 'admin' && userRole != 'technician')
                              const SizedBox(height: 16),
                            if (userRole != 'admin' && userRole != 'technician')
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const BorrowingFormScreen(),
                                    ),
                                  ).then((_) => _loadBorrowings());
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
                            child: ListTile(
                              title: Text(
                                borrowing.purpose,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (userRole == 'admin' ||
                                      userRole == 'technician')
                                    Text('Borrower: ${borrowing.borrowerName}'),
                                  Text('Status: ${borrowing.status}'),
                                  Text(
                                    'Visit: ${DateFormat('MMM dd, yyyy').format(borrowing.visitDate)} at ${borrowing.visitTime}',
                                  ),
                                  Text(
                                    'Return: ${DateFormat('MMM dd, yyyy').format(borrowing.returnDate)}',
                                    style: TextStyle(
                                      color: borrowing.returnDate.compareTo(
                                                      DateTime.now()) <
                                                  0 &&
                                              borrowing.status == 'approved'
                                          ? Colors.red
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                borrowing.status == 'approved'
                                    ? Icons.check_circle
                                    : borrowing.status == 'rejected'
                                        ? Icons.cancel
                                        : borrowing.status == 'returned'
                                            ? Icons.restore
                                            : Icons.pending,
                                color: borrowing.status == 'approved'
                                    ? Colors.green
                                    : borrowing.status == 'rejected'
                                        ? Colors.red
                                        : borrowing.status == 'returned'
                                            ? Colors.blue
                                            : Colors.orange,
                              ),
                              onTap: () {
                                // Navigate to borrowing details screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        BorrowingDetailsScreen(
                                            borrowing: borrowing),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
          if (userRole != 'admin' && userRole != 'technician')
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BorrowingFormScreen(),
                    ),
                  ).then((_) => _loadBorrowings());
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
    );
  }
}

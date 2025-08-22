import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/models/borrowing.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class BorrowingDetailsScreen extends StatefulWidget {
  final Borrowing borrowing;

  const BorrowingDetailsScreen({super.key, required this.borrowing});

  @override
  State<BorrowingDetailsScreen> createState() => _BorrowingDetailsScreenState();
}

class _BorrowingDetailsScreenState extends State<BorrowingDetailsScreen> {
  final _notesController = TextEditingController();
  final _rejectionReasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.borrowing.notes != null) {
      _notesController.text = widget.borrowing.notes!;
    }
    if (widget.borrowing.rejectionReason != null) {
      _rejectionReasonController.text = widget.borrowing.rejectionReason!;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isLoading = true);

    try {
      final updatedBorrowing = await ApiService.updateBorrowingStatus(
        widget.borrowing.id,
        status,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        rejectionReason: status == 'rejected' &&
                _rejectionReasonController.text.trim().isNotEmpty
            ? _rejectionReasonController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
        Navigator.pop(context, updatedBorrowing);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update status: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;
    final borrowing = widget.borrowing;
    final isStaff = userRole == 'admin' || userRole == 'technician';

    return Scaffold(
      appBar: AppBar(
        title: Text('Request #${borrowing.id}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Header Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            borrowing.purpose,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(borrowing.status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            borrowing.status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isStaff) ...[
                      Text('Borrower: ${borrowing.borrowerName}'),
                      Text('Email: ${borrowing.borrowerEmail}'),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Visit: ${DateFormat('MMM dd, yyyy').format(borrowing.visitDate)} at ${borrowing.visitTime}',
                    ),
                    Text(
                      'Return: ${DateFormat('MMM dd, yyyy').format(borrowing.returnDate)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(borrowing.createdAt)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (borrowing.technicianName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Technician Approved: ${borrowing.technicianName}',
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      if (borrowing.technicianApprovedAt != null)
                        Text(
                          'Approved At: ${DateFormat('MMM dd, yyyy HH:mm').format(borrowing.technicianApprovedAt!)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                    if (borrowing.adminName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Admin Approved: ${borrowing.adminName}',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      if (borrowing.adminApprovedAt != null)
                        Text(
                          'Approved At: ${DateFormat('MMM dd, yyyy HH:mm').format(borrowing.adminApprovedAt!)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Student Information Section (ONLY for admin/technician)
            if (isStaff) ...[
              Text(
                'Student Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStudentInfoRow(
                          'University', borrowing.university ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _buildStudentInfoRow('Education Level',
                          borrowing.educationLevel ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _buildStudentInfoRow('Registration Number',
                          borrowing.registrationNumber ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _buildStudentInfoRow('Student Number',
                          borrowing.studentNumber ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _buildStudentInfoRow('Current Year',
                          borrowing.currentYear?.toString() ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _buildStudentInfoRow(
                          'Semester', borrowing.semester ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _buildStudentInfoRow(
                          'Email',
                          borrowing.borrowerEmailContact ??
                              borrowing.borrowerEmail),
                      const SizedBox(height: 12),
                      _buildStudentInfoRow('Contact',
                          borrowing.borrowerContact ?? 'Not provided'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Chemicals Section
            if (borrowing.chemicals.isNotEmpty) ...[
              Text(
                'Requested Chemicals',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: borrowing.chemicals.map((chemical) {
                    return ListTile(
                      title: Text(chemical['name']),
                      subtitle: Text(
                        '${chemical['quantity']} ${chemical['unit']}',
                        style: TextStyle(
                          color: chemical['quantity'] < 10
                              ? Colors.red
                              : Colors.grey[600],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Equipment Section
            if (borrowing.equipment.isNotEmpty) ...[
              Text(
                'Requested Equipment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: borrowing.equipment.map((equipment) {
                    return ListTile(
                      title: Text(equipment['name']),
                      subtitle: Text('Quantity: ${equipment['quantity']}'),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Research Details
            Text(
              'Research Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(borrowing.researchDetails),
              ),
            ),
            const SizedBox(height: 16),

            // Notes Section
            if (borrowing.notes != null && borrowing.notes!.isNotEmpty) ...[
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.yellow[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(borrowing.notes!),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Rejection Reason Section
            if (borrowing.rejectionReason != null &&
                borrowing.rejectionReason!.isNotEmpty) ...[
              Text(
                'Rejection Reason',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    borrowing.rejectionReason!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Actions for Admin/Technician
            if (isStaff) ...[
              if (borrowing.status == 'pending') ...[
                Text(
                  'Add Notes (Optional)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: 'Add notes or comments...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text(
                  'Rejection Reason (Required for Rejection)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _rejectionReasonController,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason for rejection...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : () => _updateStatus('rejected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Reject Request'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : () => _updateStatus('approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Approve Request'),
                      ),
                    ),
                  ],
                ),
              ] else if (borrowing.status == 'approved') ...[
                Card(
                  color: Colors.green[100],
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'This request has been approved.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ),
              ] else if (borrowing.status == 'rejected') ...[
                Card(
                  color: Colors.red[100],
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'This request has been rejected.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],

            // Status Information for Borrower
            if (!isStaff) ...[
              if (borrowing.status == 'pending') ...[
                Card(
                  color: Colors.orange[100],
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Your request is pending approval. Please wait for technician/admin review.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
              ] else if (borrowing.status == 'approved') ...[
                Card(
                  color: Colors.green[100],
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Your request has been approved! You can collect the items on the scheduled visit date.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ),
              ] else if (borrowing.status == 'rejected') ...[
                Card(
                  color: Colors.red[100],
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Your request has been rejected. Please check the rejection reason above.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
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

import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/borrowing.dart';
import 'package:intl/intl.dart';

class BorrowingDetailsScreen extends StatelessWidget {
  final Borrowing borrowing;

  const BorrowingDetailsScreen({super.key, required this.borrowing});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrowing Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Purpose', borrowing.purpose),
                    _buildDetailRow('Status', borrowing.status.toUpperCase()),
                    _buildDetailRow(
                        'Borrow Date',
                        DateFormat('MMM dd, yyyy')
                            .format(borrowing.borrowDate)),
                    _buildDetailRow(
                        'Return Date',
                        DateFormat('MMM dd, yyyy')
                            .format(borrowing.returnDate)),
                    _buildDetailRow('Visit Date',
                        '${DateFormat('MMM dd, yyyy').format(borrowing.visitDate)} at ${borrowing.visitTime}'),
                    if (borrowing.notes != null && borrowing.notes!.isNotEmpty)
                      _buildDetailRow('Notes', borrowing.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (borrowing.chemicals.isNotEmpty) ...[
              Text(
                'Requested Chemicals',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: borrowing.chemicals.map((chemical) {
                    return ListTile(
                      title: Text(chemical['name']),
                      subtitle:
                          Text('${chemical['quantity']} ${chemical['unit']}'),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (borrowing.equipment.isNotEmpty) ...[
              Text(
                'Requested Equipment',
                style: Theme.of(context).textTheme.titleMedium,
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

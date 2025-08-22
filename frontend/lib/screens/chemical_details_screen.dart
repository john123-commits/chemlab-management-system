import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class ChemicalDetailsScreen extends StatelessWidget {
  final Chemical chemical;

  const ChemicalDetailsScreen({super.key, required this.chemical});

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;
    final isBorrower = userRole == 'borrower';

    return Scaffold(
      appBar: AppBar(
        title: Text(chemical.name),
        // Only show edit button for admin/technician
        actions: [
          if (!isBorrower) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Navigate to edit screen - you'd implement this
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Edit functionality coming soon')),
                );
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chemical Header Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.science,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      chemical.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chemical.category,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Details Section
            Text(
              'Chemical Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Name', chemical.name),
                    const SizedBox(height: 12),
                    _buildDetailRow('Category', chemical.category),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                        'Quantity', '${chemical.quantity} ${chemical.unit}'),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                        'Storage Location', chemical.storageLocation),
                    const SizedBox(height: 12),
                    _buildDetailRow('Expiry Date',
                        DateFormat('MMM dd, yyyy').format(chemical.expiryDate)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status Section
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildStatusCard(chemical),
              ),
            ),
            const SizedBox(height: 24),

            // Safety Data Sheet Section
            if (chemical.safetyDataSheet != null) ...[
              Text(
                'Documents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.description, color: Colors.blue),
                  title: const Text('Safety Data Sheet'),
                  subtitle: const Text('Click to view SDS document'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // SDS viewing functionality coming soon
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'SDS document viewing will be available in future updates')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(Chemical chemical) {
    final daysUntilExpiry =
        chemical.expiryDate.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry < 30 && daysUntilExpiry > 0;
    final isExpired = daysUntilExpiry < 0;
    final isLowStock = chemical.quantity < 10;

    List<Widget> statusItems = [];

    // Expiry Status
    if (isExpired) {
      statusItems.add(
        Chip(
          label: const Text('EXPIRED'),
          backgroundColor: Colors.red.withValues(alpha: 0.2),
          labelStyle: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (isExpiringSoon) {
      statusItems.add(
        Chip(
          label: const Text('EXPIRING SOON'),
          backgroundColor: Colors.orange.withValues(alpha: 0.2),
          labelStyle: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      statusItems.add(
        Chip(
          label: const Text('FRESH'),
          backgroundColor: Colors.green.withValues(alpha: 0.2),
          labelStyle: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Stock Status
    if (isLowStock) {
      statusItems.add(
        Chip(
          label: const Text('LOW STOCK'),
          backgroundColor: Colors.yellow.withValues(alpha: 0.2),
          labelStyle: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      statusItems.add(
        Chip(
          label: const Text('ADEQUATE STOCK'),
          backgroundColor: Colors.blue.withValues(alpha: 0.2),
          labelStyle: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8.0,
      children: statusItems,
    );
  }
}

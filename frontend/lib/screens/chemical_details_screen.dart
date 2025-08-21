import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:intl/intl.dart';

class ChemicalDetailsScreen extends StatelessWidget {
  final Chemical chemical;

  const ChemicalDetailsScreen({super.key, required this.chemical});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chemical.name),
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
                      chemical.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Category', chemical.category),
                    _buildDetailRow(
                        'Quantity', '${chemical.quantity} ${chemical.unit}'),
                    _buildDetailRow(
                        'Storage Location', chemical.storageLocation),
                    _buildDetailRow('Expiry Date',
                        DateFormat('MMM dd, yyyy').format(chemical.expiryDate)),
                    const SizedBox(height: 16),
                    _buildStatusCard(chemical),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (chemical.safetyDataSheet != null) ...[
              Card(
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
              const SizedBox(height: 16),
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

  Widget _buildStatusCard(Chemical chemical) {
    final daysUntilExpiry =
        chemical.expiryDate.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry < 30 && daysUntilExpiry > 0;
    final isExpired = daysUntilExpiry < 0;
    final isLowStock = chemical.quantity < 10;

    List<Widget> statusItems = [];

    if (isExpired) {
      statusItems.add(
        Chip(
          label: const Text('EXPIRED'),
          backgroundColor: Colors.red[100],
          labelStyle: TextStyle(color: Colors.red[800]),
        ),
      );
    } else if (isExpiringSoon) {
      statusItems.add(
        Chip(
          label: const Text('EXPIRING SOON'),
          backgroundColor: Colors.orange[100],
          labelStyle: TextStyle(color: Colors.orange[800]),
        ),
      );
    }

    if (isLowStock) {
      statusItems.add(
        Chip(
          label: const Text('LOW STOCK'),
          backgroundColor: Colors.yellow[100],
          labelStyle: TextStyle(color: Colors.orange[800]),
        ),
      );
    }

    if (statusItems.isEmpty) {
      statusItems.add(
        Chip(
          label: const Text('GOOD'),
          backgroundColor: Colors.green[100],
          labelStyle: TextStyle(color: Colors.green[800]),
        ),
      );
    }

    return Wrap(
      spacing: 8.0,
      children: statusItems,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    if (chemical.cNumber != null &&
                        chemical.cNumber!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'CAS: ${chemical.cNumber}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Basic Details Section
            Text(
              'Basic Information',
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
                    if (chemical.cNumber != null &&
                        chemical.cNumber!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow('CAS Number', chemical.cNumber!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Physical Properties Section
            if (_hasPhysicalProperties()) ...[
              Text(
                'Physical Properties',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (chemical.molecularFormula != null &&
                          chemical.molecularFormula!.isNotEmpty) ...[
                        _buildDetailRow(
                            'Molecular Formula', chemical.molecularFormula!),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.molecularWeight != null) ...[
                        _buildDetailRow('Molecular Weight',
                            '${chemical.molecularWeight} g/mol'),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.phicalState != null &&
                          chemical.phicalState!.isNotEmpty) ...[
                        _buildDetailRow(
                            'Physical State', chemical.phicalState!),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.color != null &&
                          chemical.color!.isNotEmpty) ...[
                        _buildDetailRow('Color', chemical.color!),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.density != null) ...[
                        _buildDetailRow('Density', '${chemical.density} g/cm³'),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.meltingPoint != null &&
                          chemical.meltingPoint!.isNotEmpty) ...[
                        _buildDetailRow(
                            'Melting Point', '${chemical.meltingPoint}°C'),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.boilingPoint != null &&
                          chemical.boilingPoint!.isNotEmpty) ...[
                        _buildDetailRow(
                            'Boiling Point', '${chemical.boilingPoint}°C'),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.solubility != null &&
                          chemical.solubility!.isNotEmpty) ...[
                        _buildDetailRow('Solubility', chemical.solubility!),
                        const SizedBox(height: 12),
                      ],
                    ]..removeWhere((widget) =>
                        widget == const SizedBox(height: 12) &&
                        widget ==
                            (const Column(children: []).children.isNotEmpty
                                ? (const Column(children: []).children.last)
                                : null)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Storage & Safety Section
            if (_hasStorageSafetyInfo()) ...[
              Text(
                'Storage & Safety',
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
                      if (chemical.storageConditions != null &&
                          chemical.storageConditions!.isNotEmpty) ...[
                        _buildDetailRow(
                            'Storage Conditions', chemical.storageConditions!),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.hazardClass != null &&
                          chemical.hazardClass!.isNotEmpty) ...[
                        _buildDetailRow('Hazard Class', chemical.hazardClass!),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.safetyPrecautions != null &&
                          chemical.safetyPrecautions!.isNotEmpty) ...[
                        _buildDetailSection(
                            'Safety Precautions', chemical.safetyPrecautions!),
                        const SizedBox(height: 12),
                      ],
                      if (chemical.safetyInfo != null &&
                          chemical.safetyInfo!.isNotEmpty) ...[
                        _buildDetailSection('Additional Safety Information',
                            chemical.safetyInfo!),
                      ],
                    ]..removeWhere((widget) =>
                        widget == const SizedBox(height: 12) &&
                        widget ==
                            (const Column(children: []).children.isNotEmpty
                                ? (Column(children: const []).children.last)
                                : null)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

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

            // Documents Section
            if (_hasDocuments()) ...[
              Text(
                'Documents & Links',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    if (chemical.safetyDataSheet != null) ...[
                      ListTile(
                        leading:
                            const Icon(Icons.description, color: Colors.blue),
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
                    ],
                    if (chemical.msdsLink != null &&
                        chemical.msdsLink!.isNotEmpty) ...[
                      if (chemical.safetyDataSheet != null)
                        const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.link, color: Colors.green),
                        title: const Text('MSDS Link'),
                        subtitle: Text(chemical.msdsLink!),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () async {
                          final url = chemical.msdsLink!;
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url),
                                mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Could not open the link')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasPhysicalProperties() {
    return (chemical.molecularFormula != null &&
            chemical.molecularFormula!.isNotEmpty) ||
        chemical.molecularWeight != null ||
        (chemical.phicalState != null && chemical.phicalState!.isNotEmpty) ||
        (chemical.color != null && chemical.color!.isNotEmpty) ||
        chemical.density != null ||
        (chemical.meltingPoint != null && chemical.meltingPoint!.isNotEmpty) ||
        (chemical.boilingPoint != null && chemical.boilingPoint!.isNotEmpty) ||
        (chemical.solubility != null && chemical.solubility!.isNotEmpty);
  }

  bool _hasStorageSafetyInfo() {
    return (chemical.storageConditions != null &&
            chemical.storageConditions!.isNotEmpty) ||
        (chemical.hazardClass != null && chemical.hazardClass!.isNotEmpty) ||
        (chemical.safetyPrecautions != null &&
            chemical.safetyPrecautions!.isNotEmpty) ||
        (chemical.safetyInfo != null && chemical.safetyInfo!.isNotEmpty);
  }

  bool _hasDocuments() {
    return chemical.safetyDataSheet != null ||
        (chemical.msdsLink != null && chemical.msdsLink!.isNotEmpty);
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

  Widget _buildDetailSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey[600],
              height: 1.4,
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

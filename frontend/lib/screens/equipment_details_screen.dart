import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:intl/intl.dart';

class EquipmentDetailsScreen extends StatelessWidget {
  final Equipment equipment;

  const EquipmentDetailsScreen({super.key, required this.equipment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(equipment.name),
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
                      equipment.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Category', equipment.category),
                    _buildDetailRow('Condition', equipment.condition),
                    _buildDetailRow('Location', equipment.location),
                    _buildDetailRow(
                        'Last Maintenance',
                        DateFormat('MMM dd, yyyy')
                            .format(equipment.lastMaintenanceDate)),
                    _buildDetailRow(
                        'Next Maintenance',
                        DateFormat('MMM dd, yyyy').format(
                            equipment.lastMaintenanceDate.add(Duration(
                                days: equipment.maintenanceSchedule)))),
                    _buildDetailRow('Maintenance Schedule',
                        '${equipment.maintenanceSchedule} days'),
                    const SizedBox(height: 16),
                    _buildStatusCard(equipment),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maintenance History',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No maintenance records available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    // Maintenance history functionality to be implemented
                    Text(
                      'Maintenance history tracking will be available in future updates',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
            width: 150,
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

  Widget _buildStatusCard(Equipment equipment) {
    final nextMaintenanceDate = equipment.lastMaintenanceDate
        .add(Duration(days: equipment.maintenanceSchedule));
    final daysUntilMaintenance =
        nextMaintenanceDate.difference(DateTime.now()).inDays;
    final isDueSoon = daysUntilMaintenance < 30 && daysUntilMaintenance > 0;
    final isOverdue = daysUntilMaintenance < 0;

    List<Widget> statusItems = [];

    if (isOverdue) {
      statusItems.add(
        Chip(
          label: const Text('OVERDUE'),
          backgroundColor: Colors.red.shade100,
          labelStyle: TextStyle(color: Colors.red.shade800),
        ),
      );
    } else if (isDueSoon) {
      statusItems.add(
        Chip(
          label: const Text('MAINTENANCE DUE SOON'),
          backgroundColor: Colors.orange.shade100,
          labelStyle: TextStyle(color: Colors.orange.shade800),
        ),
      );
    }

    // Add condition status
    MaterialColor conditionColor;
    if (equipment.condition.toLowerCase() == 'excellent') {
      conditionColor = Colors.green;
    } else if (equipment.condition.toLowerCase() == 'good') {
      conditionColor = Colors.blue;
    } else if (equipment.condition.toLowerCase() == 'fair') {
      conditionColor = Colors.orange;
    } else {
      conditionColor = Colors.red;
    }

    statusItems.add(
      Chip(
        label: Text(equipment.condition.toUpperCase()),
        backgroundColor: conditionColor.shade100,
        labelStyle: TextStyle(color: conditionColor.shade800),
      ),
    );

    return Wrap(
      spacing: 8.0,
      children: statusItems,
    );
  }
}

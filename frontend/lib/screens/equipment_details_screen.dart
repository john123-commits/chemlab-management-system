import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/equipment_form_screen.dart';
import 'package:intl/intl.dart';

class EquipmentDetailsScreen extends StatefulWidget {
  final Equipment equipment;

  const EquipmentDetailsScreen({super.key, required this.equipment});

  @override
  State<EquipmentDetailsScreen> createState() => _EquipmentDetailsScreenState();
}

class _EquipmentDetailsScreenState extends State<EquipmentDetailsScreen> {
  bool _isLoading = false;

  Future<void> _deleteEquipment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Equipment'),
        content:
            Text('Are you sure you want to delete ${widget.equipment.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      try {
        await ApiService.deleteEquipment(widget.equipment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Equipment deleted successfully')),
          );
          Navigator.pop(context, true); // Return true to indicate deletion
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to delete equipment: ${error.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;
    final equipment = widget.equipment;
    final isBorrower = userRole == 'borrower';

    return Scaffold(
      appBar: AppBar(
        title: Text(equipment.name),
        actions: [
          // Only show actions for admin/technician
          if (!isBorrower) ...[
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EquipmentFormScreen(equipment: equipment),
                    ),
                  ).then((result) {
                    if (!context.mounted) return;
                    if (result == true && mounted) {
                      Navigator.pop(context); // Refresh parent screen
                    }
                  });
                } else if (value == 'delete') {
                  _deleteEquipment();
                }
              },
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Equipment Image/Header
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.build,
                            size: 64,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            equipment.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            equipment.category,
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
                    'Equipment Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDetailRow('Name', equipment.name),
                          const SizedBox(height: 12),
                          _buildDetailRow('Category', equipment.category),
                          const SizedBox(height: 12),
                          _buildDetailRow('Condition', equipment.condition),
                          const SizedBox(height: 12),
                          _buildDetailRow('Location', equipment.location),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Last Maintenance',
                            DateFormat('MMM dd, yyyy')
                                .format(equipment.lastMaintenanceDate),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Next Maintenance',
                            DateFormat('MMM dd, yyyy').format(
                              equipment.lastMaintenanceDate.add(
                                Duration(days: equipment.maintenanceSchedule),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Maintenance Schedule',
                            '${equipment.maintenanceSchedule} days',
                          ),
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
                      child: Column(
                        children: [
                          _buildStatusChip('Condition', equipment.condition,
                              _getConditionColor(equipment.condition)),
                          const SizedBox(height: 12),
                          _buildMaintenanceStatus(equipment),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
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

  Widget _buildStatusChip(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text(value.toUpperCase()),
          backgroundColor: color.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceStatus(Equipment equipment) {
    final nextMaintenance = equipment.lastMaintenanceDate.add(
      Duration(days: equipment.maintenanceSchedule),
    );
    final daysUntilMaintenance =
        nextMaintenance.difference(DateTime.now()).inDays;

    Color statusColor;
    String statusText;

    if (daysUntilMaintenance < 0) {
      statusColor = Colors.red;
      statusText = 'OVERDUE';
    } else if (daysUntilMaintenance < 30) {
      statusColor = Colors.orange;
      statusText = 'DUE SOON';
    } else {
      statusColor = Colors.green;
      statusText = 'UP TO DATE';
    }

    return Row(
      children: [
        Text(
          'Maintenance Status:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text(statusText),
          backgroundColor: statusColor.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

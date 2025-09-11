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
                          if (equipment.serialNumber != null &&
                              equipment.serialNumber!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'S/N: ${equipment.serialNumber}',
                                style: TextStyle(
                                  color: Colors.green[700],
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
                          _buildDetailRow('Name', equipment.name),
                          const SizedBox(height: 12),
                          _buildDetailRow('Category', equipment.category),
                          const SizedBox(height: 12),
                          _buildDetailRow('Condition', equipment.condition),
                          const SizedBox(height: 12),
                          _buildDetailRow('Location', equipment.location),
                          if (equipment.serialNumber != null &&
                              equipment.serialNumber!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                                'Serial Number', equipment.serialNumber!),
                          ],
                          if (equipment.manufacturer != null &&
                              equipment.manufacturer!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                                'Manufacturer', equipment.manufacturer!),
                          ],
                          if (equipment.model != null &&
                              equipment.model!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow('Model', equipment.model!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Purchase & Warranty Section
                  if (_hasPurchaseWarrantyInfo()) ...[
                    Text(
                      'Purchase & Warranty',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            if (equipment.purchaseDate != null) ...[
                              _buildDetailRow(
                                  'Purchase Date',
                                  DateFormat('MMM dd, yyyy')
                                      .format(equipment.purchaseDate!)),
                              const SizedBox(height: 12),
                            ],
                            if (equipment.warrantyExpiry != null) ...[
                              _buildDetailRow(
                                  'Warranty Expiry',
                                  DateFormat('MMM dd, yyyy')
                                      .format(equipment.warrantyExpiry!)),
                              const SizedBox(height: 12),
                              _buildWarrantyStatus(equipment.warrantyExpiry!),
                            ],
                          ]..removeWhere((widget) =>
                              widget == const SizedBox(height: 12) &&
                              widget ==
                                  (Column(children: []).children.isNotEmpty
                                      ? (Column(children: []).children.last)
                                      : null)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Maintenance Section
                  Text(
                    'Maintenance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
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
                          const SizedBox(height: 16),
                          _buildMaintenanceStatus(equipment),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Calibration Section
                  if (_hasCalibrationInfo()) ...[
                    Text(
                      'Calibration',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            if (equipment.calibrationDate != null) ...[
                              _buildDetailRow(
                                  'Last Calibration',
                                  DateFormat('MMM dd, yyyy')
                                      .format(equipment.calibrationDate!)),
                              const SizedBox(height: 12),
                            ],
                            if (equipment.nextCalibrationDate != null) ...[
                              _buildDetailRow(
                                  'Next Calibration',
                                  DateFormat('MMM dd, yyyy')
                                      .format(equipment.nextCalibrationDate!)),
                              const SizedBox(height: 12),
                              _buildCalibrationStatus(
                                  equipment.nextCalibrationDate!),
                            ],
                          ]..removeWhere((widget) =>
                              widget == const SizedBox(height: 12) &&
                              widget ==
                                  (Column(children: []).children.isNotEmpty
                                      ? (Column(children: []).children.last)
                                      : null)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Status Section
                  Text(
                    'Status Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: [
                          _buildStatusChip('Condition', equipment.condition,
                              _getConditionColor(equipment.condition)),
                          _buildMaintenanceStatusChip(equipment),
                          if (equipment.nextCalibrationDate != null)
                            _buildCalibrationStatusChip(
                                equipment.nextCalibrationDate!),
                          if (equipment.warrantyExpiry != null)
                            _buildWarrantyStatusChip(equipment.warrantyExpiry!),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool _hasPurchaseWarrantyInfo() {
    return widget.equipment.purchaseDate != null ||
        widget.equipment.warrantyExpiry != null;
  }

  bool _hasCalibrationInfo() {
    return widget.equipment.calibrationDate != null ||
        widget.equipment.nextCalibrationDate != null;
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
    return Chip(
      label: Text('$label: ${value.toUpperCase()}'),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
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
      statusText = 'OVERDUE (${-daysUntilMaintenance} days)';
    } else if (daysUntilMaintenance < 30) {
      statusColor = Colors.orange;
      statusText = 'DUE SOON ($daysUntilMaintenance days)';
    } else {
      statusColor = Colors.green;
      statusText = 'UP TO DATE ($daysUntilMaintenance days)';
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
        Expanded(
          child: Chip(
            label: Text(statusText),
            backgroundColor: statusColor.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceStatusChip(Equipment equipment) {
    final nextMaintenance = equipment.lastMaintenanceDate.add(
      Duration(days: equipment.maintenanceSchedule),
    );
    final daysUntilMaintenance =
        nextMaintenance.difference(DateTime.now()).inDays;

    Color statusColor;
    String statusText;

    if (daysUntilMaintenance < 0) {
      statusColor = Colors.red;
      statusText = 'MAINTENANCE OVERDUE';
    } else if (daysUntilMaintenance < 30) {
      statusColor = Colors.orange;
      statusText = 'MAINTENANCE DUE SOON';
    } else {
      statusColor = Colors.green;
      statusText = 'MAINTENANCE UP TO DATE';
    }

    return Chip(
      label: Text(statusText),
      backgroundColor: statusColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: statusColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  Widget _buildCalibrationStatus(DateTime nextCalibrationDate) {
    final daysUntilCalibration =
        nextCalibrationDate.difference(DateTime.now()).inDays;

    Color statusColor;
    String statusText;

    if (daysUntilCalibration < 0) {
      statusColor = Colors.red;
      statusText = 'OVERDUE (${-daysUntilCalibration} days)';
    } else if (daysUntilCalibration < 30) {
      statusColor = Colors.orange;
      statusText = 'DUE SOON ($daysUntilCalibration days)';
    } else {
      statusColor = Colors.green;
      statusText = 'UP TO DATE ($daysUntilCalibration days)';
    }

    return Row(
      children: [
        Text(
          'Calibration Status:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Chip(
            label: Text(statusText),
            backgroundColor: statusColor.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationStatusChip(DateTime nextCalibrationDate) {
    final daysUntilCalibration =
        nextCalibrationDate.difference(DateTime.now()).inDays;

    Color statusColor;
    String statusText;

    if (daysUntilCalibration < 0) {
      statusColor = Colors.red;
      statusText = 'CALIBRATION OVERDUE';
    } else if (daysUntilCalibration < 30) {
      statusColor = Colors.orange;
      statusText = 'CALIBRATION DUE SOON';
    } else {
      statusColor = Colors.green;
      statusText = 'CALIBRATION UP TO DATE';
    }

    return Chip(
      label: Text(statusText),
      backgroundColor: statusColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: statusColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  Widget _buildWarrantyStatus(DateTime warrantyExpiry) {
    final daysUntilExpiry = warrantyExpiry.difference(DateTime.now()).inDays;

    Color statusColor;
    String statusText;

    if (daysUntilExpiry < 0) {
      statusColor = Colors.red;
      statusText = 'EXPIRED (${-daysUntilExpiry} days ago)';
    } else if (daysUntilExpiry < 90) {
      statusColor = Colors.orange;
      statusText = 'EXPIRING SOON ($daysUntilExpiry days)';
    } else {
      statusColor = Colors.green;
      statusText = 'VALID ($daysUntilExpiry days)';
    }

    return Row(
      children: [
        Text(
          'Warranty Status:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Chip(
            label: Text(statusText),
            backgroundColor: statusColor.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarrantyStatusChip(DateTime warrantyExpiry) {
    final daysUntilExpiry = warrantyExpiry.difference(DateTime.now()).inDays;

    Color statusColor;
    String statusText;

    if (daysUntilExpiry < 0) {
      statusColor = Colors.red;
      statusText = 'WARRANTY EXPIRED';
    } else if (daysUntilExpiry < 90) {
      statusColor = Colors.orange;
      statusText = 'WARRANTY EXPIRING SOON';
    } else {
      statusColor = Colors.green;
      statusText = 'WARRANTY VALID';
    }

    return Chip(
      label: Text(statusText),
      backgroundColor: statusColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: statusColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
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

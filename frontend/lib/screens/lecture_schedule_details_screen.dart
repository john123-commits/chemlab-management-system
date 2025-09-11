import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/models/lecture_schedule.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/screens/lecture_schedule_form_screen.dart';
import 'package:intl/intl.dart';

class LectureScheduleDetailsScreen extends StatefulWidget {
  final LectureSchedule schedule;

  const LectureScheduleDetailsScreen({super.key, required this.schedule});

  @override
  State<LectureScheduleDetailsScreen> createState() =>
      _LectureScheduleDetailsScreenState();
}

class _LectureScheduleDetailsScreenState
    extends State<LectureScheduleDetailsScreen> {
  final _notesController = TextEditingController();
  final _rejectionReasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.schedule.technicianNotes != null) {
      _notesController.text = widget.schedule.technicianNotes!;
    }
    if (widget.schedule.rejectionReason != null) {
      _rejectionReasonController.text = widget.schedule.rejectionReason!;
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
      final updatedSchedule = await ApiService.updateLectureSchedule(
        widget.schedule.id,
        {
          'status': status,
          if (_notesController.text.trim().isNotEmpty)
            'technician_notes': _notesController.text.trim(),
          if (status == 'rejected' &&
              _rejectionReasonController.text.trim().isNotEmpty)
            'rejection_reason': _rejectionReasonController.text.trim(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
        Navigator.pop(context, updatedSchedule);
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;
    final schedule = widget.schedule;
    final isAdmin = userRole == 'admin';
    final isTechnician = userRole == 'technician';

    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule #${schedule.id}'),
        actions: [
          if (isAdmin || isTechnician)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LectureScheduleFormScreen(
                      schedule: schedule.toJson(),
                    ),
                  ),
                ).then((result) {
                  if (!context.mounted) return;
                  if (result == true && mounted) {
                    Navigator.pop(context, true);
                  }
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Schedule Header
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              schedule.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(schedule.status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusText(schedule.status).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        schedule.description,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      if (schedule.adminName != null) ...[
                        Text(
                          'Admin: ${schedule.adminName}',
                          style: const TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (schedule.technicianName != null) ...[
                        Text(
                          'Technician: ${schedule.technicianName}',
                          style: const TextStyle(color: Colors.green),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy').format(schedule.scheduledDate)} at ${schedule.scheduledTime}',
                      ),
                      Text(
                        'Duration: ${schedule.duration ?? 0} minutes',
                      ),
                      Text(
                        'Priority: ${schedule.priority.toUpperCase()}',
                        style: TextStyle(
                          color: schedule.priority == 'urgent'
                              ? Colors.red
                              : schedule.priority == 'high'
                                  ? Colors.orange
                                  : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(schedule.createdAt)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (schedule.updatedAt != schedule.createdAt) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Updated: ${DateFormat('MMM dd, yyyy HH:mm').format(schedule.updatedAt)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Required Chemicals
              if (_isValidList(schedule.requiredChemicals)) ...[
                Text(
                  'Required Chemicals',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: _buildChemicalList(schedule.requiredChemicals),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Required Equipment
              if (_isValidList(schedule.requiredEquipment)) ...[
                Text(
                  'Required Equipment',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: _buildEquipmentList(schedule.requiredEquipment),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Technician Notes
              if (schedule.technicianNotes != null &&
                  schedule.technicianNotes!.isNotEmpty) ...[
                Text(
                  'Technician Notes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      schedule.technicianNotes!,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Rejection Reason
              if (schedule.rejectionReason != null &&
                  schedule.rejectionReason!.isNotEmpty) ...[
                Text(
                  'Rejection Reason',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      schedule.rejectionReason!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Status Update Section - FIXED: Only technicians can approve/reject
              if (isTechnician) ...[
                if (schedule.status == 'pending') ...[
                  Text(
                    'Update Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Technician Notes (Optional)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _rejectionReasonController,
                            decoration: const InputDecoration(
                              labelText:
                                  'Rejection Reason (Required for Rejection)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _updateStatus('rejected'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : const Text('Reject Request'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _updateStatus('confirmed'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : const Text('Confirm Request'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (schedule.status == 'confirmed') ...[
                  Card(
                    color: Colors.green[100],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'This schedule has been confirmed.',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ),
                ] else if (schedule.status == 'rejected') ...[
                  Card(
                    color: Colors.red[100],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'This schedule has been rejected.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ] else if (schedule.status == 'in_progress') ...[
                  Card(
                    color: Colors.blue[100],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'This schedule is in progress.',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                ] else if (schedule.status == 'completed') ...[
                  Card(
                    color: Colors.grey[100],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'This schedule has been completed.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ] else if (schedule.status == 'cancelled') ...[
                  Card(
                    color: Colors.red[100],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'This schedule has been cancelled.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ] else if (isAdmin) ...[
                // Admin can only view status, not change it
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Information',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          schedule.status == 'pending'
                              ? 'This schedule is awaiting technician approval.'
                              : 'Current status: ${_getStatusText(schedule.status)}',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidList(dynamic data) {
    return data is List && data.isNotEmpty;
  }

  List<Widget> _buildChemicalList(dynamic chemicalsData) {
    if (chemicalsData is! List) {
      return [
        const ListTile(
          title: Text('No valid chemical data available'),
        )
      ];
    }

    List<dynamic> chemicals = chemicalsData;
    if (chemicals.isEmpty) {
      return [
        const ListTile(
          title: Text('No chemicals required'),
        )
      ];
    }

    return chemicals.map((chemical) {
      if (chemical is Map<String, dynamic>) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: const Icon(
              Icons.science,
              color: Colors.blue,
            ),
          ),
          title: Text(chemical['name']?.toString() ?? 'Unknown Chemical'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${chemical['quantity'] ?? ''} ${chemical['unit'] ?? ''}'),
              if (chemical['category'] != null)
                Text('Category: ${chemical['category']}'),
            ],
          ),
        );
      } else {
        return const ListTile(
          title: Text('Invalid chemical data format'),
        );
      }
    }).toList();
  }

  List<Widget> _buildEquipmentList(dynamic equipmentData) {
    if (equipmentData is! List) {
      return [
        const ListTile(
          title: Text('No valid equipment data available'),
        )
      ];
    }

    List<dynamic> equipment = equipmentData;
    if (equipment.isEmpty) {
      return [
        const ListTile(
          title: Text('No equipment required'),
        )
      ];
    }

    return equipment.map((item) {
      if (item is Map<String, dynamic>) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green[100],
            child: const Icon(
              Icons.build,
              color: Colors.green,
            ),
          ),
          title: Text(item['name']?.toString() ?? 'Unknown Equipment'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quantity: ${item['quantity'] ?? ''}'),
              if (item['category'] != null)
                Text('Category: ${item['category']}'),
              if (item['condition'] != null)
                Text('Condition: ${item['condition']}'),
            ],
          ),
        );
      } else {
        return const ListTile(
          title: Text('Invalid equipment data format'),
        );
      }
    }).toList();
  }
}

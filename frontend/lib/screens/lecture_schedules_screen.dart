import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/models/lecture_schedule.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/lecture_schedule_form_screen.dart';
import 'package:intl/intl.dart';

class LectureSchedulesScreen extends StatefulWidget {
  const LectureSchedulesScreen({super.key});

  @override
  State<LectureSchedulesScreen> createState() => _LectureSchedulesScreenState();
}

class _LectureSchedulesScreenState extends State<LectureSchedulesScreen> {
  List<LectureSchedule> _schedules = [];
  String _selectedStatus = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final status = _selectedStatus == 'All' ? null : _selectedStatus;
      final schedules = await ApiService.getLectureSchedules(status: status);
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load schedules: ${error.toString()}')),
        );
      }
    }
  }

  Future<void> _refreshSchedules() async {
    await _loadSchedules();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
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
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;

    return RefreshIndicator(
      onRefresh: _refreshSchedules,
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
                DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                DropdownMenuItem(
                    value: 'in_progress', child: Text('In Progress')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                  _loadSchedules();
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _schedules.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No lecture schedules found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (userRole == 'admin') const SizedBox(height: 16),
                            if (userRole == 'admin')
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LectureScheduleFormScreen(),
                                    ),
                                  ).then((result) {
                                    if (result == true) {
                                      _loadSchedules();
                                    }
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Create Schedule'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _schedules.length,
                        itemBuilder: (context, index) {
                          final schedule = _schedules[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(
                                schedule.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (userRole == 'admin')
                                    Text(
                                        'Technician: ${schedule.technicianName}'),
                                  if (userRole == 'technician')
                                    Text('Admin: ${schedule.adminName}'),
                                  Text(
                                      'Date: ${DateFormat('MMM dd, yyyy').format(schedule.scheduledDate)} at ${schedule.scheduledTime}'),
                                  Text(
                                      'Duration: ${schedule.duration ?? 0} minutes'),
                                  Text(
                                    'Status: ${_getStatusText(schedule.status)}',
                                    style: TextStyle(
                                      color: _getStatusColor(schedule.status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (schedule.priority == 'urgent')
                                    const Text(
                                      'URGENT',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Icon(
                                schedule.priority == 'urgent'
                                    ? Icons.warning
                                    : schedule.priority == 'high'
                                        ? Icons.arrow_upward
                                        : Icons.info,
                                color: schedule.priority == 'urgent'
                                    ? Colors.red
                                    : schedule.priority == 'high'
                                        ? Colors.orange
                                        : Colors.grey,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        LectureScheduleFormScreen(
                                      schedule: schedule.toJson(),
                                    ),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _loadSchedules();
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
          ),
          if (userRole == 'admin')
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LectureScheduleFormScreen(),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _loadSchedules();
                    }
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Schedule'),
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

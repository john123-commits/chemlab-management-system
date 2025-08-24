import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/models/lecture_schedule.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/lecture_schedule_form_screen.dart';
import 'package:chemlab_frontend/screens/lecture_schedule_details_screen.dart'; // ✅ Added import
import 'package:intl/intl.dart';

class LectureSchedulesScreen extends StatefulWidget {
  const LectureSchedulesScreen({super.key});

  @override
  State<LectureSchedulesScreen> createState() => _LectureSchedulesScreenState();
}

class _LectureSchedulesScreenState extends State<LectureSchedulesScreen> {
  List<LectureSchedule> _filteredSchedules = []; // ✅ Added filtered list
  String _selectedStatus = 'All';
  bool _isLoading = true;
  final TextEditingController _searchController =
      TextEditingController(); // ✅ Added search controller

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userRole = authProvider.userRole;
      final userId = authProvider.userId;

      final status = _selectedStatus == 'All' ? null : _selectedStatus;
      final schedules = await ApiService.getLectureSchedules(status: status);

      // ✅ Filter schedules based on user role
      List<LectureSchedule> filteredSchedules;
      if (userRole == 'technician') {
        // Technicians only see schedules assigned to them
        filteredSchedules = schedules
            .where((schedule) => schedule.technicianId == userId)
            .toList();
      } else {
        // Admins see all schedules
        filteredSchedules = schedules;
      }

      // ✅ Apply search filter
      if (_searchController.text.isNotEmpty) {
        final searchLower = _searchController.text.toLowerCase();
        filteredSchedules = filteredSchedules.where((schedule) {
          return schedule.title.toLowerCase().contains(searchLower) ||
              schedule.description.toLowerCase().contains(searchLower);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _filteredSchedules = filteredSchedules;
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
      case 'rejected':
        return Colors.red;
      case 'pending':
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
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  // ✅ Added method to view schedule details
  void _viewScheduleDetails(LectureSchedule schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LectureScheduleDetailsScreen(schedule: schedule),
      ),
    );

    // Refresh the list when returning from details screen
    if (result == true && mounted) {
      _loadSchedules();
    }
  }

  // ✅ Added method to create new schedule
  void _createNewSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LectureScheduleFormScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _loadSchedules(); // Refresh after creating new schedule
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.userRole;
    final isAdmin = userRole == 'admin';
    final isTechnician = userRole == 'technician';

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isTechnician ? 'My Lecture Schedules' : 'Lecture Schedules'),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _createNewSchedule,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSchedules,
        child: Column(
          children: [
            // ✅ Added search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search schedules...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _loadSchedules(); // Apply search filter as user types
                },
              ),
            ),

            // Status filter dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                      value: 'confirmed', child: Text('Confirmed')),
                  DropdownMenuItem(
                      value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(
                      value: 'cancelled', child: Text('Cancelled')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                    _loadSchedules();
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSchedules.isEmpty
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
                                isTechnician
                                    ? 'No lecture schedules assigned to you'
                                    : 'No lecture schedules found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isAdmin) const SizedBox(height: 16),
                              if (isAdmin)
                                ElevatedButton.icon(
                                  onPressed: _createNewSchedule,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Schedule'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredSchedules.length,
                          itemBuilder: (context, index) {
                            final schedule = _filteredSchedules[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  schedule.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isAdmin &&
                                        schedule.technicianName != null)
                                      Text(
                                          'Technician: ${schedule.technicianName}'),
                                    if (isTechnician &&
                                        schedule.adminName != null)
                                      Text('Admin: ${schedule.adminName}'),
                                    Text(
                                        'Date: ${DateFormat('MMM dd, yyyy').format(schedule.scheduledDate)} at ${schedule.scheduledTime}'),
                                    Text(
                                        'Duration: ${schedule.duration ?? 0} minutes'),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(schedule.status),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(schedule.status),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                // ✅ Changed onTap to view details instead of edit form
                                onTap: () => _viewScheduleDetails(schedule),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      // ✅ Added floating action button for admin
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _createNewSchedule,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

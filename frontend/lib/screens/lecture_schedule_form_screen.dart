import 'dart:convert'; // ✅ Added import for jsonDecode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/models/user.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class LectureScheduleFormScreen extends StatefulWidget {
  final Map<String, dynamic>? schedule;

  const LectureScheduleFormScreen({super.key, this.schedule});

  @override
  State<LectureScheduleFormScreen> createState() =>
      _LectureScheduleFormScreenState();
}

class _LectureScheduleFormScreenState extends State<LectureScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _technicianNotesController = TextEditingController();
  List<User> _technicians = [];
  int? _selectedTechnicianId;
  List<Chemical> _availableChemicals = [];
  List<Equipment> _availableEquipment = [];
  List<Map<String, dynamic>> _selectedChemicals = [];
  List<Map<String, dynamic>> _selectedEquipment = [];
  DateTime? _scheduledDate;
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 9, minute: 0);
  int _duration = 60;
  String _priority = 'normal';
  String _status = 'pending';
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      _titleController.text = widget.schedule!['title'];
      _descriptionController.text = widget.schedule!['description'];
      _technicianNotesController.text =
          widget.schedule!['technician_notes'] ?? '';
      _selectedTechnicianId = widget.schedule!['technician_id'];
      _scheduledDate = DateTime.parse(widget.schedule!['scheduled_date']);
      final timeParts = widget.schedule!['scheduled_time'].split(':');
      _scheduledTime = TimeOfDay(
          hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
      _duration = widget.schedule!['duration'] ?? 60;
      _priority = widget.schedule!['priority'];
      _status = widget.schedule!['status'];

      // ✅ FIXED: Safely load selected items from JSON strings
      _selectedChemicals =
          _parseJsonArray(widget.schedule!['required_chemicals']);
      _selectedEquipment =
          _parseJsonArray(widget.schedule!['required_equipment']);
    }
    _loadData();
  }

  // ✅ Added helper method to safely parse JSON arrays
  List<Map<String, dynamic>> _parseJsonArray(dynamic data) {
    if (data == null) return [];

    try {
      if (data is String) {
        // Parse JSON string
        if (data.trim().isEmpty || data == '[]') {
          return [];
        }
        final parsed = jsonDecode(data);
        if (parsed is List) {
          return parsed.cast<Map<String, dynamic>>();
        }
      } else if (data is List) {
        // Already a list
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      logger.d('Error parsing JSON array: $e');
    }
    return [];
  }

  Future<void> _loadData() async {
    try {
      // Load technicians
      final users = await ApiService.getUsers();
      final technicians =
          users.where((user) => user.role == 'technician').toList();

      // Load chemicals and equipment
      final chemicals = await ApiService.getChemicals();
      final equipment = await ApiService.getEquipment();

      if (mounted) {
        setState(() {
          _technicians = technicians;
          _availableChemicals = chemicals;
          _availableEquipment = equipment;
          _isLoading = false;

          // Set default technician if none selected
          if (_selectedTechnicianId == null && technicians.isNotEmpty) {
            _selectedTechnicianId = technicians.first.id;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: ${error.toString()}')),
        );
      }
    }
  }

  void _addChemical(Chemical chemical) {
    setState(() {
      _selectedChemicals.add({
        'id': chemical.id,
        'name': chemical.name,
        'quantity': 1.0,
        'unit': chemical.unit,
      });
    });
  }

  void _addEquipment(Equipment equipment) {
    setState(() {
      _selectedEquipment.add({
        'id': equipment.id,
        'name': equipment.name,
        'quantity': 1,
      });
    });
  }

  void _removeChemical(int index) {
    setState(() {
      _selectedChemicals.removeAt(index);
    });
  }

  void _removeEquipment(int index) {
    setState(() {
      _selectedEquipment.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedTechnicianId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a technician')),
        );
        return;
      }

      if (_scheduledDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date')),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final scheduleData = {
          'technician_id': _selectedTechnicianId,
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'required_chemicals': _selectedChemicals,
          'required_equipment': _selectedEquipment,
          'scheduled_date': DateFormat('yyyy-MM-dd').format(_scheduledDate!),
          'scheduled_time':
              '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
          'duration': _duration,
          'priority': _priority,
          if (widget.schedule != null &&
              _technicianNotesController.text.isNotEmpty)
            'technician_notes': _technicianNotesController.text.trim(),
          if (widget.schedule != null) 'status': _status,
        };

        if (widget.schedule == null) {
          // Create new schedule
          await ApiService.createLectureSchedule(scheduleData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Lecture schedule created successfully')),
            );
            Navigator.pop(context, true);
          }
        } else {
          // Update existing schedule
          await ApiService.updateLectureSchedule(
              widget.schedule!['id'], scheduleData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Lecture schedule updated successfully')),
            );
            Navigator.pop(context, true);
          }
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to save schedule: ${error.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _technicianNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schedule == null
            ? 'Create Lecture Schedule'
            : 'Edit Lecture Schedule'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              // ✅ Added LayoutBuilder for better layout control
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight -
                          kToolbarHeight -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Lecture Title',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Technician selection (Admin only)
                          if (userRole == 'admin') ...[
                            DropdownButtonFormField<int>(
                              initialValue: _selectedTechnicianId,
                              decoration: const InputDecoration(
                                labelText: 'Assign to Technician',
                                border: OutlineInputBorder(),
                              ),
                              items: _technicians.map((technician) {
                                return DropdownMenuItem(
                                  value: technician.id,
                                  child: Text(technician.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedTechnicianId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a technician';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Technician notes (Technician only)
                          if (userRole == 'technician' &&
                              widget.schedule != null) ...[
                            TextFormField(
                              controller: _technicianNotesController,
                              decoration: const InputDecoration(
                                labelText: 'Technician Notes',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Status selection (Technician only)
                          if (userRole == 'technician' &&
                              widget.schedule != null) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'pending', child: Text('Pending')),
                                DropdownMenuItem(
                                    value: 'confirmed',
                                    child: Text('Confirmed')),
                                DropdownMenuItem(
                                    value: 'in_progress',
                                    child: Text('In Progress')),
                                DropdownMenuItem(
                                    value: 'completed',
                                    child: Text('Completed')),
                                DropdownMenuItem(
                                    value: 'cancelled',
                                    child: Text('Cancelled')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _status = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Select Chemicals
                          Text(
                            'Required Chemicals',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _availableChemicals.isEmpty
                                ? const Center(
                                    child: Text('No chemicals available'))
                                : ListView.builder(
                                    itemCount: _availableChemicals.length,
                                    itemBuilder: (context, index) {
                                      final chemical =
                                          _availableChemicals[index];
                                      return CheckboxListTile(
                                        title: Text(chemical.name),
                                        subtitle: Text(
                                          '${chemical.quantity} ${chemical.unit} - ${chemical.category}',
                                        ),
                                        value: _selectedChemicals
                                            .any((c) => c['id'] == chemical.id),
                                        onChanged: (bool? selected) {
                                          if (selected == true) {
                                            _addChemical(chemical);
                                          } else {
                                            final index = _selectedChemicals
                                                .indexWhere((c) =>
                                                    c['id'] == chemical.id);
                                            if (index != -1) {
                                              _removeChemical(index);
                                            }
                                          }
                                        },
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 16),

                          // Selected Chemicals
                          if (_selectedChemicals.isNotEmpty) ...[
                            Text(
                              'Selected Chemicals',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: _selectedChemicals
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key;
                                  final chemical = entry.value;
                                  return ListTile(
                                    title: Text(chemical['name']),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () => _removeChemical(index),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Select Equipment
                          Text(
                            'Required Equipment',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _availableEquipment.isEmpty
                                ? const Center(
                                    child: Text('No equipment available'))
                                : ListView.builder(
                                    itemCount: _availableEquipment.length,
                                    itemBuilder: (context, index) {
                                      final equipment =
                                          _availableEquipment[index];
                                      return CheckboxListTile(
                                        title: Text(equipment.name),
                                        subtitle: Text(
                                          '${equipment.category} - ${equipment.condition}',
                                        ),
                                        value: _selectedEquipment.any(
                                            (e) => e['id'] == equipment.id),
                                        onChanged: (bool? selected) {
                                          if (selected == true) {
                                            _addEquipment(equipment);
                                          } else {
                                            final index = _selectedEquipment
                                                .indexWhere((e) =>
                                                    e['id'] == equipment.id);
                                            if (index != -1) {
                                              _removeEquipment(index);
                                            }
                                          }
                                        },
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 16),

                          // Selected Equipment
                          if (_selectedEquipment.isNotEmpty) ...[
                            Text(
                              'Selected Equipment',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: _selectedEquipment
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key;
                                  final equipment = entry.value;
                                  return ListTile(
                                    title: Text(equipment['name']),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () => _removeEquipment(index),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Schedule Date
                          ListTile(
                            title: const Text('Schedule Date'),
                            subtitle: Text(
                              _scheduledDate == null
                                  ? 'Select date'
                                  : DateFormat('MMM dd, yyyy')
                                      .format(_scheduledDate!),
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _scheduledDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _scheduledDate = pickedDate;
                                });
                              }
                            },
                          ),

                          // Schedule Time
                          ListTile(
                            title: const Text('Schedule Time'),
                            subtitle: Text(
                              '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
                            ),
                            trailing: const Icon(Icons.access_time),
                            onTap: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: _scheduledTime,
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  _scheduledTime = pickedTime;
                                });
                              }
                            },
                          ),

                          // Duration
                          ListTile(
                            title: const Text('Duration (minutes)'),
                            subtitle: Text('$_duration minutes'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () {
                                    setState(() {
                                      if (_duration > 15) _duration -= 15;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    setState(() {
                                      if (_duration < 480) _duration += 15;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Priority
                          DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'low', child: Text('Low')),
                              DropdownMenuItem(
                                  value: 'normal', child: Text('Normal')),
                              DropdownMenuItem(
                                  value: 'high', child: Text('High')),
                              DropdownMenuItem(
                                  value: 'urgent', child: Text('Urgent')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _priority = value!;
                              });
                            },
                          ),

                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator()
                                  : Text(
                                      widget.schedule == null
                                          ? 'Create Schedule'
                                          : 'Update Schedule',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                          const SizedBox(
                              height:
                                  50), // ✅ Added extra bottom padding to prevent overflow
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

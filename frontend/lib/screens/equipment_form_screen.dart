import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class EquipmentFormScreen extends StatefulWidget {
  final Equipment? equipment;

  const EquipmentFormScreen({super.key, this.equipment});

  @override
  State<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends State<EquipmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _conditionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maintenanceScheduleController = TextEditingController();
  // Enhanced controllers
  final _serialNumberController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _storageConditionsController = TextEditingController();
  final _hazardClassController = TextEditingController();
  final _safetyPrecautionsController = TextEditingController();
  final _safetyInfoController = TextEditingController();
  final _msdsLinkController = TextEditingController();

  DateTime? _lastMaintenanceDate;
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiry;
  DateTime? _calibrationDate;
  DateTime? _nextCalibrationDate;
  bool _isLoading = false;
  bool _showAdvancedFields = false; // Toggle for advanced fields

  @override
  void initState() {
    super.initState();
    if (widget.equipment != null) {
      _nameController.text = widget.equipment!.name;
      _categoryController.text = widget.equipment!.category;
      _conditionController.text = widget.equipment!.condition;
      _locationController.text = widget.equipment!.location;
      _maintenanceScheduleController.text =
          widget.equipment!.maintenanceSchedule.toString();
      _lastMaintenanceDate = widget.equipment!.lastMaintenanceDate;
      // Enhanced fields
      _serialNumberController.text = widget.equipment!.serialNumber ?? '';
      _manufacturerController.text = widget.equipment!.manufacturer ?? '';
      _modelController.text = widget.equipment!.model ?? '';
      _purchaseDate = widget.equipment!.purchaseDate;
      _warrantyExpiry = widget.equipment!.warrantyExpiry;
      _calibrationDate = widget.equipment!.calibrationDate;
      _nextCalibrationDate = widget.equipment!.nextCalibrationDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _conditionController.dispose();
    _locationController.dispose();
    _maintenanceScheduleController.dispose();
    // Enhanced controllers
    _serialNumberController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _storageConditionsController.dispose();
    _hazardClassController.dispose();
    _safetyPrecautionsController.dispose();
    _safetyInfoController.dispose();
    _msdsLinkController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final equipmentData = {
          'name': _nameController.text.trim(),
          'category': _categoryController.text.trim(),
          'condition': _conditionController.text.trim(),
          'location': _locationController.text.trim(),
          'maintenance_schedule':
              int.parse(_maintenanceScheduleController.text),
          'last_maintenance_date': _lastMaintenanceDate != null
              ? DateFormat('yyyy-MM-dd').format(_lastMaintenanceDate!)
              : DateTime.now().toIso8601String(),
          // Enhanced fields
          'serial_number': _serialNumberController.text.trim(),
          'manufacturer': _manufacturerController.text.trim(),
          'model': _modelController.text.trim(),
          'purchase_date': _purchaseDate != null
              ? DateFormat('yyyy-MM-dd').format(_purchaseDate!)
              : null,
          'warranty_expiry': _warrantyExpiry != null
              ? DateFormat('yyyy-MM-dd').format(_warrantyExpiry!)
              : null,
          'calibration_date': _calibrationDate != null
              ? DateFormat('yyyy-MM-dd').format(_calibrationDate!)
              : null,
          'next_calibration_date': _nextCalibrationDate != null
              ? DateFormat('yyyy-MM-dd').format(_nextCalibrationDate!)
              : null,
        };

        if (widget.equipment == null) {
          await ApiService.createEquipment(equipmentData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Equipment added successfully')),
          );
        } else {
          await ApiService.updateEquipment(widget.equipment!.id, equipmentData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Equipment updated successfully')),
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: ${error.toString()}')),
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
    // Check if user is borrower - they should never access this screen
    final userRole = Provider.of<AuthProvider>(context).userRole;
    if (userRole == 'borrower') {
      // Immediately navigate back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Access denied: Insufficient permissions')),
          );
          Navigator.pop(context);
        }
      });

      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Access Denied'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.equipment == null ? 'Add Equipment' : 'Edit Equipment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Equipment Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter equipment name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conditionController,
                decoration: const InputDecoration(
                  labelText: 'Condition *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter condition';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maintenanceScheduleController,
                decoration: const InputDecoration(
                  labelText: 'Maintenance Schedule (days) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter maintenance schedule';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  final parsedValue = int.tryParse(value);
                  if (parsedValue != null && parsedValue <= 0) {
                    return 'Maintenance schedule must be positive';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Last Maintenance Date *'),
                subtitle: Text(
                  _lastMaintenanceDate == null
                      ? 'Select date'
                      : DateFormat('MMM dd, yyyy')
                          .format(_lastMaintenanceDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _lastMaintenanceDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null && mounted) {
                    setState(() {
                      _lastMaintenanceDate = pickedDate;
                    });
                  }
                },
              ),

              // Advanced Fields Section
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAdvancedFields = !_showAdvancedFields;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Advanced Equipment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Icon(
                      _showAdvancedFields
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (_showAdvancedFields) ...[
                const Divider(),
                TextFormField(
                  controller: _serialNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Serial Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _manufacturerController,
                  decoration: const InputDecoration(
                    labelText: 'Manufacturer',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Purchase Date'),
                  subtitle: Text(
                    _purchaseDate == null
                        ? 'Select purchase date'
                        : DateFormat('MMM dd, yyyy').format(_purchaseDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _purchaseDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null && mounted) {
                      setState(() {
                        _purchaseDate = pickedDate;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Warranty Expiry'),
                  subtitle: Text(
                    _warrantyExpiry == null
                        ? 'Select warranty expiry date'
                        : DateFormat('MMM dd, yyyy').format(_warrantyExpiry!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _warrantyExpiry ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (pickedDate != null && mounted) {
                      setState(() {
                        _warrantyExpiry = pickedDate;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Last Calibration Date'),
                  subtitle: Text(
                    _calibrationDate == null
                        ? 'Select calibration date'
                        : DateFormat('MMM dd, yyyy').format(_calibrationDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _calibrationDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null && mounted) {
                      setState(() {
                        _calibrationDate = pickedDate;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Next Calibration Date'),
                  subtitle: Text(
                    _nextCalibrationDate == null
                        ? 'Select next calibration date'
                        : DateFormat('MMM dd, yyyy')
                            .format(_nextCalibrationDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _nextCalibrationDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (pickedDate != null && mounted) {
                      setState(() {
                        _nextCalibrationDate = pickedDate;
                      });
                    }
                  },
                ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          widget.equipment == null
                              ? 'Add Equipment'
                              : 'Update Equipment',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

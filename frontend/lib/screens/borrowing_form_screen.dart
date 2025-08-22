import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class BorrowingFormScreen extends StatefulWidget {
  const BorrowingFormScreen({super.key});

  @override
  State<BorrowingFormScreen> createState() => _BorrowingFormScreenState();
}

class _BorrowingFormScreenState extends State<BorrowingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _researchDetailsController = TextEditingController();

  // Add controllers for student information
  final _universityController = TextEditingController();
  final _educationLevelController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _studentNumberController = TextEditingController();
  final _currentYearController = TextEditingController();
  final _semesterController = TextEditingController();
  final _borrowerEmailController = TextEditingController();
  final _borrowerContactController = TextEditingController();

  List<Chemical> _availableChemicals = [];
  List<Equipment> _availableEquipment = [];
  final List<Map<String, dynamic>> _selectedChemicals = [];
  final List<Map<String, dynamic>> _selectedEquipment = [];
  DateTime? _borrowDate;
  DateTime? _returnDate;
  DateTime? _visitDate;
  TimeOfDay _visitTime = TimeOfDay.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      final chemicals = await ApiService.getChemicals();
      final equipment = await ApiService.getEquipment();

      setState(() {
        _availableChemicals = chemicals;
        _availableEquipment = equipment;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load inventory')),
      );
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

  void _updateChemicalQuantity(int index, double quantity) {
    setState(() {
      _selectedChemicals[index]['quantity'] = quantity;
    });
  }

  void _updateEquipmentQuantity(int index, int quantity) {
    setState(() {
      _selectedEquipment[index]['quantity'] = quantity;
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedChemicals.isEmpty && _selectedEquipment.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one item')),
        );
        return;
      }

      if (_borrowDate == null || _returnDate == null || _visitDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select all dates')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Format the data correctly for the API
        final borrowingData = {
          'chemicals': _selectedChemicals,
          'equipment': _selectedEquipment,
          'purpose': _purposeController.text.trim(),
          'research_details': _researchDetailsController.text.trim(),
          'borrow_date': DateFormat('yyyy-MM-dd').format(_borrowDate!),
          'return_date': DateFormat('yyyy-MM-dd').format(_returnDate!),
          'visit_date': DateFormat('yyyy-MM-dd').format(_visitDate!),
          'visit_time':
              '${_visitTime.hour.toString().padLeft(2, '0')}:${_visitTime.minute.toString().padLeft(2, '0')}',
          // Add student information
          'university': _universityController.text.trim(),
          'education_level': _educationLevelController.text.trim(),
          'registration_number': _registrationNumberController.text.trim(),
          'student_number': _studentNumberController.text.trim(),
          'current_year': int.tryParse(_currentYearController.text.trim()) ?? 1,
          'semester': _semesterController.text.trim(),
          'borrower_email': _borrowerEmailController.text.trim(),
          'borrower_contact': _borrowerContactController.text.trim(),
        };

        logger.d('Sending borrowing data: $borrowingData'); // Debug log

        await ApiService.createBorrowing(borrowingData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Borrowing request submitted successfully')),
        );

        Navigator.pop(context, true);
      } catch (error) {
        logger.d('Error submitting borrowing request: $error'); // Debug log
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to submit request: ${error.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _researchDetailsController.dispose();
    // Dispose student information controllers
    _universityController.dispose();
    _educationLevelController.dispose();
    _registrationNumberController.dispose();
    _studentNumberController.dispose();
    _currentYearController.dispose();
    _semesterController.dispose();
    _borrowerEmailController.dispose();
    _borrowerContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Borrowing'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Information Section
                    Text(
                      'Student Information',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _universityController,
                      decoration: const InputDecoration(
                        labelText: 'University *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your university name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter university name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _educationLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Current Level of Education *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Bachelor\'s, Master\'s, PhD',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter current level of education';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Registration Number and Name *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your registration number',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter registration number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _studentNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Student Number *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your student number',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter student number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _currentYearController,
                      decoration: const InputDecoration(
                        labelText: 'Current Year *',
                        border: OutlineInputBorder(),
                        hintText:
                            'Enter current academic year (e.g., 1, 2, 3, 4)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter current year';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        final year = int.tryParse(value)!;
                        if (year < 1 || year > 10) {
                          return 'Please enter a valid year (1-10)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _semesterController,
                      decoration: const InputDecoration(
                        labelText: 'Semester *',
                        border: OutlineInputBorder(),
                        hintText:
                            'Enter current semester (e.g., Semester 1, Spring 2024)',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter semester';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _borrowerEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your email address',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _borrowerContactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your phone number',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter contact number';
                        }
                        if (value.length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Purpose and Research Details
                    Text(
                      'Borrowing Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _purposeController,
                      decoration: const InputDecoration(
                        labelText: 'Purpose *',
                        border: OutlineInputBorder(),
                        hintText: 'Briefly describe the purpose of borrowing',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter purpose';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _researchDetailsController,
                      decoration: const InputDecoration(
                        labelText: 'Research Details *',
                        border: OutlineInputBorder(),
                        hintText:
                            'Provide detailed information about your research',
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter research details';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Chemicals Selection
                    Text(
                      'Select Chemicals',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _availableChemicals.isEmpty
                          ? const Center(child: Text('No chemicals available'))
                          : ListView.builder(
                              itemCount: _availableChemicals.length,
                              itemBuilder: (context, index) {
                                final chemical = _availableChemicals[index];
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
                                      final index =
                                          _selectedChemicals.indexWhere(
                                              (c) => c['id'] == chemical.id);
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

                    // Selected Chemicals with Quantity
                    if (_selectedChemicals.isNotEmpty) ...[
                      Text(
                        'Selected Chemicals',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children:
                              _selectedChemicals.asMap().entries.map((entry) {
                            final index = entry.key;
                            final chemical = entry.value;
                            return ListTile(
                              title: Text(chemical['name']),
                              subtitle: Row(
                                children: [
                                  const Text('Quantity: '),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      initialValue:
                                          chemical['quantity'].toString(),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      onChanged: (value) {
                                        final quantity =
                                            double.tryParse(value) ?? 1.0;
                                        _updateChemicalQuantity(
                                            index, quantity);
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.all(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(chemical['unit']),
                                ],
                              ),
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

                    // Equipment Selection
                    Text(
                      'Select Equipment',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _availableEquipment.isEmpty
                          ? const Center(child: Text('No equipment available'))
                          : ListView.builder(
                              itemCount: _availableEquipment.length,
                              itemBuilder: (context, index) {
                                final equipment = _availableEquipment[index];
                                return CheckboxListTile(
                                  title: Text(equipment.name),
                                  subtitle: Text(
                                    '${equipment.category} - ${equipment.condition}',
                                  ),
                                  value: _selectedEquipment
                                      .any((e) => e['id'] == equipment.id),
                                  onChanged: (bool? selected) {
                                    if (selected == true) {
                                      _addEquipment(equipment);
                                    } else {
                                      final index =
                                          _selectedEquipment.indexWhere(
                                              (e) => e['id'] == equipment.id);
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

                    // Selected Equipment with Quantity
                    if (_selectedEquipment.isNotEmpty) ...[
                      Text(
                        'Selected Equipment',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children:
                              _selectedEquipment.asMap().entries.map((entry) {
                            final index = entry.key;
                            final equipment = entry.value;
                            return ListTile(
                              title: Text(equipment['name']),
                              subtitle: Row(
                                children: [
                                  const Text('Quantity: '),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      initialValue:
                                          equipment['quantity'].toString(),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final quantity =
                                            int.tryParse(value) ?? 1;
                                        _updateEquipmentQuantity(
                                            index, quantity);
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.all(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

                    // Date Selection
                    Text(
                      'Schedule Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Borrow Date *'),
                      subtitle: Text(
                        _borrowDate == null
                            ? 'Select date'
                            : DateFormat('MMM dd, yyyy').format(_borrowDate!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null && mounted) {
                          setState(() {
                            _borrowDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Return Date *'),
                      subtitle: Text(
                        _returnDate == null
                            ? 'Select date'
                            : DateFormat('MMM dd, yyyy').format(_returnDate!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        if (_borrowDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Please select borrow date first')),
                          );
                          return;
                        }
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate:
                              _borrowDate!.add(const Duration(days: 1)),
                          firstDate: _borrowDate!.add(const Duration(days: 1)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null && mounted) {
                          setState(() {
                            _returnDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Visit Date *'),
                      subtitle: Text(
                        _visitDate == null
                            ? 'Select date'
                            : DateFormat('MMM dd, yyyy').format(_visitDate!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null && mounted) {
                          setState(() {
                            _visitDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Visit Time *'),
                      subtitle: Text(
                        '${_visitTime.hour.toString().padLeft(2, '0')}:${_visitTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _visitTime,
                        );
                        if (pickedTime != null && mounted) {
                          setState(() {
                            _visitTime = pickedTime;
                          });
                        }
                      },
                    ),
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
                            : const Text(
                                'Submit Request',
                                style: TextStyle(fontSize: 16),
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

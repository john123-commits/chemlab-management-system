import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:intl/intl.dart';

class BorrowingFormScreen extends StatefulWidget {
  const BorrowingFormScreen({super.key});

  @override
  _BorrowingFormScreenState createState() => _BorrowingFormScreenState();
}

class _BorrowingFormScreenState extends State<BorrowingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _researchDetailsController = TextEditingController();
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
        final borrowingData = {
          'chemicals': _selectedChemicals,
          'equipment': _selectedEquipment,
          'purpose': _purposeController.text.trim(),
          'research_details': _researchDetailsController.text.trim(),
          'borrow_date': DateFormat('yyyy-MM-dd').format(_borrowDate!),
          'return_date': DateFormat('yyyy-MM-dd').format(_returnDate!),
          'visit_date': DateFormat('yyyy-MM-dd').format(_visitDate!),
          'visit_time':
              '${_visitTime.hour}:${_visitTime.minute.toString().padLeft(2, '0')}',
        };

        await ApiService.createBorrowing(borrowingData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Borrowing request submitted successfully')),
        );

        Navigator.pop(context, true);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to submit request: ${error.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _researchDetailsController.dispose();
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
                    TextFormField(
                      controller: _purposeController,
                      decoration: const InputDecoration(
                        labelText: 'Purpose',
                        border: OutlineInputBorder(),
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
                        labelText: 'Research Details',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter research details';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Select Chemicals',
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
                          children:
                              _selectedChemicals.asMap().entries.map((entry) {
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
                    Text(
                      'Select Equipment',
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
                          children:
                              _selectedEquipment.asMap().entries.map((entry) {
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
                    ListTile(
                      title: const Text('Borrow Date'),
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
                        if (pickedDate != null) {
                          setState(() {
                            _borrowDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Return Date'),
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
                        if (pickedDate != null) {
                          setState(() {
                            _returnDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Visit Date'),
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
                        if (pickedDate != null) {
                          setState(() {
                            _visitDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Visit Time'),
                      subtitle: Text(
                        '${_visitTime.hour}:${_visitTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _visitTime,
                        );
                        if (pickedTime != null) {
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
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
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

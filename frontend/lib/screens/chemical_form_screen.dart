import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class ChemicalFormScreen extends StatefulWidget {
  final Chemical? chemical;

  const ChemicalFormScreen({super.key, this.chemical});

  @override
  State<ChemicalFormScreen> createState() => _ChemicalFormScreenState();
}

class _ChemicalFormScreenState extends State<ChemicalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _storageLocationController = TextEditingController();
  DateTime? _expiryDate;
  String? _safetyDataSheetPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.chemical != null) {
      _nameController.text = widget.chemical!.name;
      _categoryController.text = widget.chemical!.category;
      _quantityController.text = widget.chemical!.quantity.toStringAsFixed(2);
      _unitController.text = widget.chemical!.unit;
      _storageLocationController.text = widget.chemical!.storageLocation;
      _expiryDate = widget.chemical!.expiryDate;
      _safetyDataSheetPath = widget.chemical!.safetyDataSheet;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _storageLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _safetyDataSheetPath = result.files.single.path;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Debug logging
        logger.d('=== FLUTTER CHEMICAL FORM DEBUG ===');
        logger.d('Form values:');
        logger.d('  Name: "${_nameController.text.trim()}"');
        logger.d('  Category: "${_categoryController.text.trim()}"');
        logger.d('  Quantity text: "${_quantityController.text}"');
        logger.d('  Unit: "${_unitController.text.trim()}"');
        logger.d('  Storage: "${_storageLocationController.text.trim()}"');
        logger.d('  Expiry Date: $_expiryDate');

        // Parse quantity with detailed logging
        final quantityText = _quantityController.text.trim();
        final quantity = double.tryParse(quantityText);

        logger.d('  Parsed quantity: $quantity');
        logger.d('  Quantity type: ${quantity?.runtimeType}');

        if (quantity == null) {
          throw Exception(
              'Invalid quantity: "$quantityText" is not a valid number');
        }

        if (quantity < 0) {
          throw Exception('Quantity cannot be negative: $quantity');
        }

        final chemicalData = {
          'name': _nameController.text.trim(),
          'category': _categoryController.text.trim(),
          'quantity': quantity, // Send as number
          'unit': _unitController.text.trim(),
          'storage_location': _storageLocationController.text.trim(),
          'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate!),
          'safety_data_sheet': _safetyDataSheetPath,
        };

        logger.d('Sending chemical data: $chemicalData');

        if (widget.chemical == null) {
          logger.d('Calling ApiService.createChemical...');
          await ApiService.createChemical(chemicalData);
          logger.d('Chemical creation successful!');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chemical added successfully')),
          );
        } else {
          logger.d('Calling ApiService.updateChemical...');
          await ApiService.updateChemical(widget.chemical!.id, chemicalData);
          logger.d('Chemical update successful!');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chemical updated successfully')),
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (error) {
        logger.e('=== FLUTTER APP ERROR ===');
        logger.e('Error type: ${error.runtimeType}');
        logger.e('Error message: $error');
        logger.e(
            'Stack trace: ${error is Error ? error.stackTrace : 'No stack trace'}');

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chemical == null ? 'Add Chemical' : 'Edit Chemical'),
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
                  labelText: 'Chemical Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter chemical name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        final parsedValue = double.tryParse(value);
                        if (parsedValue != null && parsedValue < 0) {
                          return 'Quantity cannot be negative';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter unit';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storageLocationController,
                decoration: const InputDecoration(
                  labelText: 'Storage Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter storage location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Expiry Date'),
                subtitle: Text(
                  _expiryDate == null
                      ? 'Select expiry date'
                      : DateFormat('MMM dd, yyyy').format(_expiryDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _expiryDate = pickedDate;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Safety Data Sheet'),
                subtitle: Text(
                  _safetyDataSheetPath == null
                      ? 'No file selected'
                      : _safetyDataSheetPath!.split('/').last,
                ),
                trailing: const Icon(Icons.attach_file),
                onTap: _pickFile,
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
                      : Text(
                          widget.chemical == null
                              ? 'Add Chemical'
                              : 'Update Chemical',
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

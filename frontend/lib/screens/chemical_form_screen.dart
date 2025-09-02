import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
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
  // Enhanced controllers
  final _cNumberController = TextEditingController();
  final _molecularFormulaController = TextEditingController();
  final _molecularWeightController = TextEditingController();
  final _phicalStateController = TextEditingController();
  final _colorController = TextEditingController();
  final _densityController = TextEditingController();
  final _meltingPointController = TextEditingController();
  final _boilingPointController = TextEditingController();
  final _solubilityController = TextEditingController();
  final _storageConditionsController = TextEditingController();
  final _hazardClassController = TextEditingController();
  final _safetyPrecautionsController = TextEditingController();
  final _safetyInfoController = TextEditingController();
  final _msdsLinkController = TextEditingController();

  DateTime? _expiryDate;
  String? _safetyDataSheetPath;
  bool _isLoading = false;
  bool _showAdvancedFields = false; // Toggle for advanced fields

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
      // Enhanced fields
      _cNumberController.text = widget.chemical!.cNumber ?? '';
      _molecularFormulaController.text =
          widget.chemical!.molecularFormula ?? '';
      _molecularWeightController.text =
          widget.chemical!.molecularWeight?.toString() ?? '';
      _phicalStateController.text = widget.chemical!.phicalState ?? '';
      _colorController.text = widget.chemical!.color ?? '';
      _densityController.text = widget.chemical!.density?.toString() ?? '';
      _meltingPointController.text = widget.chemical!.meltingPoint ?? '';
      _boilingPointController.text = widget.chemical!.boilingPoint ?? '';
      _solubilityController.text = widget.chemical!.solubility ?? '';
      _storageConditionsController.text =
          widget.chemical!.storageConditions ?? '';
      _hazardClassController.text = widget.chemical!.hazardClass ?? '';
      _safetyPrecautionsController.text =
          widget.chemical!.safetyPrecautions ?? '';
      _safetyInfoController.text = widget.chemical!.safetyInfo ?? '';
      _msdsLinkController.text = widget.chemical!.msdsLink ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _storageLocationController.dispose();
    // Enhanced controllers
    _cNumberController.dispose();
    _molecularFormulaController.dispose();
    _molecularWeightController.dispose();
    _phicalStateController.dispose();
    _colorController.dispose();
    _densityController.dispose();
    _meltingPointController.dispose();
    _boilingPointController.dispose();
    _solubilityController.dispose();
    _storageConditionsController.dispose();
    _hazardClassController.dispose();
    _safetyPrecautionsController.dispose();
    _safetyInfoController.dispose();
    _msdsLinkController.dispose();
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
        final quantityText = _quantityController.text.trim();
        final quantity = double.tryParse(quantityText);

        if (quantity == null) {
          throw Exception(
              'Invalid quantity: "$quantityText" is not a valid number');
        }

        if (quantity < 0) {
          throw Exception('Quantity cannot be negative: $quantity');
        }

        // Parse enhanced numeric fields
        double? parseDouble(String value) {
          if (value.isEmpty) return null;
          return double.tryParse(value);
        }

        final chemicalData = {
          'name': _nameController.text.trim(),
          'category': _categoryController.text.trim(),
          'quantity': quantity,
          'unit': _unitController.text.trim(),
          'storage_location': _storageLocationController.text.trim(),
          'expiry_date': _expiryDate != null
              ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
              : DateTime.now().add(Duration(days: 365)).toIso8601String(),
          'safety_data_sheet': _safetyDataSheetPath,
          // Enhanced fields
          'c_number': _cNumberController.text.trim(),
          'molecular_formula': _molecularFormulaController.text.trim(),
          'molecular_weight':
              parseDouble(_molecularWeightController.text.trim()),
          'phical_state': _phicalStateController.text.trim(),
          'color': _colorController.text.trim(),
          'density': parseDouble(_densityController.text.trim()),
          'melting_point': _meltingPointController.text.trim(),
          'boiling_point': _boilingPointController.text.trim(),
          'solubility': _solubilityController.text.trim(),
          'storage_conditions': _storageConditionsController.text.trim(),
          'hazard_class': _hazardClassController.text.trim(),
          'safety_precautions': _safetyPrecautionsController.text.trim(),
          'safety_info': _safetyInfoController.text.trim(),
          'msds_link': _msdsLinkController.text.trim(),
        };

        if (widget.chemical == null) {
          await ApiService.createChemical(chemicalData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chemical added successfully')),
          );
        } else {
          await ApiService.updateChemical(widget.chemical!.id, chemicalData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chemical updated successfully')),
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
                  labelText: 'Chemical Name *',
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
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
                        labelText: 'Unit *',
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
                  labelText: 'Storage Location *',
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
                title: const Text('Expiry Date *'),
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
                      'Advanced Chemical Properties',
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
                  controller: _cNumberController,
                  decoration: const InputDecoration(
                    labelText: 'CAS Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _molecularFormulaController,
                  decoration: const InputDecoration(
                    labelText: 'Molecular Formula',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _molecularWeightController,
                  decoration: const InputDecoration(
                    labelText: 'Molecular Weight (g/mol)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phicalStateController,
                  decoration: const InputDecoration(
                    labelText: 'Physical State',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _densityController,
                  decoration: const InputDecoration(
                    labelText: 'Density (g/cm³)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _meltingPointController,
                  decoration: const InputDecoration(
                    labelText: 'Melting Point (°C)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _boilingPointController,
                  decoration: const InputDecoration(
                    labelText: 'Boiling Point (°C)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _solubilityController,
                  decoration: const InputDecoration(
                    labelText: 'Solubility',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _storageConditionsController,
                  decoration: const InputDecoration(
                    labelText: 'Storage Conditions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hazardClassController,
                  decoration: const InputDecoration(
                    labelText: 'Hazard Class',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _safetyPrecautionsController,
                  decoration: const InputDecoration(
                    labelText: 'Safety Precautions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _safetyInfoController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Safety Information',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _msdsLinkController,
                  decoration: const InputDecoration(
                    labelText: 'MSDS Link (URL)',
                    border: OutlineInputBorder(),
                  ),
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

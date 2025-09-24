import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ChemicalUsageLogScreen extends StatefulWidget {
  final Chemical chemical;

  const ChemicalUsageLogScreen({super.key, required this.chemical});

  @override
  State<ChemicalUsageLogScreen> createState() => _ChemicalUsageLogScreenState();
}

class _ChemicalUsageLogScreenState extends State<ChemicalUsageLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();
  final _experimentRefController = TextEditingController();

  DateTime _usageDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    _experimentRefController.dispose();
    super.dispose();
  }

  Future<void> _logUsage() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final quantityUsed = double.parse(_quantityController.text.trim());

        if (quantityUsed > widget.chemical.quantity) {
          throw Exception('Cannot use ${quantityUsed}${widget.chemical.unit}. '
              'Available: ${widget.chemical.quantity}${widget.chemical.unit}');
        }

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final usageData = {
          'quantity_used': quantityUsed,
          'purpose': _purposeController.text.trim(),
          'notes': _notesController.text.trim(),
          'experiment_reference': _experimentRefController.text.trim(),
          'usage_date': _usageDate.toIso8601String(),
          'user_id': authProvider.userId,
        };

        final result =
            await ApiService.logChemicalUsage(widget.chemical.id, usageData);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Usage logged successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to log usage: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
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
        title: const Text('Log Chemical Usage'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chemical Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chemical.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.inventory_2,
                            size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Available: ${widget.chemical.quantity}${widget.chemical.unit}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Location: ${widget.chemical.storageLocation}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Usage Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Usage Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantity Used
                  TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity Used (${widget.chemical.unit}) *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.science),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter quantity used';
                      }
                      final quantity = double.tryParse(value);
                      if (quantity == null || quantity <= 0) {
                        return 'Please enter a valid positive number';
                      }
                      if (quantity > widget.chemical.quantity) {
                        return 'Cannot exceed available quantity (${widget.chemical.quantity}${widget.chemical.unit})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Purpose
                  TextFormField(
                    controller: _purposeController,
                    decoration: const InputDecoration(
                      labelText: 'Purpose *',
                      border: OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.assignment),
                      hintText:
                          'e.g., pH buffer preparation, crystallization experiment',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the purpose of usage';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Experiment Reference
                  TextFormField(
                    controller: _experimentRefController,
                    decoration: const InputDecoration(
                      labelText: 'Experiment Reference',
                      border: OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.science),
                      hintText: 'e.g., EXP-2024-001, Lab Session 5',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Usage Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usage Date *'),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy - HH:mm').format(_usageDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _usageDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_usageDate),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _usageDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes',
                      border: OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.notes),
                      hintText:
                          'Any additional information about this usage...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _logUsage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Log Usage',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This will automatically update the remaining quantity of ${widget.chemical.name}',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

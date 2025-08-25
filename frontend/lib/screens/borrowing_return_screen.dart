import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/borrowing.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class BorrowingReturnScreen extends StatefulWidget {
  final Borrowing borrowing;

  const BorrowingReturnScreen({super.key, required this.borrowing});

  @override
  State<BorrowingReturnScreen> createState() => _BorrowingReturnScreenState();
}

class _BorrowingReturnScreenState extends State<BorrowingReturnScreen> {
  final _notesController = TextEditingController();
  final Map<String, Map<String, dynamic>> _equipmentConditions = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize equipment conditions
    for (var equipment in widget.borrowing.equipment) {
      _equipmentConditions[equipment['id'].toString()] = {
        'status': 'good', // good, damaged, broken
        'notes': '',
      };
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReturn() async {
    setState(() => _isLoading = true);

    try {
      // ✅ DEBUG: Log the data being sent
      logger.d('=== RETURN SUBMISSION DEBUG ===');
      logger.d('Borrowing ID: ${widget.borrowing.id}');
      logger.d('Equipment Conditions: $_equipmentConditions');
      logger.d('Return Notes: ${_notesController.text.trim()}');

      final result = await ApiService.markBorrowingAsReturned(
        widget.borrowing.id,
        {
          'equipmentCondition': _equipmentConditions,
          'returnNotes': _notesController.text.trim(),
        },
      );

      logger.d('Return API result: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Borrowing marked as returned successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (error) {
      logger.e('=== RETURN ERROR ===');
      logger.e('Failed to mark as returned: $error');
      logger.e('Error type: ${error.runtimeType}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to mark as returned: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Return Confirmation #${widget.borrowing.id}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Borrowing Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.borrowing.borrowerName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Borrowed: ${widget.borrowing.createdAt}'),
                    Text('Purpose: ${widget.borrowing.purpose}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Equipment Condition Assessment
            Text(
              'Equipment Condition Assessment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            ...widget.borrowing.equipment.map((equipment) {
              final equipmentId = equipment['id'].toString();
              final condition = _equipmentConditions[equipmentId] ??
                  {'status': 'good', 'notes': ''};

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Quantity: ${equipment['quantity']}'),
                      const SizedBox(height: 12),

                      // Condition Selection
                      DropdownButtonFormField<String>(
                        value: condition['status'],
                        decoration: const InputDecoration(
                          labelText: 'Condition',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'good', child: Text('Good')),
                          DropdownMenuItem(
                              value: 'damaged', child: Text('Damaged')),
                          DropdownMenuItem(
                              value: 'broken', child: Text('Broken')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _equipmentConditions[equipmentId] = {
                              ...condition,
                              'status': value!,
                            };
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Condition Notes
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Condition Notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        onChanged: (value) {
                          setState(() {
                            _equipmentConditions[equipmentId] = {
                              ...condition,
                              'notes': value,
                            };
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            // General Return Notes
            const SizedBox(height: 24),
            Text(
              'Return Notes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional notes about the return',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReturn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Confirm Return',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

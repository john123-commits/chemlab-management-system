import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/equipment_details_screen.dart';
import 'package:chemlab_frontend/screens/equipment_form_screen.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  List<Equipment> _equipment = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    try {
      final equipment = await ApiService.getEquipment();
      setState(() {
        _equipment = equipment;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load equipment')),
      );
    }
  }

  Future<void> _refreshEquipment() async {
    await _loadEquipment();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;
    final isBorrower = userRole == 'borrower';

    return RefreshIndicator(
      onRefresh: _refreshEquipment,
      child: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _equipment.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.build_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No equipment found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _equipment.length,
                        itemBuilder: (context, index) {
                          final eq = _equipment[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green[100],
                                child: const Icon(
                                  Icons.build,
                                  color: Colors.green,
                                ),
                              ),
                              title: Text(eq.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(eq.category),
                                  Text('Condition: ${eq.condition}'),
                                  Text('Location: ${eq.location}'),
                                  Text(
                                    'Last Maintenance: ${DateFormat('MMM dd, yyyy').format(eq.lastMaintenanceDate)}',
                                    style: TextStyle(
                                      color: eq.lastMaintenanceDate
                                                  .add(Duration(
                                                      days: eq
                                                          .maintenanceSchedule))
                                                  .difference(DateTime.now())
                                                  .inDays <
                                              30
                                          ? Colors.orange
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              // Only show popup menu for admin/technician
                              trailing: !isBorrower
                                  ? PopupMenuButton(
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'Edit',
                                          child: Text('Edit'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'Edit') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EquipmentFormScreen(
                                                equipment: eq,
                                              ),
                                            ),
                                          ).then((_) => _loadEquipment());
                                        } else if (value == 'Delete') {
                                          _deleteEquipment(eq);
                                        }
                                      },
                                    )
                                  : null,
                              onTap: () {
                                // Navigate to equipment details screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EquipmentDetailsScreen(equipment: eq),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
          // Only show add button for admin/technician
          if (!isBorrower)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EquipmentFormScreen(),
                    ),
                  ).then((_) => _loadEquipment());
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Equipment'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteEquipment(Equipment equipment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Equipment'),
        content: Text('Are you sure you want to delete ${equipment.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.deleteEquipment(equipment.id);
        _loadEquipment();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment deleted successfully')),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete equipment')),
        );
      }
    }
  }
}

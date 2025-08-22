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
  List<Equipment> _filteredEquipment = [];
  bool _isLoading = true;
  String _searchQuery = '';

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
        _filteredEquipment = equipment;
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

  void _filterEquipment() {
    setState(() {
      _filteredEquipment = _equipment.where((eq) {
        final matchesSearch = _searchQuery.isEmpty ||
            eq.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            eq.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            eq.condition.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            eq.location.toLowerCase().contains(_searchQuery.toLowerCase());

        return matchesSearch;
      }).toList();
    });
  }

  Future<void> _refreshEquipment() async {
    await _loadEquipment();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;
    final isBorrower = userRole == 'borrower';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment'),
        actions: [
          if (!isBorrower)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EquipmentFormScreen(),
                  ),
                ).then((_) => _loadEquipment());
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshEquipment,
        child: Column(
          children: [
            // Search Bar - Wrapped in Material widget to fix error
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Material(
                type: MaterialType.transparency,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search equipment...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterEquipment();
                  },
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredEquipment.isEmpty
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
                              const SizedBox(height: 16),
                              if (isBorrower)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // Go back to dashboard
                                    Navigator.popUntil(
                                        context, (route) => route.isFirst);
                                  },
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Back to Dashboard'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredEquipment.length,
                          itemBuilder: (context, index) {
                            final eq = _filteredEquipment[index];
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
            // Back to dashboard button for borrowers
            if (isBorrower && _filteredEquipment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Go back to dashboard
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            // Add button for admin/technician
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

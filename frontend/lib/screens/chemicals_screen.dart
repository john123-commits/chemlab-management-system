import 'package:chemlab_frontend/screens/chemical_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/chemical_form_screen.dart';
import 'package:intl/intl.dart';

class ChemicalsScreen extends StatefulWidget {
  const ChemicalsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChemicalsScreenState createState() => _ChemicalsScreenState();
}

class _ChemicalsScreenState extends State<ChemicalsScreen> {
  List<Chemical> _chemicals = [];
  List<Chemical> _filteredChemicals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadChemicals();
  }

  Future<void> _loadChemicals() async {
    try {
      final chemicals = await ApiService.getChemicals();
      setState(() {
        _chemicals = chemicals;
        _filteredChemicals = chemicals;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load chemicals')),
      );
    }
  }

  void _filterChemicals() {
    setState(() {
      _filteredChemicals = _chemicals.where((chemical) {
        final matchesSearch = _searchQuery.isEmpty ||
            chemical.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            chemical.category
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());

        final matchesCategory = _selectedCategory == 'All' ||
            chemical.category == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  List<String> _getCategories() {
    final categories = _chemicals.map((c) => c.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  Future<void> _refreshChemicals() async {
    await _loadChemicals();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshChemicals,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search chemicals...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterChemicals();
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _getCategories().map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                      _filterChemicals();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChemicals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No chemicals found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ChemicalFormScreen(),
                                  ),
                                ).then((_) => _loadChemicals());
                              },
                              child: const Text('Add Chemical'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredChemicals.length,
                        itemBuilder: (context, index) {
                          final chemical = _filteredChemicals[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: const Icon(
                                  Icons.science,
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text(chemical.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(chemical.category),
                                  Text(
                                    '${chemical.quantity} ${chemical.unit}',
                                    style: TextStyle(
                                      color: chemical.quantity < 10
                                          ? Colors.red
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Expires: ${DateFormat('MMM dd, yyyy').format(chemical.expiryDate)}',
                                    style: TextStyle(
                                      color: chemical.expiryDate
                                                  .difference(DateTime.now())
                                                  .inDays <
                                              30
                                          ? Colors.orange
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Text('Edit'),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ChemicalFormScreen(
                                            chemical: chemical,
                                          ),
                                        ),
                                      ).then((_) => _loadChemicals());
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Text('Delete'),
                                    onTap: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Chemical'),
                                          content: Text(
                                              'Are you sure you want to delete ${chemical.name}?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        try {
                                          await ApiService.deleteChemical(
                                              chemical.id);
                                          _loadChemicals();
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Chemical deleted successfully')),
                                          );
                                        } catch (error) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Failed to delete chemical')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                // Navigate to chemical details screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChemicalDetailsScreen(
                                        chemical: chemical),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChemicalFormScreen(),
                  ),
                ).then((_) => _loadChemicals());
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Chemical'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

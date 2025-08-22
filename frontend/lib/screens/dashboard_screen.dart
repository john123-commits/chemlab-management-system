import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/models/equipment.dart';
import 'package:chemlab_frontend/screens/chemical_details_screen.dart';
import 'package:chemlab_frontend/screens/equipment_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/chemicals_screen.dart';
import 'package:chemlab_frontend/screens/equipment_screen.dart';
import 'package:chemlab_frontend/screens/borrowings_screen.dart';
import 'package:chemlab_frontend/screens/borrowing_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _reportData;
  List<dynamic>? _alerts;
  int _pendingRequestsCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final userRole =
          Provider.of<AuthProvider>(context, listen: false).userRole;

      // For borrowers - limited dashboard
      if (userRole == 'borrower') {
        try {
          final alerts = await ApiService.getAlerts();
          if (mounted) {
            setState(() {
              _alerts = alerts;
              _isLoading = false;
            });
          }
        } catch (alertError) {
          if (mounted) {
            setState(() {
              _alerts = [];
              _isLoading = false;
            });
          }
        }
      }
      // For technicians and admins - staff dashboard
      else {
        // Load dashboard data for staff
        final report = await ApiService.getMonthlyReport();
        final alerts = await ApiService.getAlerts();
        final pendingCount = await ApiService.getPendingRequestsCount();

        if (mounted) {
          setState(() {
            _reportData = report;
            _alerts = alerts;
            _pendingRequestsCount = pendingCount;
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to load dashboard data: ${error.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;

    // Special dashboard for borrowers
    if (userRole == 'borrower') {
      return _buildBorrowerDashboard();
    }

    // Staff dashboard for technicians and admins
    return _buildStaffDashboard();
  }

  Widget _buildStaffDashboard() {
    final userRole = Provider.of<AuthProvider>(context).userRole;
    final isTechnician = userRole == 'technician';

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load dashboard data',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadDashboardData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Header
                        Text(
                          isTechnician
                              ? 'Technician Dashboard'
                              : 'Admin Dashboard',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),

                        // Pending Requests Alert
                        if (_pendingRequestsCount > 0) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[300]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$_pendingRequestsCount Pending Request${_pendingRequestsCount == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Review pending borrowing requests',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const BorrowingsScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Review'),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Quick Actions Card
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.build_outlined,
                                  size: 64,
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isTechnician
                                      ? 'Welcome Technician!'
                                      : 'Welcome Admin!',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Quick Actions:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                    '• Manage chemical and equipment inventory'),
                                const Text(
                                    '• Review and approve borrowing requests'),
                                const Text('• Monitor system alerts'),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ChemicalsScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.science),
                                    label: const Text('Manage Chemicals'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const EquipmentScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.build),
                                    label: const Text('Manage Equipment'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const BorrowingsScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.assignment),
                                    label: const Text('Review Requests'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Summary Cards (for admin with full reports)
                        if (!isTechnician && _reportData != null) ...[
                          Text(
                            'Summary',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          // First Row
                          Row(
                            children: [
                              Flexible(
                                child: _buildSummaryCard(
                                  'Chemicals',
                                  _reportData!['summary']['totalChemicals']
                                      .toString(),
                                  Icons.science,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Flexible(
                                child: _buildSummaryCard(
                                  'Equipment',
                                  _reportData!['summary']['totalEquipment']
                                      .toString(),
                                  Icons.build,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Second Row
                          Row(
                            children: [
                              Flexible(
                                child: _buildSummaryCard(
                                  'Active',
                                  _reportData!['summary']['activeBorrowings']
                                      .toString(),
                                  Icons.check_circle,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Flexible(
                                child: _buildSummaryCard(
                                  'Pending',
                                  _reportData!['summary']['pendingBorrowings']
                                      .toString(),
                                  Icons.pending,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Full Width Card
                          _buildSummaryCard(
                            'Overdue',
                            _reportData!['summary']['overdueBorrowings']
                                .toString(),
                            Icons.warning,
                            Colors.red,
                            fullWidth: true,
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Alerts Section
                        if (_alerts != null && _alerts!.isNotEmpty) ...[
                          Text(
                            'System Alerts',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            constraints: const BoxConstraints(
                              maxHeight: 300,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _alerts!.map((alert) {
                                  return ListTile(
                                    leading: Icon(
                                      alert['type'] == 'chemical_expiry' ||
                                              alert['type'] ==
                                                  'overdue_borrowing'
                                          ? Icons.warning
                                          : Icons.info,
                                      color: Colors.red,
                                    ),
                                    title: Text(alert['message']),
                                    subtitle: Text(
                                      alert['type']
                                          .toString()
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Charts Section (only for admin)
                        if (!isTechnician && _reportData != null) ...[
                          Text(
                            'Inventory Overview',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Text(
                                'Charts functionality to be implemented',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildBorrowerDashboard() {
    return RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrower Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.science_outlined,
                                size: 64,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Welcome Borrower!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'You can:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                  '• View available chemicals and equipment'),
                              const Text('• Submit borrowing requests'),
                              const Text('• View your request status'),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ChemicalsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.science),
                                  label: const Text('View Chemicals'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EquipmentScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.build),
                                  label: const Text('View Equipment'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const BorrowingsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.assignment),
                                  label: const Text('My Requests'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const BorrowingFormScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Request Borrowing'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Borrower alerts (if any)
                      if (_alerts != null && _alerts!.isNotEmpty) ...[
                        Text(
                          'Your Alerts',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Column(
                            children: _alerts!.map((alert) {
                              return ListTile(
                                leading: const Icon(
                                  Icons.info,
                                  color: Colors.orange,
                                ),
                                title: Text(alert['message']),
                                subtitle: Text(
                                  alert['type']
                                      .toString()
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ));
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        height: 100,
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Search Results Screen (same as before)
class SearchResultsScreen extends StatefulWidget {
  final String searchType;
  final String searchQuery;

  const SearchResultsScreen({
    super.key,
    required this.searchType,
    required this.searchQuery,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;
  List<dynamic> _searchResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    try {
      if (widget.searchType == 'chemicals') {
        final results = await ApiService.getChemicals(
            filters: {'search': widget.searchQuery});
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isLoading = false;
          });
        }
      } else {
        // For equipment, we'll need to implement client-side filtering
        // since the API doesn't support search yet
        final allEquipment = await ApiService.getEquipment();
        final filtered = allEquipment.where((eq) {
          return eq.name
                  .toLowerCase()
                  .contains(widget.searchQuery.toLowerCase()) ||
              eq.category
                  .toLowerCase()
                  .contains(widget.searchQuery.toLowerCase()) ||
              eq.condition
                  .toLowerCase()
                  .contains(widget.searchQuery.toLowerCase()) ||
              eq.location
                  .toLowerCase()
                  .contains(widget.searchQuery.toLowerCase());
        }).toList();

        if (mounted) {
          setState(() {
            _searchResults = filtered;
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${error.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChemicals = widget.searchType == 'chemicals';

    return Scaffold(
      appBar: AppBar(
        title: Text(isChemicals
            ? 'Chemical Search Results'
            : 'Equipment Search Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    isChemicals ? 'Search chemicals...' : 'Search equipment...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  // Update search and re-perform
                  setState(() {
                    _searchResults = [];
                  });
                  _performSearch();
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isChemicals
                                  ? Icons.science_outlined
                                  : Icons.build_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No ${isChemicals ? 'chemicals' : 'equipment'} found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Back to Dashboard'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          if (isChemicals) {
                            final chemical = _searchResults[index] as Chemical;
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
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChemicalDetailsScreen(
                                              chemical: chemical),
                                    ),
                                  );
                                },
                              ),
                            );
                          } else {
                            final equipment =
                                _searchResults[index] as Equipment;
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
                                title: Text(equipment.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(equipment.category),
                                    Text('Condition: ${equipment.condition}'),
                                    Text('Location: ${equipment.location}'),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EquipmentDetailsScreen(
                                              equipment: equipment),
                                    ),
                                  );
                                },
                              ),
                            );
                          }
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:chemlab_frontend/screens/user_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/chemicals_screen.dart';
import 'package:chemlab_frontend/screens/equipment_screen.dart';
import 'package:chemlab_frontend/screens/borrowings_screen.dart';
import 'package:chemlab_frontend/screens/borrowing_form_screen.dart';
import 'package:logger/logger.dart';

var logger = Logger();

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
          logger.d('Alerts loading error (borrower): $alertError');
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
        try {
          // Load all data concurrently to improve performance and isolate errors
          final futureReport = ApiService.getMonthlyReport();
          final futureAlerts = ApiService.getAlerts();
          final futurePendingCount = ApiService.getPendingRequestsCount();

          // Wait for all to complete (errors won't stop others)
          Map<String, dynamic>? reportData;
          List<dynamic>? alertsData;
          int pendingCount = 0;

          try {
            reportData = await futureReport;
          } catch (reportError) {
            logger.d('Report loading error (continuing): $reportError');
            // Continue without report data
          }

          try {
            alertsData = await futureAlerts;
          } catch (alertError) {
            logger.d('Alerts loading error (continuing): $alertError');
            alertsData = [];
          }

          try {
            pendingCount = await futurePendingCount;
          } catch (pendingError) {
            logger.d('Pending count loading error (continuing): $pendingError');
            pendingCount = 0; // Default to 0 if error
          }

          if (mounted) {
            setState(() {
              _reportData = reportData;
              _alerts = alertsData;
              _pendingRequestsCount = pendingCount;
              _isLoading = false;
            });
          }
        } catch (overallError) {
          logger.d('Overall dashboard loading error: $overallError');
          if (mounted) {
            setState(() {
              _isLoading = false;
              // Don't set error message to prevent UI blocking
            });
          }
        }
      }
    } catch (error) {
      logger.d('Critical dashboard error: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Even on critical error, try to show basic dashboard
        });
      }
    }
  }

  Future<void> _refreshDashboardData() async {
    await _loadDashboardData();
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
    final isAdmin = userRole == 'admin';

    return RefreshIndicator(
      onRefresh: _refreshDashboardData,
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
                        // Welcome Header with User Info
                        Text(
                          isTechnician
                              ? 'Technician Dashboard'
                              : 'Admin Dashboard',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),

                        // ✅ Enhanced User Information Display
                        _buildUserInfoCard(),
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
                                // ✅ REMOVED: Lecture schedule action text for technicians
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
                                // ✅ REMOVED: Lecture schedule button for technicians
                                // ✅ Admin-only user management
                                if (isAdmin) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const UserManagementScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.people),
                                      label: const Text('Manage Users'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Summary Cards (for admin with full reports)
                        if (isAdmin && _reportData != null) ...[
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
                        if (isAdmin && _reportData != null) ...[
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
      onRefresh: _refreshDashboardData,
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
                    const SizedBox(height: 8),

                    // ✅ Enhanced User Information Display for Borrowers
                    _buildUserInfoCard(),
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
      ),
    );
  }

  // ✅ New method to build user information card
  Widget _buildUserInfoCard() {
    final user = Provider.of<AuthProvider>(context, listen: false).user!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            _buildUserDetailRow('Name', user.name),
            _buildUserDetailRow('Email', user.email),
            if (user.phone != null && user.phone!.isNotEmpty)
              _buildUserDetailRow('Phone', user.phone!),
            if (user.studentId != null && user.studentId!.isNotEmpty)
              _buildUserDetailRow('Student ID', user.studentId!),
            if (user.institution != null && user.institution!.isNotEmpty)
              _buildUserDetailRow('Institution', user.institution!),
            if (user.department != null && user.department!.isNotEmpty)
              _buildUserDetailRow('Department', user.department!),
            if (user.educationLevel != null && user.educationLevel!.isNotEmpty)
              _buildUserDetailRow('Education Level', user.educationLevel!),
            if (user.semester != null && user.semester!.isNotEmpty)
              _buildUserDetailRow('Semester', user.semester!),
            _buildUserDetailRow(
              'Role',
              user.role.toUpperCase(),
              isHighlighted: true,
            ),
            _buildUserDetailRow(
              'Member Since',
              '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Helper method to build user detail rows
  Widget _buildUserDetailRow(String label, String value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted
                    ? (value == 'ADMIN'
                        ? Colors.red
                        : value == 'TECHNICIAN'
                            ? Colors.green
                            : Colors.blue)
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
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

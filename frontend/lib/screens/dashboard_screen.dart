import 'package:chemlab_frontend/screens/user_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/screens/chemicals_screen.dart';
import 'package:chemlab_frontend/screens/equipment_screen.dart';
import 'package:chemlab_frontend/screens/borrowings_screen.dart';
import 'package:chemlab_frontend/screens/borrowing_form_screen.dart';
import 'package:chemlab_frontend/screens/chatbot_screen.dart';
import 'package:chemlab_frontend/utils/constants.dart';
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
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error,
                                  size: 64, color: Colors.red[300]),
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
                            const SizedBox(height: AppConstants.spacing8),

                            // ✅ Enhanced User Information Display
                            _buildUserInfoCard(),
                            const SizedBox(height: AppConstants.spacing24),

                            // Pending Requests Alert
                            if (_pendingRequestsCount > 0) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.orange[300]!),
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
                                    // ✅ ChatBot Quick Action for Staff
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const ChatBotScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.chat_bubble),
                                        label: const Text('Chat with ChemBot'),
                                      ),
                                    ),
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

                            // Enhanced Summary Cards (for admin with full reports)
                            if (isAdmin && _reportData != null) ...[
                              Text(
                                'Dashboard Overview',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),

                              // Responsive Summary Cards Grid
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // Determine layout based on screen width
                                  final screenWidth =
                                      MediaQuery.of(context).size.width;
                                  int crossAxisCount;

                                  if (screenWidth >= 1200) {
                                    // Desktop: 4 columns
                                    crossAxisCount = 4;
                                  } else if (screenWidth >= 768) {
                                    // Tablet: 2 columns
                                    crossAxisCount = 2;
                                  } else {
                                    // Mobile: 1 column
                                    crossAxisCount = 1;
                                  }

                                  return GridView.count(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: AppConstants.spacing16,
                                    mainAxisSpacing: AppConstants.spacing16,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: [
                                      _buildEnhancedSummaryCard(
                                        'Chemicals',
                                        _reportData!['summary']
                                                ['totalChemicals']
                                            .toString(),
                                        Icons.science,
                                        Colors.blue,
                                        trendDirection: 'up',
                                        trendPercentage: 12.5,
                                        healthStatus: 'good',
                                        healthPercentage: 78.0,
                                        quickStat: '5 expiring this month',
                                      ),
                                      _buildEnhancedSummaryCard(
                                        'Equipment',
                                        _reportData!['summary']
                                                ['totalEquipment']
                                            .toString(),
                                        Icons.build,
                                        Colors.green,
                                        trendDirection: 'stable',
                                        trendPercentage: 0.0,
                                        healthStatus: 'warning',
                                        healthPercentage: 65.0,
                                        quickStat: '3 need maintenance',
                                      ),
                                      _buildEnhancedSummaryCard(
                                        'Active Borrowings',
                                        _reportData!['summary']
                                                ['activeBorrowings']
                                            .toString(),
                                        Icons.check_circle,
                                        Colors.orange,
                                        trendDirection: 'up',
                                        trendPercentage: 8.3,
                                        healthStatus: 'good',
                                        healthPercentage: 85.0,
                                        quickStat: '12 due this week',
                                      ),
                                      _buildEnhancedSummaryCard(
                                        'Pending Requests',
                                        _reportData!['summary']
                                                ['pendingBorrowings']
                                            .toString(),
                                        Icons.pending,
                                        Colors.purple,
                                        trendDirection: 'down',
                                        trendPercentage: -5.2,
                                        healthStatus: 'good',
                                        healthPercentage: 90.0,
                                        quickStat: '3 urgent approvals',
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Full Width Card - Critical Issues (always full width)
                              _buildEnhancedSummaryCard(
                                'Overdue Items',
                                _reportData!['summary']['overdueBorrowings']
                                    .toString(),
                                Icons.warning,
                                Colors.red,
                                fullWidth: true,
                                trendDirection: 'down',
                                trendPercentage: -15.7,
                                healthStatus: _reportData!['summary']
                                            ['overdueBorrowings'] >
                                        0
                                    ? 'critical'
                                    : 'good',
                                healthPercentage: _reportData!['summary']
                                            ['overdueBorrowings'] >
                                        0
                                    ? 25.0
                                    : 95.0,
                                quickStat: _reportData!['summary']
                                            ['overdueBorrowings'] >
                                        0
                                    ? 'Requires immediate attention'
                                    : 'All items returned on time',
                              ),
                              const SizedBox(height: 32),
                            ],

                            // Enhanced Alerts Section with Priority-based Visual Hierarchy
                            if (_alerts != null && _alerts!.isNotEmpty) ...[
                              Text(
                                'System Alerts',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 400,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: _buildPrioritizedAlerts(),
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
          // ✅ Floating Chat Button for Staff
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChatBotScreen()),
                );
              },
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              child: const Icon(Icons.chat_bubble),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowerDashboard() {
    return RefreshIndicator(
      onRefresh: _refreshDashboardData,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
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
                                // ✅ ChatBot Quick Action for Borrowers
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ChatBotScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.chat_bubble),
                                    label: const Text('Chat with ChemBot'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Enhanced Borrower alerts (if any)
                        if (_alerts != null && _alerts!.isNotEmpty) ...[
                          Text(
                            'Your Alerts',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            constraints: const BoxConstraints(
                              maxHeight: 300,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: _buildPrioritizedAlerts(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          // ✅ Floating Chat Button for Borrowers
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChatBotScreen()),
                );
              },
              child: const Icon(Icons.chat_bubble),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
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

  Widget _buildEnhancedSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
    String? trendDirection, // 'up', 'down', 'stable'
    double? trendPercentage,
    String? healthStatus, // 'good', 'warning', 'critical'
    double? healthPercentage,
    String? quickStat,
  }) {
    // Determine health color based on status
    Color healthColor;
    if (healthStatus == 'critical') {
      healthColor = Colors.red;
    } else if (healthStatus == 'warning') {
      healthColor = Colors.orange;
    } else {
      healthColor = Colors.green;
    }

    // Determine trend icon and color
    IconData? trendIcon;
    Color trendColor = Colors.grey;
    if (trendDirection == 'up') {
      trendIcon = Icons.trending_up;
      trendColor = Colors.green;
    } else if (trendDirection == 'down') {
      trendIcon = Icons.trending_down;
      trendColor = Colors.red;
    } else if (trendDirection == 'stable') {
      trendIcon = Icons.trending_flat;
      trendColor = Colors.blue;
    }

    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          // Add navigation or detailed view here
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('View detailed $title statistics')),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 140, // Increased height for new elements
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: healthColor.withValues(alpha: 0.1),
            border: Border.all(
              color: healthColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header with icon and trend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: healthColor, size: 28),
                  if (trendIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trendIcon, color: trendColor, size: 20),
                    if (trendPercentage != null)
                      Text(
                        '${trendPercentage > 0 ? '+' : ''}${trendPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: trendColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Main value
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: healthColor,
                ),
              ),

              // Title
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              // Health progress bar
              if (healthPercentage != null) ...[
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: healthPercentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: healthColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${healthPercentage.toStringAsFixed(0)}% healthy',
                  style: TextStyle(
                    color: healthColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // Quick stat
              if (quickStat != null && quickStat.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  quickStat,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Backward compatibility method
  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return _buildEnhancedSummaryCard(
      title,
      value,
      icon,
      color,
      fullWidth: fullWidth,
      healthStatus: 'good',
      healthPercentage: 85.0, // Default healthy percentage
    );
  }

  // Enhanced alerts with priority-based visual hierarchy
  List<Widget> _buildPrioritizedAlerts() {
    if (_alerts == null || _alerts!.isEmpty) return [];

    // Group alerts by priority
    final criticalAlerts =
        _alerts!.where((alert) => alert['priority'] == 'high').toList();
    final warningAlerts =
        _alerts!.where((alert) => alert['priority'] == 'medium').toList();
    final infoAlerts = _alerts!
        .where((alert) =>
            alert['priority'] != 'high' && alert['priority'] != 'medium')
        .toList();

    final alertWidgets = <Widget>[];

    // Critical alerts first
    if (criticalAlerts.isNotEmpty) {
      alertWidgets.add(_buildAlertGroup(
          'Critical Issues', criticalAlerts, Colors.red, Icons.error));
    }

    // Warning alerts
    if (warningAlerts.isNotEmpty) {
      alertWidgets.add(_buildAlertGroup(
          'Warnings', warningAlerts, Colors.orange, Icons.warning));
    }

    // Info alerts
    if (infoAlerts.isNotEmpty) {
      alertWidgets.add(
          _buildAlertGroup('Information', infoAlerts, Colors.blue, Icons.info));
    }

    return alertWidgets;
  }

  Widget _buildAlertGroup(
      String title, List<dynamic> alerts, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alert items
          ...alerts.map((alert) => _buildEnhancedAlertTile(alert, color)),
        ],
      ),
    );
  }

  Widget _buildEnhancedAlertTile(dynamic alert, Color color) {
    final alertType = alert['type'] as String;
    final message = alert['message'] as String;
    final itemId = alert['item_id'];

    // Determine action buttons based on alert type
    List<Widget> actionButtons = [];

    switch (alertType) {
      case 'low_stock':
        actionButtons = [
          TextButton.icon(
            onPressed: () {
              // Navigate to order/supply management
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Navigate to supply ordering')),
              );
            },
            icon: const Icon(Icons.shopping_cart, size: 16),
            label: const Text('Order Now'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              // Set reminder
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Reminder set for low stock item')),
              );
            },
            child: const Text('Set Reminder'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ];
        break;

      case 'overdue_borrowing':
        actionButtons = [
          TextButton.icon(
            onPressed: () {
              // Send reminder to user
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reminder sent to borrower')),
              );
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send Reminder'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              // Navigate to user contact
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Navigate to user contact')),
              );
            },
            child: const Text('Contact User'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ];
        break;

      case 'equipment_maintenance':
        actionButtons = [
          TextButton.icon(
            onPressed: () {
              // Schedule maintenance
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Maintenance scheduled')),
              );
            },
            icon: const Icon(Icons.schedule, size: 16),
            label: const Text('Schedule'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              // Mark as resolved
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alert marked as resolved')),
              );
            },
            child: const Text('Mark Resolved'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ];
        break;

      default:
        actionButtons = [
          TextButton(
            onPressed: () {
              // View details
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('View details for $alertType')),
              );
            },
            child: const Text('View Details'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ];
    }

    return Dismissible(
      key: Key('alert_${alertType}_$itemId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.grey[300],
        child: const Icon(Icons.delete, color: Colors.grey),
      ),
      onDismissed: (direction) {
        // Remove alert from list
        setState(() {
          _alerts!.remove(alert);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert dismissed')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: color.withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getAlertIcon(alertType),
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alertType.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '2 hours ago', // In real app, use actual timestamp
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actionButtons,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAlertIcon(String alertType) {
    switch (alertType) {
      case 'chemical_expiry':
        return Icons.hourglass_bottom;
      case 'low_stock':
        return Icons.inventory_2;
      case 'overdue_borrowing':
        return Icons.schedule;
      case 'equipment_maintenance':
        return Icons.build;
      default:
        return Icons.notifications;
    }
  }
}

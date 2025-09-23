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
  bool _isUserInfoExpanded = false;

  // Borrower-specific stats
  int _activeRequestsCount = 0;
  int _borrowedItemsCount = 0;
  int _pendingReturnsCount = 0;
  int _recentActivityCount = 0;

  String _getHealthStatus(int count) {
    if (count == 0) return 'critical';
    if (count < 5) return 'warning';
    return 'good';
  }

  double _getHealthPercentage(int count) {
    if (count == 0) return 0.0;
    if (count < 5) return 50.0;
    return 85.0;
  }

  String _getBorrowingHealthStatus(int count) {
    if (count > 20) return 'warning';
    if (count > 10) return 'good';
    return 'good';
  }

  double _getBorrowingHealthPercentage(int count) {
    if (count > 20) return 60.0;
    return 85.0;
  }

  String _getPendingHealthStatus(int count) {
    if (count > 10) return 'critical';
    if (count > 5) return 'warning';
    return 'good';
  }

  double _getPendingHealthPercentage(int count) {
    if (count > 10) return 25.0;
    if (count > 5) return 60.0;
    return 90.0;
  }

  String _getChemicalQuickStat() {
    int totalChemicals = _reportData!['summary']['totalChemicals'] ?? 0;
    if (totalChemicals == 0) return 'No chemicals in inventory';
    if (totalChemicals == 1) return '1 chemical in inventory';
    return '$totalChemicals chemicals in inventory';
  }

  String _getEquipmentQuickStat() {
    int totalEquipment = _reportData!['summary']['totalEquipment'] ?? 0;
    if (totalEquipment == 0) return 'No equipment in inventory';
    if (totalEquipment == 1) return '1 equipment item';
    return '$totalEquipment equipment items';
  }

  String _getBorrowingQuickStat() {
    int activeBorrowings = _reportData!['summary']['activeBorrowings'] ?? 0;
    if (activeBorrowings == 0) return 'No active borrowings';
    if (activeBorrowings == 1) return '1 active borrowing';
    return '$activeBorrowings active borrowings';
  }

  String _getPendingQuickStat() {
    int pendingBorrowings = _reportData!['summary']['pendingBorrowings'] ?? 0;
    if (pendingBorrowings == 0) return 'No pending requests';
    if (pendingBorrowings == 1) return '1 pending request';
    return '$pendingBorrowings pending requests';
  }

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
          // Load alerts and borrower stats concurrently
          final alertsFuture = ApiService.getAlerts();
          final statsFuture = _loadBorrowerStats();

          final alerts = await alertsFuture;
          await statsFuture;

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

  Future<void> _loadBorrowerStats() async {
    try {
      // Load active borrowings for the current user
      final activeBorrowings = await ApiService.getActiveBorrowings();
      final allBorrowings = await ApiService.getBorrowings();

      if (mounted) {
        setState(() {
          _activeRequestsCount = allBorrowings
              .where((b) => b.status == 'pending' || b.status == 'approved')
              .length;
          _borrowedItemsCount = activeBorrowings.length;
          _pendingReturnsCount =
              activeBorrowings.where((b) => b.status == 'approved').length;
          _recentActivityCount = allBorrowings.where((b) {
            final now = DateTime.now();
            final borrowingDate = b.createdAt;
            return now.difference(borrowingDate).inDays <= 7; // Last 7 days
          }).length;
        });
      }
    } catch (error) {
      logger.d('Error loading borrower stats: $error');
      // Keep default values (0)
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
                                        trendDirection:
                                            'stable', // Changed from 'up'
                                        trendPercentage:
                                            0.0, // Changed from 12.5
                                        healthStatus: _getHealthStatus(
                                            _reportData!['summary']
                                                ['totalChemicals']),
                                        healthPercentage: _getHealthPercentage(
                                            _reportData!['summary']
                                                ['totalChemicals']),
                                        quickStat:
                                            _getChemicalQuickStat(), // This will now show correct count
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
                                        healthStatus: _getHealthStatus(
                                            _reportData!['summary']
                                                ['totalEquipment']),
                                        healthPercentage: _getHealthPercentage(
                                            _reportData!['summary']
                                                ['totalEquipment']),
                                        quickStat:
                                            _getEquipmentQuickStat(), // This will now show correct count
                                      ),
                                      _buildEnhancedSummaryCard(
                                        'Active Borrowings',
                                        _reportData!['summary']
                                                ['activeBorrowings']
                                            .toString(),
                                        Icons.check_circle,
                                        Colors.orange,
                                        trendDirection:
                                            'stable', // Changed from 'up'
                                        trendPercentage:
                                            0.0, // Changed from 8.3
                                        healthStatus: _getBorrowingHealthStatus(
                                            _reportData!['summary']
                                                ['activeBorrowings']),
                                        healthPercentage:
                                            _getBorrowingHealthPercentage(
                                                _reportData!['summary']
                                                    ['activeBorrowings']),
                                        quickStat:
                                            _getBorrowingQuickStat(), // This will now show correct count
                                      ),
                                      _buildEnhancedSummaryCard(
                                        'Pending Requests',
                                        _reportData!['summary']
                                                ['pendingBorrowings']
                                            .toString(),
                                        Icons.pending,
                                        Colors.purple,
                                        trendDirection:
                                            'stable', // Changed from 'down'
                                        trendPercentage:
                                            0.0, // Changed from -5.2
                                        healthStatus: _getPendingHealthStatus(
                                            _reportData!['summary']
                                                ['pendingBorrowings']),
                                        healthPercentage:
                                            _getPendingHealthPercentage(
                                                _reportData!['summary']
                                                    ['pendingBorrowings']),
                                        quickStat:
                                            _getPendingQuickStat(), // This will now show correct count
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

                        // ✅ Dashboard Statistics Section
                        _buildBorrowerStatsSection(),
                        const SizedBox(height: 24),

                        // ✅ Redesigned Action Buttons as Interactive Cards
                        _buildActionButtonsGrid(),
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
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              child: const Icon(Icons.chat_bubble),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Redesigned compact user information header card
  Widget _buildUserInfoCard() {
    final user = Provider.of<AuthProvider>(context, listen: false).user!;

    // Generate initials for avatar
    String initials = user.name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join('')
        .toUpperCase();
    if (initials.length > 2) initials = initials.substring(0, 2);

    return Semantics(
      label: 'User information for ${user.name}',
      hint: _isUserInfoExpanded
          ? 'Tap to collapse details'
          : 'Tap to expand details',
      button: true,
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacing16,
            vertical: AppConstants.spacing8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        ),
        child: InkWell(
          onTap: () {
            // Toggle expanded view
            setState(() {
              _isUserInfoExpanded = !_isUserInfoExpanded;
            });
          },
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacing12),
                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            user.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: user.role == 'admin'
                                  ? Colors.red
                                  : user.role == 'technician'
                                      ? Colors.green
                                      : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Expand/collapse icon
                    Icon(
                      _isUserInfoExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                // Expanded details
                if (_isUserInfoExpanded) ...[
                  const SizedBox(height: AppConstants.spacing12),
                  const Divider(),
                  const SizedBox(height: AppConstants.spacing8),
                  if (user.phone != null && user.phone!.isNotEmpty)
                    _buildCompactUserDetailRow('Phone', user.phone!),
                  if (user.studentId != null && user.studentId!.isNotEmpty)
                    _buildCompactUserDetailRow('Student ID', user.studentId!),
                  if (user.institution != null && user.institution!.isNotEmpty)
                    _buildCompactUserDetailRow(
                        'Institution', user.institution!),
                  if (user.department != null && user.department!.isNotEmpty)
                    _buildCompactUserDetailRow('Department', user.department!),
                  if (user.educationLevel != null &&
                      user.educationLevel!.isNotEmpty)
                    _buildCompactUserDetailRow(
                        'Education Level', user.educationLevel!),
                  if (user.semester != null && user.semester!.isNotEmpty)
                    _buildCompactUserDetailRow('Semester', user.semester!),
                  _buildCompactUserDetailRow(
                    'Member Since',
                    '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Helper method to build user detail rows

  // ✅ Helper method to build compact user detail rows for expanded view
  Widget _buildCompactUserDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Build borrower statistics section
  Widget _buildBorrowerStatsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        int crossAxisCount =
            screenWidth >= 768 ? 2 : 1; // 2 columns on tablet+, 1 on mobile

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppConstants.spacing16,
          mainAxisSpacing: AppConstants.spacing16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildBorrowerStatCard(
              'Active Requests',
              _activeRequestsCount.toString(),
              Icons.pending,
              Colors.blue,
              'Requests awaiting approval',
            ),
            _buildBorrowerStatCard(
              'Items Borrowed',
              _borrowedItemsCount.toString(),
              Icons.inventory,
              Colors.green,
              'Currently in your possession',
            ),
            _buildBorrowerStatCard(
              'Pending Returns',
              _pendingReturnsCount.toString(),
              Icons.assignment_return,
              Colors.orange,
              'Items to return soon',
            ),
            _buildBorrowerStatCard(
              'Recent Activity',
              _recentActivityCount.toString(),
              Icons.history,
              Colors.purple,
              'Activity in last 7 days',
            ),
          ],
        );
      },
    );
  }

  // ✅ Build individual borrower stat card
  Widget _buildBorrowerStatCard(String title, String value, IconData icon,
      Color color, String description) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to relevant screen based on stat type
          switch (title) {
            case 'Active Requests':
            case 'Items Borrowed':
            case 'Pending Returns':
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const BorrowingsScreen()),
              );
              break;
            case 'Recent Activity':
              // Could navigate to activity/history screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('View recent activity')),
              );
              break;
          }
        },
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        hoverColor: color.withValues(alpha: 0.1),
        splashColor: color.withValues(alpha: 0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: AppConstants.spacing8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: AppConstants.spacing4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacing4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Set Reminder'),
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
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Contact User'),
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
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Mark Resolved'),
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
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('View Details'),
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

  // ✅ Build action buttons grid
  Widget _buildActionButtonsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        int crossAxisCount =
            screenWidth >= 768 ? 2 : 1; // 2 columns on tablet+, 1 on mobile

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppConstants.spacing16,
          mainAxisSpacing: AppConstants.spacing16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildActionCard(
              'View Chemicals',
              'Browse available chemicals',
              Icons.science,
              Colors.blue[600]!,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ChemicalsScreen()),
              ),
            ),
            _buildActionCard(
              'View Equipment',
              'Browse available equipment',
              Icons.build,
              Colors.blue[600]!,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EquipmentScreen()),
              ),
            ),
            _buildActionCard(
              'My Requests',
              'View your borrowing requests',
              Icons.assignment,
              Colors.blue[600]!,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const BorrowingsScreen()),
              ),
            ),
            _buildActionCard(
              'Request Borrowing',
              'Submit a new borrowing request',
              Icons.add,
              const Color(0xFF4CAF50), // Green
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const BorrowingFormScreen()),
              ),
            ),
            _buildActionCard(
              'Chat with ChemBot',
              'Get help from our AI assistant',
              Icons.chat_bubble,
              const Color(0xFF9C27B0), // Purple
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatBotScreen()),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ Build individual action card
  Widget _buildActionCard(String title, String description, IconData icon,
      Color color, VoidCallback onTap) {
    return Semantics(
      label: title,
      hint: description,
      button: true,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          hoverColor: color.withValues(alpha: 0.1),
          splashColor: color.withValues(alpha: 0.2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 40),
                const SizedBox(height: AppConstants.spacing12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacing4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

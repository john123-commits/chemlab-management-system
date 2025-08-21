import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _reportData;
  List<dynamic>? _alerts;
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

      // Borrowers get limited dashboard
      if (userRole == 'borrower') {
        // Load only alerts for borrowers (if they have permission)
        try {
          final alerts = await ApiService.getAlerts();
          if (mounted) {
            setState(() {
              _alerts = alerts;
              _isLoading = false;
            });
          }
        } catch (alertError) {
          // Borrowers might not have alert access
          if (mounted) {
            setState(() {
              _alerts = [];
              _isLoading = false;
            });
          }
        }
      } else {
        // Admin/Technician get full dashboard
        final report = await ApiService.getMonthlyReport();
        final alerts = await ApiService.getAlerts();

        if (mounted) {
          setState(() {
            _reportData = report;
            _alerts = alerts;
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

    // Full dashboard for admin/technician
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
                        // Summary Cards
                        if (_reportData != null) ...[
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
                            'Alerts',
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

                        // Charts Section
                        if (_reportData != null) ...[
                          Text(
                            'Inventory Overview',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 300,
                            child: SfCircularChart(
                              title:
                                  const ChartTitle(text: 'Chemical Categories'),
                              legend: const Legend(isVisible: true),
                              series: <CircularSeries>[
                                PieSeries<_ChartData, String>(
                                  dataSource: [
                                    _ChartData(
                                        'Expiring Soon',
                                        _reportData!['expiringChemicals']
                                            .length),
                                    _ChartData(
                                        'Low Stock',
                                        _reportData!['lowStockChemicals']
                                            .length),
                                    _ChartData(
                                        'Normal',
                                        _reportData!['summary']
                                                ['totalChemicals'] -
                                            _reportData!['expiringChemicals']
                                                .length -
                                            _reportData!['lowStockChemicals']
                                                .length),
                                  ],
                                  xValueMapper: (_ChartData data, _) => data.x,
                                  yValueMapper: (_ChartData data, _) => data.y,
                                  dataLabelSettings:
                                      const DataLabelSettings(isVisible: true),
                                )
                              ],
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
                            ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to chemicals screen
                                Navigator.pushNamed(context, '/chemicals');
                              },
                              icon: const Icon(Icons.science),
                              label: const Text('View Chemicals'),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to equipment screen
                                Navigator.pushNamed(context, '/equipment');
                              },
                              icon: const Icon(Icons.build),
                              label: const Text('View Equipment'),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to borrowings screen
                                Navigator.pushNamed(context, '/borrowings');
                              },
                              icon: const Icon(Icons.assignment),
                              label: const Text('My Requests'),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to borrowing form
                                Navigator.pushNamed(context, '/borrowings/new');
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Request Borrowing'),
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

class _ChartData {
  final String x;
  final int y;

  _ChartData(this.x, this.y);
}

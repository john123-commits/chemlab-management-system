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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final report = await ApiService.getMonthlyReport();
      final alerts = await ApiService.getAlerts();

      setState(() {
        _reportData = report;
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load dashboard data')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final userRole = Provider.of<AuthProvider>(context).userRole;

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
                    // Summary Cards
                    if (_reportData != null) ...[
                      Text(
                        'Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      // First Row - Use Flexible instead of Expanded
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
                      // Full Width Card - Don't use Expanded here
                      _buildSummaryCard(
                        'Overdue',
                        _reportData!['summary']['overdueBorrowings'].toString(),
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
                          maxHeight: 300, // Add max height
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // Add this
                            children: _alerts!.map((alert) {
                              return ListTile(
                                leading: Icon(
                                  alert['type'] == 'chemical_expiry' ||
                                          alert['type'] == 'overdue_borrowing'
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
                          title: const ChartTitle(text: 'Chemical Categories'),
                          legend: const Legend(isVisible: true),
                          series: <CircularSeries>[
                            PieSeries<_ChartData, String>(
                              dataSource: [
                                _ChartData('Expiring Soon',
                                    _reportData!['expiringChemicals'].length),
                                _ChartData('Low Stock',
                                    _reportData!['lowStockChemicals'].length),
                                _ChartData(
                                    'Normal',
                                    _reportData!['summary']['totalChemicals'] -
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

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    // Don't wrap with Expanded - use direct widget
    return Card(
      elevation: 4,
      child: Container(
        height: 100,
        width: fullWidth ? double.infinity : null, // Full width when needed
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

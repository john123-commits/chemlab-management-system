import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await ApiService.getMonthlyReport();
      setState(() {
        _reportData = report;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load report')),
      );
    }
  }

  Future<void> _exportReport(String format) async {
    try {
      // In a real implementation, you would download the file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported as $format')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;

    if (userRole != 'admin' && userRole != 'technician') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Only admins and technicians can view reports',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reportData == null
                ? const Center(child: Text('No report data available'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Report Summary',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildReportStat(
                                    'Chemicals',
                                    _reportData!['summary']['totalChemicals']
                                        .toString(),
                                    Icons.science,
                                    Colors.blue,
                                  ),
                                  _buildReportStat(
                                    'Equipment',
                                    _reportData!['summary']['totalEquipment']
                                        .toString(),
                                    Icons.build,
                                    Colors.green,
                                  ),
                                  _buildReportStat(
                                    'Active',
                                    _reportData!['summary']['activeBorrowings']
                                        .toString(),
                                    Icons.check_circle,
                                    Colors.orange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildReportStat(
                                    'Pending',
                                    _reportData!['summary']['pendingBorrowings']
                                        .toString(),
                                    Icons.pending,
                                    Colors.purple,
                                  ),
                                  _buildReportStat(
                                    'Overdue',
                                    _reportData!['summary']['overdueBorrowings']
                                        .toString(),
                                    Icons.warning,
                                    Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Charts
                      SizedBox(
                        height: 300,
                        child: SfCircularChart(
                          title: const ChartTitle(text: 'Inventory Status'),
                          legend: const Legend(isVisible: true),
                          series: <CircularSeries>[
                            PieSeries<_ChartData, String>(
                              dataSource: [
                                _ChartData(
                                    'Normal',
                                    _reportData!['summary']['totalChemicals'] -
                                        _reportData!['expiringChemicals']
                                            .length -
                                        _reportData!['lowStockChemicals']
                                            .length),
                                _ChartData('Expiring Soon',
                                    _reportData!['expiringChemicals'].length),
                                _ChartData('Low Stock',
                                    _reportData!['lowStockChemicals'].length),
                              ],
                              xValueMapper: (_ChartData data, _) => data.x,
                              yValueMapper: (_ChartData data, _) => data.y,
                              dataLabelSettings:
                                  const DataLabelSettings(isVisible: true),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Expiring Chemicals
                      if (_reportData!['expiringChemicals'].isNotEmpty) ...[
                        Text(
                          'Expiring Chemicals',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: _reportData!['expiringChemicals']
                                .map((chemical) {
                              return ListTile(
                                title: Text(chemical['name']),
                                subtitle: Text(
                                  'Expires: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(chemical['expiry_date']))}',
                                ),
                                trailing: const Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Low Stock Chemicals
                      if (_reportData!['lowStockChemicals'].isNotEmpty) ...[
                        Text(
                          'Low Stock Chemicals',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: _reportData!['lowStockChemicals']
                                .map((chemical) {
                              return ListTile(
                                title: Text(chemical['name']),
                                subtitle: Text(
                                  'Quantity: ${chemical['quantity']} ${chemical['unit']}',
                                ),
                                trailing: const Icon(
                                  Icons.low_priority,
                                  color: Colors.red,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Due Equipment
                      if (_reportData!['dueEquipment'].isNotEmpty) ...[
                        Text(
                          'Equipment Due for Maintenance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: _reportData!['dueEquipment'].map((eq) {
                              return ListTile(
                                title: Text(eq['name']),
                                subtitle: Text(
                                  'Last Maintenance: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(eq['last_maintenance_date']))}',
                                ),
                                trailing: const Icon(
                                  Icons.build,
                                  color: Colors.orange,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Overdue Borrowings
                      if (_reportData!['overdueBorrowings'].isNotEmpty) ...[
                        Text(
                          'Overdue Borrowings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: _reportData!['overdueBorrowings']
                                .map((borrowing) {
                              return ListTile(
                                title: Text(borrowing['borrower_name']),
                                subtitle: Text(
                                  'Return Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(borrowing['return_date']))}',
                                ),
                                trailing: const Icon(
                                  Icons.warning,
                                  color: Colors.red,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Export Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _exportReport('PDF'),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _exportReport('CSV'),
                            icon: const Icon(Icons.table_chart),
                            label: const Text('Export CSV'),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildReportStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ChartData {
  final String x;
  final int y;

  _ChartData(this.x, this.y);
}

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
  bool _isRefreshing = false;
  String? _errorMessage;
  List<_ChartData> _chartData = [];
  List<Map<String, dynamic>> _equipmentChartData = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final report = await ApiService.getMonthlyReport();
      _prepareChartData(report);
      await _prepareEquipmentChartData(); // Load real equipment data
      setState(() {
        _reportData = report;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = error.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load report: ${error.toString()}')),
      );
    }
  }

  void _prepareChartData(Map<String, dynamic> report) {
    if (report.isEmpty) return;

    final totalChemicals = report['summary']['totalChemicals'] ?? 0;
    final expiringChemicals = report['expiringChemicals']?.length ?? 0;
    final lowStockChemicals = report['lowStockChemicals']?.length ?? 0;

    _chartData = [
      _ChartData(
          'Normal', totalChemicals - expiringChemicals - lowStockChemicals),
      _ChartData('Expiring Soon', expiringChemicals),
      _ChartData('Low Stock', lowStockChemicals),
    ];
  }

  Future<void> _prepareEquipmentChartData() async {
    try {
      print('Loading equipment data...');
      // Get actual equipment data from API
      final equipment = await ApiService.getEquipment();
      print('Loaded ${equipment.length} equipment items');

      // Count equipment by condition
      Map<String, int> conditionCounts = {};

      for (var item in equipment) {
        print('Equipment: ${item.name}, Condition: ${item.condition}');
        final condition =
            item.condition; // Use dot notation instead of ['condition']
        conditionCounts[condition] = (conditionCounts[condition] ?? 0) + 1;
      }

      print('Equipment condition counts: $conditionCounts');

      // Convert to chart data format
      _equipmentChartData = conditionCounts.entries
          .map((entry) => {
                'condition': entry.key,
                'count': entry.value,
              })
          .toList();

      // Sort by count for better visualization
      _equipmentChartData.sort((a, b) => b['count'].compareTo(a['count']));
    } catch (error) {
      print('Error loading equipment data for chart: $error');
      // Fallback to empty data if equipment loading fails
      _equipmentChartData = [];
    }
  }

  Future<void> _refreshReport() async {
    setState(() => _isRefreshing = true);
    await _loadReport(showLoading: false);
  }

  Future<void> _exportReport(String format) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating report...'),
            ],
          ),
        ),
      );

      if (format == 'PDF') {
        await ApiService.generateMonthlyReportPDF();
      } else if (format == 'CSV') {
        await ApiService.generateMonthlyReportCSV();
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported as $format successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export report: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
      onRefresh: _refreshReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load report',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadReport,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
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
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildReportStat(
                                        'Chemicals',
                                        _reportData!['summary']
                                                ['totalChemicals']
                                            .toString(),
                                        Icons.science,
                                        Colors.blue,
                                      ),
                                      _buildReportStat(
                                        'Equipment',
                                        _reportData!['summary']
                                                ['totalEquipment']
                                            .toString(),
                                        Icons.build,
                                        Colors.green,
                                      ),
                                      _buildReportStat(
                                        'Active',
                                        _reportData!['summary']
                                                ['activeBorrowings']
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
                                        _reportData!['summary']
                                                ['pendingBorrowings']
                                            .toString(),
                                        Icons.pending,
                                        Colors.purple,
                                      ),
                                      _buildReportStat(
                                        'Overdue',
                                        _reportData!['summary']
                                                ['overdueBorrowings']
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

                          // Charts Section with Performance Optimization
                          if (_chartData.isNotEmpty) ...[
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Inventory Status',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 300,
                                      child: _isRefreshing
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : SfCircularChart(
                                              title: const ChartTitle(
                                                  text:
                                                      'Chemical Inventory Overview'),
                                              legend: const Legend(
                                                isVisible: true,
                                                position: LegendPosition.bottom,
                                                overflowMode:
                                                    LegendItemOverflowMode.wrap,
                                              ),
                                              tooltipBehavior:
                                                  TooltipBehavior(enable: true),
                                              series: <CircularSeries<
                                                  _ChartData, String>>[
                                                PieSeries<_ChartData, String>(
                                                  dataSource: _chartData,
                                                  xValueMapper:
                                                      (_ChartData data, _) =>
                                                          data.x,
                                                  yValueMapper:
                                                      (_ChartData data, _) =>
                                                          data.y,
                                                  dataLabelMapper: (_ChartData
                                                              data,
                                                          _) =>
                                                      '${data.x}: ${data.y}',
                                                  dataLabelSettings:
                                                      const DataLabelSettings(
                                                    isVisible: true,
                                                    labelPosition:
                                                        ChartDataLabelPosition
                                                            .outside,
                                                    useSeriesColor: true,
                                                  ),
                                                  pointColorMapper:
                                                      (_ChartData data, _) {
                                                    switch (data.x) {
                                                      case 'Normal':
                                                        return Colors.green;
                                                      case 'Expiring Soon':
                                                        return Colors.orange;
                                                      case 'Low Stock':
                                                        return Colors.red;
                                                      default:
                                                        return Colors.blue;
                                                    }
                                                  },
                                                  explode: true,
                                                  explodeIndex: 0,
                                                )
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Equipment Status Chart - Now using real data
                            if (_equipmentChartData.isNotEmpty) ...[
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Equipment Status Overview',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 250,
                                        child: SfCartesianChart(
                                          primaryXAxis: const CategoryAxis(),
                                          primaryYAxis:
                                              const NumericAxis(minimum: 0),
                                          title: const ChartTitle(
                                              text: 'Equipment by Condition'),
                                          legend:
                                              const Legend(isVisible: false),
                                          tooltipBehavior:
                                              TooltipBehavior(enable: true),
                                          series: <CartesianSeries>[
                                            ColumnSeries<Map<String, dynamic>,
                                                String>(
                                              dataSource: _equipmentChartData,
                                              xValueMapper:
                                                  (Map<String, dynamic> data,
                                                          _) =>
                                                      data['condition'],
                                              yValueMapper:
                                                  (Map<String, dynamic> data,
                                                          _) =>
                                                      data['count'],
                                              name: 'Equipment Count',
                                              pointColorMapper:
                                                  (Map<String, dynamic> data,
                                                      _) {
                                                switch (data['condition']
                                                    .toString()
                                                    .toLowerCase()) {
                                                  case 'excellent':
                                                    return Colors.green;
                                                  case 'good':
                                                    return Colors.blue;
                                                  case 'fair':
                                                    return Colors.orange;
                                                  case 'poor':
                                                    return Colors.red;
                                                  default:
                                                    return Colors.grey;
                                                }
                                              },
                                              dataLabelSettings:
                                                  const DataLabelSettings(
                                                      isVisible: true),
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Show message when no equipment data
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Equipment Status Overview',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        height: 100,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'No equipment data available',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                                    .map<Widget>((chemical) {
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
                                    .map<Widget>((chemical) {
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
                                children: _reportData!['dueEquipment']
                                    .map<Widget>((eq) {
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
                                    .map<Widget>((borrowing) {
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

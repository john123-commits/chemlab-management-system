import 'package:flutter/material.dart';
import 'package:chemlab_frontend/models/chemical.dart';
import 'package:chemlab_frontend/models/chemical_usage_log.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:intl/intl.dart';

class UsageHistoryScreen extends StatefulWidget {
  final Chemical chemical;

  const UsageHistoryScreen({super.key, required this.chemical});

  @override
  State<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends State<UsageHistoryScreen> {
  List<ChemicalUsageLog> usageLogs = [];
  Map<String, dynamic>? statistics;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadUsageHistory();
  }

  Future<void> _loadUsageHistory() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await ApiService.getChemicalUsageHistory(
        widget.chemical.id,
        limit: 50,
      );

      if (response['success'] == true) {
        setState(() {
          usageLogs = (response['data']['usage_logs'] as List)
              .map((json) => ChemicalUsageLog.fromJson(json))
              .toList();
          statistics = response['data']['statistics'];
          isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load usage history');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage History'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Chemical Info Header
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.science, color: Colors.blue, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chemical.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'Current: ${widget.chemical.quantity}${widget.chemical.unit}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Statistics Card (if available)
          if (statistics != null && !isLoading)
            Container(
              margin: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Usage Statistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'Total Uses',
                            statistics!['total_usage_entries']?.toString() ??
                                '0',
                            Icons.history,
                          ),
                          _buildStatItem(
                            'Total Used',
                            '${statistics!['total_quantity_used']?.toStringAsFixed(1) ?? '0'}${widget.chemical.unit}',
                            Icons.remove_circle_outline,
                          ),
                          _buildStatItem(
                            'Avg. Usage',
                            '${statistics!['average_usage']?.toStringAsFixed(1) ?? '0'}${widget.chemical.unit}',
                            Icons.analytics,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Usage History List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsageHistory,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading usage history...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading usage history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsageHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (usageLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Usage History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No usage has been logged for this chemical yet.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: usageLogs.length,
      itemBuilder: (context, index) {
        final log = usageLogs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.2),
              child:
                  const Icon(Icons.remove_circle_outline, color: Colors.orange),
            ),
            title: Text(
              '${log.quantityUsed} ${widget.chemical.unit} used',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (log.purpose != null && log.purpose!.isNotEmpty)
                  Text('Purpose: ${log.purpose}'),
                if (log.userName != null) Text('By: ${log.userName}'),
                Text(
                  'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(log.usageDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Remaining: ${log.remainingQuantity} ${widget.chemical.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: log.notes != null && log.notes!.isNotEmpty
                ? const Icon(Icons.notes, color: Colors.grey)
                : null,
            onTap: log.notes != null && log.notes!.isNotEmpty
                ? () => _showNotesDialog(log)
                : null,
          ),
        );
      },
    );
  }

  void _showNotesDialog(ChemicalUsageLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usage Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage: ${log.quantityUsed} ${widget.chemical.unit}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (log.purpose != null && log.purpose!.isNotEmpty) ...[
              Text('Purpose: ${log.purpose}'),
              const SizedBox(height: 8),
            ],
            if (log.experimentReference != null &&
                log.experimentReference!.isNotEmpty) ...[
              Text('Experiment: ${log.experimentReference}'),
              const SizedBox(height: 8),
            ],
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const Text('Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(log.notes!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

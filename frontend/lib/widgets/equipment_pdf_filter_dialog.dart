import 'package:flutter/material.dart';
import '../models/equipment_pdf_filter_options.dart';

class EquipmentPdfFilterDialog extends StatefulWidget {
  final List<String> categories;
  final List<String> conditions;
  final EquipmentPdfFilterOptions initialOptions;

  const EquipmentPdfFilterDialog({
    Key? key,
    required this.categories,
    required this.conditions,
    required this.initialOptions,
  }) : super(key: key);

  @override
  _EquipmentPdfFilterDialogState createState() =>
      _EquipmentPdfFilterDialogState();
}

class _EquipmentPdfFilterDialogState extends State<EquipmentPdfFilterDialog> {
  late EquipmentPdfFilterOptions options;

  @override
  void initState() {
    super.initState();
    options = widget.initialOptions;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Equipment PDF Export Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content Sections
            Text('Include Sections:',
                style: Theme.of(context).textTheme.titleMedium),
            CheckboxListTile(
              title: const Text('Basic Information'),
              subtitle: const Text('Name, Category, Condition, Location'),
              value: options.includeBasicInfo,
              onChanged: (value) =>
                  setState(() => options.includeBasicInfo = value!),
            ),
            CheckboxListTile(
              title: const Text('Maintenance Information'),
              subtitle:
                  const Text('Last maintenance, next maintenance, schedule'),
              value: options.includeMaintenanceInfo,
              onChanged: (value) =>
                  setState(() => options.includeMaintenanceInfo = value!),
            ),
            CheckboxListTile(
              title: const Text('Calibration Information'),
              subtitle: const Text('Last calibration, next calibration'),
              value: options.includeCalibrationInfo,
              onChanged: (value) =>
                  setState(() => options.includeCalibrationInfo = value!),
            ),
            CheckboxListTile(
              title: const Text('Purchase & Warranty'),
              subtitle: const Text('Purchase date, warranty expiry'),
              value: options.includePurchaseWarranty,
              onChanged: (value) =>
                  setState(() => options.includePurchaseWarranty = value!),
            ),
            CheckboxListTile(
              title: const Text('Manufacturer Information'),
              subtitle: const Text('Serial number, manufacturer, model'),
              value: options.includeManufacturerInfo,
              onChanged: (value) =>
                  setState(() => options.includeManufacturerInfo = value!),
            ),

            const Divider(),

            // Filters
            Text('Filters:', style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: options.selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: (['All', ...widget.categories].toSet().toList())
                  .map((category) =>
                      DropdownMenuItem(value: category, child: Text(category)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => options.selectedCategory = value!),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: options.selectedCondition,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: (['All', ...widget.conditions].toSet().toList())
                  .map((condition) => DropdownMenuItem(
                      value: condition, child: Text(condition)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => options.selectedCondition = value!),
            ),

            const SizedBox(height: 16),

            CheckboxListTile(
              title: const Text('Maintenance Due Only'),
              subtitle: const Text('Show only equipment requiring maintenance'),
              value: options.maintenanceDueOnly,
              onChanged: (value) =>
                  setState(() => options.maintenanceDueOnly = value!),
            ),

            if (options.maintenanceDueOnly) ...[
              const SizedBox(height: 8),
              Text('Maintenance due within (days):'),
              TextField(
                decoration: const InputDecoration(
                  hintText: '30',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: options.maintenanceDueWithin.toString(),
                ),
                onChanged: (value) {
                  final days = int.tryParse(value);
                  if (days != null && days > 0) {
                    setState(() => options.maintenanceDueWithin = days);
                  }
                },
              ),
            ],

            CheckboxListTile(
              title: const Text('Calibration Due Only'),
              subtitle: const Text('Show only equipment requiring calibration'),
              value: options.calibrationDueOnly,
              onChanged: (value) =>
                  setState(() => options.calibrationDueOnly = value!),
            ),

            if (options.calibrationDueOnly) ...[
              const SizedBox(height: 8),
              Text('Calibration due within (days):'),
              TextField(
                decoration: const InputDecoration(
                  hintText: '30',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: options.calibrationDueWithin.toString(),
                ),
                onChanged: (value) {
                  final days = int.tryParse(value);
                  if (days != null && days > 0) {
                    setState(() => options.calibrationDueWithin = days);
                  }
                },
              ),
            ],

            CheckboxListTile(
              title: const Text('Warranty Expiring Only'),
              subtitle:
                  const Text('Show only equipment with expiring warranty'),
              value: options.warrantyExpiringOnly,
              onChanged: (value) =>
                  setState(() => options.warrantyExpiringOnly = value!),
            ),

            const SizedBox(height: 16),

            Text('Search Query (optional):'),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, manufacturer, or model',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: options.searchQuery),
              onChanged: (value) => setState(() => options.searchQuery = value),
            ),

            const Divider(),

            // Additional Options
            CheckboxListTile(
              title: const Text('Include Statistics'),
              subtitle: const Text('Summary statistics and overview'),
              value: options.includeStatistics,
              onChanged: (value) =>
                  setState(() => options.includeStatistics = value!),
            ),

            CheckboxListTile(
              title: const Text('Show Status Colors'),
              subtitle: const Text('Color-code items by status'),
              value: options.showStatusColors,
              onChanged: (value) =>
                  setState(() => options.showStatusColors = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, options),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Generate PDF'),
        ),
      ],
    );
  }
}

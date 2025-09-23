import 'package:flutter/material.dart';
import '../models/pdf_filter_options.dart';

class PdfFilterDialog extends StatefulWidget {
  final List<String> categories;
  final PdfFilterOptions initialOptions;

  const PdfFilterDialog({
    Key? key,
    required this.categories,
    required this.initialOptions,
  }) : super(key: key);

  @override
  _PdfFilterDialogState createState() => _PdfFilterDialogState();
}

class _PdfFilterDialogState extends State<PdfFilterDialog> {
  late PdfFilterOptions options;

  @override
  void initState() {
    super.initState();
    options = widget.initialOptions;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PDF Export Options'),
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
              subtitle: const Text('Name, Category, Quantity, Location'),
              value: options.includeBasicInfo,
              onChanged: (value) =>
                  setState(() => options.includeBasicInfo = value!),
            ),
            CheckboxListTile(
              title: const Text('Physical Properties'),
              subtitle: const Text('CAS, Formula, Weight, State, etc.'),
              value: options.includePhysicalProperties,
              onChanged: (value) =>
                  setState(() => options.includePhysicalProperties = value!),
            ),
            CheckboxListTile(
              title: const Text('Storage & Safety'),
              subtitle: const Text('Hazard Class, Precautions, Storage'),
              value: options.includeStorageSafety,
              onChanged: (value) =>
                  setState(() => options.includeStorageSafety = value!),
            ),
            CheckboxListTile(
              title: const Text('Stock Analysis'),
              subtitle: const Text('Usage, Reorder levels, Stock status'),
              value: options.includeStockAnalysis,
              onChanged: (value) =>
                  setState(() => options.includeStockAnalysis = value!),
            ),
            CheckboxListTile(
              title: const Text('Documents & Links'),
              subtitle: const Text('SDS references, MSDS links'),
              value: options.includeDocuments,
              onChanged: (value) =>
                  setState(() => options.includeDocuments = value!),
            ),

            const Divider(),

            // Filters
            Text('Filters:', style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: options.selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.categories
                  .map((category) =>
                      DropdownMenuItem(value: category, child: Text(category)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => options.selectedCategory = value!),
            ),

            CheckboxListTile(
              title: const Text('Low Stock Items Only'),
              value: options.lowStockOnly,
              onChanged: (value) =>
                  setState(() => options.lowStockOnly = value!),
            ),

            if (!options.lowStockOnly) ...[
              const SizedBox(height: 8),
              Text('Show items expiring within:'),
              RadioListTile<int>(
                title: const Text('All items'),
                value: 0,
                groupValue: options.expiringSoon,
                onChanged: (value) =>
                    setState(() => options.expiringSoon = value!),
              ),
              RadioListTile<int>(
                title: const Text('30 days'),
                value: 30,
                groupValue: options.expiringSoon,
                onChanged: (value) =>
                    setState(() => options.expiringSoon = value!),
              ),
              RadioListTile<int>(
                title: const Text('90 days'),
                value: 90,
                groupValue: options.expiringSoon,
                onChanged: (value) =>
                    setState(() => options.expiringSoon = value!),
              ),
            ],

            const Divider(),

            // Additional Options
            CheckboxListTile(
              title: const Text('Include Statistics'),
              subtitle: const Text('Summary charts and totals'),
              value: options.includeStatistics,
              onChanged: (value) =>
                  setState(() => options.includeStatistics = value!),
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

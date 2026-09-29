import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../services/excel_import_service.dart';

class ImportExcelDialog extends StatefulWidget {
  const ImportExcelDialog({super.key});

  @override
  State<ImportExcelDialog> createState() => _ImportExcelDialogState();
}

class _ImportExcelDialogState extends State<ImportExcelDialog> {
  bool _isLoading = false;
  ExcelImportResult? _result;
  String? _errorMessage;

  Future<void> _handlePickExcel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final importResult = await ExcelImportService.pickAndImportExcel();
      if (importResult != null) {
        setState(() {
          _result = importResult;
        });

        // Refresh products list in ProductProvider
        if (mounted) {
          context.read<ProductProvider>().fetchProducts();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Excel import error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.table_chart, color: Colors.green),
          SizedBox(width: 8),
          Text('Import Products Excel'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select an Excel (.xlsx / .xls / .csv) sheet containing product catalog:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Excel Format Columns:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text('Col A: Product Name', style: TextStyle(fontSize: 11)),
                  Text('Col B: Rate / Price (₹)', style: TextStyle(fontSize: 11)),
                  Text('Col C: Stock Qty', style: TextStyle(fontSize: 11)),
                  Text('Col D: HSN Code (e.g. 21069099)', style: TextStyle(fontSize: 11)),
                  Text('Col E: GST Rate % (e.g. 5)', style: TextStyle(fontSize: 11)),
                  Text('Col F: Pcs Per Box (e.g. 90)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              Center(
                child: Column(
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Uploading & Importing Products...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            else if (_result != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Success! ${_result!.successCount} Products Imported',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    if (_result!.errorCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${_result!.errorCount} items failed.',
                          style: const TextStyle(color: Colors.red, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handlePickExcel,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Choose Excel File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_result != null ? 'Done' : 'Cancel'),
        ),
      ],
    );
  }
}

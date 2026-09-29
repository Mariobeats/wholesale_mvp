import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import 'supabase_service.dart';

class ExcelImportResult {
  final int successCount;
  final int errorCount;
  final List<String> errorMessages;
  final List<ProductModel> importedProducts;

  ExcelImportResult({
    required this.successCount,
    required this.errorCount,
    required this.errorMessages,
    required this.importedProducts,
  });
}

class ExcelImportService {
  /// Allows the user to select an Excel (.xlsx / .xls) file and imports products.
  static Future<ExcelImportResult?> pickAndImportExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      List<int>? bytes;

      if (kIsWeb) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Could not read file content');
      }

      final excel = Excel.decodeBytes(bytes);
      final List<ProductModel> importedProducts = [];
      final List<String> errorMessages = [];
      int successCount = 0;
      int errorCount = 0;

      for (var table in excel.tables.keys) {
        final rows = excel.tables[table]?.rows;
        if (rows == null || rows.isEmpty) continue;

        // Skip header row if first row has text headers
        int startRowIndex = 0;
        final firstRow = rows.first;
        if (firstRow.isNotEmpty &&
            firstRow.any((cell) =>
                cell?.value.toString().toLowerCase().contains('name') == true ||
                cell?.value.toString().toLowerCase().contains('product') == true)) {
          startRowIndex = 1;
        }

        for (int i = startRowIndex; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue;

          final nameVal = row.isNotEmpty ? row[0]?.value?.toString().trim() : null;
          if (nameVal == null || nameVal.isEmpty) continue;

          final priceVal = row.length > 1 ? double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0.0 : 0.0;
          final stockVal = row.length > 2 ? int.tryParse(row[2]?.value?.toString() ?? '0') ?? 0 : 0;
          final hsnVal = row.length > 3 ? row[3]?.value?.toString().trim() : '21069099';
          final gstVal = row.length > 4 ? double.tryParse(row[4]?.value?.toString() ?? '5') ?? 5.0 : 5.0;
          final boxPcsVal = row.length > 5 ? int.tryParse(row[5]?.value?.toString() ?? '90') ?? 90 : 90;
          final unitVal = row.length > 6 ? row[6]?.value?.toString().trim() : 'PCS';

          final newProdMap = {
            'name': nameVal,
            'price': priceVal,
            'stock': stockVal,
            'hsn_code': hsnVal?.isEmpty == true ? '21069099' : hsnVal,
            'gst_rate': gstVal,
            'pcs_per_box': boxPcsVal,
            'unit': unitVal?.isEmpty == true ? 'PCS' : unitVal,
          };

          try {
            // Upload to Supabase if connected
            if (SupabaseService().isInitialized) {
              final res = await SupabaseService()
                  .client
                  .from('products')
                  .insert(newProdMap)
                  .select()
                  .single();
              importedProducts.add(ProductModel.fromJson(res));
            } else {
              importedProducts.add(ProductModel(
                id: '${DateTime.now().millisecondsSinceEpoch}_$i',
                name: nameVal,
                price: priceVal,
                stock: stockVal,
                hsnCode: hsnVal ?? '21069099',
                gstRate: gstVal,
                pcsPerBox: boxPcsVal,
                unit: unitVal ?? 'PCS',
              ));
            }
            successCount++;
          } catch (e) {
            errorCount++;
            errorMessages.add('Row ${i + 1} ($nameVal): $e');
          }
        }
      }


      return ExcelImportResult(
        successCount: successCount,
        errorCount: errorCount,
        errorMessages: errorMessages,
        importedProducts: importedProducts,
      );
    } catch (e) {
      debugPrint('Error importing Excel: $e');
      rethrow;
    }
  }
}

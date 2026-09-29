import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/order_model.dart';
import '../../models/party_model.dart';
import '../../services/tally_pdf_invoice_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  final OrderModel order;
  final PartyModel? party;

  const PdfPreviewScreen({
    super.key,
    required this.order,
    this.party,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Preview #${order.id.length > 6 ? order.id.substring(0, 6) : order.id}'),
      ),
      body: PdfPreview(
        build: (format) async {
          final pdfDoc = await TallyPdfInvoiceService.generatePdfInvoice(
            order: order,
            party: party,
          );
          return pdfDoc.save();
        },
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        pdfFileName: 'Invoice_${order.id}.pdf',
        loadingWidget: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Generating Tally GST Invoice Preview...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

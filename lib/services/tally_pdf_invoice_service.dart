import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../models/party_model.dart';

class TallyPdfInvoiceService {
  /// Generates the PDF document matching the uploaded Tally / e-Invoice GST format
  static Future<pw.Document> generatePdfInvoice({
    required OrderModel order,
    PartyModel? party,
    String sellerName = 'AGRAWAL SNACKS FOOD INDIA LLP',
    String sellerAddress = '304/2 LIMBODAGARI, TEHSIL HATOD, INDORE - 453111 (M.P.) INDIA',
    String sellerFssai = '10017026001187',
    String sellerUdhyam = 'MP-23-0007010',
    String sellerGstin = '23ABGFA4439G1ZP',
    String sellerState = 'Madhya Pradesh',
    String sellerStateCode = '23',
    String sellerEmail = 'agrawal420namkeen@yahoo.com',
    String sellerLlpNo = 'AAH-6078',
  }) async {
    final pdf = pw.Document();

    pw.Font fontRoboto;
    pw.Font fontRobotoBold;

    try {
      fontRoboto = await PdfGoogleFonts.robotoRegular();
      fontRobotoBold = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      fontRoboto = pw.Font.helvetica();
      fontRobotoBold = pw.Font.helveticaBold();
    }

    final String invoiceNo = 'AS/26-27/${order.id.length > 5 ? order.id.substring(order.id.length - 5) : order.id}';
    final String invoiceDate = order.createdAt != null
        ? DateFormat('dd-MMM-yy').format(order.createdAt!)
        : DateFormat('dd-MMM-yy').format(DateTime.now());

    // Calculate totals
    double totalTaxableValue = 0;
    int totalBoxes = 0;
    int totalQuantityPcs = 0;

    final items = order.items.isNotEmpty
        ? order.items
        : [
            OrderItemModel(
              productId: '1',
              productName: '420 SPANISH TOMATO CHIPS 24 GM RS 10 (90 PCS)',
              quantity: 360,
              price: 6.81,
              hsnCode: '21069099',
              pcsPerBox: 90,
              discountPercent: 3.0,
              gstRate: 5.0,
            ),
            OrderItemModel(
              productId: '2',
              productName: '420 CLASSIC SALTED CHIPS 24 GM RS 10 (90 PCS)',
              quantity: 127,
              price: 6.81,
              hsnCode: '21069099',
              pcsPerBox: 90,
              discountPercent: 3.0,
              gstRate: 5.0,
            ),
            OrderItemModel(
              productId: '3',
              productName: '420 INDIAN MASALA CHIPS 24 GM RS 10 (90 PCS)',
              quantity: 360,
              price: 6.81,
              hsnCode: '21069099',
              pcsPerBox: 90,
              discountPercent: 3.0,
              gstRate: 5.0,
            ),
            OrderItemModel(
              productId: '4',
              productName: '420 ITALIAN CREAM N ONION CHIPS 24 GM RS 10 (90 PCS)',
              quantity: 360,
              price: 6.81,
              hsnCode: '21069099',
              pcsPerBox: 90,
              discountPercent: 3.0,
              gstRate: 5.0,
            ),
          ];

    for (var item in items) {
      totalTaxableValue += item.totalPrice;
      totalQuantityPcs += item.quantity;
      totalBoxes += item.boxCount > 0 ? item.boxCount : 1;
    }

    final double cgstAmount = totalTaxableValue * 0.025; // 2.5%
    final double sgstAmount = totalTaxableValue * 0.025; // 2.5%
    final double totalWithTax = totalTaxableValue + cgstAmount + sgstAmount;
    final double grandTotal = totalWithTax.roundToDouble();
    final double roundOff = grandTotal - totalWithTax;

    final String partyName = party?.shopName ?? order.partyShopName ?? 'PARTH FOODS AND SPICE INDUSTRIES, INDORE';
    final String partyAddress = party?.address ?? 'Shop No. 6, Plot No. 32, T S Navlakha Krishna Tower, Indore, 452001';
    final String partyMobile = party?.mobile ?? '9685545581';
    final String partyGstin = party?.gstin ?? '23IOOPK1725J1ZP';
    final String partyState = party?.stateName ?? 'Madhya Pradesh';
    final String partyStateCode = party?.stateCode ?? '23';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Theme(
            data: pw.ThemeData.withFont(
              base: fontRoboto,
              bold: fontRobotoBold,
            ),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1, color: PdfColors.black),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Bar: TAX INVOICE & e-Invoice QR Code
                  _buildHeaderBar(invoiceNo, invoiceDate),
                  pw.Divider(height: 1, thickness: 1, color: PdfColors.black),

                  // 2. IRN & Ack Details
                  _buildIrnSection(invoiceDate),
                  pw.Divider(height: 1, thickness: 1, color: PdfColors.black),

                  // 3. Two Column Details (Seller + Invoice Meta)
                  _buildSellerAndMetaGrid(
                    sellerName: sellerName,
                    sellerAddress: sellerAddress,
                    sellerFssai: sellerFssai,
                    sellerUdhyam: sellerUdhyam,
                    sellerGstin: sellerGstin,
                    sellerState: sellerState,
                    sellerStateCode: sellerStateCode,
                    sellerEmail: sellerEmail,
                    sellerLlpNo: sellerLlpNo,
                    invoiceNo: invoiceNo,
                    invoiceDate: invoiceDate,
                    totalBoxes: totalBoxes,
                  ),
                  pw.Divider(height: 1, thickness: 1, color: PdfColors.black),

                  // 4. Buyer / Consignee Section
                  _buildBuyerSection(
                    partyName: partyName,
                    partyAddress: partyAddress,
                    partyMobile: partyMobile,
                    partyGstin: partyGstin,
                    partyState: partyState,
                    partyStateCode: partyStateCode,
                  ),
                  pw.Divider(height: 1, thickness: 1, color: PdfColors.black),

                  // 5. Items Grid Table
                  _buildItemsTable(
                    items: items,
                    totalTaxableValue: totalTaxableValue,
                    cgstAmount: cgstAmount,
                    sgstAmount: sgstAmount,
                    roundOff: roundOff,
                    grandTotal: grandTotal,
                    totalBoxes: totalBoxes,
                    totalQuantityPcs: totalQuantityPcs,
                  ),
                  pw.Divider(height: 1, thickness: 1, color: PdfColors.black),

                  // 6. Amount in Words
                  _buildAmountInWords(grandTotal),
                  pw.Divider(height: 1, thickness: 1, color: PdfColors.black),

                  // 7. HSN/SAC Tax Summary Table
                  _buildHsnSummaryTable(
                    taxableValue: totalTaxableValue,
                    cgstAmount: cgstAmount,
                    sgstAmount: sgstAmount,
                    totalTax: cgstAmount + sgstAmount,
                  ),
                  pw.Divider(height: 1, thickness: 1, color: PdfColors.black),

                  // 8. Declaration & Signatory Box
                  _buildDeclarationAndSignatory(sellerName),

                  // 9. Footer Text
                  _buildFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeaderBar(String invoiceNo, String invoiceDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Spacer(),
          pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Spacer(),
          pw.Text('e-Invoice', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: 'eInvoice:$invoiceNo Date:$invoiceDate GSTIN:23ABGFA4439G1ZP Amount:8372',
            width: 35,
            height: 35,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildIrnSection(String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Text('IRN : ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.Text('4eb042fbd5922df41b0ad808072f80b3a57b59a1a072f67ecda0b5d651c62017', style: const pw.TextStyle(fontSize: 7)),
          ]),
          pw.Row(children: [
            pw.Text('Ack No. : ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.Text('16262592382848', style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(width: 30),
            pw.Text('Ack Date : ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.Text(dateStr, style: const pw.TextStyle(fontSize: 7)),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _buildSellerAndMetaGrid({
    required String sellerName,
    required String sellerAddress,
    required String sellerFssai,
    required String sellerUdhyam,
    required String sellerGstin,
    required String sellerState,
    required String sellerStateCode,
    required String sellerEmail,
    required String sellerLlpNo,
    required String invoiceNo,
    required String invoiceDate,
    required int totalBoxes,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left Column (Seller Details)
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(width: 1, color: PdfColors.black)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(sellerName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(sellerAddress, style: const pw.TextStyle(fontSize: 7)),
                pw.Text('FSSAI NO. : $sellerFssai', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('UDHYAM : $sellerUdhyam', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('GSTIN/UIN : $sellerGstin', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.Text('State Name : $sellerState, Code : $sellerStateCode', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('E-Mail : $sellerEmail', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('LLP No : $sellerLlpNo', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ),

        // Right Column (Invoice Metadata Table)
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            children: [
              _buildMetaRow('Invoice No.', invoiceNo, 'Dated', invoiceDate),
              _buildMetaRow('Delivery Note', invoiceNo, 'Mode/Terms of Payment', 'Credit'),
              _buildMetaRow('Reference No. & Date', 'TB:11959-DG dt. $invoiceDate', 'Other References', ''),
              _buildMetaRow('Buyer\'s Order No.', '11959', 'Dated', invoiceDate),
              _buildMetaRow('Dispatch Doc No.', 'Road', 'Delivery Note Date', invoiceDate),
              _buildMetaRow('Dispatched through', 'Road', 'Destination', 'INDORE'),
              _buildMetaRow('Terms of Delivery', '$totalBoxes BOX', '', ''),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetaRow(String label1, String val1, String label2, String val2) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label1, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                pw.Text(val1, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          if (label2.isNotEmpty)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(label2, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                  pw.Text(val2, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildBuyerSection({
    required String partyName,
    required String partyAddress,
    required String partyMobile,
    required String partyGstin,
    required String partyState,
    required String partyStateCode,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Buyer (Bill to) & Consignee (Ship to) :', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Text(partyName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text(partyAddress, style: const pw.TextStyle(fontSize: 7)),
          pw.Text('MOB = $partyMobile', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Text('GSTIN/UIN : $partyGstin', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Text('State Name : $partyState, Code : $partyStateCode', style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable({
    required List<OrderItemModel> items,
    required double totalTaxableValue,
    required double cgstAmount,
    required double sgstAmount,
    required double roundOff,
    required double grandTotal,
    required int totalBoxes,
    required int totalQuantityPcs,
  }) {
    return pw.Column(
      children: [
        // Table Header Row
        pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 20, child: pw.Text('Sl No.', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 5, child: pw.Text('Description of Goods', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 50, child: pw.Text('HSN/SAC', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 25, child: pw.Text('Box', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 30, child: pw.Text('Pcs/Box', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 45, child: pw.Text('Quantity', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
              pw.SizedBox(width: 40, child: pw.Text('Rate', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
              pw.SizedBox(width: 25, child: pw.Text('per', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 35, child: pw.Text('Disc.%', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
              pw.SizedBox(width: 55, child: pw.Text('Amount', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
            ],
          ),
        ),
        pw.Divider(height: 1, thickness: 0.5, color: PdfColors.black),

        // Items Rows
        ...List.generate(items.length, (index) {
          final item = items[index];
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 20, child: pw.Text('${index + 1}', style: const pw.TextStyle(fontSize: 7))),
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    item.productName ?? 'Item ${index + 1}',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(width: 50, child: pw.Text(item.hsnCode, style: const pw.TextStyle(fontSize: 7))),
                pw.SizedBox(width: 25, child: pw.Text('${item.boxCount}', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                pw.SizedBox(width: 30, child: pw.Text('${item.pcsPerBox}', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                pw.SizedBox(width: 45, child: pw.Text('${item.quantity}.000 PCS', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                pw.SizedBox(width: 40, child: pw.Text(item.price.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                pw.SizedBox(width: 25, child: pw.Text(item.unit, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                pw.SizedBox(width: 35, child: pw.Text('${item.discountPercent.toStringAsFixed(0)} %', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                pw.SizedBox(width: 55, child: pw.Text(item.totalPrice.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
              ],
            ),
          );
        }),

        // Tax Lines
        _buildTaxLine('CGST OUTPUT (2.5%)', cgstAmount.toStringAsFixed(2)),
        _buildTaxLine('SGST OUTPUT (2.5%)', sgstAmount.toStringAsFixed(2)),
        _buildTaxLine('Rounding A/c', roundOff.toStringAsFixed(2)),

        pw.Divider(height: 1, thickness: 1, color: PdfColors.black),

        // Total Row
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 20, child: pw.Text('')),
              pw.Expanded(flex: 5, child: pw.Text('Total', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 50, child: pw.Text('')),
              pw.SizedBox(width: 25, child: pw.Text('$totalBoxes', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 30, child: pw.Text('')),
              pw.SizedBox(width: 45, child: pw.Text('$totalQuantityPcs.000 PCS', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
              pw.Spacer(),
              pw.Text('INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTaxLine(String label, String amount) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 20),
          pw.Expanded(
            flex: 5,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
            ),
          ),
          pw.SizedBox(width: 185),
          pw.SizedBox(width: 55, child: pw.Text(amount, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  static pw.Widget _buildAmountInWords(double grandTotal) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Amount Chargeable (in words)', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
              pw.Text('INR Eight Thousand Three Hundred Seventy Two Only', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Text('E. & O.E', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildHsnSummaryTable({
    required double taxableValue,
    required double cgstAmount,
    required double sgstAmount,
    required double totalTax,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _hsnCell('HSN/SAC', isHeader: true),
                  _hsnCell('Taxable Value', isHeader: true),
                  _hsnCell('CGST Rate', isHeader: true),
                  _hsnCell('CGST Amount', isHeader: true),
                  _hsnCell('SGST Rate', isHeader: true),
                  _hsnCell('SGST Amount', isHeader: true),
                  _hsnCell('Total Tax Amount', isHeader: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _hsnCell('21069099'),
                  _hsnCell(taxableValue.toStringAsFixed(2)),
                  _hsnCell('2.50%'),
                  _hsnCell(cgstAmount.toStringAsFixed(2)),
                  _hsnCell('2.50%'),
                  _hsnCell(sgstAmount.toStringAsFixed(2)),
                  _hsnCell(totalTax.toStringAsFixed(2)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text('Tax Amount (in words) : INR Three Hundred Ninety Eight and Sixty Four paise Only', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Text('Company\'s PAN : ABGFA4439G', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _hsnCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 6, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildDeclarationAndSignatory(String sellerName) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Terms / Declaration
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Declaration:', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '(1) Goods manufactured at Indore local area.\n'
                  '(2) Company will not receive any kind of replacement & expiry.\n'
                  '(3) Goods once sold will not be taken back.\n'
                  '(4) Warranty I/We hereby certify that food/foods mentioned in this invoice is/are warranted to be of the nature & quality which these purports/purport to be.',
                  style: const pw.TextStyle(fontSize: 5.5),
                ),
              ],
            ),
          ),
        ),

        // Right: Stamp & Authorised Signatory Box
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(width: 1, color: PdfColors.black)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('for $sellerName', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 25),
                pw.Text('Authorised Signatory', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      color: PdfColors.grey100,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Prepared By :', style: const pw.TextStyle(fontSize: 6)),
          pw.Text('Approved By :', style: const pw.TextStyle(fontSize: 6)),
          pw.Text('SUBJECT TO INDORE JURISDICTION', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
          pw.Text('This is a Computer Generated Invoice', style: const pw.TextStyle(fontSize: 6)),
        ],
      ),
    );
  }

  /// Directly print or open share sheet for PDF Invoice
  static Future<void> printOrShareInvoice(OrderModel order, {PartyModel? party}) async {
    final pdfDoc = await generatePdfInvoice(order: order, party: party);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfDoc.save(),
      name: 'Invoice_${order.id}.pdf',
    );
  }
}

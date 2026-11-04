// Apna Clinic - Billing Receipt PDF Generation Service
// Primary source of truth: TRD Section 9 & 10
// Itemized receipt with sequential invoice number, integer paise math, and payment method details

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/entities.dart';
import '../../core/utils/money.dart';

class ReceiptSlipService {
  static String _formatMoney(int paise) {
    return 'Rs. ${Money.fromPaise(paise).format(includeSymbol: false)}';
  }

  static Future<Uint8List> generateReceiptPdf({
    required Clinic clinic,
    required Invoice invoice,
    required Patient patient,
    List<Payment> payments = const [],
    String paperSize = 'A5',
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (clinic.logoBase64 != null && clinic.logoBase64!.trim().isNotEmpty) {
      try {
        final logoBytes = base64Decode(clinic.logoBase64!.trim());
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {}
    }

    final safePaperSize = (paperSize.isEmpty ? 'A5' : paperSize).toUpperCase();
    final pageFormat = safePaperSize == 'A4'
        ? PdfPageFormat.a4
        : PdfPageFormat.a5;

    final clinicDisplayName = clinic.displayName.trim().isNotEmpty
        ? clinic.displayName.trim()
        : (clinic.legalName.trim().isNotEmpty ? clinic.legalName.trim() : 'APNA CLINIC');
    final addressParts = [
      if (clinic.addressLine1.trim().isNotEmpty) clinic.addressLine1.trim(),
      if (clinic.city.trim().isNotEmpty) clinic.city.trim(),
      if (clinic.state.trim().isNotEmpty) clinic.state.trim(),
    ];
    final clinicAddress = addressParts.isNotEmpty
        ? '${addressParts.join(", ")}${clinic.pincode.trim().isNotEmpty ? " - ${clinic.pincode.trim()}" : ""}'
        : 'Clinic Address';
    final clinicPhone = clinic.contactPhone.trim().isNotEmpty ? clinic.contactPhone.trim() : 'N/A';

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 38,
                          height: 38,
                          margin: const pw.EdgeInsets.only(right: 8),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            clinicDisplayName,
                            style: const pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                            ),
                          ),
                          pw.Text(
                            clinicAddress,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            'Phone: $clinicPhone',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          if (clinic.taxRegistrationNumber != null &&
                              clinic.taxRegistrationNumber!.trim().isNotEmpty)
                            pw.Text(
                              'GSTIN: ${clinic.taxRegistrationNumber}',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RECEIPT / INVOICE',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800,
                        ),
                      ),
                      pw.Text(
                        'Invoice #: ${invoice.invoiceNumber}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Date: ${invoice.issueDateLocal}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'Status: ${invoice.status.name.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.status.name == 'paid'
                              ? PdfColors.green700
                              : PdfColors.amber800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.grey400),

              // Billed to
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Billed To: ${patient.fullName} (${patient.patientNumber})',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Phone: ${patient.maskedPhone}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // Itemized Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Item Description',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Qty',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Unit Price',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Discount',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Total',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final item in invoice.items)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            item.description,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            _formatMoney(item.unitPriceMinor),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            _formatMoney(item.discountMinor),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            _formatMoney(item.lineTotalMinor),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 8),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 180,
                    child: pw.Column(
                      children: [
                        _totalRow(
                          'Subtotal:',
                          _formatMoney(invoice.subtotalMinor),
                        ),
                        if (invoice.discountMinor > 0)
                          _totalRow(
                            'Discount:',
                            '- ${_formatMoney(invoice.discountMinor)}',
                          ),
                        if (invoice.taxMinor > 0)
                          _totalRow(
                            'Tax:',
                            _formatMoney(invoice.taxMinor),
                          ),
                        pw.Divider(thickness: 1, color: PdfColors.grey500),
                        _totalRow(
                          'Total Amount:',
                          _formatMoney(invoice.totalMinor),
                          isBold: true,
                        ),
                        _totalRow(
                          'Amount Paid:',
                          _formatMoney(invoice.paidMinor),
                        ),
                        _totalRow(
                          'Balance Due:',
                          _formatMoney(invoice.balanceMinor),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (payments.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Payment History:',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                for (final p in payments)
                  pw.Text(
                    '- ${p.method.name.toUpperCase()}: ${_formatMoney(p.amountMinor)} on ${p.receivedAt.toIso8601String().split('T').first}',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey800,
                    ),
                  ),
              ],

              pw.Spacer(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Thank you for visiting Apna Clinic.',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Authorized Reception Signatory',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> printReceipt({
    required Clinic clinic,
    required Invoice invoice,
    required Patient patient,
    List<Payment> payments = const [],
    String paperSize = 'A5',
  }) async {
    final pdfBytes = await generateReceiptPdf(
      clinic: clinic,
      invoice: invoice,
      patient: patient,
      payments: payments,
      paperSize: paperSize,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Receipt_${invoice.invoiceNumber}',
    );
  }
}

// Apna Clinic - Daily Report & Day Close PDF Generation Service
// ignore_for_file: prefer_const_constructors
// Primary source of truth: PRD Section 5 M07, Section 6.2, TRD Section 4 & 9
// Generates printable, privacy-safe A4 reports reconciling strictly to source ledger.
// DPDPA Compliant: Strictly excludes illness reasons, symptoms, and medical notes.

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/i_reports_repository.dart';

class ReportsPdfService {
  static String _formatMoney(int paise) {
    return 'Rs. ${Money.fromPaise(paise).format(includeSymbol: false)}';
  }

  static Future<Uint8List> generateDailyReportPdf({
    required Clinic clinic,
    required DailySummary summary,
    required List<DailySummary> doctorSummaries,
    required Map<String, String> doctorNames,
    DayClose? dayClose,
    List<ReportFinancialTransaction> transactions = const [],
    String staffName = 'Staff',
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (clinic.logoBase64 != null && clinic.logoBase64!.trim().isNotEmpty) {
      try {
        final logoBytes = base64Decode(clinic.logoBase64!.trim());
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {}
    }

    final clinicDisplayName = clinic.displayName.trim().isNotEmpty
        ? clinic.displayName.trim()
        : (clinic.legalName.trim().isNotEmpty ? clinic.legalName.trim() : 'APNA CLINIC');

    final addressParts = [
      if (clinic.addressLine1.trim().isNotEmpty) clinic.addressLine1.trim(),
      if (clinic.city.trim().isNotEmpty) clinic.city.trim(),
      if (clinic.state.trim().isNotEmpty) clinic.state.trim(),
    ];
    final clinicAddress = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Healthcare Operations';

    final now = DateTime.now();
    final printedTimestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        clinicDisplayName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        clinicAddress,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                      if (clinic.contactPhone.isNotEmpty) ...[
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'Phone: ${clinic.contactPhone}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (logoImage != null)
                  pw.Container(
                    width: 48,
                    height: 48,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: dayClose != null ? PdfColors.green50 : PdfColors.amber50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(
                          color: dayClose != null ? PdfColors.green700 : PdfColors.amber700,
                          width: 0.8,
                        ),
                      ),
                      child: pw.Text(
                        dayClose != null ? 'DAY RECONCILED & CLOSED' : 'DAY PENDING CLOSE',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: dayClose != null ? PdfColors.green900 : PdfColors.amber900,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Business Date: ${summary.localDate}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Text(
                      'Printed: $printedTimestamp by $staffName',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),

            // Report Title Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: PdfColors.grey100,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DAILY OPERATIONAL & FINANCIAL RECONCILIATION REPORT',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900,
                    ),
                  ),
                  pw.Text(
                    'INTEGER PAISE ACCREDITED',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 1: Financial Collections Summary Grid
            pw.Text(
              '1. FINANCIAL COLLECTIONS BREAKDOWN',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableHeaderCell('Gross Invoiced'),
                    _tableHeaderCell('Cash Collected'),
                    _tableHeaderCell('UPI Collected'),
                    _tableHeaderCell('Card Collected'),
                    _tableHeaderCell('Refunds Settled'),
                    _tableHeaderCell('Outstanding Balance'),
                    _tableHeaderCell('Net Collections'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _tableValueCell(_formatMoney(summary.invoicedMinor)),
                    _tableValueCell(_formatMoney(summary.paidCashMinor)),
                    _tableValueCell(_formatMoney(summary.paidUpiMinor)),
                    _tableValueCell(_formatMoney(summary.paidCardMinor)),
                    _tableValueCell(_formatMoney(summary.refundedMinor), color: PdfColors.red800),
                    _tableValueCell(_formatMoney(summary.outstandingMinor)),
                    _tableValueCell(
                      _formatMoney(summary.netCollectionsMinor),
                      color: PdfColors.green900,
                      isBold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Section 2: Patient Footfall & Queue Performance
            pw.Text(
              '2. PATIENT QUEUE & FOOTFALL EFFICIENCY',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableHeaderCell('Total Visits'),
                    _tableHeaderCell('Walk-In Tokens'),
                    _tableHeaderCell('Appointments'),
                    _tableHeaderCell('Completed'),
                    _tableHeaderCell('No-Shows'),
                    _tableHeaderCell('Cancelled'),
                    _tableHeaderCell('Completion Rate'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _tableValueCell('${summary.registeredCount}'),
                    _tableValueCell('${summary.walkinCount}'),
                    _tableValueCell('${summary.appointmentCount}'),
                    _tableValueCell('${summary.completedCount}'),
                    _tableValueCell('${summary.noShowCount}'),
                    _tableValueCell('${summary.cancelledCount}'),
                    _tableValueCell(
                      '${summary.completionRate.toStringAsFixed(1)}%',
                      isBold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Section 3: Doctor-Wise Breakdown
            if (doctorSummaries.isNotEmpty) ...[
              pw.Text(
                '3. DOCTOR-WISE CLINICAL & FINANCIAL BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableHeaderCell('Doctor Name', align: pw.TextAlign.left),
                      _tableHeaderCell('Total Visits'),
                      _tableHeaderCell('Completed'),
                      _tableHeaderCell('Cancelled / No-Show'),
                      _tableHeaderCell('Gross Invoiced'),
                      _tableHeaderCell('Net Collected'),
                    ],
                  ),
                  for (final ds in doctorSummaries) ...[
                    pw.TableRow(
                      children: [
                        _tableValueCell(
                          doctorNames[ds.doctorIdOptional ?? ''] ?? 'Dr. Assigned (${ds.doctorIdOptional})',
                          align: pw.TextAlign.left,
                        ),
                        _tableValueCell('${ds.registeredCount}'),
                        _tableValueCell('${ds.completedCount}'),
                        _tableValueCell('${ds.cancelledCount + ds.noShowCount}'),
                        _tableValueCell(_formatMoney(ds.invoicedMinor)),
                        _tableValueCell(_formatMoney(ds.netCollectionsMinor), isBold: true),
                      ],
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 12),
            ],

            // Section 4: Day Close Drawer Reconciliation
            if (dayClose != null) ...[
              pw.Text(
                '4. PHYSICAL CASH DRAWER RECONCILIATION (DAY CLOSE AUDIT)',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableHeaderCell('Opening Cash'),
                      _tableHeaderCell('Expected Cash'),
                      _tableHeaderCell('Counted Cash'),
                      _tableHeaderCell('Drawer Variance'),
                      _tableHeaderCell('Closed By'),
                      _tableHeaderCell('Closed At'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableValueCell(_formatMoney(dayClose.openingCashPaise)),
                      _tableValueCell(_formatMoney(dayClose.expectedCashPaise)),
                      _tableValueCell(_formatMoney(dayClose.countedCashPaise), isBold: true),
                      _tableValueCell(
                        dayClose.variancePaise == 0
                            ? 'MATCHED (Rs. 0)'
                            : (dayClose.variancePaise > 0
                                ? '+${_formatMoney(dayClose.variancePaise)} (Surplus)'
                                : '-${_formatMoney(dayClose.variancePaise.abs())} (Deficit)'),
                        color: dayClose.variancePaise == 0
                            ? PdfColors.green800
                            : (dayClose.variancePaise > 0 ? PdfColors.blue800 : PdfColors.red800),
                        isBold: true,
                      ),
                      _tableValueCell(dayClose.closedBy),
                      _tableValueCell(
                        '${dayClose.closedAt.hour.toString().padLeft(2, '0')}:${dayClose.closedAt.minute.toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),
                ],
              ),
              if (dayClose.notesOptional != null && dayClose.notesOptional!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Cashier Notes: ${dayClose.notesOptional}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
              pw.SizedBox(height: 12),
            ],

            // Section 5: Itemized Financial Transactions (DPDPA Privacy Preserved)
            if (transactions.isNotEmpty) ...[
              pw.Text(
                '5. RECONCILED TRANSACTION LEDGER (FIRST ${transactions.length.clamp(0, 15)} RECORDS)',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableHeaderCell('Invoice #', align: pw.TextAlign.left),
                      _tableHeaderCell('Patient Name', align: pw.TextAlign.left),
                      _tableHeaderCell('Doctor', align: pw.TextAlign.left),
                      _tableHeaderCell('Billed'),
                      _tableHeaderCell('Paid'),
                      _tableHeaderCell('Balance'),
                      _tableHeaderCell('Tender'),
                      _tableHeaderCell('Status'),
                    ],
                  ),
                  for (final tx in transactions.take(15)) ...[
                    pw.TableRow(
                      children: [
                        _tableValueCell(tx.invoiceNumber, align: pw.TextAlign.left),
                        _tableValueCell(tx.patientName, align: pw.TextAlign.left),
                        _tableValueCell(tx.doctorName, align: pw.TextAlign.left),
                        _tableValueCell(_formatMoney(tx.totalAmountMinor)),
                        _tableValueCell(_formatMoney(tx.paidAmountMinor)),
                        _tableValueCell(_formatMoney(tx.balanceDueMinor)),
                        _tableValueCell(tx.paymentMethods),
                        _tableValueCell(
                          tx.status,
                          color: tx.status == 'PAID'
                              ? PdfColors.green800
                              : (tx.status == 'VOIDED' ? PdfColors.red800 : PdfColors.amber800),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 12),
            ],

            // Footer / Privacy Isolation Notice
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.amber50,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.amber800,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(
                      'DPDPA & HEALTH PRIVACY NOTICE (PRD Sec 12 & 49): Ordinary management and financial reports strictly exclude patient-reported health reasons, diagnosis codes, and clinical descriptions. Medical notes remain isolated on paper consultation slips.',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _tableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _tableValueCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    PdfColor color = PdfColors.black,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static Future<void> printDailyReport({
    required Clinic clinic,
    required DailySummary summary,
    required List<DailySummary> doctorSummaries,
    required Map<String, String> doctorNames,
    DayClose? dayClose,
    List<ReportFinancialTransaction> transactions = const [],
    String staffName = 'Staff',
  }) async {
    final pdfBytes = await generateDailyReportPdf(
      clinic: clinic,
      summary: summary,
      doctorSummaries: doctorSummaries,
      doctorNames: doctorNames,
      dayClose: dayClose,
      transactions: transactions,
      staffName: staffName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Apna_Clinic_Report_${summary.localDate}.pdf',
    );
  }

  static Future<void> downloadDailyReportPdf({
    required Clinic clinic,
    required DailySummary summary,
    required List<DailySummary> doctorSummaries,
    required Map<String, String> doctorNames,
    DayClose? dayClose,
    List<ReportFinancialTransaction> transactions = const [],
    String staffName = 'Staff',
  }) async {
    final pdfBytes = await generateDailyReportPdf(
      clinic: clinic,
      summary: summary,
      doctorSummaries: doctorSummaries,
      doctorNames: doctorNames,
      dayClose: dayClose,
      transactions: transactions,
      staffName: staffName,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Apna_Clinic_Report_${summary.localDate}.pdf',
    );
  }
}

// Apna Clinic - Consultation Slip PDF Generation Service
// Primary source of truth: PRD Section 29, 30, 31 and TRD Section 9
// CLINICAL BOUNDARY MANDATE:
// Application generates blank handwriting sections. Doctor writes medicines, diagnosis,
// and advice by hand. The application NEVER generates prescription content or diagnoses.

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';

class ConsultationSlipService {
  /// Generates a PDF consultation slip in A5 (default) or A4 format
  static Future<Uint8List> generateConsultationSlipPdf({
    required Clinic clinic,
    required Doctor doctor,
    required Patient patient,
    required Visit visit,
    String? patientReportedReasonForVisit,
    String? clinicalNotes,
    String paperSize = 'A5',
    bool isReprint = false,
    bool showReasonForVisit = true,
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
    final clinicOpen = clinic.openingTime.trim().isNotEmpty ? clinic.openingTime.trim() : '09:00';
    final clinicClose = clinic.closingTime.trim().isNotEmpty ? clinic.closingTime.trim() : '21:00';

    final docName = doctor.displayName.trim().isNotEmpty
        ? doctor.displayName.trim()
        : 'Attending Physician';
    final docQual = doctor.qualificationText.trim().isNotEmpty
        ? ' (${doctor.qualificationText.trim()})'
        : '';
    final docReg = doctor.registrationNumber.trim().isNotEmpty
        ? doctor.registrationNumber.trim()
        : 'N/A';
    final docSpec = doctor.specialtyLabel.trim().isNotEmpty
        ? doctor.specialtyLabel.trim()
        : 'General Physician';
    final docRoom = doctor.roomLabel.trim().isNotEmpty
        ? doctor.roomLabel.trim()
        : 'Cabin 1';

    final patName = patient.fullName.trim().isNotEmpty
        ? patient.fullName.trim()
        : 'Unknown Patient';
    final patNumber = patient.patientNumber.trim().isNotEmpty
        ? patient.patientNumber.trim()
        : 'N/A';
    final patPhone = patient.phoneOptional != null && patient.phoneOptional!.trim().isNotEmpty
        ? patient.maskedPhone
        : 'N/A';
    final displayAge = patient.displayAge != null
        ? '${patient.displayAge} Y'
        : 'N/A';
    final displaySex = patient.sexOptional?.trim().isNotEmpty == true
        ? patient.sexOptional!.trim()
        : 'N/A';

    final hasPriority = visit.priority != QueuePriority.normal;
    final isDuplicate = isReprint || visit.slipPrintCount > 0;
    final tokenDisplay = visit.tokenNumber > 0 ? '#${visit.tokenNumber}' : '#--';
    final visitDate = visit.visitDateLocal.trim().isNotEmpty
        ? visit.visitDateLocal.trim()
        : DateTime.now().toIso8601String().split('T').first;
    final visitIdDisplay = visit.visitId.length > 8
        ? visit.visitId.substring(0, 8)
        : (visit.visitId.isNotEmpty ? visit.visitId : 'N/A');

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // REPRINT Watermark if applicable
              if (isDuplicate)
                pw.Center(
                  child: pw.Transform.rotateBox(
                    angle: 0.6,
                    child: pw.Text(
                      'DUPLICATE / REPRINT',
                      style: pw.TextStyle(
                        color: PdfColors.grey300,
                        fontSize: safePaperSize == 'A4' ? 60 : 38,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Top Duplicate Notice Banner
                  if (isDuplicate)
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.amber100,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'DUPLICATE / REPRINT CONSULTATION SLIP',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber900,
                            ),
                          ),
                          pw.Text(
                            'Printed: ${visit.slipPrintCount + 1} times',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber900,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. Clinic Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 42,
                          height: 42,
                          margin: const pw.EdgeInsets.only(right: 8),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      pw.Expanded(
                        child: pw.Column(
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
                            pw.SizedBox(height: 2),
                            pw.Text(
                              clinicAddress,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              'Phone: $clinicPhone | Timings: $clinicOpen - $clinicClose',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Token Badge
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColors.teal700,
                            width: 1.5,
                          ),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6),
                          ),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              'TOKEN',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal800,
                              ),
                            ),
                            pw.Text(
                              tokenDisplay,
                              style: const pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal900,
                              ),
                            ),
                            if (hasPriority) ...[
                              pw.SizedBox(height: 2),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: pw.BoxDecoration(
                                  color: visit.priority == QueuePriority.emergency
                                      ? PdfColors.red700
                                      : (visit.priority == QueuePriority.urgent
                                          ? PdfColors.amber800
                                          : PdfColors.purple700),
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                ),
                                child: pw.Text(
                                  visit.priority.displayName.toUpperCase(),
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 1, color: PdfColors.grey400),

                  // 2. Doctor & Visit Metadata Bar
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Dr. $docName$docQual',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Reg No: $docReg | $docSpec | $docRoom',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date: $visitDate',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Visit ID: $visitIdDisplay',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),

                  // 3. Patient Demographics Bar
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Patient: $patName',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Age/Sex: $displayAge / $displaySex',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'ID: $patNumber',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Phone: $patPhone',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),

                  if (patient.guardianNameOptional != null &&
                      patient.guardianNameOptional!.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Guardian / Contact: ${patient.guardianNameOptional}${patient.guardianRelationOptional != null && patient.guardianRelationOptional!.isNotEmpty ? " (${patient.guardianRelationOptional})" : ""}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],

                  if (showReasonForVisit &&
                      patientReportedReasonForVisit != null &&
                      patientReportedReasonForVisit.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Patient-reported reason for visit: $patientReportedReasonForVisit',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],

                  pw.SizedBox(height: 5),

                  // 3.5. PRE-PRINTED PHYSICAL VITALS RECORDING ROW
                  // Guided physical triage layout for handwritten BP, Pulse, Temp, Weight, SpO2 (PRD M05 compliant)
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.teal700, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      color: PdfColors.grey50,
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('BP: ________ mmHg', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text('Pulse: ____ /min', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text('Temp: ____ °F', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text('Weight: ____ kg', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text('SpO2: ____ %', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 5),
                  pw.Divider(thickness: 1, color: PdfColors.teal900),

                  // 4. LARGE BLANK HANDWRITING AREAS
                  // Area 1: Doctor's Notes (Clinical observations written manually or doctor-entered)
                  pw.Container(
                    height: paperSize.toUpperCase() == 'A4' ? 140 : 85,
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "DOCTOR'S NOTES / CLINICAL OBSERVATIONS",
                              style: const pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal800,
                              ),
                            ),
                            if (clinicalNotes != null && clinicalNotes.trim().isNotEmpty)
                              pw.Text(
                                "(Doctor Entered)",
                                style: const pw.TextStyle(
                                  fontSize: 7,
                                  fontStyle: pw.FontStyle.italic,
                                  color: PdfColors.grey600,
                                ),
                              ),
                          ],
                        ),
                        if (clinicalNotes != null && clinicalNotes.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            clinicalNotes.trim(),
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.black,
                              lineSpacing: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 6),

                  // Area 2: Prescription / Medicines (Handwritten Rx)
                  pw.Expanded(
                    child: pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey300,
                          width: 0.5,
                        ),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                'Rx  ',
                                style: const pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal900,
                                ),
                              ),
                              pw.Text(
                                'MEDICINES / PRESCRIPTION (Handwritten)',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 6),

                  // Area 3: Advice / Follow-up (Handwritten)
                  pw.Container(
                    height: paperSize.toUpperCase() == 'A4' ? 80 : 50,
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ADVICE / INVESTIGATIONS / NEXT FOLLOW-UP',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 10),

                  // 5. Signature Footer
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '* Not an E-Prescription. Doctor manually writes prescription and instructions.',
                        style: const pw.TextStyle(
                          fontSize: 6,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 100,
                            height: 1,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            "Doctor's Signature",
                            style: const pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
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

  /// Triggers browser print dialog for the generated PDF
  static Future<void> printSlip({
    required Clinic clinic,
    required Doctor doctor,
    required Patient patient,
    required Visit visit,
    String? patientReportedReasonForVisit,
    String? clinicalNotes,
    String paperSize = 'A5',
    bool isReprint = false,
    bool showReasonForVisit = true,
  }) async {
    final pdfBytes = await generateConsultationSlipPdf(
      clinic: clinic,
      doctor: doctor,
      patient: patient,
      visit: visit,
      patientReportedReasonForVisit: patientReportedReasonForVisit,
      clinicalNotes: clinicalNotes,
      paperSize: paperSize,
      isReprint: isReprint,
      showReasonForVisit: showReasonForVisit,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Consultation_Slip_Token_${visit.tokenNumber}',
    );
  }

  /// Triggers browser download / sharing for the generated PDF
  static Future<void> downloadSlipPdf({
    required Clinic clinic,
    required Doctor doctor,
    required Patient patient,
    required Visit visit,
    String? patientReportedReasonForVisit,
    String? clinicalNotes,
    String paperSize = 'A5',
    bool isReprint = false,
    bool showReasonForVisit = true,
  }) async {
    final pdfBytes = await generateConsultationSlipPdf(
      clinic: clinic,
      doctor: doctor,
      patient: patient,
      visit: visit,
      patientReportedReasonForVisit: patientReportedReasonForVisit,
      clinicalNotes: clinicalNotes,
      paperSize: paperSize,
      isReprint: isReprint,
      showReasonForVisit: showReasonForVisit,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Consultation_Slip_Token_${visit.tokenNumber}_${visit.visitDateLocal}.pdf',
    );
  }
}

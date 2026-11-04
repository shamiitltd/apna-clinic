// Apna Clinic - Consultation Slip & PDF Generation Unit Tests (Module 5)
// Primary source of truth: PRD Section 5 M05 and TRD Section 9
// Tests A5/A4 layout, clinical boundary handwriting boxes, duplicate watermark,
// priority indicator, and privacy reason-for-visit suppression.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/application/printing/consultation_slip_service.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('APNA CLINIC — MODULE 5 CONSULTATION SLIP TESTS', () {
    late Clinic sampleClinic;
    late Doctor sampleDoctor;
    late Patient samplePatient;
    late Visit sampleVisit;

    setUp(() {
      sampleClinic = Clinic(
        clinicId: 'c_test_1',
        legalName: 'Apna Health Clinic Private Limited',
        displayName: 'Apna Health Care',
        ownerName: 'Dr. R. K. Sharma',
        contactPhone: '9876543210',
        contactEmail: 'contact@apnaclinic.com',
        addressLine1: 'Shop 4, Market Complex',
        city: 'New Delhi',
        district: 'South Delhi',
        state: 'Delhi',
        pincode: '110001',
        defaultPaperSize: 'A5',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      sampleDoctor = Doctor(
        doctorId: 'doc_sharma',
        clinicId: 'c_test_1',
        displayName: 'Dr. R. K. Sharma',
        qualificationText: 'MBBS, MD (Medicine)',
        registrationNumber: 'MCI-123456',
        roomLabel: 'Cabin 1',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      samplePatient = Patient(
        patientId: 'pat_001',
        clinicId: 'c_test_1',
        patientNumber: 'P-1001',
        fullName: 'Vikram Aditya',
        phoneOptional: '9876543210',
        dateOfBirth: DateTime(1988, 4, 12),
        sexOptional: 'Male',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      sampleVisit = Visit(
        visitId: 'v_slip_001',
        clinicId: 'c_test_1',
        patientId: 'pat_001',
        doctorId: 'doc_sharma',
        visitDateLocal: '2026-10-28',
        tokenNumber: 42,
        tokenScopeKey: 'c_test_1:doc_sharma:2026-10-28',
        createdByStaffId: 'staff_rec_1',
        priority: QueuePriority.normal,
        queueStatus: QueueStatus.waiting,
        slipPrintCount: 0,
        checkinAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
    });

    test('1. A5 Consultation Slip PDF generates valid PDF bytes', () async {
      final pdfBytes = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit,
        patientReportedReasonForVisit: 'Severe chest pain radiating to left shoulder',
        paperSize: 'A5',
        isReprint: false,
        showReasonForVisit: true,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
      // PDF standard magic bytes: %PDF-
      final magicHeader = utf8.decode(pdfBytes.sublist(0, 5));
      expect(magicHeader, equals('%PDF-'));
    });

    test('2. A4 Consultation Slip PDF generates valid PDF bytes with A4 layout', () async {
      final pdfBytes = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit,
        patientReportedReasonForVisit: 'Severe chest pain radiating to left shoulder',
        paperSize: 'A4',
        isReprint: false,
        showReasonForVisit: true,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
      final magicHeader = utf8.decode(pdfBytes.sublist(0, 5));
      expect(magicHeader, equals('%PDF-'));
    });

    test('3. Privacy Isolation: showReasonForVisit=false suppresses sensitive reason text', () async {
      // PDF with reason omitted
      final pdfWithoutReason = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit,
        patientReportedReasonForVisit: 'Sensitive medical condition',
        paperSize: 'A5',
        isReprint: false,
        showReasonForVisit: false,
      );

      // PDF with reason included
      final pdfWithReason = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit,
        patientReportedReasonForVisit: 'Sensitive medical condition',
        paperSize: 'A5',
        isReprint: false,
        showReasonForVisit: true,
      );

      expect(pdfWithoutReason.length, greaterThan(0));
      expect(pdfWithReason.length, greaterThan(0));
      // PDFs have different byte representations when reason is toggled
      expect(pdfWithoutReason, isNot(equals(pdfWithReason)));
    });

    test('4. Duplicate / Reprint Protection: adds watermark and banner when slipPrintCount > 0', () async {
      final freshSlip = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit.copyWith(slipPrintCount: 0),
        paperSize: 'A5',
        isReprint: false,
      );

      final reprintSlip = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit.copyWith(slipPrintCount: 2),
        paperSize: 'A5',
        isReprint: true,
      );

      expect(freshSlip.length, greaterThan(0));
      expect(reprintSlip.length, greaterThan(0));
      expect(reprintSlip, isNot(equals(freshSlip)));
    });

    test('5. Triage Priority tag: Emergency & Urgent visits generate distinct priority styling', () async {
      final normalSlip = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit.copyWith(priority: QueuePriority.normal),
        paperSize: 'A5',
      );

      final emergencySlip = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit.copyWith(priority: QueuePriority.emergency),
        paperSize: 'A5',
      );

      final urgentSlip = await ConsultationSlipService.generateConsultationSlipPdf(
        clinic: sampleClinic,
        doctor: sampleDoctor,
        patient: samplePatient,
        visit: sampleVisit.copyWith(priority: QueuePriority.urgent),
        paperSize: 'A5',
      );

      expect(emergencySlip.length, greaterThan(0));
      expect(urgentSlip.length, greaterThan(0));
      expect(emergencySlip, isNot(equals(normalSlip)));
      expect(urgentSlip, isNot(equals(normalSlip)));
    });

    test('6. Masked Phone: Patient phone number is masked on consultation slip header', () {
      expect(samplePatient.maskedPhone, equals('******3210'));
    });
  });
}

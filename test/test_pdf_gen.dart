import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/application/printing/receipt_slip_service.dart';
import 'package:apna_clinic/application/printing/consultation_slip_service.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/repositories/patient_repository.dart';

void main() {
  test('PDF Generation: Itemized Receipt & Consultation Slip bytes generate cleanly', () async {
    final now = DateTime.now().toUtc();
    final clinic = Clinic(
      clinicId: 'clinic_test',
      legalName: 'Test Clinic',
      displayName: 'Test Clinic',
      ownerName: 'Dr. Test Owner',
      contactPhone: '9876543210',
      contactEmail: 'test@clinic.com',
      addressLine1: 'Road 1',
      city: 'Delhi',
      district: 'Delhi',
      state: 'Delhi',
      pincode: '110001',
      createdAt: now,
      updatedAt: now,
    );

    final doctor = Doctor(
      doctorId: 'doc_1',
      clinicId: 'clinic_test',
      displayName: 'Dr. Test',
      createdAt: now,
      updatedAt: now,
    );

    final patient = Patient(
      patientId: 'pat_1',
      clinicId: 'clinic_test',
      patientNumber: 'P-101',
      fullName: 'Test Patient',
      createdAt: now,
      updatedAt: now,
    );

    final visit = Visit(
      visitId: 'vis_1',
      clinicId: 'clinic_test',
      patientId: 'pat_1',
      doctorId: 'doc_1',
      visitDateLocal: '2026-10-23',
      checkinAt: now,
      tokenNumber: 1,
      tokenScopeKey: 'test',
      createdByStaffId: 'staff_1',
      createdAt: now,
      updatedAt: now,
    );

    final invoice = Invoice(
      invoiceId: 'inv_1',
      clinicId: 'clinic_test',
      invoiceNumber: 'INV-001',
      financialYear: '2026-2027',
      patientId: 'pat_1',
      issueDateLocal: '2026-10-23',
      subtotalMinor: 50000,
      totalMinor: 50000,
      paidMinor: 50000,
      balanceMinor: 0,
      createdByStaffId: 'staff_1',
      createdAt: now,
      updatedAt: now,
      items: [
        InvoiceItem(
          invoiceItemId: 'item_1',
          clinicId: 'clinic_test',
          invoiceId: 'inv_1',
          description: 'Consultation Fee',
          quantity: 1,
          unitPriceMinor: 50000,
          discountMinor: 0,
          taxMinor: 0,
          lineTotalMinor: 50000,
          createdAt: now,
        )
      ],
    );

    final rBytes = await ReceiptSlipService.generateReceiptPdf(
      clinic: clinic,
      invoice: invoice,
      patient: patient,
    );
    expect(rBytes, isNotEmpty);
    expect(rBytes.length, greaterThan(1000));

    final cBytes = await ConsultationSlipService.generateConsultationSlipPdf(
      clinic: clinic,
      doctor: doctor,
      patient: patient,
      visit: visit,
    );
    expect(cBytes, isNotEmpty);
    expect(cBytes.length, greaterThan(1000));
  });

  test('PDF Generation: Slips embed clinic logo seamlessly when logoBase64 is present', () async {
    final now = DateTime.now().toUtc();
    const sampleLogoBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

    final brandedClinic = Clinic(
      clinicId: 'clinic_branded',
      legalName: 'Apex Health Ltd',
      displayName: 'Apex Super Clinic',
      ownerName: 'Dr. Apex',
      contactPhone: '9876543210',
      contactEmail: 'apex@clinic.in',
      addressLine1: 'Road 1',
      city: 'Delhi',
      district: 'Delhi',
      state: 'Delhi',
      pincode: '110001',
      createdAt: now,
      updatedAt: now,
      logoBase64: sampleLogoBase64,
      logoDriveFileId: 'drive_logo_file_123',
    );

    final doctor = Doctor(
      doctorId: 'doc_1',
      clinicId: 'clinic_branded',
      displayName: 'Dr. Test',
      createdAt: now,
      updatedAt: now,
    );

    final patient = Patient(
      patientId: 'pat_1',
      clinicId: 'clinic_branded',
      patientNumber: 'P-101',
      fullName: 'Test Patient',
      createdAt: now,
      updatedAt: now,
    );

    final visit = Visit(
      visitId: 'vis_1',
      clinicId: 'clinic_branded',
      patientId: 'pat_1',
      doctorId: 'doc_1',
      visitDateLocal: '2026-10-23',
      checkinAt: now,
      tokenNumber: 1,
      tokenScopeKey: 'test',
      createdByStaffId: 'staff_1',
      createdAt: now,
      updatedAt: now,
    );

    final invoice = Invoice(
      invoiceId: 'inv_1',
      clinicId: 'clinic_branded',
      invoiceNumber: 'INV-001',
      financialYear: '2026-2027',
      patientId: 'pat_1',
      issueDateLocal: '2026-10-23',
      subtotalMinor: 50000,
      totalMinor: 50000,
      paidMinor: 50000,
      balanceMinor: 0,
      createdByStaffId: 'staff_1',
      createdAt: now,
      updatedAt: now,
      items: [
        InvoiceItem(
          invoiceItemId: 'item_1',
          clinicId: 'clinic_branded',
          invoiceId: 'inv_1',
          description: 'Consultation Fee',
          quantity: 1,
          unitPriceMinor: 50000,
          discountMinor: 0,
          taxMinor: 0,
          lineTotalMinor: 50000,
          createdAt: now,
        )
      ],
    );

    final receiptBytes = await ReceiptSlipService.generateReceiptPdf(
      clinic: brandedClinic,
      invoice: invoice,
      patient: patient,
    );
    expect(receiptBytes, isNotEmpty);
    expect(receiptBytes.length, greaterThan(1000));

    final slipBytes = await ConsultationSlipService.generateConsultationSlipPdf(
      clinic: brandedClinic,
      doctor: doctor,
      patient: patient,
      visit: visit,
    );
    expect(slipBytes, isNotEmpty);
    expect(slipBytes.length, greaterThan(1000));
  });

  test('Patient Deduplication: Prevents registering patients with identical credentials multiple times', () async {
    final db = LocalDatabase(MemoryStorageAdapter());
    await db.initialize();
    final patientRepo = PatientRepository(db);
    final now = DateTime.now().toUtc();

    final p1 = Patient(
      patientId: 'pat_orig',
      clinicId: 'clinic_1',
      patientNumber: 'P-0001',
      fullName: 'Sunita Sharma',
      phoneOptional: '9876543210',
      createdAt: now,
      updatedAt: now,
    );

    await patientRepo.savePatient(p1);

    // Attempting to save another patient with the exact same name and phone must throw StateError
    final p2 = Patient(
      patientId: 'pat_dup',
      clinicId: 'clinic_1',
      patientNumber: 'P-0002',
      fullName: '  sunita sharma  ', // case & trim insensitive
      phoneOptional: '+919876543210',  // normalized phone matches
      createdAt: now,
      updatedAt: now,
    );

    expect(
      () => patientRepo.savePatient(p2),
      throwsA(isA<StateError>()),
      reason: 'Should block creation of patient with duplicate phone and name',
    );

    // Family member with different name sharing the same phone must be allowed
    final pFamily = Patient(
      patientId: 'pat_family',
      clinicId: 'clinic_1',
      patientNumber: 'P-0003',
      fullName: 'Aarav Sharma', // Different family member name
      phoneOptional: '9876543210', // Shared phone number
      createdAt: now,
      updatedAt: now,
    );

    await patientRepo.savePatient(pFamily);
    final count = await patientRepo.countPatients('clinic_1');
    expect(count, equals(2));
  });
}

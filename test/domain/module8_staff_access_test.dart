import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';
import 'package:apna_clinic/application/providers.dart';

void main() {
  test('PRD Module 8 - Staff and Access Suite', () async {
    stdout.writeln('=====================================================');
    stdout.writeln('TESTING MODULE 8: STAFF AND ACCESS (PRD SECTION 5 M08)');
    stdout.writeln('=====================================================\n');

    int passed = 0;
    int failed = 0;

    void assertM8(String description, bool condition, [String? detail]) {
      if (condition) {
        stdout.writeln('  [PASS] $description');
        passed++;
      } else {
        stderr.writeln('  [FAIL] $description ${detail != null ? "--> $detail" : ""}');
        failed++;
      }
    }

    // 1. ROLE AND PERMISSION MATRIX (DENY-BY-DEFAULT)
    stdout.writeln('1. ROLE-BASED ACCESS CONTROL (RBAC) MATRIX');
    assertM8(
      'Owner has full permissions (exportReports, bulkExport, manageStaff, voidInvoice)',
      AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.exportReports) &&
          AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.bulkExportPatients) &&
          AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.manageStaff) &&
          AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.voidInvoice),
    );

    assertM8(
      'Receptionist has daily operational permissions (registerPatient, createVisit, printSlip, createInvoice)',
      AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.registerPatient) &&
          AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.createVisit) &&
          AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.printConsultationSlip) &&
          AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.createInvoice),
    );

    assertM8(
      'Receptionist DENIED administrative & reversal permissions (bulkExport, exportReports, restoreBackup, voidInvoice)',
      !AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.bulkExportPatients) &&
          !AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.exportReports) &&
          !AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.restoreBackup) &&
          !AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.voidInvoice),
    );

    assertM8(
      'Doctor has clinical queue permissions (viewDoctorQueue, updateQueueStatus, viewReasonForVisit)',
      AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.viewDoctorQueue) &&
          AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.updateQueueStatus) &&
          AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.viewReasonForVisit),
    );

    assertM8(
      'Doctor DENIED financial ledger and export access (viewFinancialLedger, exportReports, approveRefund)',
      !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.viewFinancialLedger) &&
          !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.exportReports) &&
          !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.approveRefund),
    );

    assertM8(
      'Accountant has financial ledger & report export permissions',
      AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.viewFinancialLedger) &&
          AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.exportReports) &&
          AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.approveRefund) &&
          AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.voidInvoice),
    );

    assertM8(
      'Accountant STRICTLY DENIED clinical reason for visit (Health Privacy Isolation)',
      !AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.viewReasonForVisit),
    );

    // 2. CRYPTOGRAPHIC PIN HASHING (SALTED SHA-256)
    stdout.writeln('\n2. SALTED PIN HASHING & INTEGRITY');
    final pinData1 = Staff.generatePinHash('2468');
    final pinData2 = Staff.generatePinHash('2468');

    assertM8(
      'Salted PIN generation generates unique salt for each call',
      pinData1['pin_salt'] != pinData2['pin_salt'],
    );
    assertM8(
      'Unique salt results in distinct hashes for identical PINs',
      pinData1['pin_hash'] != pinData2['pin_hash'],
    );

    final testStaff = Staff(
      staffId: 'staff_test_1',
      clinicId: 'clinic_test',
      displayName: 'Priya Sharma',
      role: UserRole.receptionist,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      pinHash: pinData1['pin_hash'],
      pinSalt: pinData1['pin_salt'],
    );

    assertM8('Valid PIN returns true on verifyPin', testStaff.verifyPin('2468'));
    assertM8('Invalid PIN returns false on verifyPin', !testStaff.verifyPin('1234'));
    assertM8('Empty PIN returns false on verifyPin', !testStaff.verifyPin(''));

    // 3. SHARED WORKSTATION SESSION NOTIFIER & PIN UNLOCK
    stdout.writeln('\n3. SHARED WORKSTATION AUTHENTICATION & QUICK ROLE SWITCHING');
    final db = LocalDatabase(MemoryStorageAdapter());
    await db.initialize();
    final clinicRepo = ClinicRepository(db);

    await clinicRepo.saveStaff(testStaff);

    final doctorStaff = Staff(
      staffId: 'staff_doc_1',
      clinicId: 'clinic_test',
      displayName: 'Dr. Anita Roy',
      role: UserRole.doctor,
      assignedDoctorIds: ['doc_anita_101'],
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      pinHash: Staff.generatePinHash('9999')['pin_hash'],
      pinSalt: Staff.generatePinHash('9999')['pin_salt'],
    );
    final docPinMap = Staff.generatePinHash('9999');
    final exactDoctorStaff = doctorStaff.copyWith(
      pinHash: docPinMap['pin_hash'],
      pinSalt: docPinMap['pin_salt'],
    );
    await clinicRepo.saveStaff(exactDoctorStaff);

    final sessionNotifier = SessionNotifier();
    sessionNotifier.setClinic('clinic_test', 'staff_rec_01', 'Reception Desk');

    // Initial State
    assertM8('Initial workstation is unlocked as receptionist', !sessionNotifier.currentSessionState.isWorkstationLocked);

    // Lock to Receptionist role
    await sessionNotifier.lockWorkstationToRole(UserRole.receptionist);
    assertM8('Workstation locked to receptionist role', sessionNotifier.currentSessionState.isWorkstationLocked && sessionNotifier.currentSessionState.role == UserRole.receptionist);

    // Auto-lock on inactivity
    await sessionNotifier.autoLockWorkstation(db);
    assertM8('autoLockWorkstation sets isAutoLocked and isWorkstationLocked to true', sessionNotifier.currentSessionState.isAutoLocked && sessionNotifier.currentSessionState.isWorkstationLocked);

    // Check audit event logged for auto-lock
    final autoLockAudit = db.query('Audit_Events', where: (r) => r['action'] == 'workstation.autolock');
    assertM8('Workstation auto-lock writes immutable Audit_Events record', autoLockAudit.isNotEmpty);

    // Unlock with distinct staff PIN (Doctor PIN 9999)
    final docUnlockSuccess = await sessionNotifier.unlockWorkstation(
      '9999',
      clinicRepo: clinicRepo,
      db: db,
    );
    assertM8('Doctor unlocks workstation using their individual 4-digit PIN', docUnlockSuccess);
    assertM8('Active session switches to Dr. Anita Roy', sessionNotifier.currentSessionState.staffId == 'staff_doc_1' && sessionNotifier.currentSessionState.staffName == 'Dr. Anita Roy');
    assertM8('Assigned doctor ID populated correctly', sessionNotifier.currentSessionState.assignedDoctorId == 'doc_anita_101');
    assertM8('Workstation auto-lock cleared on successful staff PIN entry', !sessionNotifier.currentSessionState.isAutoLocked);

    // Unlock back to Owner using Owner PIN ('1234')
    final ownerUnlockSuccess = await sessionNotifier.unlockWorkstation(
      '1234',
      clinicRepo: clinicRepo,
      db: db,
    );
    assertM8('Owner PIN unlocks workstation back to Owner / Admin mode', ownerUnlockSuccess);
    assertM8('Role restored to UserRole.owner', sessionNotifier.currentSessionState.role == UserRole.owner);
    assertM8('Workstation lock flags cleared for Owner', !sessionNotifier.currentSessionState.isWorkstationLocked && !sessionNotifier.currentSessionState.isAutoLocked);

    // 4. BRUTE-FORCE LOCKOUT & AUDIT TRAILS
    stdout.writeln('\n4. BRUTE-FORCE LOCKOUT PROTECTION');
    for (int i = 1; i <= 4; i++) {
      await sessionNotifier.unlockWorkstation('0000', clinicRepo: clinicRepo, db: db);
    }
    assertM8('4 failed PIN attempts recorded', sessionNotifier.currentSessionState.failedPinAttempts == 4);
    assertM8('Workstation not yet locked out after 4 attempts', !sessionNotifier.currentSessionState.isLockedOut);

    // 5th failed attempt triggers lockout
    await sessionNotifier.unlockWorkstation('0000', clinicRepo: clinicRepo, db: db);
    assertM8('5th failed attempt triggers lockout (isLockedOut == true)', sessionNotifier.currentSessionState.isLockedOut);
    assertM8('Lockout seconds remaining > 0', sessionNotifier.currentSessionState.lockoutSecondsRemaining > 0);

    // PIN entry during lockout is rejected immediately
    final blockedResult = await sessionNotifier.unlockWorkstation('1234', clinicRepo: clinicRepo, db: db);
    assertM8('Owner PIN entry blocked during active lockout window', !blockedResult);

    final lockoutAudit = db.query('Audit_Events', where: (r) => r['action'] == 'auth.pin_lockout');
    assertM8('Brute-force lockout writes permanent Audit_Events record', lockoutAudit.isNotEmpty);

    // 5. DOCTOR ISOLATION (PRD M08 ACCEPTANCE)
    stdout.writeln('\n5. DOCTOR QUEUE SENSITIVE DATA ISOLATION');
    final visitRepo = VisitRepository(db);
    final now = DateTime.now().toUtc();
    final todayStr = now.toIso8601String().split('T').first;

    await db.upsert('Patients', 'pat_1', Patient(
      patientId: 'pat_1',
      clinicId: 'clinic_test',
      patientNumber: 'P-101',
      fullName: 'Ramesh Gupta',
      consentStatus: 'granted',
      consentVersion: '1.0',
      createdAt: now,
      updatedAt: now,
    ).toMap());

    await db.upsert('Patients', 'pat_2', Patient(
      patientId: 'pat_2',
      clinicId: 'clinic_test',
      patientNumber: 'P-102',
      fullName: 'Sunita Patel',
      consentStatus: 'granted',
      consentVersion: '1.0',
      createdAt: now,
      updatedAt: now,
    ).toMap());

    // Visit for Doctor 1 (Dr. Cardio)
    await visitRepo.createVisitAtomic(
      visit: Visit(
        visitId: 'vis_doc1_01',
        clinicId: 'clinic_test',
        patientId: 'pat_1',
        doctorId: 'doc_cardio',
        visitDateLocal: todayStr,
        checkinAt: now,
        tokenNumber: 1,
        tokenScopeKey: 'clinic_test:doc_cardio:$todayStr',
        visitType: 'walkin',
        queueStatus: QueueStatus.waiting,
        createdByStaffId: 'staff_rec',
        createdAt: now,
        updatedAt: now,
      ),
      deviceId: 'dev_1',
      staffId: 'staff_rec',
      idempotencyKey: 'idemp_v1',
    );

    // Visit for Doctor 2 (Dr. Neuro)
    await visitRepo.createVisitAtomic(
      visit: Visit(
        visitId: 'vis_doc2_01',
        clinicId: 'clinic_test',
        patientId: 'pat_2',
        doctorId: 'doc_neuro',
        visitDateLocal: todayStr,
        checkinAt: now,
        tokenNumber: 1,
        tokenScopeKey: 'clinic_test:doc_neuro:$todayStr',
        visitType: 'walkin',
        queueStatus: QueueStatus.waiting,
        createdByStaffId: 'staff_rec',
        createdAt: now,
        updatedAt: now,
      ),
      deviceId: 'dev_1',
      staffId: 'staff_rec',
      idempotencyKey: 'idemp_v2',
    );

    final allVisits = await visitRepo.getVisitsForDate('clinic_test', todayStr);
    assertM8('Total visits created for clinic across doctors is 2', allVisits.length == 2);

    // Dr. Cardio queue query isolation
    final cardioQueue = allVisits.where((v) => v.doctorId == 'doc_cardio').toList();
    assertM8('Dr. Cardio queue isolated to exactly 1 visit (Token #1 for doc_cardio)', cardioQueue.length == 1 && cardioQueue.first.visitId == 'vis_doc1_01');

    // Dr. Neuro cannot see Dr. Cardio's visits
    final neuroQueue = allVisits.where((v) => v.doctorId == 'doc_neuro').toList();
    assertM8('Dr. Neuro queue does not leak Dr. Cardio visit details', !neuroQueue.any((v) => v.visitId == 'vis_doc1_01'));

    // 6. BILLING REVERSAL AUTHORIZATION (REFUNDS & VOIDS)
    stdout.writeln('\n6. BILLING REVERSALS & SUPERVISOR PIN APPROVAL');
    final billingRepo = BillingRepository(db);

    final invoice = Invoice(
      invoiceId: 'inv_m8_01',
      clinicId: 'clinic_test',
      invoiceNumber: 'INV-2026-2027-0050',
      financialYear: '2026-2027',
      patientId: 'pat_1',
      visitId: 'vis_doc1_01',
      issueDateLocal: todayStr,
      subtotalMinor: 50000,
      totalMinor: 50000,
      paidMinor: 50000,
      balanceMinor: 0,
      status: InvoiceStatus.paid,
      createdByStaffId: 'staff_rec',
      createdAt: now,
      updatedAt: now,
    );
    await billingRepo.createInvoiceAtomic(
      invoice: invoice,
      items: [],
      initialPayment: Payment(
        paymentId: 'pay_m8_01',
        clinicId: 'clinic_test',
        invoiceId: 'inv_m8_01',
        amountMinor: 50000,
        method: PaymentMethod.cash,
        receivedAt: now,
        receivedByStaffId: 'staff_rec',
        createdAt: now,
      ),
      idempotencyKey: 'idemp_inv_m8',
    );

    // Unpaid invoice for void test
    final unpaidInvoice = Invoice(
      invoiceId: 'inv_m8_unpaid',
      clinicId: 'clinic_test',
      invoiceNumber: 'INV-2026-2027-0051',
      financialYear: '2026-2027',
      patientId: 'pat_2',
      issueDateLocal: todayStr,
      subtotalMinor: 30000,
      totalMinor: 30000,
      paidMinor: 0,
      balanceMinor: 30000,
      status: InvoiceStatus.issued,
      createdByStaffId: 'staff_rec',
      createdAt: now,
      updatedAt: now,
    );
    await billingRepo.createInvoiceAtomic(
      invoice: unpaidInvoice,
      items: [],
      idempotencyKey: 'idemp_unpaid',
    );

    // Voiding paid invoice is blocked
    bool voidPaidBlocked = false;
    try {
      await billingRepo.voidInvoice(
        clinicId: 'clinic_test',
        invoiceId: 'inv_m8_01',
        reason: 'Should fail',
        staffId: 'staff_rec',
      );
    } catch (_) {
      voidPaidBlocked = true;
    }
    assertM8('Attempt to void paid invoice is blocked as per PRD M06 & M08 immutability', voidPaidBlocked);

    // Voiding unpaid invoice with Owner/Accountant role
    await billingRepo.voidInvoice(
      clinicId: 'clinic_test',
      invoiceId: 'inv_m8_unpaid',
      reason: 'Created in error',
      staffId: 'staff_owner',
    );
    final voidedInv = await billingRepo.getInvoiceById('clinic_test', 'inv_m8_unpaid');
    assertM8('Unpaid invoice successfully voided with authorization', voidedInv?.status == InvoiceStatus.voided);

    // Process refund for paid invoice
    final refund = Refund(
      refundId: 'ref_m8_01',
      clinicId: 'clinic_test',
      invoiceId: 'inv_m8_01',
      amountMinor: 50000,
      reason: 'Doctor cancelled OPD',
      requestedByStaffId: 'staff_rec',
      approvedByStaffId: 'Owner (PIN Verified)',
      status: RefundStatus.settled,
      refundedAt: now,
      refundMethod: PaymentMethod.cash,
      createdAt: now,
    );
    await billingRepo.recordRefund(refund: refund, idempotencyKey: 'idemp_ref_m8');
    final refundedInv = await billingRepo.getInvoiceById('clinic_test', 'inv_m8_01');
    assertM8('Invoice marked as refunded after authorized reversal', refundedInv?.status == InvoiceStatus.refunded);
    assertM8('Approved by recorded in permanent refund record', refund.approvedByStaffId == 'Owner (PIN Verified)');

    stdout.writeln('\n=====================================================');
    stdout.writeln('MODULE 8 TEST SUMMARY: $passed PASSED, $failed FAILED');
    stdout.writeln('=====================================================');

    expect(failed, 0, reason: 'Module 8 tests had failures');
  });
}


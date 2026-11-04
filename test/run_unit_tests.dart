import 'dart:convert';
import 'dart:io';

import 'package:apna_clinic/core/errors/failures.dart';
import 'package:apna_clinic/core/utils/money.dart';
import 'package:apna_clinic/core/utils/phone_normalizer.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/infrastructure/security/local_encryption_service.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';
import 'package:apna_clinic/infrastructure/google/mock_google_integration.dart';

void main() async {
  stdout.writeln('========================================');
  stdout.writeln('RUNNING APNA CLINIC CORE UNIT TEST SUITE');
  stdout.writeln('========================================\n');

  int passed = 0;
  int failed = 0;

  void assertTest(String description, bool condition, [String? errorDetail]) {
    if (condition) {
      stdout.writeln('  [PASS] $description');
      passed++;
    } else {
      stderr.writeln(
        '  [FAIL] $description ${errorDetail != null ? "--> $errorDetail" : ""}',
      );
      failed++;
    }
  }

  stdout.writeln('1. MONEY REPRESENTATION TESTS (Minor Units - Paise)');
  // Zero money
  assertTest(
    'Zero money represents 0 paise',
    Money.zero.minorUnits == 0 && Money.zero.isZero,
  );
  assertTest('Zero money formats as ₹0.00', Money.zero.formatted == '₹0.00');

  // Exact conversions without floating point inaccuracies
  final m1 = Money.fromRupees(1.0);
  assertTest('₹1.00 converts to exactly 100 paise', m1.minorUnits == 100);

  final m99_99 = Money.fromRupees(99.99);
  assertTest(
    '₹99.99 converts to exactly 9999 paise',
    m99_99.minorUnits == 9999,
  );

  final m100 = Money.fromRupees(100.0);
  assertTest(
    '₹100.00 converts to exactly 10000 paise',
    m100.minorUnits == 10000,
  );

  final m250_50 = Money.fromRupees(250.50);
  assertTest(
    '₹250.50 converts to exactly 25050 paise',
    m250_50.minorUnits == 25050,
  );

  // Arithmetic
  final a = Money.fromPaise(50000); // ₹500
  final b = Money.fromPaise(25050); // ₹250.50
  assertTest(
    'Addition ₹500 + ₹250.50 = 75050 paise',
    (a + b).minorUnits == 75050,
  );
  assertTest(
    'Subtraction ₹500 - ₹250.50 = 24950 paise',
    (a - b).minorUnits == 24950,
  );
  assertTest(
    'Negation -₹500 = -50000 paise',
    (-a).minorUnits == -50000 && (-a).isNegative,
  );

  // Discounts & Tax
  final bill = Money.fromRupees(500.0);
  final discount = bill.calculateDiscount(10.0);
  assertTest(
    '10% discount on ₹500 is 5000 paise (₹50)',
    discount.minorUnits == 5000,
  );
  assertTest(
    'Net after discount is 45000 paise (₹450)',
    (bill - discount).minorUnits == 45000,
  );

  final gstBill = Money.fromRupees(1000.0);
  final tax = gstBill.calculateTax(18.0);
  assertTest('18% GST on ₹1000 is 18000 paise (₹180)', tax.minorUnits == 18000);
  assertTest(
    'Gross after tax is 118000 paise (₹1180)',
    (gstBill + tax).minorUnits == 118000,
  );

  // Indian Lakhs / Crores formatting
  assertTest('Format ₹500.00', Money.fromRupees(500.0).formatted == '₹500.00');
  assertTest(
    'Format ₹1,234.50',
    Money.fromRupees(1234.50).formatted == '₹1,234.50',
  );
  assertTest(
    'Format ₹1,23,456.78',
    Money.fromRupees(123456.78).formatted == '₹1,23,456.78',
  );
  assertTest(
    'Format ₹1,23,45,678.90',
    Money.fromRupees(12345678.90).formatted == '₹1,23,45,678.90',
  );

  stdout.writeln(
    '\n2. PHONE NORMALIZER TESTS (Indian E.164, Masking, Hashing)',
  );
  assertTest(
    'Normalizes 10-digit Indian phone',
    PhoneNormalizer.normalize('9876543210') == '9876543210',
  );
  assertTest(
    'Normalizes +91 prefixed phone',
    PhoneNormalizer.normalize('+91 98765-43210') == '9876543210',
  );
  assertTest(
    'Normalizes 0 prefixed phone',
    PhoneNormalizer.normalize('09876543210') == '9876543210',
  );
  assertTest(
    'Handles null or invalid input',
    PhoneNormalizer.normalize(null) == null &&
        PhoneNormalizer.normalize('') == null,
  );
  assertTest(
    'Masks phone for shared display (******3210)',
    PhoneNormalizer.mask('9876543210') == '******3210',
  );
  assertTest(
    'Masks invalid/short phone as ******',
    PhoneNormalizer.mask(null) == '******',
  );

  final h1 = PhoneNormalizer.hash('9876543210');
  final h2 = PhoneNormalizer.hash('+91 98765 43210');
  assertTest(
    'Deterministic SHA-256 hash across variations',
    h1 != null && h1 == h2,
  );

  stdout.writeln(
    '\n3. AUTHORIZATION & ROLE PERMISSION TESTS (Deny-By-Default)',
  );
  // Owner
  assertTest(
    'Owner has manageClinicConfig',
    AuthorizationService.hasPermission(
      role: UserRole.owner,
      permission: AppPermission.manageClinicConfig,
    ),
  );
  assertTest(
    'Owner has bulkExportPatients',
    AuthorizationService.hasPermission(
      role: UserRole.owner,
      permission: AppPermission.bulkExportPatients,
    ),
  );
  assertTest(
    'Owner has restoreBackup',
    AuthorizationService.hasPermission(
      role: UserRole.owner,
      permission: AppPermission.restoreBackup,
    ),
  );
  assertTest(
    'Owner has rotateKeys',
    AuthorizationService.hasPermission(
      role: UserRole.owner,
      permission: AppPermission.rotateKeys,
    ),
  );

  // Receptionist (Permitted)
  assertTest(
    'Receptionist has registerPatient',
    AuthorizationService.hasPermission(
      role: UserRole.receptionist,
      permission: AppPermission.registerPatient,
    ),
  );
  assertTest(
    'Receptionist has createVisit',
    AuthorizationService.hasPermission(
      role: UserRole.receptionist,
      permission: AppPermission.createVisit,
    ),
  );
  assertTest(
    'Receptionist has printConsultationSlip',
    AuthorizationService.hasPermission(
      role: UserRole.receptionist,
      permission: AppPermission.printConsultationSlip,
    ),
  );
  assertTest(
    'Receptionist has collectPayment',
    AuthorizationService.hasPermission(
      role: UserRole.receptionist,
      permission: AppPermission.collectPayment,
    ),
  );

  // Receptionist (DENIED)
  assertTest(
    'Receptionist DENIED bulkExportPatients',
    !AuthorizationService.hasPermission(
      role: UserRole.receptionist,
      permission: AppPermission.bulkExportPatients,
    ),
  );
  assertTest(
    'Receptionist DENIED manageSubscriptions',
    !AuthorizationService.hasPermission(
      role: UserRole.receptionist,
      permission: AppPermission.manageSubscriptions,
    ),
  );
  assertTest(
    'Receptionist DENIED restoreBackup',
    !AuthorizationService.hasPermission(
      role: UserRole.receptionist,
      permission: AppPermission.restoreBackup,
    ),
  );
  assertTest(
    'Receptionist DENIED rotateKeys',
    !AuthorizationService.hasPermission(
      role: UserRole.receptionist,
      permission: AppPermission.rotateKeys,
    ),
  );

  // Doctor (Permitted & DENIED)
  assertTest(
    'Doctor has viewDoctorQueue',
    AuthorizationService.hasPermission(
      role: UserRole.doctor,
      permission: AppPermission.viewDoctorQueue,
    ),
  );
  assertTest(
    'Doctor has viewReasonForVisit',
    AuthorizationService.hasPermission(
      role: UserRole.doctor,
      permission: AppPermission.viewReasonForVisit,
    ),
  );
  assertTest(
    'Doctor DENIED bulkExportPatients',
    !AuthorizationService.hasPermission(
      role: UserRole.doctor,
      permission: AppPermission.bulkExportPatients,
    ),
  );
  assertTest(
    'Doctor DENIED restoreBackup',
    !AuthorizationService.hasPermission(
      role: UserRole.doctor,
      permission: AppPermission.restoreBackup,
    ),
  );

  // Accountant (Permitted & DENIED)
  assertTest(
    'Accountant has viewFinancialLedger',
    AuthorizationService.hasPermission(
      role: UserRole.accountant,
      permission: AppPermission.viewFinancialLedger,
    ),
  );
  assertTest(
    'Accountant has approveRefund',
    AuthorizationService.hasPermission(
      role: UserRole.accountant,
      permission: AppPermission.approveRefund,
    ),
  );
  assertTest(
    'Accountant DENIED viewReasonForVisit (Health Privacy Isolation)',
    !AuthorizationService.hasPermission(
      role: UserRole.accountant,
      permission: AppPermission.viewReasonForVisit,
    ),
  );
  assertTest(
    'Accountant DENIED bulkExportPatients',
    !AuthorizationService.hasPermission(
      role: UserRole.accountant,
      permission: AppPermission.bulkExportPatients,
    ),
  );

  // Clinic Scope
  assertTest(
    'Valid clinic scope matches',
    AuthorizationService.isClinicScopeValid(
      sessionClinicId: 'clinic_1',
      targetClinicId: 'clinic_1',
    ),
  );
  assertTest(
    'Cross-clinic scope is rejected',
    !AuthorizationService.isClinicScopeValid(
      sessionClinicId: 'clinic_1',
      targetClinicId: 'clinic_2',
    ),
  );

  stdout.writeln('\n4. QUEUE STATE MACHINE TESTS');
  assertTest(
    'Progression registered -> waiting',
    QueueStatus.registered.canTransitionTo(QueueStatus.waiting),
  );
  assertTest(
    'Progression waiting -> called',
    QueueStatus.waiting.canTransitionTo(QueueStatus.called),
  );
  assertTest(
    'Progression called -> inConsultation',
    QueueStatus.called.canTransitionTo(QueueStatus.inConsultation),
  );
  assertTest(
    'Progression inConsultation -> completed',
    QueueStatus.inConsultation.canTransitionTo(QueueStatus.completed),
  );

  assertTest(
    'Terminal states (completed, cancelled, noShow) are terminal',
    QueueStatus.completed.isTerminal &&
        QueueStatus.cancelled.isTerminal &&
        QueueStatus.noShow.isTerminal,
  );
  assertTest(
    'Terminal cannot transition to called',
    !QueueStatus.completed.canTransitionTo(QueueStatus.called),
  );
  assertTest(
    'Invalid skip registered -> inConsultation is blocked',
    !QueueStatus.registered.canTransitionTo(QueueStatus.inConsultation),
  );
  assertTest(
    'Invalid skip waiting -> completed is blocked',
    !QueueStatus.waiting.canTransitionTo(QueueStatus.completed),
  );

  stdout.writeln(
    '\n5. LOCAL ENCRYPTION SERVICE TESTS (AES-256-CBC, IV, SHA-256 Checksum)',
  );
  final testKey = LocalEncryptionService.generate256BitKey();
  final testIv = LocalEncryptionService.generateSecureIv();
  const testPlaintext =
      'Confidential patient clinical note: Patient reported mild seasonal cough.';

  final envelope = LocalEncryptionService.encryptText(
    plaintext: testPlaintext,
    key: testKey,
    iv: testIv,
  );

  assertTest(
    'Ciphertext is non-empty Base64',
    envelope.ciphertextBase64.isNotEmpty,
  );
  assertTest('IV is non-empty Base64', envelope.ivBase64.isNotEmpty);
  assertTest(
    'Checksum is 64-char hex SHA-256',
    envelope.checksumSha256.length == 64,
  );

  final decrypted = LocalEncryptionService.decryptEnvelope(
    envelope: envelope,
    key: testKey,
  );
  assertTest(
    'Decrypted text matches original plaintext exactly',
    decrypted == testPlaintext,
  );

  // Wrong Key failure
  final wrongKey = LocalEncryptionService.generate256BitKey();
  bool wrongKeyFailed = false;
  try {
    final result = LocalEncryptionService.decryptEnvelope(envelope: envelope, key: wrongKey);
    if (result != testPlaintext) wrongKeyFailed = true;
  } catch (_) {
    wrongKeyFailed = true;
  }
  assertTest('Decryption with wrong key throws CryptoFailure or produces invalid plaintext', wrongKeyFailed);

  // Tampered Checksum failure
  final tamperedEnvelope = EncryptedEnvelope(
    ciphertextBase64: envelope.ciphertextBase64,
    ivBase64: envelope.ivBase64,
    checksumSha256:
        '0000000000000000000000000000000000000000000000000000000000000000',
  );
  bool tamperedFailed = false;
  try {
    LocalEncryptionService.decryptEnvelope(
      envelope: tamperedEnvelope,
      key: testKey,
    );
  } catch (_) {
    tamperedFailed = true;
  }
  assertTest(
    'Decryption of tampered envelope is detected and rejected',
    tamperedFailed,
  );

  // PBKDF2 Key derivation
  final salt = LocalEncryptionService.generateSalt();
  final derivedKey1 = LocalEncryptionService.deriveKeyFromPassphrase(
    'OwnerPassphrase123!',
    salt,
  );
  final derivedKey2 = LocalEncryptionService.deriveKeyFromPassphrase(
    'OwnerPassphrase123!',
    salt,
  );
  assertTest(
    'PBKDF2 key derivation is deterministic',
    derivedKey1.base64 == derivedKey2.base64,
  );

  stdout.writeln('\n6. LOCAL DATABASE & ACID TRANSACTION TESTS');
  await runDatabaseAndRepositoryTests(assertTest);

  stdout.writeln('\n----------------------------------------');
  stdout.writeln('TEST SUMMARY: $passed PASSED, $failed FAILED');
  stdout.writeln('----------------------------------------');

  if (failed > 0) {
    exit(1);
  }
}

Future<void> runDatabaseAndRepositoryTests(
  void Function(String, bool, [String?]) assertTest,
) async {
  final db = LocalDatabase();
  await db.initialize();

  // Test 6.1: Upsert and Query
  await db.upsert('Patients', 'p1', {
    'patient_id': 'p1',
    'clinic_id': 'clinic_test',
    'patient_number': 'P-2026-0001',
    'full_name': 'Ramesh Kumar',
    'phone_optional': '9876543210',
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  final pRecord = db.get('Patients', 'p1');
  assertTest(
    'Record upsert and retrieval',
    pRecord != null && pRecord['full_name'] == 'Ramesh Kumar',
  );

  // Test 6.2: Inverted search index <300ms
  final searchByPhone = db.searchPatients(
    clinicId: 'clinic_test',
    query: '9876543210',
  );
  assertTest(
    'Indexed search by phone finds patient',
    searchByPhone.isNotEmpty && searchByPhone.first['patient_id'] == 'p1',
  );

  final searchByName = db.searchPatients(
    clinicId: 'clinic_test',
    query: 'ramesh',
  );
  assertTest(
    'Indexed search by partial name finds patient',
    searchByName.isNotEmpty && searchByName.first['patient_id'] == 'p1',
  );

  final searchByPNum = db.searchPatients(
    clinicId: 'clinic_test',
    query: 'p-2026-0001',
  );
  assertTest(
    'Indexed search by patient number finds patient',
    searchByPNum.isNotEmpty && searchByPNum.first['patient_id'] == 'p1',
  );

  // Test 6.3: ACID Rollback on Exception
  bool rollbackSucceeded = false;
  try {
    await db.transaction((tx) async {
      await db.upsert('Patients', 'p2', {
        'patient_id': 'p2',
        'clinic_id': 'clinic_test',
        'patient_number': 'P-2026-0002',
        'full_name': 'Suresh Patel',
        'phone_optional': '9123456789',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, tx: tx);

      // Trigger intentional failure mid-transaction
      throw Exception('Simulated crash during visit processing');
    });
  } catch (_) {
    rollbackSucceeded = true;
  }

  assertTest('Transaction failure triggers rollback', rollbackSucceeded);
  final uncommittedP2 = db.get('Patients', 'p2');
  assertTest(
    'Uncommitted record p2 is rolled back completely',
    uncommittedP2 == null,
  );

  // Test 7: REPOSITORY WORKFLOW INTEGRATION (ATOMIC VISIT CREATION)
  final visitRepo = VisitRepository(db);
  final visit = Visit(
    visitId: 'v1',
    clinicId: 'clinic_test',
    patientId: 'p1',
    doctorId: 'doc1',
    visitDateLocal: '2026-09-22',
    checkinAt: DateTime.now().toUtc(),
    tokenNumber: 0,
    tokenScopeKey: '',
    createdByStaffId: 'staff1',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  final createdVisit = await visitRepo.createVisitAtomic(
    visit: visit,
    idempotencyKey: 'idemp_v1',
    deviceId: 'dev_primary',
    staffId: 'staff1',
  );

  assertTest(
    'Atomic visit creation assigns monotonic token #1',
    createdVisit.tokenNumber == 1,
  );
  assertTest(
    'Token scope key is formatted clinic:doctor:date',
    createdVisit.tokenScopeKey == 'clinic_test:doc1:2026-09-22',
  );

  // Second visit for same doctor on same date gets token #2
  final visit2 = Visit(
    visitId: 'v2',
    clinicId: 'clinic_test',
    patientId: 'p1',
    doctorId: 'doc1',
    visitDateLocal: '2026-09-22',
    checkinAt: DateTime.now().toUtc(),
    tokenNumber: 0,
    tokenScopeKey: '',
    createdByStaffId: 'staff1',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  final createdVisit2 = await visitRepo.createVisitAtomic(
    visit: visit2,
    idempotencyKey: 'idemp_v2',
    deviceId: 'dev_primary',
    staffId: 'staff1',
  );
  assertTest(
    'Consecutive visit atomically receives monotonic token #2',
    createdVisit2.tokenNumber == 2,
  );

  // Duplicate click on visit 1 returns identical visit without incrementing counter
  final duplicateVisit1 = await visitRepo.createVisitAtomic(
    visit: visit,
    idempotencyKey: 'idemp_v1',
    deviceId: 'dev_primary',
    staffId: 'staff1',
  );
  assertTest(
    'Idempotent retry returns existing visit with token #1',
    duplicateVisit1.tokenNumber == 1 && duplicateVisit1.visitId == 'v1',
  );

  // Verify Outbox recorded both visits
  final syncRepo = SyncRepository(db);
  final outboxEvents = await syncRepo.getPendingOutboxEvents('clinic_test');
  assertTest(
    'SyncOutbox contains pending events for visits',
    outboxEvents.any((e) => e.entityId == 'v1') &&
        outboxEvents.any((e) => e.entityId == 'v2'),
  );

  // Test Billing Repository with integer paise math
  final billingRepo = BillingRepository(db);
  final invoice = Invoice(
    invoiceId: 'inv1',
    clinicId: 'clinic_test',
    invoiceNumber: 'INV-2026-0001',
    financialYear: '2026-2027',
    patientId: 'p1',
    visitId: 'v1',
    issueDateLocal: '2026-09-22',
    subtotalMinor: 50000, // ₹500
    discountMinor: 5000, // ₹50 (10%)
    taxMinor: 0,
    totalMinor: 45000, // ₹450
    paidMinor: 0,
    balanceMinor: 45000,
    createdByStaffId: 'staff1',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  final invoiceItem = InvoiceItem(
    invoiceItemId: 'item1',
    clinicId: 'clinic_test',
    invoiceId: 'inv1',
    description: 'General Consultation',
    quantity: 1,
    unitPriceMinor: 50000,
    discountMinor: 5000,
    lineTotalMinor: 45000,
    createdAt: DateTime.now().toUtc(),
  );

  final createdInvoice = await billingRepo.createInvoiceAtomic(
    invoice: invoice,
    items: [invoiceItem],
    idempotencyKey: 'idemp_inv1',
  );

  assertTest(
    'Invoice created with correct total minor (45000 paise)',
    createdInvoice.totalMinor == 45000,
  );
  assertTest(
    'Invoice balance equals total before payment',
    createdInvoice.balanceMinor == 45000,
  );

  // Partial Payment
  final partialPayment = Payment(
    paymentId: 'pay1',
    clinicId: 'clinic_test',
    invoiceId: 'inv1',
    amountMinor: 25000, // ₹250
    method: PaymentMethod.cash,
    receivedAt: DateTime.parse('2026-09-22T10:00:00Z'),
    receivedByStaffId: 'staff1',
    createdAt: DateTime.now().toUtc(),
  );

  await billingRepo.recordPayment(
    payment: partialPayment,
    idempotencyKey: 'idemp_pay1',
  );
  final updatedInv = await billingRepo.getInvoiceById('clinic_test', 'inv1');
  assertTest(
    'Partial payment of ₹250 updates paidMinor to 25000 paise',
    updatedInv?.paidMinor == 25000,
  );
  assertTest(
    'Remaining balance is 20000 paise (₹200)',
    updatedInv?.balanceMinor == 20000,
  );
  assertTest(
    'Invoice status is partiallyPaid',
    updatedInv?.status == InvoiceStatus.partiallyPaid,
  );

  // Final Settlement
  final finalPayment = Payment(
    paymentId: 'pay2',
    clinicId: 'clinic_test',
    invoiceId: 'inv1',
    amountMinor: 20000, // ₹200
    method: PaymentMethod.upi,
    receivedAt: DateTime.parse('2026-09-22T11:00:00Z'),
    receivedByStaffId: 'staff1',
    createdAt: DateTime.now().toUtc(),
  );
  await billingRepo.recordPayment(
    payment: finalPayment,
    idempotencyKey: 'idemp_pay2',
  );
  final settledInv = await billingRepo.getInvoiceById('clinic_test', 'inv1');
  assertTest(
    'Full settlement updates status to paid',
    settledInv?.status == InvoiceStatus.paid,
  );
  assertTest('Balance is 0 paise', settledInv?.balanceMinor == 0);

  // Daily Financial Reconciliation
  final recon = await billingRepo.getDailyFinancialReconciliation(
    'clinic_test',
    '2026-09-22',
  );
  assertTest(
    'Reconciliation invoiced = ₹450 (45000 paise)',
    recon.totalInvoicedMinor == 45000,
  );
  assertTest(
    'Reconciliation cash collected = ₹250 (25000 paise)',
    recon.totalCashCollectedMinor == 25000,
  );
  assertTest(
    'Reconciliation UPI collected = ₹200 (20000 paise)',
    recon.totalUpiCollectedMinor == 20000,
  );
  assertTest(
    'Reconciliation outstanding = ₹0',
    recon.totalOutstandingMinor == 0,
  );
  assertTest('Net cash in hand = ₹250', recon.netCashInHandMinor == 25000);

  stdout.writeln('\n7. APPOINTMENTS & SLOT CONFLICT TESTS');
  final appRepo = AppointmentRepository(db);
  final appDate = DateTime(2026, 9, 22, 10, 0); // 10:00 AM

  final app1 = Appointment(
    appointmentId: 'app_001',
    clinicId: 'clinic_test',
    patientId: 'pat_001',
    doctorId: 'doc_sharma',
    scheduledStartAt: appDate,
    scheduledEndAt: appDate.add(const Duration(minutes: 15)), // 10:00 - 10:15
    status: AppointmentStatus.scheduled,
    createdByStaffId: 'staff1',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  await appRepo.saveAppointment(app1);
  final fetchedApp = await appRepo.getAppointmentById('clinic_test', 'app_001');
  assertTest(
    'Appointment saved and retrieved successfully',
    fetchedApp != null && fetchedApp.appointmentId == 'app_001',
  );

  // Conflict tests
  final conflict1 = await appRepo.hasSlotConflict(
    clinicId: 'clinic_test',
    doctorId: 'doc_sharma',
    start: DateTime(2026, 9, 22, 10, 5), // overlaps 10:05 - 10:20
    end: DateTime(2026, 9, 22, 10, 20),
  );
  assertTest(
    'Overlapping time slot (10:05-10:20) detects conflict',
    conflict1 == true,
  );

  final noConflict = await appRepo.hasSlotConflict(
    clinicId: 'clinic_test',
    doctorId: 'doc_sharma',
    start: DateTime(2026, 9, 22, 10, 30), // disjoint 10:30 - 10:45
    end: DateTime(2026, 9, 22, 10, 45),
  );
  assertTest(
    'Disjoint time slot (10:30-10:45) has no conflict',
    noConflict == false,
  );

  // Different doctor has no conflict
  final diffDoc = await appRepo.hasSlotConflict(
    clinicId: 'clinic_test',
    doctorId: 'doc_verma',
    start: DateTime(2026, 9, 22, 10, 0),
    end: DateTime(2026, 9, 22, 10, 15),
  );
  assertTest('Different doctor on same slot has no conflict', diffDoc == false);

  // Cancellation releases slot
  await appRepo.updateAppointmentStatus(
    'clinic_test',
    'app_001',
    AppointmentStatus.cancelled,
    cancelReason: 'Patient called to cancel',
  );
  final cancelledApp = await appRepo.getAppointmentById(
    'clinic_test',
    'app_001',
  );
  assertTest(
    'Appointment status updated to cancelled with reason',
    cancelledApp?.status == AppointmentStatus.cancelled &&
        cancelledApp?.cancelReason == 'Patient called to cancel',
  );

  final slotAfterCancel = await appRepo.hasSlotConflict(
    clinicId: 'clinic_test',
    doctorId: 'doc_sharma',
    start: DateTime(2026, 9, 22, 10, 0),
    end: DateTime(2026, 9, 22, 10, 15),
  );
  assertTest(
    'Cancelled appointment no longer conflicts with slot',
    slotAfterCancel == false,
  );

  // Reschedule test (M03)
  final reschedDate = DateTime(2026, 9, 22, 11, 0);
  await appRepo.rescheduleAppointment(
    clinicId: 'clinic_test',
    appointmentId: 'app_001',
    newStart: reschedDate,
    newEnd: reschedDate.add(const Duration(minutes: 15)),
  );
  final reschedApp = await appRepo.getAppointmentById('clinic_test', 'app_001');
  assertTest(
    'Reschedule appointment updates time and sets rescheduledFromId',
    reschedApp?.scheduledStartAt == reschedDate &&
        reschedApp?.rescheduledFromId == 'app_001' &&
        reschedApp?.status == AppointmentStatus.scheduled,
  );

  // Mark No-Show test (M03)
  await appRepo.updateAppointmentStatus(
    'clinic_test',
    'app_001',
    AppointmentStatus.noShow,
  );
  final noShowApp = await appRepo.getAppointmentById('clinic_test', 'app_001');
  assertTest(
    'Marking appointment as no-show sets status correctly',
    noShowApp?.status == AppointmentStatus.noShow,
  );

  final slotAfterNoShow = await appRepo.hasSlotConflict(
    clinicId: 'clinic_test',
    doctorId: 'doc_sharma',
    start: reschedDate,
    end: reschedDate.add(const Duration(minutes: 15)),
  );
  assertTest(
    'No-show appointment releases slot for other patients',
    slotAfterNoShow == false,
  );

  // Available slots calculation test (M03)
  final availableSlots = await appRepo.getAvailableSlots(
    clinicId: 'clinic_test',
    doctorId: 'doc_sharma',
    date: DateTime(2026, 9, 22),
    durationMinutes: 15,
    startHour: 10,
    endHour: 11,
  );
  assertTest(
    'Available slots calculation generates valid non-overlapping slots',
    availableSlots.isNotEmpty && availableSlots.length == 4,
  );

  stdout.writeln(
    '\n8. DISASTER RECOVERY & ENCRYPTED BACKUP/RESTORE TESTS (PRD Sec 42-45)',
  );
  final backupDb = LocalDatabase(MemoryStorageAdapter());
  await backupDb.initialize();
  // Seed sample data in backupDb
  await backupDb.upsert('Clinic_Config', 'c1', {
    'clinic_id': 'c1',
    'display_name': 'Original Clinic',
  });
  await backupDb.upsert('Patients', 'p1', {
    'patient_id': 'p1',
    'clinic_id': 'c1',
    'full_name': 'Test Patient',
  });

  // 1. Export snapshot
  final rawDbSnapshot = backupDb.exportFullSnapshot('c1');
  final snapshotJson = jsonEncode(rawDbSnapshot);

  // 2. Derive key from passphrase & encrypt
  const masterPass = 'SuperSecretClinicPassword2026!';
  const salt = 'ApnaClinicSalt2026';
  final key = LocalEncryptionService.deriveKeyFromPassphrase(masterPass, salt);
  final envelope = LocalEncryptionService.encryptText(
    plaintext: snapshotJson,
    key: key,
  );

  assertTest(
    'Full database snapshot encrypted with AES-256-CBC',
    envelope.ciphertextBase64.isNotEmpty,
  );
  assertTest(
    'SHA-256 integrity checksum generated (64 hex characters)',
    envelope.checksumSha256.length == 64,
  );

  // 3. Tampered payload checksum failure test (Disaster recovery safeguard)
  final tamperedEnvelope = EncryptedEnvelope(
    ciphertextBase64: '${envelope.ciphertextBase64}A',
    ivBase64: envelope.ivBase64,
    checksumSha256: envelope.checksumSha256,
  );
  bool tamperedThrew = false;
  try {
    LocalEncryptionService.decryptEnvelope(
      envelope: tamperedEnvelope,
      key: key,
    );
  } catch (_) {
    tamperedThrew = true;
  }
  assertTest(
    'Tampered backup fails SHA-256 checksum check safely',
    tamperedThrew == true,
  );

  // 4. Wrong passphrase decryption failure test
  final wrongKey = LocalEncryptionService.deriveKeyFromPassphrase(
    'WrongPassword!',
    salt,
  );
  bool wrongKeyThrew = false;
  try {
    LocalEncryptionService.decryptEnvelope(envelope: envelope, key: wrongKey);
  } catch (_) {
    wrongKeyThrew = true;
  }
  assertTest(
    'Wrong decryption key fails safely and throws error',
    wrongKeyThrew == true,
  );

  // 5. Successful decryption & atomic restore
  final decryptedJson = LocalEncryptionService.decryptEnvelope(
    envelope: envelope,
    key: key,
  );
  final Map<String, dynamic> parsedDecrypted =
      jsonDecode(decryptedJson) as Map<String, dynamic>;

  final restoredDb = LocalDatabase(MemoryStorageAdapter());
  await restoredDb.initialize();
  await restoredDb.restoreFullSnapshot('c1', parsedDecrypted);

  final restoredClinic = restoredDb.get('Clinic_Config', 'c1');
  final restoredPatient = restoredDb.get('Patients', 'p1');
  assertTest(
    'Database restored atomically with matching clinic record',
    restoredClinic?['display_name'] == 'Original Clinic',
  );
  assertTest(
    'Database restored atomically with matching patient record',
    restoredPatient?['full_name'] == 'Test Patient',
  );

  // 9. CLINIC BRANDING, LOGO PERSISTENCE & DRIVE FOLDER TESTS (PRD Module 1)
  stdout.writeln('\n9. CLINIC BRANDING, LOGO PERSISTENCE & DRIVE FOLDER TESTS');

  // Valid 1x1 transparent PNG base64 for unit testing
  const sampleLogoBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  final brandedClinic = Clinic(
    clinicId: 'c_brand_1',
    legalName: 'Apex Health Ltd',
    displayName: 'Apex Super Clinic',
    ownerName: 'Dr. Apex',
    contactPhone: '9876543210',
    contactEmail: 'apex@health.in',
    addressLine1: '123 Health Ave',
    city: 'Mumbai',
    district: 'Mumbai',
    state: 'Maharashtra',
    pincode: '400001',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
    logoBase64: sampleLogoBase64,
    logoDriveFileId: 'drive_file_apex_logo_123',
  );

  final clinicMap = brandedClinic.toMap();
  assertTest(
    'Clinic toMap correctly serializes logoBase64 and logoDriveFileId',
    clinicMap['logo_base64'] == sampleLogoBase64 &&
        clinicMap['logo_drive_file_id'] == 'drive_file_apex_logo_123',
  );

  final reconstitutedClinic = Clinic.fromMap(clinicMap);
  assertTest(
    'Clinic fromMap correctly deserializes logoBase64 and logoDriveFileId',
    reconstitutedClinic.logoBase64 == sampleLogoBase64 &&
        reconstitutedClinic.logoDriveFileId == 'drive_file_apex_logo_123',
  );

  final updatedClinic = brandedClinic.copyWith(logoDriveFileId: 'drive_file_new_999');
  assertTest(
    'Clinic copyWith updates logoDriveFileId and preserves logoBase64',
    updatedClinic.logoDriveFileId == 'drive_file_new_999' &&
        updatedClinic.logoBase64 == sampleLogoBase64,
  );

  // Google Drive client Branding folder & file upload tests
  final mockDrive = MockGoogleDriveClient();
  final brandingFolderId = await mockDrive.initializeClinicBrandingFolder(
    accessToken: 'mock_token',
    clinicId: 'c_brand_1',
  );
  assertTest(
    'Drive client initializes Apna Clinic/c_brand_1/Branding folder',
    brandingFolderId.isNotEmpty,
  );

  final logoBytes = base64Decode(sampleLogoBase64);
  final uploadedDriveFileId = await mockDrive.uploadBinaryFile(
    accessToken: 'mock_token',
    parentFolderId: brandingFolderId,
    fileName: 'clinic_logo_test.png',
    mimeType: 'image/png',
    bytes: logoBytes,
  );
  assertTest(
    'Drive client uploads binary logo to Branding folder and returns file ID',
    uploadedDriveFileId.isNotEmpty,
  );

  // 10. PATIENT REGISTRATION, EDIT WITH AUDIT TRAIL & CONTROLLED DELETION (PRD Module 2)
  stdout.writeln('\n10. PATIENT REGISTRATION, EDIT WITH CHANGE HISTORY & SOFT-DELETE (PRD Module 2)');

  final pDb = LocalDatabase();
  await pDb.initialize();
  final pRepo = PatientRepository(pDb);
  const testClinicId = 'clinic_mod2_test';

  // 10.1 DPDPA Shared Display Phone Masking
  final p1 = Patient(
    patientId: 'pat_001',
    clinicId: testClinicId,
    patientNumber: 'P-1001',
    fullName: 'Rajesh Kumar',
    phoneOptional: '9876543210',
    ageIfDobUnknown: 42,
    sexOptional: 'Male',
    cityOptional: 'Jaipur',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  assertTest(
    'DPDPA: 10-digit phone number is masked as ******3210 on shared displays',
    p1.maskedPhone == '******3210',
  );

  final pNoPhone = Patient(
    patientId: 'pat_no_phone',
    clinicId: testClinicId,
    patientNumber: 'P-1000',
    fullName: 'Anita Devi',
    phoneOptional: null,
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  assertTest(
    'DPDPA: Unspecified phone returns "******"',
    pNoPhone.maskedPhone == '******',
  );

  // 10.2 Patient Registration & Search
  await pRepo.savePatient(p1);
  final searchByNamePatients = await pRepo.searchPatients(testClinicId, 'Rajesh');
  assertTest(
    'Fast lookup by patient name returns registered patient',
    searchByNamePatients.length == 1 && searchByNamePatients.first.patientId == 'pat_001',
  );

  final searchByPhonePatients = await pRepo.searchPatients(testClinicId, '9876543210');
  assertTest(
    'Fast lookup by phone number returns registered patient',
    searchByPhonePatients.length == 1 && searchByPhonePatients.first.fullName == 'Rajesh Kumar',
  );

  // 10.3 Exact Duplicate Detection on Registration
  final duplicatePatient = Patient(
    patientId: 'pat_dup',
    clinicId: testClinicId,
    patientNumber: 'P-1002',
    fullName: 'rajesh kumar', // case-insensitive test
    phoneOptional: '+91 98765 43210', // unformatted phone test
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  bool dupCaught = false;
  try {
    await pRepo.savePatient(duplicatePatient);
  } on StateError {
    dupCaught = true;
  }
  assertTest(
    'Registration blocks exact duplicate (case-insensitive name + normalized phone)',
    dupCaught,
  );

  // 10.4 Patient Edit with Change History (Audit Log)
  final p2 = Patient(
    patientId: 'pat_002',
    clinicId: testClinicId,
    patientNumber: 'P-1003',
    fullName: 'Sunita Sharma',
    phoneOptional: '9123456789',
    ageIfDobUnknown: 35,
    sexOptional: 'Female',
    cityOptional: 'Ajmer',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  await pRepo.savePatient(p2);

  final updatedP1 = p1.copyWith(
    cityOptional: 'Udaipur',
    guardianNameOptional: 'Ramesh Kumar',
    guardianRelationOptional: 'Brother',
    updatedAt: DateTime.now().toUtc(),
  );

  await pRepo.updatePatient(
    updatedP1,
    actorId: 'staff_dr_sharma',
    actorRole: 'doctor',
    changedFields: ['city_optional', 'guardian_name_optional', 'guardian_relation_optional'],
  );

  final fetchedP1 = await pRepo.getPatientById(testClinicId, 'pat_001');
  assertTest(
    'Patient demographic update persists correctly to database',
    fetchedP1?.cityOptional == 'Udaipur' &&
        fetchedP1?.guardianNameOptional == 'Ramesh Kumar' &&
        fetchedP1?.guardianRelationOptional == 'Brother',
  );

  // Check audit trail for edit
  final p1History = await pRepo.getPatientAuditHistory(testClinicId, 'pat_001');
  final editAudit = p1History.where((e) => e.action == 'patient.edit').firstOrNull;
  assertTest(
    'Patient edit creates immutable Audit_Events record with actor and modified field names',
    editAudit != null &&
        editAudit.actorId == 'staff_dr_sharma' &&
        editAudit.actorRole == 'doctor' &&
        editAudit.fieldNamesJson.contains('city_optional') &&
        editAudit.fieldNamesJson.contains('guardian_name_optional'),
  );

  // 10.5 Duplicate Collision Prevention on Update
  bool editDupCaught = false;
  try {
    // Try updating p2 to match p1's name and phone
    final collidingP2 = p2.copyWith(
      fullName: 'Rajesh Kumar',
      phoneOptional: '9876543210',
    );
    await pRepo.updatePatient(
      collidingP2,
      actorId: 'receptionist_1',
      actorRole: 'receptionist',
      changedFields: ['full_name', 'phone_optional'],
    );
  } on StateError {
    editDupCaught = true;
  }
  assertTest(
    'Patient edit prevents collisions with other existing patients in clinic',
    editDupCaught,
  );

  // 10.6 Controlled Soft-Deletion (Owner/Admin)
  await pRepo.deletePatient(
    testClinicId,
    'pat_002',
    actorId: 'clinic_owner_1',
    actorRole: 'owner',
    reason: 'Duplicate patient record entered by mistake',
  );

  final deletedCheck = await pRepo.getPatientById(testClinicId, 'pat_002');
  final searchExcludesDeleted = await pRepo.searchPatients(testClinicId, 'Sunita');
  assertTest(
    'Soft-deleted patient is excluded from standard lookup and search',
    deletedCheck == null && searchExcludesDeleted.isEmpty,
  );

  final p2History = await pRepo.getPatientAuditHistory(testClinicId, 'pat_002');
  final deleteAudit = p2History.where((e) => e.action == 'patient.delete').firstOrNull;
  assertTest(
    'Soft-deletion records permanent Audit_Events entry with actor role, reason, and timestamp',
    deleteAudit != null &&
        deleteAudit.actorId == 'clinic_owner_1' &&
        deleteAudit.actorRole == 'owner' &&
        deleteAudit.reasonOptional == 'Duplicate patient record entered by mistake',
  );

  // 10.7 Outbox Synchronization Staging for Edits & Deletions
  final outboxRecords = pDb.query('sync_outbox', where: (row) => row['clinic_id'] == testClinicId);
  final hasUpdateOutbox = outboxRecords.any((r) => r['operation'] == 'update' && r['entity_id'] == 'pat_001');
  final hasDeleteOutbox = outboxRecords.any((r) => r['operation'] == 'delete' && r['entity_id'] == 'pat_002');
  assertTest(
    'sync_outbox stages patient update and delete events for cloud sync',
    hasUpdateOutbox && hasDeleteOutbox,
  );

  stdout.writeln('\n11. TOKEN AND QUEUE TESTS (PRD Module 4)');
  // 11.1 Default priority & enum level hierarchy
  final defaultVisit = Visit(
    visitId: 'v_prio_001',
    clinicId: testClinicId,
    patientId: 'pat_001',
    doctorId: 'doc_sharma',
    visitDateLocal: '2026-09-22',
    tokenNumber: 1,
    tokenScopeKey: '$testClinicId:doc_sharma:2026-09-22',
    createdByStaffId: 'staff_1',
    queueStatus: QueueStatus.waiting,
    visitType: 'consultation',
    checkinAt: DateTime.now().toUtc(),
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  assertTest(
    'Default Visit priority is QueuePriority.normal',
    defaultVisit.priority == QueuePriority.normal,
  );
  assertTest(
    'QueuePriority level ordering satisfies emergency > urgent > vip > normal',
    QueuePriority.emergency.level > QueuePriority.urgent.level &&
        QueuePriority.urgent.level > QueuePriority.vip.level &&
        QueuePriority.vip.level > QueuePriority.normal.level,
  );

  // 11.2 Serialization / Deserialization mapping with wire values
  final serializedMap = defaultVisit.toMap();
  assertTest(
    'Visit.toMap() maps priority to canonical Master Sheet wireValue ("NORMAL")',
    serializedMap['priority'] == 'NORMAL',
  );

  final urgentVisit = defaultVisit.copyWith(priority: QueuePriority.urgent);
  final deserializedUrgent = Visit.fromMap(urgentVisit.toMap());
  assertTest(
    'Visit.fromMap() deserializes wireValue "URGENT" to QueuePriority.urgent',
    deserializedUrgent.priority == QueuePriority.urgent,
  );

  final emergencyVisit = defaultVisit.copyWith(priority: QueuePriority.emergency);
  final deserializedEmergency = Visit.fromMap(emergencyVisit.toMap());
  assertTest(
    'Visit.fromMap() deserializes wireValue "EMERGENCY" to QueuePriority.emergency',
    deserializedEmergency.priority == QueuePriority.emergency,
  );

  // 11.3 Priority Override via VisitRepository with Queue_Events & SyncOutbox staging
  final qVisitRepo = VisitRepository(pDb);
  await pDb.upsert('Visits', defaultVisit.visitId, defaultVisit.toMap());

  final overriddenVisit = await qVisitRepo.updateVisitPriority(
    clinicId: testClinicId,
    visitId: defaultVisit.visitId,
    newPriority: QueuePriority.emergency,
    staffId: 'staff_receptionist_1',
    deviceId: 'desk_reception_tab_1',
  );
  assertTest(
    'updateVisitPriority returns visit with new priority (emergency)',
    overriddenVisit.priority == QueuePriority.emergency,
  );

  final fetchedDbVisit = await qVisitRepo.getVisitById(testClinicId, defaultVisit.visitId);
  assertTest(
    'Database record reflects updated priority',
    fetchedDbVisit != null && fetchedDbVisit.priority == QueuePriority.emergency,
  );

  final prioOutboxEvents = pDb.query(
    'sync_outbox',
    where: (row) =>
        row['clinic_id'] == testClinicId &&
        (row['outbox_event_id'] as String).startsWith('outbox_prio_'),
  );
  assertTest(
    'updateVisitPriority enqueues sync_outbox event with idempotencyKey',
    prioOutboxEvents.isNotEmpty &&
        prioOutboxEvents.first['idempotency_key'] != null &&
        prioOutboxEvents.first['idempotency_key'].toString().isNotEmpty,
  );

  // 11.4 Triage sorting logic
  final vNormal1 = Visit(
    visitId: 'v_norm_1',
    clinicId: testClinicId,
    patientId: 'pat_001',
    doctorId: 'doc_sharma',
    visitDateLocal: '2026-09-22',
    tokenNumber: 1,
    tokenScopeKey: '$testClinicId:doc_sharma:2026-09-22',
    createdByStaffId: 'staff_1',
    priority: QueuePriority.normal,
    queueStatus: QueueStatus.waiting,
    visitType: 'consultation',
    checkinAt: DateTime.now().toUtc(),
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  final vNormal2 = Visit(
    visitId: 'v_norm_2',
    clinicId: testClinicId,
    patientId: 'pat_001',
    doctorId: 'doc_sharma',
    visitDateLocal: '2026-09-22',
    tokenNumber: 2,
    tokenScopeKey: '$testClinicId:doc_sharma:2026-09-22',
    createdByStaffId: 'staff_1',
    priority: QueuePriority.normal,
    queueStatus: QueueStatus.waiting,
    checkinAt: DateTime.now().toUtc(),
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  final vUrgent3 = Visit(
    visitId: 'v_urg_3',
    clinicId: testClinicId,
    patientId: 'pat_001',
    doctorId: 'doc_sharma',
    visitDateLocal: '2026-09-22',
    tokenNumber: 3,
    tokenScopeKey: '$testClinicId:doc_sharma:2026-09-22',
    createdByStaffId: 'staff_1',
    priority: QueuePriority.urgent,
    queueStatus: QueueStatus.waiting,
    checkinAt: DateTime.now().toUtc(),
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  final vEmerg4 = Visit(
    visitId: 'v_emg_4',
    clinicId: testClinicId,
    patientId: 'pat_001',
    doctorId: 'doc_sharma',
    visitDateLocal: '2026-09-22',
    tokenNumber: 4,
    tokenScopeKey: '$testClinicId:doc_sharma:2026-09-22',
    createdByStaffId: 'staff_1',
    priority: QueuePriority.emergency,
    queueStatus: QueueStatus.waiting,
    checkinAt: DateTime.now().toUtc(),
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  final triageList = [vNormal1, vNormal2, vUrgent3, vEmerg4]
    ..sort((a, b) {
      final pDiff = b.priority.level.compareTo(a.priority.level);
      if (pDiff != 0) return pDiff;
      return a.tokenNumber.compareTo(b.tokenNumber);
    });

  assertTest(
    'Triage sorting orders emergency (#4) -> urgent (#3) -> normal (#1) -> normal (#2)',
    triageList[0].tokenNumber == 4 &&
        triageList[1].tokenNumber == 3 &&
        triageList[2].tokenNumber == 1 &&
        triageList[3].tokenNumber == 2,
  );

  // 12. CONSULTATION SLIP, PRINT TRACKING & REPRINT AUDIT TRAIL (PRD Module 5)
  stdout.writeln('\n12. CONSULTATION SLIP, PRINT TRACKING & REPRINT AUDIT TRAIL (PRD Module 5)');

  // 12.1 Initial print of consultation slip
  final visitBeforePrint = Visit(
    visitId: 'v_slip_test_1',
    clinicId: testClinicId,
    patientId: 'pat_001',
    doctorId: 'doc_sharma',
    visitDateLocal: '2026-09-22',
    tokenNumber: 10,
    tokenScopeKey: '$testClinicId:doc_sharma:2026-09-22',
    createdByStaffId: 'staff_1',
    priority: QueuePriority.normal,
    queueStatus: QueueStatus.waiting,
    slipPrintCount: 0,
    checkinAt: DateTime.now().toUtc(),
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  await pDb.upsert('Visits', visitBeforePrint.visitId, visitBeforePrint.toMap());

  await qVisitRepo.incrementSlipPrintCount(
    clinicId: testClinicId,
    visitId: visitBeforePrint.visitId,
    paperSize: 'A5',
    staffId: 'staff_reception_1',
    deviceId: 'desk_tab_1',
  );
  final printedVisit1 = await qVisitRepo.getVisitById(testClinicId, visitBeforePrint.visitId);

  assertTest(
    'Initial slip print increments slipPrintCount to 1',
    printedVisit1 != null && printedVisit1.slipPrintCount == 1,
  );
  assertTest(
    'Initial slip print sets lastSlipPrintedAt timestamp',
    printedVisit1 != null && printedVisit1.lastSlipPrintedAt != null,
  );

  // Check pending_print_jobs
  final printJobs = pDb.query(
    'pending_print_jobs',
    where: (row) => row['visit_id'] == visitBeforePrint.visitId,
  );
  assertTest(
    'incrementSlipPrintCount logs job in pending_print_jobs table',
    printJobs.isNotEmpty && printJobs.first['paper_size'] == 'A5',
  );

  // Check Audit_Events for consultation_slip.print
  final auditPrintEvents = pDb.query(
    'Audit_Events',
    where: (row) =>
        row['clinic_id'] == testClinicId &&
        row['action'] == 'consultation_slip.print',
  );
  assertTest(
    'First print logs immutable Audit_Events entry with action consultation_slip.print',
    auditPrintEvents.isNotEmpty &&
        auditPrintEvents.first['actor_id'] == 'staff_reception_1',
  );

  // 12.2 Duplicate / Reprint protection: second print
  await qVisitRepo.incrementSlipPrintCount(
    clinicId: testClinicId,
    visitId: visitBeforePrint.visitId,
    paperSize: 'A5',
    staffId: 'staff_reception_1',
    deviceId: 'desk_tab_1',
  );
  final printedVisit2 = await qVisitRepo.getVisitById(testClinicId, visitBeforePrint.visitId);

  assertTest(
    'Second print increments slipPrintCount to 2',
    printedVisit2 != null && printedVisit2.slipPrintCount == 2,
  );

  final auditReprintEvents = pDb.query(
    'Audit_Events',
    where: (row) =>
        row['clinic_id'] == testClinicId &&
        row['action'] == 'consultation_slip.reprint',
  );
  assertTest(
    'Reprint logs immutable Audit_Events entry with action consultation_slip.reprint',
    auditReprintEvents.isNotEmpty &&
        auditReprintEvents.last['reason_optional'] != null &&
        auditReprintEvents.last['reason_optional'].toString().contains('Copy #2'),
  );

  // Check sync_outbox staging for Master Sheet 06_VISITS update
  final slipSyncEvents = pDb.query(
    'sync_outbox',
    where: (row) =>
        row['clinic_id'] == testClinicId &&
        (row['outbox_event_id'] as String).startsWith('outbox_print_'),
  );
  assertTest(
    'incrementSlipPrintCount stages sync_outbox event for Google Master Sheet sync',
    slipSyncEvents.isNotEmpty &&
        slipSyncEvents.last['payload_json'].toString().contains('"slip_print_count":2'),
  );

  stdout.writeln('\n13. BILLING, PAYMENTS, MIXED TENDER, REFUNDS & DAY CLOSE (PRD Module 6)');
  final m6Db = LocalDatabase();
  await m6Db.initialize();
  final m6BillingRepo = BillingRepository(m6Db);
  const m6ClinicId = 'clinic_m06_unit';
  const m6DoctorId = 'doc_m06_spec';
  const m6PatientId = 'pat_m06_unit';
  final m6Today = DateTime.now().toIso8601String().split('T').first;
  final m6Now = DateTime.now().toUtc();
  const m6FY = '2026-2027';

  // 1. Fee Catalog by Doctor/Visit Type
  final m6GeneralFee = FeeCatalog(
    feeId: 'fee_gen_1',
    clinicId: m6ClinicId,
    visitTypeOptional: 'walkin',
    feeCode: 'CONSULT-GEN',
    feeName: 'General OPD Consultation',
    defaultAmountMinor: 30000,
    createdAt: m6Now,
    updatedAt: m6Now,
  );
  await m6BillingRepo.saveFeeCatalogItem(m6GeneralFee);

  final m6DoctorFee = FeeCatalog(
    feeId: 'fee_doc_1',
    clinicId: m6ClinicId,
    doctorIdOptional: m6DoctorId,
    visitTypeOptional: 'appointment',
    feeCode: 'CONSULT-SPEC',
    feeName: 'Specialist Consultation',
    defaultAmountMinor: 75000,
    createdAt: m6Now,
    updatedAt: m6Now,
  );
  await m6BillingRepo.saveFeeCatalogItem(m6DoctorFee);

  final m6Catalog = await m6BillingRepo.getFeeCatalog(m6ClinicId);
  assertTest('Fee catalog stores general and doctor-scoped entries', m6Catalog.length == 2);
  assertTest(
    'Doctor-scoped fee accurately resolved to doctor ID',
    m6Catalog.any((f) => f.doctorIdOptional == m6DoctorId && f.defaultAmountMinor == 75000),
  );

  // 2. Sequential Invoice Numbering
  final m6InvNum1 = await m6BillingRepo.generateNextInvoiceNumber(m6ClinicId, m6FY);
  assertTest('Sequential invoice numbering starts at INV-2026-2027-0001', m6InvNum1 == 'INV-2026-2027-0001');

  // 3. Discount with reason and approval threshold
  const m6Subtotal = 75000; // ₹750
  const m6Discount = 15000; // ₹150 (20%)
  const m6Total = m6Subtotal - m6Discount; // ₹600

  final m6Invoice1 = Invoice(
    invoiceId: 'inv_m06_unit_1',
    clinicId: m6ClinicId,
    invoiceNumber: m6InvNum1,
    financialYear: m6FY,
    patientId: m6PatientId,
    issueDateLocal: m6Today,
    subtotalMinor: m6Subtotal,
    discountMinor: m6Discount,
    discountReasonOptional: 'Senior Citizen Discount',
    discountApprovedByOptional: 'Dr. Lead Practitioner',
    totalMinor: m6Total,
    paidMinor: 0,
    balanceMinor: m6Total,
    status: InvoiceStatus.issued,
    createdByStaffId: 'staff_unit_1',
    createdAt: m6Now,
    updatedAt: m6Now,
  );

  final m6CreatedInv1 = await m6BillingRepo.createInvoiceAtomic(
    invoice: m6Invoice1,
    items: [
      InvoiceItem(
        invoiceItemId: 'item_m06_u1',
        clinicId: m6ClinicId,
        invoiceId: 'inv_m06_unit_1',
        description: 'Specialist Consultation',
        unitPriceMinor: m6Subtotal,
        discountMinor: m6Discount,
        lineTotalMinor: m6Total,
        createdAt: m6Now,
      ),
    ],
    idempotencyKey: 'inv_m06_u1_idemp',
  );

  assertTest(
    'Invoice created with discount reason and approver',
    m6CreatedInv1.discountMinor == 15000 &&
        m6CreatedInv1.discountReasonOptional == 'Senior Citizen Discount' &&
        m6CreatedInv1.discountApprovedByOptional == 'Dr. Lead Practitioner',
  );

  // 4. Mixed tender payment (Cash + UPI)
  final m6SplitCash = Payment(
    paymentId: 'pay_m06_c1',
    clinicId: m6ClinicId,
    invoiceId: m6CreatedInv1.invoiceId,
    amountMinor: 40000, // ₹400 Cash
    method: PaymentMethod.cash,
    receivedAt: m6Now,
    receivedByStaffId: 'staff_unit_1',
    status: PaymentStatus.completed,
    createdAt: m6Now,
  );
  final m6SplitUpi = Payment(
    paymentId: 'pay_m06_u1',
    clinicId: m6ClinicId,
    invoiceId: m6CreatedInv1.invoiceId,
    amountMinor: 20000, // ₹200 UPI
    method: PaymentMethod.upi,
    cashUpiCardReferenceOptional: 'UPI987654',
    receivedAt: m6Now,
    receivedByStaffId: 'staff_unit_1',
    status: PaymentStatus.completed,
    createdAt: m6Now,
  );

  await m6BillingRepo.recordPayments(
    payments: [m6SplitCash, m6SplitUpi],
    idempotencyKey: 'mixed_pay_unit_1',
  );

  final m6UpdatedInv1 = await m6BillingRepo.getInvoiceById(m6ClinicId, m6CreatedInv1.invoiceId);
  assertTest('Invoice paid in full with mixed tender', m6UpdatedInv1?.status == InvoiceStatus.paid && m6UpdatedInv1?.balanceMinor == 0);

  // 5. Refund
  final m6Refund = Refund(
    refundId: 'ref_m06_u1',
    clinicId: m6ClinicId,
    invoiceId: m6CreatedInv1.invoiceId,
    amountMinor: 10000, // ₹100
    reason: 'Billing adjustment',
    requestedByStaffId: 'staff_unit_1',
    approvedByStaffId: 'Dr. Lead Practitioner',
    status: RefundStatus.settled,
    refundedAt: m6Now,
    refundMethod: PaymentMethod.cash,
    createdAt: m6Now,
  );
  await m6BillingRepo.recordRefund(refund: m6Refund, idempotencyKey: 'ref_m06_u1_idemp');

  final m6InvAfterRefund = await m6BillingRepo.getInvoiceById(m6ClinicId, m6CreatedInv1.invoiceId);
  assertTest('Invoice paid amount decremented by refund (60000 -> 50000)', m6InvAfterRefund?.paidMinor == 50000);

  // 6. Immutability
  bool m6PaidVoidFailed = false;
  try {
    await m6BillingRepo.voidInvoice(
      clinicId: m6ClinicId,
      invoiceId: m6CreatedInv1.invoiceId,
      reason: 'Should fail',
      staffId: 'staff_unit_1',
    );
  } catch (e) {
    if (e is ValidationFailure) m6PaidVoidFailed = true;
  }
  assertTest('Attempt to void paid invoice is blocked as ValidationFailure', m6PaidVoidFailed);

  // 7. Day close reconciliation & persistence
  final m6Recon = await m6BillingRepo.getDailyFinancialReconciliation(m6ClinicId, m6Today);
  assertTest('Reconciliation cash collected is 40000 paise', m6Recon.totalCashCollectedMinor == 40000);
  assertTest('Reconciliation upi collected is 20000 paise', m6Recon.totalUpiCollectedMinor == 20000);
  assertTest('Reconciliation refunded is 10000 paise', m6Recon.totalRefundedMinor == 10000);
  assertTest('Reconciliation net cash in hand is 30000 paise', m6Recon.netCashInHandMinor == 30000);

  final m6DayClose = DayClose(
    closeId: 'dc_${m6ClinicId}_$m6Today',
    clinicId: m6ClinicId,
    businessDate: m6Today,
    openedBy: 'Staff',
    closedBy: 'Staff',
    closedAt: m6Now,
    openingCashPaise: 0,
    expectedCashPaise: m6Recon.netCashInHandMinor,
    countedCashPaise: m6Recon.netCashInHandMinor,
    variancePaise: 0,
    upiTotalPaise: m6Recon.totalUpiCollectedMinor,
    cardTotalPaise: m6Recon.totalCardCollectedMinor,
    refundTotalPaise: m6Recon.totalRefundedMinor,
  );
  await m6BillingRepo.performDayClose(m6DayClose);
  final m6FetchedDayClose = await m6BillingRepo.getDayClose(m6ClinicId, m6Today);
  assertTest('DayClose entity stored and retrieved from Day_Close table', m6FetchedDayClose != null && m6FetchedDayClose.variancePaise == 0);

  // ---------------------------------------------------------------------------
  // 14. DASHBOARD & REPORTS (PRD Module 7)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n14. DASHBOARD & REPORTS (PRD Module 7)');

  // 1. DailySummary Canonical Model & Mathematical Precision
  final m7Summary = DailySummary(
    summaryId: 'sum_m7_test',
    clinicId: 'clinic_m7',
    localDate: '2026-10-29',
    registeredCount: 10,
    walkinCount: 7,
    appointmentCount: 3,
    completedCount: 8,
    noShowCount: 1,
    cancelledCount: 1,
    invoicedMinor: 500000,
    paidCashMinor: 300000,
    paidUpiMinor: 150000,
    paidCardMinor: 50000,
    refundedMinor: 20000,
    outstandingMinor: 20000,
    expensesMinor: 50000,
    generatedAt: DateTime.now().toUtc(),
  );

  assertTest('DailySummary totalVisits equals registered count', m7Summary.totalVisits == 10);
  assertTest('DailySummary completedVisits matches completed count', m7Summary.completedVisits == 8);
  assertTest('DailySummary completion rate is 80%', m7Summary.completionRate == 80.0);
  assertTest('DailySummary total collected equals Cash + UPI + Card (500000 paise)', m7Summary.totalCollectedMinor == 500000);
  assertTest('DailySummary net collections equals Total - Refunds (480000 paise)', m7Summary.netCollectionsMinor == 480000);
  assertTest('DailySummary net cash in hand equals Cash - Refunds - Expenses (230000 paise)', m7Summary.netCashInHandMinor == 230000);

  final m7Map = m7Summary.toMap();
  assertTest('DailySummary toMap preserves canonical TRD columns', m7Map['registered_count'] == 10 && m7Map['invoiced_minor'] == 500000);
  final m7ReconSummary = DailySummary.fromMap(m7Map);
  assertTest('DailySummary fromMap reconstitutes identical integer values', m7ReconSummary.summaryId == m7Summary.summaryId && m7ReconSummary.netCashInHandMinor == 230000);

  // 2. ReportsRepository Ledger Integration & Doctor Breakdown
  final m7Db = LocalDatabase();
  await m7Db.initialize();
  final m7VisitRepo = VisitRepository(m7Db);
  final m7BillingRepo = BillingRepository(m7Db);
  final m7ClinicRepo = ClinicRepository(m7Db);
  final m7PatientRepo = PatientRepository(m7Db);
  final m7SyncRepo = SyncRepository(m7Db);
  final m7ReportsRepo = ReportsRepository(
    db: m7Db,
    visitRepo: m7VisitRepo,
    billingRepo: m7BillingRepo,
    clinicRepo: m7ClinicRepo,
    patientRepo: m7PatientRepo,
    syncRepo: m7SyncRepo,
  );

  const m7ClinicId = 'clinic_m7_integration';
  final m7Date = m6Today;
  const m7Doc1 = 'doc_cardio_m7';
  const m7Doc2 = 'doc_neuro_m7';

  await m7ClinicRepo.saveDoctor(Doctor(
    doctorId: m7Doc1,
    clinicId: m7ClinicId,
    displayName: 'Dr. Cardio',
    defaultFee: 50000,
    createdAt: m6Now,
    updatedAt: m6Now,
  ));
  await m7ClinicRepo.saveDoctor(Doctor(
    doctorId: m7Doc2,
    clinicId: m7ClinicId,
    displayName: 'Dr. Neuro',
    defaultFee: 60000,
    createdAt: m6Now,
    updatedAt: m6Now,
  ));

  await m7Db.upsert('Visits', 'vis_m7_1', Visit(
    visitId: 'vis_m7_1',
    clinicId: m7ClinicId,
    patientId: 'pat_m7_1',
    doctorId: m7Doc1,
    visitDateLocal: m7Date,
    checkinAt: m6Now,
    tokenNumber: 1,
    tokenScopeKey: '$m7ClinicId:$m7Doc1:$m7Date',
    visitType: 'walkin',
    queueStatus: QueueStatus.completed,
    createdByStaffId: 'staff_1',
    createdAt: m6Now,
    updatedAt: m6Now,
  ).toMap());

  await m7Db.upsert('Visits', 'vis_m7_2', Visit(
    visitId: 'vis_m7_2',
    clinicId: m7ClinicId,
    patientId: 'pat_m7_2',
    doctorId: m7Doc2,
    visitDateLocal: m7Date,
    checkinAt: m6Now,
    tokenNumber: 1,
    tokenScopeKey: '$m7ClinicId:$m7Doc2:$m7Date',
    visitType: 'appointment',
    appointmentIdOptional: 'apt_m7_1',
    queueStatus: QueueStatus.completed,
    createdByStaffId: 'staff_1',
    createdAt: m6Now,
    updatedAt: m6Now,
  ).toMap());

  final m7Inv1 = Invoice(
    invoiceId: 'inv_m7_1',
    clinicId: m7ClinicId,
    invoiceNumber: 'INV-2026-2027-0010',
    financialYear: '2026-2027',
    patientId: 'pat_m7_1',
    visitId: 'vis_m7_1',
    issueDateLocal: m7Date,
    subtotalMinor: 50000,
    totalMinor: 50000,
    paidMinor: 50000,
    balanceMinor: 0,
    status: InvoiceStatus.paid,
    createdByStaffId: 'staff_1',
    createdAt: m6Now,
    updatedAt: m6Now,
  );
  await m7BillingRepo.createInvoiceAtomic(
    invoice: m7Inv1,
    items: [],
    initialPayment: Payment(
      paymentId: 'pay_m7_1',
      clinicId: m7ClinicId,
      invoiceId: 'inv_m7_1',
      amountMinor: 50000,
      method: PaymentMethod.cash,
      receivedAt: m6Now,
      receivedByStaffId: 'staff_1',
      createdAt: m6Now,
    ),
    idempotencyKey: 'idemp_m7_1',
  );

  final m7Doc1Summary = await m7ReportsRepo.getDailySummary(m7ClinicId, m7Date, doctorId: m7Doc1);
  assertTest('ReportsRepository filters doctor-specific metrics', m7Doc1Summary.registeredCount == 1 && m7Doc1Summary.paidCashMinor == 50000);

  final m7AllDocSummaries = await m7ReportsRepo.getDoctorSummaries(m7ClinicId, m7Date);
  assertTest('ReportsRepository generates doctor-wise summary list', m7AllDocSummaries.length == 2);

  // 3. Offline / Sync Status Labeling
  final m7ExistingEvents = await m7SyncRepo.getPendingOutboxEvents(m7ClinicId);
  if (m7ExistingEvents.isNotEmpty) {
    await m7SyncRepo.acknowledgeEvents(m7ExistingEvents.map((e) => e.outboxEventId).toList(), 'batch_ack');
  }
  final m7SyncedState = await m7ReportsRepo.getSyncStatus(m7ClinicId);
  assertTest('Sync status labels clean ledger as synced', m7SyncedState.isSynced == true);

  await m7Db.upsert('sync_outbox', 'ev_un_synced', SyncOutboxEvent(
    outboxEventId: 'ev_un_synced',
    clinicId: m7ClinicId,
    entityType: 'Invoice',
    entityId: 'inv_m7_1',
    operation: OutboxOperation.insert,
    payloadJson: '{}',
    idempotencyKey: 'idemp_ev',
    createdAt: m6Now,
  ).toMap());
  final m7UnsyncedState = await m7ReportsRepo.getSyncStatus(m7ClinicId);
  assertTest('Sync status explicitly labels offline un-synced totals', m7UnsyncedState.isSynced == false && m7UnsyncedState.pendingOutboxCount == 1);

  // 4. Role Authorization for Reports
  assertTest('Owner has permission to view daily reports', AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.viewDailyReports));
  assertTest('Receptionist has permission to view daily reports', AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.viewDailyReports));
  assertTest('Doctor is denied general daily reports permission', !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.viewDailyReports));
  assertTest('Accountant is denied access to reason for visit', !AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.viewReasonForVisit));

  // =========================================================================
  // 15. STAFF AND ACCESS CONTROL TESTS - PRD Module 8
  // =========================================================================
  stdout.writeln('\n15. STAFF AND ACCESS CONTROL TESTS (PRD Module 8)');
  final m8Db = LocalDatabase(MemoryStorageAdapter());
  await m8Db.initialize();
  final m8ClinicRepo = ClinicRepository(m8Db);
  final m8BillingRepo = BillingRepository(m8Db);
  final m8VisitRepo = VisitRepository(m8Db);
  const m8ClinicId = 'clinic_m8_unit';

  // 15.1 RBAC Matrix and Deny-by-default
  assertTest('Owner has exportReports permission', AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.exportReports));
  assertTest('Accountant has exportReports permission', AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.exportReports));
  assertTest('Receptionist is strictly denied exportReports', !AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.exportReports));
  assertTest('Doctor is strictly denied exportReports', !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.exportReports));
  assertTest('Receptionist is strictly denied voidInvoice', !AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.voidInvoice));
  assertTest('Doctor is strictly denied voidInvoice', !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.voidInvoice));
  assertTest('Owner has voidInvoice permission', AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.voidInvoice));
  assertTest('Accountant has voidInvoice permission', AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.voidInvoice));

  // 15.2 Salted SHA-256 PIN Security
  final pinData1 = Staff.generatePinHash('4321');
  final pinData2 = Staff.generatePinHash('4321');
  assertTest('Salted PIN generates 64-char SHA-256 hash', pinData1['pin_hash']!.length == 64);
  assertTest('Salted PIN generates 16-byte cryptographically secure salt', base64Decode(pinData1['pin_salt']!).length == 16);
  assertTest('Unique salt creates distinct hashes for identical PINs', pinData1['pin_hash'] != pinData2['pin_hash']);

  final staffDoctor = Staff(
    staffId: 'staff_doc_m8',
    clinicId: m8ClinicId,
    displayName: 'Dr. Sameer Khan',
    role: UserRole.doctor,
    phone: '9876500001',
    active: true,
    pinHash: pinData1['pin_hash'],
    pinSalt: pinData1['pin_salt'],
    createdAt: m6Now,
    updatedAt: m6Now,
  );
  assertTest('Staff verifyPin returns true for correct PIN', staffDoctor.verifyPin('4321'));
  assertTest('Staff verifyPin returns false for incorrect PIN', !staffDoctor.verifyPin('0000'));
  assertTest('Staff verifyPin returns false for empty PIN', !staffDoctor.verifyPin(''));
  assertTest('Staff hasPin returns true when PIN is set', staffDoctor.hasPin);

  // 15.3 Staff Persistence & Deactivation
  await m8ClinicRepo.saveStaff(staffDoctor);
  final fetchedStaff = await m8ClinicRepo.getStaffMembers(m8ClinicId, activeOnly: true);
  assertTest('Active staff member persisted and retrieved', fetchedStaff.any((s) => s.staffId == 'staff_doc_m8'));

  final deactivatedStaff = staffDoctor.copyWith(active: false);
  await m8ClinicRepo.saveStaff(deactivatedStaff);
  final activeStaffOnly = await m8ClinicRepo.getStaffMembers(m8ClinicId, activeOnly: true);
  assertTest('Deactivated staff excluded from activeOnly lookup', !activeStaffOnly.any((s) => s.staffId == 'staff_doc_m8'));

  // 15.4 Doctor Queue Sensitive Data Isolation
  await m8Db.upsert('Patients', 'pat_m8_1', Patient(
    patientId: 'pat_m8_1',
    clinicId: m8ClinicId,
    patientNumber: 'P-M8-1',
    fullName: 'Ananya Verma',
    consentStatus: 'granted',
    consentVersion: '1.0',
    createdAt: m6Now,
    updatedAt: m6Now,
  ).toMap());

  await m8Db.upsert('Patients', 'pat_m8_2', Patient(
    patientId: 'pat_m8_2',
    clinicId: m8ClinicId,
    patientNumber: 'P-M8-2',
    fullName: 'Vikram Joshi',
    consentStatus: 'granted',
    consentVersion: '1.0',
    createdAt: m6Now,
    updatedAt: m6Now,
  ).toMap());

  await m8VisitRepo.createVisitAtomic(
    visit: Visit(
      visitId: 'vis_docA',
      clinicId: m8ClinicId,
      patientId: 'pat_m8_1',
      doctorId: 'doc_A',
      visitDateLocal: m6Today,
      checkinAt: m6Now,
      tokenNumber: 1,
      tokenScopeKey: '$m8ClinicId:doc_A:$m6Today',
      visitType: 'walkin',
      reasonForVisitEncryptedRef: 'ref_chest_palpitations',
      queueStatus: QueueStatus.waiting,
      createdByStaffId: 'staff_rec',
      createdAt: m6Now,
      updatedAt: m6Now,
    ),
    deviceId: 'dev_m8',
    staffId: 'staff_rec',
    idempotencyKey: 'idemp_v_docA',
  );

  await m8VisitRepo.createVisitAtomic(
    visit: Visit(
      visitId: 'vis_docB',
      clinicId: m8ClinicId,
      patientId: 'pat_m8_2',
      doctorId: 'doc_B',
      visitDateLocal: m6Today,
      checkinAt: m6Now,
      tokenNumber: 1,
      tokenScopeKey: '$m8ClinicId:doc_B:$m6Today',
      visitType: 'walkin',
      reasonForVisitEncryptedRef: 'ref_skin_rash',
      queueStatus: QueueStatus.waiting,
      createdByStaffId: 'staff_rec',
      createdAt: m6Now,
      updatedAt: m6Now,
    ),
    deviceId: 'dev_m8',
    staffId: 'staff_rec',
    idempotencyKey: 'idemp_v_docB',
  );

  final m8AllVisits = await m8VisitRepo.getVisitsForDate(m8ClinicId, m6Today);
  final docAQueue = m8AllVisits.where((v) => v.doctorId == 'doc_A').toList();
  final docBQueue = m8AllVisits.where((v) => v.doctorId == 'doc_B').toList();
  assertTest('Dr. A queue isolated to Dr. A patients', docAQueue.length == 1 && docAQueue.first.patientId == 'pat_m8_1');
  assertTest('Dr. B queue does not leak Dr. A sensitive symptoms', !docBQueue.any((v) => v.reasonForVisitEncryptedRef?.contains('palpitations') ?? false));

  // 15.5 Billing Reversals & Immutability Rules
  final m8UnpaidInv = Invoice(
    invoiceId: 'inv_m8_unpaid_u',
    clinicId: m8ClinicId,
    invoiceNumber: 'INV-2026-2027-0801',
    financialYear: '2026-2027',
    patientId: 'pat_m8_1',
    issueDateLocal: m6Today,
    subtotalMinor: 40000,
    totalMinor: 40000,
    paidMinor: 0,
    balanceMinor: 40000,
    status: InvoiceStatus.issued,
    createdByStaffId: 'staff_rec',
    createdAt: m6Now,
    updatedAt: m6Now,
  );
  await m8BillingRepo.createInvoiceAtomic(
    invoice: m8UnpaidInv,
    items: [
      InvoiceItem(
        invoiceItemId: 'item_m8_u1',
        clinicId: m8ClinicId,
        invoiceId: 'inv_m8_unpaid_u',
        description: 'Specialist Consultation',
        quantity: 1,
        unitPriceMinor: 40000,
        lineTotalMinor: 40000,
        createdAt: m6Now,
      ),
    ],
    idempotencyKey: 'idemp_m8_u1',
  );

  await m8BillingRepo.voidInvoice(
    clinicId: m8ClinicId,
    invoiceId: 'inv_m8_unpaid_u',
    reason: 'Billing entry mistake',
    staffId: 'staff_owner',
  );
  final voidedM8Inv = await m8BillingRepo.getInvoiceById(m8ClinicId, 'inv_m8_unpaid_u');
  assertTest('Unpaid invoice voided with supervisor authorization', voidedM8Inv?.status == InvoiceStatus.voided);

  // Attempting to void paid invoice is blocked
  final m8PaidInv = Invoice(
    invoiceId: 'inv_m8_paid_u',
    clinicId: m8ClinicId,
    invoiceNumber: 'INV-2026-2027-0802',
    financialYear: '2026-2027',
    patientId: 'pat_m8_2',
    issueDateLocal: m6Today,
    subtotalMinor: 50000,
    totalMinor: 50000,
    paidMinor: 50000,
    balanceMinor: 0,
    status: InvoiceStatus.paid,
    createdByStaffId: 'staff_rec',
    createdAt: m6Now,
    updatedAt: m6Now,
  );
  await m8BillingRepo.createInvoiceAtomic(
    invoice: m8PaidInv,
    items: [
      InvoiceItem(
        invoiceItemId: 'item_m8_p1',
        clinicId: m8ClinicId,
        invoiceId: 'inv_m8_paid_u',
        description: 'General Checkup',
        quantity: 1,
        unitPriceMinor: 50000,
        lineTotalMinor: 50000,
        createdAt: m6Now,
      ),
    ],
    initialPayment: Payment(
      paymentId: 'pay_m8_u1',
      clinicId: m8ClinicId,
      invoiceId: 'inv_m8_paid_u',
      amountMinor: 50000,
      method: PaymentMethod.cash,
      receivedAt: m6Now,
      receivedByStaffId: 'staff_rec',
      createdAt: m6Now,
    ),
    idempotencyKey: 'idemp_m8_p1',
  );

  bool paidVoidBlocked = false;
  try {
    await m8BillingRepo.voidInvoice(
      clinicId: m8ClinicId,
      invoiceId: 'inv_m8_paid_u',
      reason: 'Should fail',
      staffId: 'staff_owner',
    );
  } catch (e) {
    if (e is ValidationFailure) {
      paidVoidBlocked = true;
    }
  }
  assertTest('Voiding paid invoice is blocked as per PRD M06 & M08 immutability', paidVoidBlocked);

  // =========================================================================
  // 16. MULTI-DOCTOR & MULTI-DEVICE LIVE COLLABORATION TESTS (PRD Module 13)
  // =========================================================================
  stdout.writeln('\n16. MULTI-DOCTOR & MULTI-DEVICE LIVE COLLABORATION (PRD Module 13)');
  final m13Db = LocalDatabase(MemoryStorageAdapter());
  await m13Db.initialize();

  final collab1 = DeviceCollaborationRepository(m13Db, initialDeviceId: 'term_reception_01');
  final collab2 = DeviceCollaborationRepository(m13Db, initialDeviceId: 'term_doctor_01');
  const m13ClinicId = 'clinic_m13';

  // 16.1 Workstation registration
  final dev1 = await collab1.getLocalDevice(m13ClinicId, defaultName: 'Front Reception Station', defaultRole: DeviceRole.primaryReception);
  assertTest('Terminal 1 registered with deviceId', dev1.deviceId == 'term_reception_01');
  assertTest('Terminal 1 role is primaryReception', dev1.deviceRole == DeviceRole.primaryReception);
  assertTest('Terminal 1 online status is true', dev1.isOnline);

  // 16.2 Single-Writer Lease Acquisition
  final lease1 = await collab1.acquireWriteLease(clinicId: m13ClinicId, staffId: 'staff_rec_01', role: UserRole.receptionist);
  assertTest('Primary lease acquired by term_reception_01', lease1.holderDeviceId == 'term_reception_01');
  assertTest('Lease status is active and not expired', lease1.isActive && !lease1.isExpired);
  assertTest('collab1 is authoritative writer', await collab1.isCurrentDeviceAuthoritativeWriter(m13ClinicId));
  assertTest('collab2 is NOT authoritative writer', !await collab2.isCurrentDeviceAuthoritativeWriter(m13ClinicId));

  // 16.3 Concurrent Write Protection
  bool concurrentBlocked = false;
  try {
    await collab2.acquireWriteLease(clinicId: m13ClinicId, staffId: 'staff_rec_02', role: UserRole.receptionist);
  } catch (e) {
    if (e is DeviceLeaseFailure) concurrentBlocked = true;
  }
  assertTest('Concurrent lease acquisition blocked by active write lease', concurrentBlocked);

  // 16.4 Monotonic Sequence Vector
  final m13Seq1 = await collab1.getNextAuthoritativeSequence(m13ClinicId, 'queue_stream');
  final m13Seq2 = await collab1.getNextAuthoritativeSequence(m13ClinicId, 'queue_stream');
  assertTest('Monotonic sequence increments sequentially (1 -> 2)', m13Seq1 == 1 && m13Seq2 == 2);

  // 16.5 Collaboration Conflict Recording & Resolution
  final m13Conflict = CollaborationConflict(
    conflictId: 'conf_m13_01',
    clinicId: m13ClinicId,
    entityType: 'appointment',
    entityId: 'slot_m13',
    localDeviceId: 'term_reception_01',
    remoteDeviceId: 'term_doctor_01',
    conflictType: 'overlapping_slot',
    detectedAt: DateTime.now().toUtc(),
    localSummary: 'Dr. Sharma 11:00 AM slot booked by Reception',
    remoteSummary: 'Dr. Sharma 11:00 AM slot requested by Doctor Mobile',
  );
  await collab1.recordConflict(m13Conflict);
  final unres = await collab1.getConflicts(m13ClinicId, unresolvedOnly: true);
  assertTest('Conflict recorded and retrieved as unresolved', unres.length == 1 && !unres.first.isResolved);

  await collab1.resolveConflict(
    conflictId: 'conf_m13_01',
    clinicId: m13ClinicId,
    staffId: 'staff_owner_01',
    resolutionStatus: 'resolved_keep_local',
    notes: 'Slot assigned to reception walk-in',
  );
  final res = await collab1.getConflicts(m13ClinicId, unresolvedOnly: false);
  assertTest('Conflict resolved with strategy and audit trail', res.first.isResolved && res.first.resolutionStatus == 'resolved_keep_local');

  // 16.6 RBAC Enforcements
  assertTest('Owner has manageDeviceLease permission', AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.manageDeviceLease));
  assertTest('Receptionist has manageDeviceLease permission', AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.manageDeviceLease));
  assertTest('Doctor is denied manageDeviceLease permission', !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.manageDeviceLease));
  assertTest('Accountant is denied manageDeviceLease permission', !AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.manageDeviceLease));
  assertTest('Owner has resolveConflicts permission', AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.resolveConflicts));
  assertTest('Receptionist has resolveConflicts permission', AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.resolveConflicts));
  assertTest('Doctor is denied resolveConflicts permission', !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.resolveConflicts));
  assertTest('Accountant is denied resolveConflicts permission', !AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.resolveConflicts));

  // =========================================================================
  // 17. MULTI-BRANCH & THIRD-PARTY INTEGRATIONS (PRD Module 14)
  // =========================================================================
  stdout.writeln('\n17. MULTI-BRANCH & THIRD-PARTY INTEGRATIONS (PRD Module 14)');
  final m14Db = LocalDatabase(MemoryStorageAdapter());
  await m14Db.initialize();

  final branchRepo = BranchRepository(m14Db);
  const m14ClinicId = 'clinic_m14';

  // 17.1 Flagship branch auto-provisioning
  final branches14 = await branchRepo.getBranches(m14ClinicId);
  assertTest('Flagship main branch BR-01 auto-provisioned', branches14.length == 1 && branches14.first.isMainBranch);

  // 17.2 Secondary branch registration
  final b2 = Branch(
    branchId: 'br_m14_noida',
    clinicId: m14ClinicId,
    branchCode: 'BR-02',
    branchName: 'Noida Satellite OPD',
    contactPhone: '+919876543210',
    addressLine1: 'Sector 18 Market',
    city: 'Noida',
    state: 'UP',
    pincode: '201301',
    isMainBranch: false,
    isActive: true,
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  await branchRepo.saveBranch(b2);
  final allB = await branchRepo.getBranches(m14ClinicId);
  assertTest('Secondary branch BR-02 registered', allB.length == 2 && allB.any((b) => b.branchCode == 'BR-02'));

  // 17.3 Flagship deactivation invariant
  bool deactFlagshipBlocked = false;
  try {
    await branchRepo.deleteBranch(m14ClinicId, branches14.first.branchId, staffId: 'staff_owner');
  } catch (e) {
    if (e is ValidationFailure) deactFlagshipBlocked = true;
  }
  assertTest('Attempt to deactivate main flagship branch is blocked', deactFlagshipBlocked);

  // 17.4 Consolidated multi-branch reporting
  final m14Now = DateTime.now().toUtc();
  final m14DateStr = '${m14Now.year.toString().padLeft(4, "0")}-${m14Now.month.toString().padLeft(2, "0")}-${m14Now.day.toString().padLeft(2, "0")}';
  await m14Db.upsert('Visits', 'v_m14_b1', {
    'visit_id': 'v_m14_b1',
    'clinic_id': m14ClinicId,
    'branch_id': branches14.first.branchId,
    'visit_date_local': m14DateStr,
  });
  await m14Db.upsert('Visits', 'v_m14_b2', {
    'visit_id': 'v_m14_b2',
    'clinic_id': m14ClinicId,
    'branch_id': 'br_m14_noida',
    'visit_date_local': m14DateStr,
  });
  await m14Db.upsert('Payments', 'p_m14_b2', {
    'payment_id': 'p_m14_b2',
    'clinic_id': m14ClinicId,
    'branch_id': 'br_m14_noida',
    'amount_minor': 75000,
  });
  final consolReport = await branchRepo.getConsolidatedReport(m14ClinicId, date: m14Now);
  assertTest('Consolidated report aggregates 2 branches', consolReport.totalBranches == 2);
  assertTest('Consolidated grand total visits is 2', consolReport.grandTotalVisits == 2);
  assertTest('Consolidated grand total collections is 75000 paise', consolReport.grandTotalCollectionsMinor == 75000);

  // 17.5 Confidentiality CSV export (Zero clinical leakage)
  final consolCsv = await branchRepo.exportConsolidatedReportCsv(consolReport);
  assertTest('Consolidated CSV starts with UTF-8 BOM', consolCsv.startsWith('\uFEFF'));
  assertTest('Consolidated CSV excludes patient clinical notes', !consolCsv.contains('diagnosis') && !consolCsv.contains('prescription'));

  // 17.6 ABDM facility configuration & ABHA profile linking
  final abdmConfig = await branchRepo.getAbdmConfig(m14ClinicId);
  assertTest('ABDM configuration retrieved with facility ID', abdmConfig.facilityId.isNotEmpty);

  final abhaProfile = const AbhaProfile(
    abhaNumber: '91-1234-5678-9012',
    abhaAddress: 'patient.test@abdm',
    patientId: 'pat_m14_01',
    clinicId: m14ClinicId,
    verificationStatus: 'verified',
    dpdpConsentGiven: true,
  );
  assertTest('ABHA profile with DPDP consent evaluates as verified', abhaProfile.isVerified);
  await branchRepo.linkPatientAbha(abhaProfile);
  final retrievedAbha = await branchRepo.getPatientAbha(m14ClinicId, 'pat_m14_01');
  assertTest('Linked ABHA profile successfully retrieved', retrievedAbha != null && retrievedAbha.abhaNumber == '91-1234-5678-9012');

  // 17.7 RBAC matrix
  assertTest('Owner has manageBranches permission', AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.manageBranches));
  assertTest('Owner has manageAbdmIntegration permission', AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.manageAbdmIntegration));
  assertTest('Accountant has viewConsolidatedReports permission', AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.viewConsolidatedReports));
  assertTest('Receptionist is denied manageBranches permission', !AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.manageBranches));
  assertTest('Doctor is denied manageBranches permission', !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.manageBranches));
}

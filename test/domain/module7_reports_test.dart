// Apna Clinic - Module 7 (Dashboard & Reports) Comprehensive Test Suite
// Primary source of truth: PRD Section 5 M07, Section 6.2, TRD Section 4, 7, 9
// Tests: Authoritative ledger reconciliation, DailySummary entity, doctor-wise breakdown,
// day-close drawer audit, offline/sync labeling, DPDPA health privacy isolation, role authorization.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';
import 'package:apna_clinic/application/reports/reports_pdf_service.dart';

void main() {
  test('PRD Module 7 - Dashboard and Reports Comprehensive Suite', () async {
    stdout.writeln('===============================================================');
    stdout.writeln('TESTING PRD MODULE 7: DASHBOARD & REPORTS (STRICT PRD)');
    stdout.writeln('===============================================================\n');

    int passed = 0;
    int failed = 0;

  void assertM07(String testName, bool condition, [String? errorDetail]) {
    if (condition) {
      stdout.writeln('  [PASS] $testName');
      passed++;
    } else {
      stderr.writeln('  [FAIL] $testName ${errorDetail != null ? "--> $errorDetail" : ""}');
      failed++;
    }
  }

  // ---------------------------------------------------------------------------
  // 1. DailySummary Canonical Entity & Integer Math (TRD Sec 7 & PRD M07)
  // ---------------------------------------------------------------------------
  stdout.writeln('1. DAILYSUMMARY CANONICAL SCHEMA & INTEGER PAISE ARITHMETIC');

  final now = DateTime.utc(2026, 10, 29, 18, 0, 0);
  final summary = DailySummary(
    summaryId: 'sum_clinic1_2026-10-29_all',
    clinicId: 'clinic1',
    localDate: '2026-10-29',
    doctorIdOptional: null,
    registeredCount: 15,
    walkinCount: 10,
    appointmentCount: 5,
    completedCount: 12,
    noShowCount: 2,
    cancelledCount: 1,
    invoicedMinor: 750000, // Rs. 7,500.00
    paidCashMinor: 400000, // Rs. 4,000.00
    paidUpiMinor: 250000,  // Rs. 2,500.00
    paidCardMinor: 50000,  // Rs. 500.00
    refundedMinor: 20000,  // Rs. 200.00
    outstandingMinor: 50000, // Rs. 500.00
    expensesMinor: 80000,  // Rs. 800.00
    generatedAt: now,
    sourceEventCheckpoint: 'cp_001',
  );

  final map = summary.toMap();
  assertM07('DailySummary serializes canonical columns', map['summary_id'] == 'sum_clinic1_2026-10-29_all');
  assertM07('DailySummary registeredCount is 15', map['registered_count'] == 15);
  assertM07('DailySummary invoicedMinor is 750000 paise', map['invoiced_minor'] == 750000);

  final reconstructed = DailySummary.fromMap(map);
  assertM07('DailySummary deserializes correctly', reconstructed.summaryId == summary.summaryId);
  assertM07('DailySummary paidCashMinor matches', reconstructed.paidCashMinor == 400000);
  assertM07('DailySummary paidUpiMinor matches', reconstructed.paidUpiMinor == 250000);
  assertM07('DailySummary refundedMinor matches', reconstructed.refundedMinor == 20000);

  // Math validations
  assertM07('Total visits getter returns registered count', summary.totalVisits == 15);
  assertM07('Completed visits getter matches', summary.completedVisits == 12);
  assertM07('Completion rate is 80.0%', summary.completionRate == 80.0);
  assertM07('Total collected equals Cash + UPI + Card (700000 paise)', summary.totalCollectedMinor == 700000);
  assertM07('Net collections equals Total Collected - Refunds (680000 paise)', summary.netCollectionsMinor == 680000);
  assertM07('Net cash in hand equals Cash - Refunds - Expenses (300000 paise)', summary.netCashInHandMinor == 300000);

  // ---------------------------------------------------------------------------
  // 2. Authoritative Ledger Reconciliation (Invoices, Payments, Refunds, Day Close)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n2. AUTHORITATIVE LEDGER RECONCILIATIONS');

  final db = LocalDatabase();
  await db.initialize();
  final visitRepo = VisitRepository(db);
  final billingRepo = BillingRepository(db);
  final clinicRepo = ClinicRepository(db);
  final patientRepo = PatientRepository(db);
  final syncRepo = SyncRepository(db);
  final reportsRepo = ReportsRepository(
    db: db,
    visitRepo: visitRepo,
    billingRepo: billingRepo,
    clinicRepo: clinicRepo,
    patientRepo: patientRepo,
    syncRepo: syncRepo,
  );

  const clinicId = 'clinic_m07_test';
  const date = '2026-10-29';
  const doc1Id = 'doc_sharma';
  const doc2Id = 'doc_verma';

  // Seed Doctors
  await clinicRepo.saveDoctor(Doctor(
    doctorId: doc1Id,
    clinicId: clinicId,
    displayName: 'Dr. Sharma',
    specialtyLabel: 'General Physician',
    defaultFee: 30000,
    createdAt: now,
    updatedAt: now,
  ));
  await clinicRepo.saveDoctor(Doctor(
    doctorId: doc2Id,
    clinicId: clinicId,
    displayName: 'Dr. Verma',
    specialtyLabel: 'Pediatrician',
    defaultFee: 40000,
    createdAt: now,
    updatedAt: now,
  ));

  // Seed Patients
  await patientRepo.savePatient(Patient(
    patientId: 'pat_001',
    clinicId: clinicId,
    patientNumber: 'P-101',
    fullName: 'Ramesh Kumar',
    phoneOptional: '9876543210',
    createdAt: now,
    updatedAt: now,
  ));
  await patientRepo.savePatient(Patient(
    patientId: 'pat_002',
    clinicId: clinicId,
    patientNumber: 'P-102',
    fullName: 'Sita Devi',
    phoneOptional: '9876543211',
    createdAt: now,
    updatedAt: now,
  ));

  // Visit 1: Dr. Sharma, walkin, completed
  final v1 = Visit(
    visitId: 'vis_001',
    clinicId: clinicId,
    patientId: 'pat_001',
    doctorId: doc1Id,
    visitDateLocal: date,
    checkinAt: now,
    tokenNumber: 1,
    tokenScopeKey: '$clinicId:$doc1Id:$date',
    visitType: 'walkin',
    queueStatus: QueueStatus.completed,
    createdByStaffId: 'staff_1',
    createdAt: now,
    updatedAt: now,
  );
  await db.upsert('Visits', v1.visitId, v1.toMap());

  // Invoice 1: Rs. 500 (Consultation 300 + Emergency 200), Paid via Cash
  final inv1 = Invoice(
    invoiceId: 'inv_001',
    clinicId: clinicId,
    invoiceNumber: 'INV-2026-0001',
    financialYear: '2026-2027',
    patientId: 'pat_001',
    visitId: 'vis_001',
    issueDateLocal: date,
    subtotalMinor: 50000,
    totalMinor: 50000,
    paidMinor: 50000,
    balanceMinor: 0,
    status: InvoiceStatus.paid,
    currency: 'INR',
    notesNonclinical: 'Consultation & Emergency',
    createdByStaffId: 'staff_1',
    createdAt: now,
    updatedAt: now,
    items: [
      InvoiceItem(
        invoiceItemId: 'item_1',
        clinicId: clinicId,
        invoiceId: 'inv_001',
        description: 'General Consultation',
        unitPriceMinor: 30000,
        lineTotalMinor: 30000,
        createdAt: now,
      ),
      InvoiceItem(
        invoiceItemId: 'item_2',
        clinicId: clinicId,
        invoiceId: 'inv_001',
        description: 'Emergency Surcharge',
        unitPriceMinor: 20000,
        lineTotalMinor: 20000,
        createdAt: now,
      ),
    ],
  );
  await billingRepo.createInvoiceAtomic(
    invoice: inv1,
    items: inv1.items,
    initialPayment: Payment(
      paymentId: 'pay_001',
      clinicId: clinicId,
      invoiceId: 'inv_001',
      amountMinor: 50000,
      method: PaymentMethod.cash,
      status: PaymentStatus.completed,
      receivedAt: now,
      receivedByStaffId: 'staff_1',
      createdAt: now,
    ),
    idempotencyKey: 'idemp_inv_001',
  );

  // Visit 2: Dr. Verma, appointment, completed
  final v2 = Visit(
    visitId: 'vis_002',
    clinicId: clinicId,
    patientId: 'pat_002',
    doctorId: doc2Id,
    visitDateLocal: date,
    checkinAt: now,
    tokenNumber: 1,
    tokenScopeKey: '$clinicId:$doc2Id:$date',
    visitType: 'appointment',
    appointmentIdOptional: 'apt_001',
    queueStatus: QueueStatus.completed,
    createdByStaffId: 'staff_1',
    createdAt: now,
    updatedAt: now,
  );
  await db.upsert('Visits', v2.visitId, v2.toMap());

  // Invoice 2: Rs. 400, Paid via UPI
  final inv2 = Invoice(
    invoiceId: 'inv_002',
    clinicId: clinicId,
    invoiceNumber: 'INV-2026-0002',
    financialYear: '2026-2027',
    patientId: 'pat_002',
    visitId: 'vis_002',
    issueDateLocal: date,
    subtotalMinor: 40000,
    totalMinor: 40000,
    paidMinor: 40000,
    balanceMinor: 0,
    status: InvoiceStatus.paid,
    currency: 'INR',
    notesNonclinical: 'Pediatric Consultation',
    createdByStaffId: 'staff_1',
    createdAt: now,
    updatedAt: now,
    items: [
      InvoiceItem(
        invoiceItemId: 'item_3',
        clinicId: clinicId,
        invoiceId: 'inv_002',
        description: 'Pediatric Consultation',
        unitPriceMinor: 40000,
        lineTotalMinor: 40000,
        createdAt: now,
      ),
    ],
  );
  await billingRepo.createInvoiceAtomic(
    invoice: inv2,
    items: inv2.items,
    initialPayment: Payment(
      paymentId: 'pay_002',
      clinicId: clinicId,
      invoiceId: 'inv_002',
      amountMinor: 40000,
      method: PaymentMethod.upi,
      status: PaymentStatus.completed,
      receivedAt: now,
      receivedByStaffId: 'staff_1',
      createdAt: now,
    ),
    idempotencyKey: 'idemp_inv_002',
  );

  // Refund: Rs. 100 on Invoice 1
  await billingRepo.recordRefund(
    refund: Refund(
      refundId: 'ref_001',
      clinicId: clinicId,
      invoiceId: 'inv_001',
      paymentIdOptional: 'pay_001',
      amountMinor: 10000,
      reason: 'Overcharge correction',
      requestedByStaffId: 'staff_1',
      approvedByStaffId: 'owner_1',
      status: RefundStatus.settled,
      refundedAt: now,
      refundMethod: PaymentMethod.cash,
      createdAt: now,
    ),
    idempotencyKey: 'idemp_ref_001',
  );

  // Expense: Rs. 150 for office supplies
  await billingRepo.recordExpense(Expense(
    expenseId: 'exp_001',
    clinicId: clinicId,
    expenseDate: date,
    category: 'Supplies',
    description: 'Printer ink and prescription paper',
    amountMinor: 15000,
    paymentMethod: PaymentMethod.cash,
    createdByStaffId: 'staff_1',
    createdAt: now,
    updatedAt: now,
  ));

  // Compute Clinic-wide DailySummary
  final clinicSummary = await reportsRepo.getDailySummary(clinicId, date);
  assertM07('Clinic-wide visits registered = 2', clinicSummary.registeredCount == 2);
  assertM07('Walk-in count = 1', clinicSummary.walkinCount == 1);
  assertM07('Appointment count = 1', clinicSummary.appointmentCount == 1);
  assertM07('Completed visits = 2', clinicSummary.completedCount == 2);
  assertM07('Gross invoiced = Rs. 900 (90000 paise)', clinicSummary.invoicedMinor == 90000);
  assertM07('Cash collected = Rs. 500 (50000 paise)', clinicSummary.paidCashMinor == 50000);
  assertM07('UPI collected = Rs. 400 (40000 paise)', clinicSummary.paidUpiMinor == 40000);
  assertM07('Refunds settled = Rs. 100 (10000 paise)', clinicSummary.refundedMinor == 10000);
  assertM07('Expenses settled = Rs. 150 (15000 paise)', clinicSummary.expensesMinor == 15000);
  assertM07('Net collections = Rs. 800 (80000 paise)', clinicSummary.netCollectionsMinor == 80000);
  assertM07('Net cash in drawer = Rs. 250 (25000 paise)', clinicSummary.netCashInHandMinor == 25000);

  // ---------------------------------------------------------------------------
  // 3. Doctor-Wise Metrics Breakdown
  // ---------------------------------------------------------------------------
  stdout.writeln('\n3. DOCTOR-WISE METRICS BREAKDOWN');

  final doc1Summary = await reportsRepo.getDailySummary(clinicId, date, doctorId: doc1Id);
  assertM07('Dr. Sharma registered visits = 1', doc1Summary.registeredCount == 1);
  assertM07('Dr. Sharma completed visits = 1', doc1Summary.completedCount == 1);
  assertM07('Dr. Sharma invoiced = Rs. 500', doc1Summary.invoicedMinor == 50000);
  assertM07('Dr. Sharma cash collected = Rs. 500', doc1Summary.paidCashMinor == 50000);
  assertM07('Dr. Sharma net collected = Rs. 400 (after Rs. 100 refund)', doc1Summary.netCollectionsMinor == 40000);

  final doc2Summary = await reportsRepo.getDailySummary(clinicId, date, doctorId: doc2Id);
  assertM07('Dr. Verma registered visits = 1', doc2Summary.registeredCount == 1);
  assertM07('Dr. Verma completed visits = 1', doc2Summary.completedCount == 1);
  assertM07('Dr. Verma invoiced = Rs. 400', doc2Summary.invoicedMinor == 40000);
  assertM07('Dr. Verma UPI collected = Rs. 400', doc2Summary.paidUpiMinor == 40000);
  assertM07('Dr. Verma net collected = Rs. 400', doc2Summary.netCollectionsMinor == 40000);

  final allDocSummaries = await reportsRepo.getDoctorSummaries(clinicId, date);
  assertM07('Doctor summaries count equals registered active doctors (2)', allDocSummaries.length == 2);

  // ---------------------------------------------------------------------------
  // 4. Physical Cash Drawer Reconciliation (Day Close Audit)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n4. PHYSICAL CASH DRAWER RECONCILIATION (DAY CLOSE)');

  final dayClose = DayClose(
    closeId: 'close_001',
    clinicId: clinicId,
    businessDate: date,
    openedBy: 'staff_morning',
    closedBy: 'staff_evening',
    closedAt: now,
    openingCashPaise: 100000,  // Rs. 1,000 opening float
    expectedCashPaise: 350000, // Rs. 3,500 expected cash in drawer
    countedCashPaise: 350000,  // Exact physical cash count
    variancePaise: 0,          // Zero variance
    upiTotalPaise: 40000,
    cardTotalPaise: 0,
    refundTotalPaise: 10000,
    notesOptional: 'Evening drawer exact tally verified',
  );
  await billingRepo.performDayClose(dayClose);

  final fetchedDayClose = await reportsRepo.getDayClose(clinicId, date);
  assertM07('DayClose record is retrieved for date', fetchedDayClose != null);
  assertM07('DayClose closedBy matches staff', fetchedDayClose?.closedBy == 'staff_evening');
  assertM07('DayClose counted cash matches expected cash', fetchedDayClose?.countedCashPaise == fetchedDayClose?.expectedCashPaise);
  assertM07('DayClose variance is exactly zero', fetchedDayClose?.variancePaise == 0);

  // ---------------------------------------------------------------------------
  // 5. Offline / Sync Status Reporting
  // ---------------------------------------------------------------------------
  stdout.writeln('\n5. OFFLINE / SYNC STATUS REPORTING');

  // Acknowledge any earlier staged events to test fully synced state
  final existingEvents = await syncRepo.getPendingOutboxEvents(clinicId);
  if (existingEvents.isNotEmpty) {
    await syncRepo.acknowledgeEvents(
      existingEvents.map((e) => e.outboxEventId).toList(),
      'batch_test_ack',
    );
  }

  var syncStatus = await reportsRepo.getSyncStatus(clinicId);
  assertM07('Initial acknowledged state is synced', syncStatus.isSynced == true && syncStatus.pendingOutboxCount == 0);

  // Insert a new pending outbox event to simulate offline/pending sync
  await db.upsert(
    'sync_outbox',
    'outbox_1',
    SyncOutboxEvent(
      outboxEventId: 'outbox_1',
      clinicId: clinicId,
      entityType: 'Invoice',
      entityId: 'inv_001',
      operation: OutboxOperation.insert,
      payloadJson: '{}',
      idempotencyKey: 'idemp_outbox_1',
      createdAt: now,
    ).toMap(),
  );

  syncStatus = await reportsRepo.getSyncStatus(clinicId);
  assertM07('Sync status reflects un-synced outbox count = 1', syncStatus.pendingOutboxCount == 1);
  assertM07('isSynced flag is false when outbox has pending items', syncStatus.isSynced == false);

  // ---------------------------------------------------------------------------
  // 6. DPDPA Health Privacy Isolation & PDF Generation
  // ---------------------------------------------------------------------------
  stdout.writeln('\n6. DPDPA HEALTH PRIVACY ISOLATION & PDF GENERATION');

  final txs = await reportsRepo.getFinancialTransactions(clinicId, date);
  assertM07('Financial transactions count is 2', txs.length == 2);
  final tx1 = txs.firstWhere((t) => t.invoiceId == 'inv_001');
  assertM07('Transaction has invoice number', tx1.invoiceNumber == 'INV-2026-0001');
  assertM07('Transaction has patient name', tx1.patientName == 'Ramesh Kumar');
  assertM07('Transaction has doctor name', tx1.doctorName == 'Dr. Sharma');
  assertM07('Transaction line items show services', tx1.lineItemsSummary.contains('General Consultation'));
  assertM07('Transaction payment methods recorded', tx1.paymentMethods.contains('CASH'));

  // Generate printable PDF
  final pdfBytes = await ReportsPdfService.generateDailyReportPdf(
    clinic: Clinic(
      clinicId: clinicId,
      legalName: 'Apna Clinic LLP',
      displayName: 'Apna Clinic Test',
      ownerName: 'Owner',
      contactPhone: '9876543210',
      contactEmail: 'clinic@test.com',
      addressLine1: 'Main Road',
      city: 'Jaipur',
      district: 'Jaipur',
      state: 'Rajasthan',
      pincode: '302001',
      createdAt: now,
      updatedAt: now,
    ),
    summary: clinicSummary,
    doctorSummaries: allDocSummaries,
    doctorNames: {doc1Id: 'Dr. Sharma', doc2Id: 'Dr. Verma'},
    dayClose: fetchedDayClose,
    transactions: txs,
  );
  assertM07('Printable PDF report generated successfully', pdfBytes.isNotEmpty);
  assertM07('PDF file size is substantial (> 2000 bytes)', pdfBytes.length > 2000);

  // ---------------------------------------------------------------------------
  // 7. TRD Section 4 Role Authorization for Reports
  // ---------------------------------------------------------------------------
  stdout.writeln('\n7. TRD SECTION 4 ROLE AUTHORIZATION FOR REPORTS');

  assertM07(
    'Owner has viewDailyReports permission',
    AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.viewDailyReports),
  );
  assertM07(
    'Owner has viewFinancialLedger permission',
    AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.viewFinancialLedger),
  );
  assertM07(
    'Owner has performDayClose permission',
    AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.performDayClose),
  );
  assertM07(
    'Receptionist has viewDailyReports permission',
    AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.viewDailyReports),
  );
  assertM07(
    'Receptionist has performDayClose permission',
    AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.performDayClose),
  );
  assertM07(
    'Receptionist has NO unrestricted financial ledger permission',
    !AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.viewFinancialLedger),
  );
  assertM07(
    'Accountant has viewDailyReports & viewFinancialLedger',
    AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.viewDailyReports) &&
        AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.viewFinancialLedger),
  );
  assertM07(
    'Accountant has NO permission to view clinical reason for visit',
    !AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.viewReasonForVisit),
  );
  assertM07(
    'Doctor has NO unrestricted access to daily reports',
    !AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.viewDailyReports),
  );

    stdout.writeln('\n===============================================================');
    stdout.writeln('MODULE 7 REPORT RESULTS: $passed PASSED, $failed FAILED');
    stdout.writeln('===============================================================\n');

    expect(failed, 0, reason: 'All Module 7 assertions must pass');
  });
}

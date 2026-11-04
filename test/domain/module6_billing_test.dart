// Apna Clinic - Module 6: Billing, Payments & Day Close Comprehensive Test Suite
// Primary source of truth: PRD Section 5 M06, Section 6.2 Data Model, and Section 15 Matrix Test 10
// Tests fee catalog by doctor/visit type, discounts with reason and threshold, mixed tender,
// partial payments, refunds, voids, and day close reconciliation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/errors/failures.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/repositories/billing_repository.dart';

void main() {
  test('PRD Module 6 - Billing, Payments & Day Close', () async {
  stdout.writeln('===============================================================');
  stdout.writeln('TESTING PRD MODULE 6: BILLING, PAYMENTS & DAY CLOSE (STRICT PRD)');
  stdout.writeln('===============================================================\n');

  final db = LocalDatabase();
  await db.initialize();
  final billingRepo = BillingRepository(db);

  const clinicId = 'clinic_prd_m06';
  const doctorId = 'doc_cardio_1';
  const patientId = 'pat_m06_001';
  final today = DateTime.now().toIso8601String().split('T').first;
  final now = DateTime.now().toUtc();
  const financialYear = '2026-2027';

  int passed = 0;
  int failed = 0;

  void assertM06(String testName, bool condition, [String? errorDetail]) {
    if (condition) {
      stdout.writeln('  [PASS] $testName');
      passed++;
    } else {
      stderr.writeln('  [FAIL] $testName ${errorDetail != null ? "--> $errorDetail" : ""}');
      failed++;
    }
  }

  // ---------------------------------------------------------------------------
  // 1. Fee Catalog by Doctor & Visit Type (PRD M06 & PRD Section 6.2)
  // ---------------------------------------------------------------------------
  stdout.writeln('1. CONSULTATION FEE CATALOGUE BY DOCTOR & VISIT TYPE');

  final generalFee = FeeCatalog(
    feeId: 'fee_gen_walkin',
    clinicId: clinicId,
    visitTypeOptional: 'walkin',
    feeCode: 'CONSULT-GEN',
    feeName: 'General OPD Consultation',
    defaultAmountMinor: 30000, // ₹300
    createdAt: now,
    updatedAt: now,
  );
  await billingRepo.saveFeeCatalogItem(generalFee);

  final doctorFee = FeeCatalog(
    feeId: 'fee_doc_specialist',
    clinicId: clinicId,
    doctorIdOptional: doctorId,
    visitTypeOptional: 'appointment',
    feeCode: 'CONSULT-CARDIO',
    feeName: 'Cardiology Specialist Consultation',
    defaultAmountMinor: 80000, // ₹800
    taxCategory: 'exempt',
    taxRateConfig: '0.0',
    createdAt: now,
    updatedAt: now,
  );
  await billingRepo.saveFeeCatalogItem(doctorFee);

  final allFees = await billingRepo.getFeeCatalog(clinicId);
  assertM06('Fee catalog persists general and doctor-specific items', allFees.length == 2);

  final fetchedDocFee = allFees.firstWhere((f) => f.doctorIdOptional == doctorId);
  assertM06(
    'Doctor-scoped fee matches doctor ID and amount (₹800 = 80000 paise)',
    fetchedDocFee.doctorIdOptional == doctorId && fetchedDocFee.defaultAmountMinor == 80000,
  );

  // ---------------------------------------------------------------------------
  // 2. Sequential Display Numbers & Monotonic Counter (PRD M06)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n2. MONOTONIC INVOICE NUMBER GENERATION');

  final invNum1 = await billingRepo.generateNextInvoiceNumber(clinicId, financialYear);
  assertM06('First invoice sequence is INV-2026-2027-0001', invNum1 == 'INV-2026-2027-0001');

  // ---------------------------------------------------------------------------
  // 3. Discounts with Reason & Approval Threshold (PRD M06)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n3. DISCOUNTS WITH MANDATORY REASON & APPROVAL THRESHOLD');

  const subtotal1 = 80000; // ₹800
  const discount1 = 20000; // ₹200 (25% discount, threshold triggered)
  const total1 = subtotal1 - discount1; // ₹600

  final item1 = InvoiceItem(
    invoiceItemId: 'item_m06_1',
    clinicId: clinicId,
    invoiceId: 'inv_m06_1',
    description: fetchedDocFee.feeName,
    unitPriceMinor: subtotal1,
    discountMinor: discount1,
    lineTotalMinor: total1,
    createdAt: now,
  );

  final invoice1 = Invoice(
    invoiceId: 'inv_m06_1',
    clinicId: clinicId,
    invoiceNumber: invNum1,
    financialYear: financialYear,
    patientId: patientId,
    issueDateLocal: today,
    subtotalMinor: subtotal1,
    discountMinor: discount1,
    discountReasonOptional: 'Senior Citizen 25% Concession',
    discountApprovedByOptional: 'Dr. Clinical Director',
    totalMinor: total1,
    paidMinor: 0,
    balanceMinor: total1,
    status: InvoiceStatus.issued,
    createdByStaffId: 'staff_reception_1',
    createdAt: now,
    updatedAt: now,
  );

  final createdInv1 = await billingRepo.createInvoiceAtomic(
    invoice: invoice1,
    items: [item1],
    idempotencyKey: 'inv_m06_1_idemp',
  );

  assertM06(
    'Invoice created with discount reason and approver',
    createdInv1.discountMinor == 20000 &&
        createdInv1.discountReasonOptional == 'Senior Citizen 25% Concession' &&
        createdInv1.discountApprovedByOptional == 'Dr. Clinical Director',
  );
  assertM06('Invoice total equals subtotal minus discount (₹600 = 60000 paise)', createdInv1.totalMinor == 60000);

  final invNum2 = await billingRepo.generateNextInvoiceNumber(clinicId, financialYear);
  assertM06('Next sequential invoice number increments to INV-2026-2027-0002', invNum2 == 'INV-2026-2027-0002');

  // ---------------------------------------------------------------------------
  // 4. Mixed Tender Payments & Integer Paise Reconciliation (PRD Acceptance 10)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n4. MIXED TENDER PAYMENT (SPLIT CASH + UPI)');

  // Patient pays ₹600 invoice as ₹350 Cash + ₹250 UPI
  final splitCash = Payment(
    paymentId: 'pay_mixed_cash_1',
    clinicId: clinicId,
    invoiceId: createdInv1.invoiceId,
    amountMinor: 35000, // ₹350 in paise
    method: PaymentMethod.cash,
    cashUpiCardReferenceOptional: 'Split Tender (Cash Drawer)',
    receivedAt: now,
    receivedByStaffId: 'staff_reception_1',
    status: PaymentStatus.completed,
    createdAt: now,
  );

  final splitUpi = Payment(
    paymentId: 'pay_mixed_upi_1',
    clinicId: clinicId,
    invoiceId: createdInv1.invoiceId,
    amountMinor: 25000, // ₹250 in paise
    method: PaymentMethod.upi,
    cashUpiCardReferenceOptional: 'UPI-REF-99887766',
    receivedAt: now,
    receivedByStaffId: 'staff_reception_1',
    status: PaymentStatus.completed,
    createdAt: now,
  );

  final recordedPayments = await billingRepo.recordPayments(
    payments: [splitCash, splitUpi],
    idempotencyKey: 'mixed_pay_inv1_idemp',
  );

  assertM06('Mixed tender recorded 2 discrete payment records', recordedPayments.length == 2);

  final updatedInv1 = await billingRepo.getInvoiceById(clinicId, createdInv1.invoiceId);
  assertM06('Invoice paid in full (paid=60000, balance=0)', updatedInv1?.paidMinor == 60000 && updatedInv1?.balanceMinor == 0);
  assertM06('Invoice auto-flipped to PAID', updatedInv1?.status == InvoiceStatus.paid);

  var recon = await billingRepo.getDailyFinancialReconciliation(clinicId, today);
  assertM06('Reconciliation accurately segregates Cash (₹350 = 35000 paise)', recon.totalCashCollectedMinor == 35000);
  assertM06('Reconciliation accurately segregates UPI (₹250 = 25000 paise)', recon.totalUpiCollectedMinor == 25000);

  // ---------------------------------------------------------------------------
  // 5. Partial Payment & Subsequent Settlement (PRD Acceptance 10)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n5. PARTIAL PAYMENT & SUBSEQUENT SETTLEMENT');

  final item2 = InvoiceItem(
    invoiceItemId: 'item_m06_2',
    clinicId: clinicId,
    invoiceId: 'inv_m06_2',
    description: 'Minor Wound Dressing & Suturing',
    unitPriceMinor: 50000, // ₹500
    lineTotalMinor: 50000,
    createdAt: now,
  );

  final invoice2 = Invoice(
    invoiceId: 'inv_m06_2',
    clinicId: clinicId,
    invoiceNumber: invNum2,
    financialYear: financialYear,
    patientId: patientId,
    issueDateLocal: today,
    subtotalMinor: 50000,
    totalMinor: 50000,
    paidMinor: 20000, // ₹200 advance paid
    balanceMinor: 30000, // ₹300 remaining due
    status: InvoiceStatus.partiallyPaid,
    createdByStaffId: 'staff_reception_1',
    createdAt: now,
    updatedAt: now,
  );

  final initialAdvancePayment = Payment(
    paymentId: 'pay_advance_1',
    clinicId: clinicId,
    invoiceId: 'inv_m06_2',
    amountMinor: 20000,
    method: PaymentMethod.cash,
    receivedAt: now,
    receivedByStaffId: 'staff_reception_1',
    status: PaymentStatus.completed,
    createdAt: now,
  );

  final createdInv2 = await billingRepo.createInvoiceAtomic(
    invoice: invoice2,
    items: [item2],
    initialPayment: initialAdvancePayment,
    idempotencyKey: 'inv2_advance_idemp',
  );

  assertM06('Partial advance invoice status is partiallyPaid', createdInv2.status == InvoiceStatus.partiallyPaid);
  assertM06('Balance due is ₹300 (30000 paise)', createdInv2.balanceMinor == 30000);

  // Settle remaining balance on departure via Card
  final settlementPayment = Payment(
    paymentId: 'pay_settle_card_1',
    clinicId: clinicId,
    invoiceId: createdInv2.invoiceId,
    amountMinor: 30000,
    method: PaymentMethod.card,
    cashUpiCardReferenceOptional: 'POS-AUTH-5544',
    receivedAt: now,
    receivedByStaffId: 'staff_reception_1',
    status: PaymentStatus.completed,
    createdAt: now,
  );
  await billingRepo.recordPayment(
    payment: settlementPayment,
    idempotencyKey: 'pay_settle_card_1_idemp',
  );

  final settledInv2 = await billingRepo.getInvoiceById(clinicId, createdInv2.invoiceId);
  assertM06('After settlement, invoice is paid with 0 balance', settledInv2?.status == InvoiceStatus.paid && settledInv2?.balanceMinor == 0);

  recon = await billingRepo.getDailyFinancialReconciliation(clinicId, today);
  assertM06('Reconciliation includes Card (₹300 = 30000 paise)', recon.totalCardCollectedMinor == 30000);

  // ---------------------------------------------------------------------------
  // 6. Refund Reversal & Audit Trail (PRD M06 & PRD Acceptance 10)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n6. REFUND TRANSACTION & FINANCIAL AUDIT REVERSAL');

  // Issue partial refund of ₹100 on Invoice 1 due to overcharge
  final refund = Refund(
    refundId: 'ref_m06_001',
    clinicId: clinicId,
    invoiceId: createdInv1.invoiceId,
    amountMinor: 10000, // ₹100 in paise
    reason: 'Clinical fee adjustment / Overcharge concession',
    requestedByStaffId: 'staff_reception_1',
    approvedByStaffId: 'Dr. Lead Practitioner',
    status: RefundStatus.settled,
    refundedAt: now,
    refundMethod: PaymentMethod.cash,
    createdAt: now,
  );

  final recordedRefund = await billingRepo.recordRefund(
    refund: refund,
    idempotencyKey: 'refund_m06_001_idemp',
  );

  assertM06('Refund recorded with mandatory reason and approvedBy', recordedRefund.reason.isNotEmpty && recordedRefund.approvedByStaffId.isNotEmpty);

  final inv1AfterRefund = await billingRepo.getInvoiceById(clinicId, createdInv1.invoiceId);
  assertM06(
    'Invoice paid amount adjusted down by refund (60000 - 10000 = 50000)',
    inv1AfterRefund?.paidMinor == 50000,
  );

  recon = await billingRepo.getDailyFinancialReconciliation(clinicId, today);
  assertM06('Daily reconciliation reflects refund total (₹100 = 10000 paise)', recon.totalRefundedMinor == 10000);
  assertM06(
    'Net Cash in hand accounts for Gross Cash minus Refunds (35000 + 20000 - 10000 = 45000)',
    recon.netCashInHandMinor == 45000,
  );

  // ---------------------------------------------------------------------------
  // 7. Immutability: Paid Invoices Cannot Be Voided (PRD M06)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n7. FINANCIAL IMMUTABILITY & REVERSAL ENFORCEMENT');

  bool caughtVoidPaidError = false;
  try {
    await billingRepo.voidInvoice(
      clinicId: clinicId,
      invoiceId: createdInv1.invoiceId,
      reason: 'Attempt invalid void on paid invoice',
      staffId: 'staff_reception_1',
    );
  } catch (e) {
    if (e is ValidationFailure) {
      caughtVoidPaidError = true;
    }
  }
  assertM06('Voiding a paid invoice throws ValidationFailure as per PRD M06', caughtVoidPaidError);

  // Voiding an unpaid invoice succeeds
  final invNum3 = await billingRepo.generateNextInvoiceNumber(clinicId, financialYear);
  final invoice3 = Invoice(
    invoiceId: 'inv_m06_3',
    clinicId: clinicId,
    invoiceNumber: invNum3,
    financialYear: financialYear,
    patientId: patientId,
    issueDateLocal: today,
    subtotalMinor: 40000,
    totalMinor: 40000,
    paidMinor: 0,
    balanceMinor: 40000,
    status: InvoiceStatus.issued,
    createdByStaffId: 'staff_reception_1',
    createdAt: now,
    updatedAt: now,
  );

  await billingRepo.createInvoiceAtomic(
    invoice: invoice3,
    items: [
      InvoiceItem(
        invoiceItemId: 'item_3',
        clinicId: clinicId,
        invoiceId: 'inv_m06_3',
        description: 'Scheduled Consultation',
        unitPriceMinor: 40000,
        lineTotalMinor: 40000,
        createdAt: now,
      ),
    ],
    idempotencyKey: 'inv3_idemp',
  );

  await billingRepo.voidInvoice(
    clinicId: clinicId,
    invoiceId: 'inv_m06_3',
    reason: 'Patient left without consultation',
    staffId: 'staff_reception_1',
  );

  final voidedInv3 = await billingRepo.getInvoiceById(clinicId, 'inv_m06_3');
  assertM06('Unpaid invoice is successfully voided with recorded reason', voidedInv3?.status == InvoiceStatus.voided && voidedInv3?.voidReason == 'Patient left without consultation');

  // ---------------------------------------------------------------------------
  // 8. Day Close Reconciliation & Persistence (PRD Section 6.2 `Finance / day_close`)
  // ---------------------------------------------------------------------------
  stdout.writeln('\n8. DAY CLOSE CASH RECONCILIATION & TABLE PERSISTENCE');

  recon = await billingRepo.getDailyFinancialReconciliation(clinicId, today);
  final expectedCashPaise = recon.netCashInHandMinor; // 45000 paise (₹450)
  final physicallyCountedCashPaise = 45000; // Balanced drawer
  final variancePaise = physicallyCountedCashPaise - expectedCashPaise; // 0

  final dayClose = DayClose(
    closeId: 'dc_${clinicId}_$today',
    clinicId: clinicId,
    businessDate: today,
    openedBy: 'Receptionist Sunita',
    closedBy: 'Receptionist Sunita',
    closedAt: DateTime.now().toUtc(),
    openingCashPaise: 0,
    expectedCashPaise: expectedCashPaise,
    countedCashPaise: physicallyCountedCashPaise,
    variancePaise: variancePaise,
    upiTotalPaise: recon.totalUpiCollectedMinor,
    cardTotalPaise: recon.totalCardCollectedMinor,
    refundTotalPaise: recon.totalRefundedMinor,
    notesOptional: 'Physical drawer balanced perfectly to the rupee.',
  );

  await billingRepo.performDayClose(dayClose);

  final persistedDayClose = await billingRepo.getDayClose(clinicId, today);
  assertM06('Day close persisted to day_close table successfully', persistedDayClose != null);
  assertM06('Day close variance is 0 paise', persistedDayClose?.variancePaise == 0);
  assertM06(
    'Day close UPI total matches reconciliation (₹250 = 25000 paise)',
    persistedDayClose?.upiTotalPaise == 25000,
  );
  assertM06(
    'Day close Card total matches reconciliation (₹300 = 30000 paise)',
    persistedDayClose?.cardTotalPaise == 30000,
  );
  assertM06(
    'Day close Refund total matches reconciliation (₹100 = 10000 paise)',
    persistedDayClose?.refundTotalPaise == 10000,
  );

  stdout.writeln('\n---------------------------------------------------------------');
  stdout.writeln('MODULE 6 RESULT: $passed PASSED, $failed FAILED');
  stdout.writeln('---------------------------------------------------------------');

  expect(failed, 0, reason: 'Module 6 tests had failures');
  });
}


// Test Suite for Visit Creation & Billing Integration (PRD M04, M05, M06 & TRD Sec 9, 10)
// Validates Full Payment, Partial Advance, and Unpaid Pay-Later billing tied to Queue Visits

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/domain/entities/patient.dart';
import 'package:apna_clinic/domain/entities/visit.dart';
import 'package:apna_clinic/domain/entities/invoice.dart';
import 'package:apna_clinic/domain/entities/payment.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/repositories/visit_repository.dart';
import 'package:apna_clinic/infrastructure/repositories/billing_repository.dart';

void main() {
  test('Visit creation & billing workflow integration', () async {
  print('========================================================');
  print('TESTING VISIT CREATION & BILLING WORKFLOW INTEGRATION');
  print('========================================================');

  final db = LocalDatabase();
  await db.initialize();
  final visitRepo = VisitRepository(db);
  final billingRepo = BillingRepository(db);

  final today = DateTime.now().toIso8601String().split('T').first;
  final now = DateTime.now().toUtc();
  const clinicId = 'clinic_billing_int';
  const doctorId = 'doc_billing_1';
  const patientId = 'pat_billing_1';

  // Create Patient
  final patient = Patient(
    patientId: patientId,
    clinicId: clinicId,
    patientNumber: 'P-BILL-001',
    fullName: 'Sunita Verma',
    phoneOptional: '9812345678',
    createdAt: now,
    updatedAt: now,
  );
  await db.upsert('Patients', patient.patientId, patient.toMap());

  // -------------------------------------------------------------------------
  // TEST 1: Full Payment at Check-In (Consultation Fee ₹500, Paid ₹500 Cash)
  // -------------------------------------------------------------------------
  print('\n[CASE 1: Full Payment at Check-in]');
  final visitId1 = 'visit_full_pay_1';
  final invId1 = 'inv_full_pay_1';
  const feeMinor1 = 50000; // ₹500 in paise

  final invItem1 = InvoiceItem(
    invoiceItemId: 'item_1',
    clinicId: clinicId,
    invoiceId: invId1,
    description: 'Consultation - Dr. Specialist',
    quantity: 1,
    unitPriceMinor: feeMinor1,
    lineTotalMinor: feeMinor1,
    createdAt: now,
  );

  final invoice1 = Invoice(
    invoiceId: invId1,
    clinicId: clinicId,
    invoiceNumber: 'INV-2026-0001',
    financialYear: '2026-2027',
    patientId: patientId,
    visitId: visitId1,
    issueDateLocal: today,
    subtotalMinor: feeMinor1,
    totalMinor: feeMinor1,
    paidMinor: feeMinor1,
    balanceMinor: 0,
    status: InvoiceStatus.paid,
    createdByStaffId: 'staff_rec_1',
    createdAt: now,
    updatedAt: now,
  );

  final payment1 = Payment(
    paymentId: 'pay_1',
    clinicId: clinicId,
    invoiceId: invId1,
    amountMinor: feeMinor1,
    method: PaymentMethod.cash,
    receivedAt: now,
    receivedByStaffId: 'staff_rec_1',
    status: PaymentStatus.completed,
    createdAt: now,
  );

  final createdInv1 = await billingRepo.createInvoiceAtomic(
    invoice: invoice1,
    items: [invItem1],
    initialPayment: payment1,
    idempotencyKey: 'inv_$invId1',
  );

  final visit1 = Visit(
    visitId: visitId1,
    clinicId: clinicId,
    patientId: patientId,
    doctorId: doctorId,
    visitDateLocal: today,
    checkinAt: now,
    tokenNumber: 0,
    tokenScopeKey: '',
    queueStatus: QueueStatus.waiting,
    invoiceIdOptional: invId1,
    createdByStaffId: 'staff_rec_1',
    createdAt: now,
    updatedAt: now,
  );

  final createdVisit1 = await visitRepo.createVisitAtomic(
    visit: visit1,
    idempotencyKey: 'create_visit_$visitId1',
    deviceId: 'dev_1',
    staffId: 'staff_rec_1',
  );

  assert(createdVisit1.tokenNumber == 1, 'Token should be #1');
  assert(createdInv1.status == InvoiceStatus.paid, 'Invoice status should be paid');
  assert(createdInv1.balanceMinor == 0, 'Balance should be 0');
  assert(createdInv1.paidMinor == 50000, 'Paid should be 50000 paise');
  print('  [PASS] Full payment visit created with Token #1, status=PAID, balance=₹0');

  // Progress visit 1 through valid states to completed
  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId1,
    newStatus: QueueStatus.called,
    staffId: 'staff_rec_1',
    deviceId: 'dev_1',
  );
  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId1,
    newStatus: QueueStatus.inConsultation,
    staffId: 'staff_rec_1',
    deviceId: 'dev_1',
  );
  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId1,
    newStatus: QueueStatus.completed,
    staffId: 'staff_rec_1',
    deviceId: 'dev_1',
  );

  // -------------------------------------------------------------------------
  // TEST 2: Partial Advance Payment at Check-In (Fee ₹500, Paid ₹200 UPI, Due ₹300)
  // -------------------------------------------------------------------------
  print('\n[CASE 2: Partial Advance Payment at Check-in]');
  final visitId2 = 'visit_partial_pay_2';
  final invId2 = 'inv_partial_pay_2';
  const paidMinor2 = 20000; // ₹200
  const balanceMinor2 = 30000; // ₹300

  final invItem2 = InvoiceItem(
    invoiceItemId: 'item_2',
    clinicId: clinicId,
    invoiceId: invId2,
    description: 'Consultation - Dr. Specialist',
    quantity: 1,
    unitPriceMinor: feeMinor1,
    lineTotalMinor: feeMinor1,
    createdAt: now,
  );

  final invoice2 = Invoice(
    invoiceId: invId2,
    clinicId: clinicId,
    invoiceNumber: 'INV-2026-0002',
    financialYear: '2026-2027',
    patientId: patientId,
    visitId: visitId2,
    issueDateLocal: today,
    subtotalMinor: feeMinor1,
    totalMinor: feeMinor1,
    paidMinor: paidMinor2,
    balanceMinor: balanceMinor2,
    status: InvoiceStatus.partiallyPaid,
    createdByStaffId: 'staff_rec_1',
    createdAt: now,
    updatedAt: now,
  );

  final payment2 = Payment(
    paymentId: 'pay_2',
    clinicId: clinicId,
    invoiceId: invId2,
    amountMinor: paidMinor2,
    method: PaymentMethod.upi,
    receivedAt: now,
    receivedByStaffId: 'staff_rec_1',
    status: PaymentStatus.completed,
    createdAt: now,
  );

  final createdInv2 = await billingRepo.createInvoiceAtomic(
    invoice: invoice2,
    items: [invItem2],
    initialPayment: payment2,
    idempotencyKey: 'inv_$invId2',
  );

  final visit2 = Visit(
    visitId: visitId2,
    clinicId: clinicId,
    patientId: patientId,
    doctorId: doctorId,
    visitDateLocal: today,
    checkinAt: now,
    tokenNumber: 0,
    tokenScopeKey: '',
    queueStatus: QueueStatus.waiting,
    invoiceIdOptional: invId2,
    createdByStaffId: 'staff_rec_1',
    createdAt: now,
    updatedAt: now,
  );

  final createdVisit2 = await visitRepo.createVisitAtomic(
    visit: visit2,
    idempotencyKey: 'create_visit_$visitId2',
    deviceId: 'dev_1',
    staffId: 'staff_rec_1',
  );

  assert(createdVisit2.tokenNumber == 2, 'Token should be #2');
  assert(createdInv2.status == InvoiceStatus.partiallyPaid, 'Status should be partiallyPaid');
  assert(createdInv2.paidMinor == 20000, 'Paid should be 20000 paise (₹200)');
  assert(createdInv2.balanceMinor == 30000, 'Balance should be 30000 paise (₹300)');
  print('  [PASS] Partial visit created with Token #2, status=PARTIALLY_PAID, paid=₹200, due=₹300');

  // Progress visit 2 through valid states to completed
  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId2,
    newStatus: QueueStatus.called,
    staffId: 'staff_rec_1',
    deviceId: 'dev_1',
  );
  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId2,
    newStatus: QueueStatus.inConsultation,
    staffId: 'staff_rec_1',
    deviceId: 'dev_1',
  );
  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId2,
    newStatus: QueueStatus.completed,
    staffId: 'staff_rec_1',
    deviceId: 'dev_1',
  );

  // Settle the remaining ₹300 due on visit 2
  print('\n[CASE 2B: Settle Remaining Balance on Exit]');
  final settlePayment = Payment(
    paymentId: 'pay_settle_2',
    clinicId: clinicId,
    invoiceId: invId2,
    amountMinor: 30000, // ₹300
    method: PaymentMethod.cash,
    receivedAt: now,
    receivedByStaffId: 'staff_rec_1',
    status: PaymentStatus.completed,
    createdAt: now,
  );

  await billingRepo.recordPayment(
    payment: settlePayment,
    idempotencyKey: 'pay_settle_2',
  );

  final settledInvoices = await billingRepo.getInvoicesForDate(clinicId, today);
  final settledInv2 = settledInvoices.firstWhere((i) => i.invoiceId == invId2);
  assert(settledInv2.status == InvoiceStatus.paid, 'Settled invoice should be paid');
  assert(settledInv2.paidMinor == 50000, 'Total paid should now be ₹500');
  assert(settledInv2.balanceMinor == 0, 'Balance should now be ₹0');
  print('  [PASS] Remaining ₹300 settled! Invoice auto-flipped to PAID with balance=₹0');

  // -------------------------------------------------------------------------
  // TEST 3: Unpaid / Pay Later at Check-In (Fee ₹500, Paid ₹0, Due ₹500)
  // -------------------------------------------------------------------------
  print('\n[CASE 3: Unpaid (Pay Later) at Check-in]');
  final visitId3 = 'visit_unpaid_3';
  final invId3 = 'inv_unpaid_3';

  final invItem3 = InvoiceItem(
    invoiceItemId: 'item_3',
    clinicId: clinicId,
    invoiceId: invId3,
    description: 'Consultation - Dr. Specialist',
    quantity: 1,
    unitPriceMinor: feeMinor1,
    lineTotalMinor: feeMinor1,
    createdAt: now,
  );

  final invoice3 = Invoice(
    invoiceId: invId3,
    clinicId: clinicId,
    invoiceNumber: 'INV-2026-0003',
    financialYear: '2026-2027',
    patientId: patientId,
    visitId: visitId3,
    issueDateLocal: today,
    subtotalMinor: feeMinor1,
    totalMinor: feeMinor1,
    paidMinor: 0,
    balanceMinor: feeMinor1,
    status: InvoiceStatus.issued,
    createdByStaffId: 'staff_rec_1',
    createdAt: now,
    updatedAt: now,
  );

  final createdInv3 = await billingRepo.createInvoiceAtomic(
    invoice: invoice3,
    items: [invItem3],
    initialPayment: null, // No initial payment!
    idempotencyKey: 'inv_$invId3',
  );

  final visit3 = Visit(
    visitId: visitId3,
    clinicId: clinicId,
    patientId: patientId,
    doctorId: doctorId,
    visitDateLocal: today,
    checkinAt: now,
    tokenNumber: 0,
    tokenScopeKey: '',
    queueStatus: QueueStatus.waiting,
    invoiceIdOptional: invId3,
    createdByStaffId: 'staff_rec_1',
    createdAt: now,
    updatedAt: now,
  );

  final createdVisit3 = await visitRepo.createVisitAtomic(
    visit: visit3,
    idempotencyKey: 'create_visit_$visitId3',
    deviceId: 'dev_1',
    staffId: 'staff_rec_1',
  );

  assert(createdVisit3.tokenNumber == 3, 'Token should be #3');
  assert(createdInv3.status == InvoiceStatus.issued, 'Status should be issued (unpaid)');
  assert(createdInv3.paidMinor == 0, 'Paid should be 0');
  assert(createdInv3.balanceMinor == 50000, 'Balance should be ₹500');
  print('  [PASS] Unpaid visit queued with Token #3, status=ISSUED/UNPAID, balance=₹500');

  // Verify daily reconciliation separates cash, UPI, and outstanding dues cleanly
  final recon = await billingRepo.getDailyFinancialReconciliation(clinicId, today);
  print('\n[CASE 4: Daily Ledger Reconciliation]');
  print('  Total Invoiced: ₹${recon.totalInvoicedMinor ~/ 100}');
  print('  Cash Collected: ₹${recon.totalCashCollectedMinor ~/ 100}');
  print('  UPI Collected: ₹${recon.totalUpiCollectedMinor ~/ 100}');
  print('  Outstanding Due: ₹${recon.totalOutstandingMinor ~/ 100}');

  assert(recon.totalInvoicedMinor == 150000, 'Total invoiced should be ₹1500 (150000 paise)');
  assert(recon.totalCashCollectedMinor == 80000, 'Cash collected: ₹500 (case 1) + ₹300 (settlement) = ₹800');
  assert(recon.totalUpiCollectedMinor == 20000, 'UPI collected: ₹200 (case 2 initial) = ₹200');
  assert(recon.totalOutstandingMinor == 50000, 'Outstanding: ₹500 from Case 3 = ₹500');
  print('  [PASS] Daily reconciliation accurately matches integer paise totals with zero discrepancies!');

  print('\n========================================================');
  print('ALL VISIT-BILLING INTEGRATION TESTS PASSED (100%)');
  print('========================================================');
  });
}

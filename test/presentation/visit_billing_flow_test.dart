import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/repositories/billing_repository.dart';
import 'package:apna_clinic/infrastructure/repositories/visit_repository.dart';

void main() {
  test('Visit billing workflow test', () async {
  stdout.writeln('===============================================================');
  stdout.writeln('TESTING VISIT BILLING WORKFLOW (MODULE 6 + QUEUE INDEPENDENCE)');
  stdout.writeln('===============================================================\n');

  final db = LocalDatabase();
  await db.initialize();
  final billingRepo = BillingRepository(db);
  final visitRepo = VisitRepository(db);

  int passed = 0;
  int failed = 0;

  void assertStep(String testName, bool condition, [String? errorDetail]) {
    if (condition) {
      stdout.writeln('  [PASS] $testName');
      passed++;
    } else {
      stderr.writeln('  [FAIL] $testName ${errorDetail != null ? "--> $errorDetail" : ""}');
      failed++;
    }
  }

  const clinicId = 'clinic_visit_flow';
  const doctorId = 'doc_cardio_99';
  const patientId = 'pat_emergency_01';
  const staffId = 'staff_rec_01';
  final now = DateTime.now().toUtc();
  final today = DateTime.now().toIso8601String().split('T').first;

  // 1. Setup Doctor with default consultation fee Rs 300 (30000 minor) and Patient
  final doctor = Doctor(
    doctorId: doctorId,
    clinicId: clinicId,
    displayName: 'Dr. Mehta',
    specialtyLabel: 'General Medicine',
    defaultFee: 30000, // Rs 300
    active: true,
    createdAt: now,
    updatedAt: now,
  );
  await db.upsert('Doctors', doctor.doctorId, doctor.toMap());

  final patient = Patient(
    patientId: patientId,
    clinicId: clinicId,
    patientNumber: 'P-101',
    fullName: 'Rahul Sharma',
    createdAt: now,
    updatedAt: now,
  );
  await db.upsert('Patients', patient.patientId, patient.toMap());

  // 2. Setup Fee Catalog with Emergency Fee Rs 200 (20000 minor)
  final emergencyFee = FeeCatalog(
    feeId: 'fee_emergency_200',
    clinicId: clinicId,
    visitTypeOptional: 'emergency',
    feeCode: 'EMERGENCY',
    feeName: 'Emergency Care',
    defaultAmountMinor: 20000, // Rs 200
    createdAt: now,
    updatedAt: now,
  );
  await billingRepo.saveFeeCatalogItem(emergencyFee);

  final catalog = await billingRepo.getFeeCatalog(clinicId);
  assertStep('Fee catalog contains emergency fee', catalog.any((f) => f.feeId == 'fee_emergency_200'));

  // 3. Priority-based auto-resolution logic (Emergency surcharge Rs 200 added to Base Consultation Rs 300)
  const priorityKey = 'emergency';
  final matchedFee = catalog.where((f) =>
    f.active &&
    (f.visitTypeOptional?.toLowerCase() == priorityKey ||
     f.feeName.toLowerCase().contains(priorityKey))
  ).firstOrNull;

  final baseFeeRupees = (doctor.defaultFee / 100).round(); // Rs 300
  final additionalFeeRupees = matchedFee != null ? (matchedFee.defaultAmountMinor / 100).round() : 0; // Rs 200
  final wholeFeeRupees = baseFeeRupees + additionalFeeRupees; // Rs 500

  assertStep('Base consultation fee is Rs 300', baseFeeRupees == 300);
  assertStep('Emergency surcharge is Rs 200', additionalFeeRupees == 200);
  assertStep('Whole fee equals Base + Emergency surcharge = Rs 500', wholeFeeRupees == 500);

  // 4. Create Visit with "Pay Later (At Checkout)" with itemized whole fee
  final visitId = 'v_emergency_flow_1';
  final invoiceId = 'inv_emergency_flow_1';
  final wholeFeeMinor = wholeFeeRupees * 100; // 50000 minor

  final item1 = InvoiceItem(
    invoiceItemId: 'item_1',
    clinicId: clinicId,
    invoiceId: invoiceId,
    description: 'Consultation - Dr. ${doctor.displayName}',
    quantity: 1,
    unitPriceMinor: baseFeeRupees * 100, // 30000
    discountMinor: 0,
    taxMinor: 0,
    lineTotalMinor: baseFeeRupees * 100,
    createdAt: now,
  );

  final item2 = InvoiceItem(
    invoiceItemId: 'item_2',
    clinicId: clinicId,
    invoiceId: invoiceId,
    feeIdOptional: matchedFee?.feeId,
    description: matchedFee?.feeName ?? 'Emergency Care',
    quantity: 1,
    unitPriceMinor: additionalFeeRupees * 100, // 20000
    discountMinor: 0,
    taxMinor: 0,
    lineTotalMinor: additionalFeeRupees * 100,
    createdAt: now,
  );

  final invoice = Invoice(
    invoiceId: invoiceId,
    clinicId: clinicId,
    invoiceNumber: 'INV/2026-27/0099',
    financialYear: '2026-2027',
    patientId: patientId,
    visitId: visitId,
    issueDateLocal: today,
    subtotalMinor: wholeFeeMinor,
    discountMinor: 0,
    taxMinor: 0,
    totalMinor: wholeFeeMinor,
    paidMinor: 0,
    balanceMinor: wholeFeeMinor,
    status: InvoiceStatus.issued,
    createdByStaffId: staffId,
    createdAt: now,
    updatedAt: now,
  );

  final createdInvoice = await billingRepo.createInvoiceAtomic(
    invoice: invoice,
    items: [item1, item2],
    initialPayment: null, // Pay Later (Unpaid)
    idempotencyKey: 'inv_v_$visitId',
  );

  assertStep('Created invoice has status issued (unpaid)', createdInvoice.status == InvoiceStatus.issued);
  assertStep('Created invoice has paidMinor = 0', createdInvoice.paidMinor == 0);
  assertStep('Created invoice has balanceMinor = 50000 (Whole fee Rs 500)', createdInvoice.balanceMinor == 50000);
  assertStep('Invoice has 2 line items (Consultation + Emergency)', createdInvoice.items.length == 2);

  // 5. Patient enters waiting queue
  final visit = Visit(
    visitId: visitId,
    clinicId: clinicId,
    patientId: patientId,
    doctorId: doctorId,
    visitDateLocal: today,
    checkinAt: now,
    tokenNumber: 1,
    tokenScopeKey: '$clinicId:$doctorId:$today',
    visitType: 'emergency',
    priority: QueuePriority.emergency,
    queueStatus: QueueStatus.waiting,
    invoiceIdOptional: invoiceId,
    createdByStaffId: staffId,
    createdAt: now,
    updatedAt: now,
  );
  await visitRepo.createVisitAtomic(
    visit: visit,
    idempotencyKey: 'visit_$visitId',
    deviceId: 'dev_1',
    staffId: staffId,
  );

  // 6. Clinical consultation progresses: waiting -> called -> inConsultation -> completed
  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId,
    newStatus: QueueStatus.called,
    staffId: doctorId,
    deviceId: 'dev_1',
  );

  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId,
    newStatus: QueueStatus.inConsultation,
    staffId: doctorId,
    deviceId: 'dev_1',
  );

  // Consultation finishes
  await visitRepo.updateQueueStatus(
    clinicId: clinicId,
    visitId: visitId,
    newStatus: QueueStatus.completed,
    staffId: doctorId,
    deviceId: 'dev_1',
  );

  final completedVisit = await visitRepo.getVisitById(clinicId, visitId);
  assertStep('Visit queue status is completed', completedVisit?.queueStatus == QueueStatus.completed);

  // 7. Critical PRD requirement: Billing did NOT automatically settle upon consultation completion
  final billAfterConsultation = await billingRepo.getInvoiceById(clinicId, invoiceId);
  assertStep('Billing remains issued (unpaid) after consultation completion', billAfterConsultation?.status == InvoiceStatus.issued);
  assertStep('Bill paidMinor remains 0 after consultation completion', billAfterConsultation?.paidMinor == 0);
  assertStep('Bill balanceMinor remains 50000 (Rs 500) after consultation completion', billAfterConsultation?.balanceMinor == 50000);

  // 8. Reception Checkout: Collect whole fee via Mixed Tender (Rs 300 Cash + Rs 200 UPI = Rs 500)
  final p1 = Payment(
    paymentId: 'pay_split_1',
    clinicId: clinicId,
    invoiceId: invoiceId,
    amountMinor: 30000, // Rs 300 Cash (Base consultation)
    method: PaymentMethod.cash,
    receivedAt: now,
    receivedByStaffId: staffId,
    status: PaymentStatus.completed,
    createdAt: now,
  );
  final p2 = Payment(
    paymentId: 'pay_split_2',
    clinicId: clinicId,
    invoiceId: invoiceId,
    amountMinor: 20000, // Rs 200 UPI (Emergency surcharge)
    method: PaymentMethod.upi,
    receivedAt: now,
    receivedByStaffId: staffId,
    status: PaymentStatus.completed,
    createdAt: now,
  );

  await billingRepo.recordPayments(
    payments: [p1, p2],
    idempotencyKey: 'pay_mixed_checkout_$invoiceId',
  );

  // 9. Verify bill is now fully settled and paid
  final settledInvoice = await billingRepo.getInvoiceById(clinicId, invoiceId);
  assertStep('Invoice status transitions to paid after checkout collection', settledInvoice?.status == InvoiceStatus.paid);
  assertStep('Invoice paidMinor is 50000 (Whole fee Rs 500)', settledInvoice?.paidMinor == 50000);
  assertStep('Invoice balanceMinor is 0', settledInvoice?.balanceMinor == 0);

  final payments = await billingRepo.getPaymentsForInvoice(clinicId, invoiceId);
  assertStep('Both cash and UPI tender payments are recorded', payments.length == 2);

  stdout.writeln('\n===============================================================');
  stdout.writeln('TEST SUMMARY: $passed Passed, $failed Failed');
  stdout.writeln('===============================================================');

  expect(failed, 0, reason: 'Visit billing flow tests had failures');
  });
}

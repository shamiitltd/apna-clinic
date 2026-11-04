// Apna Clinic - Module 11: Expense Tracking Test Suite
// Verifies PRD Section 5 M11, Section 6.2, TRD Section 7 `Expenses`:
// 1. Integer minor units arithmetic (paise) for all expense calculations.
// 2. PRD expense categories (rent, salaries, utilities, supplies, printer_consumables, refreshments, maintenance, other).
// 3. Cash vs Non-Cash payment methods & impact on net cash-in-hand reconciliation.
// 4. Soft deletion with audit trail (Audit_Events) and sync outbox staging.
// 5. PRD Acceptance Criterion: Zero Patient PII in Expense CSV Export.
// 6. Strict RBAC: Owner & Accountant granted manageExpenses; Doctor & Receptionist denied.

import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/core/utils/money.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/repositories/expense_repository.dart';

void main() {
  group('MODULE 11 — EXPENSE TRACKING & RECONCILIATION (PRD M11)', () {
    late LocalDatabase memoryDb;
    late ExpenseRepository expenseRepo;
    const testClinicId = 'clinic_m11_test';
    const testStaffOwner = 'staff_owner_01';
    const testStaffAccountant = 'staff_acct_01';

    setUp(() async {
      memoryDb = LocalDatabase(MemoryStorageAdapter());
      await memoryDb.initialize();

      final now = DateTime.now().toUtc();
      final clinic = Clinic(
        clinicId: testClinicId,
        legalName: 'Apex Health Center',
        displayName: 'Apex Clinic',
        ownerName: 'Dr. Anita Desai',
        contactPhone: '9876543210',
        contactEmail: 'anita@apexclinic.com',
        addressLine1: '12 MG Road',
        city: 'Indore',
        district: 'Indore',
        state: 'Madhya Pradesh',
        pincode: '452001',
        createdAt: now,
        updatedAt: now,
      );
      await memoryDb.upsert('Clinic_Config', testClinicId, clinic.toMap());

      expenseRepo = ExpenseRepository(memoryDb);
    });

    test('1. Integer Minor Units: Expense amounts are strictly stored and calculated in integer paise', () async {
      final now = DateTime.now().toUtc();
      final today = '2026-10-31';

      // ₹450.50 = 45,050 paise (printer paper)
      final expense1 = Expense(
        expenseId: 'exp_001',
        clinicId: testClinicId,
        expenseDate: today,
        category: 'printer_consumables',
        description: '5 Reams A5 thermal / laser paper',
        amountMinor: 45050,
        paymentMethod: PaymentMethod.cash,
        vendorOptional: 'City Paper Mart',
        paymentReferenceOptional: 'RCPT-1029',
        createdByStaffId: testStaffAccountant,
        createdAt: now,
        updatedAt: now,
      );

      // ₹1,200.00 = 120,000 paise (medical supplies)
      final expense2 = Expense(
        expenseId: 'exp_002',
        clinicId: testClinicId,
        expenseDate: today,
        category: 'supplies',
        description: 'Sterile gloves & disposable syringes',
        amountMinor: 120000,
        paymentMethod: PaymentMethod.upi,
        vendorOptional: 'MedEquip Distributors',
        paymentReferenceOptional: 'UPI/IND/293849',
        createdByStaffId: testStaffOwner,
        createdAt: now,
        updatedAt: now,
      );

      await expenseRepo.recordExpense(expense1);
      await expenseRepo.recordExpense(expense2);

      final totalPaise = await expenseRepo.getTotalExpensesForDate(testClinicId, today);
      expect(totalPaise, 165050, reason: '45050 + 120000 must strictly equal 165050 paise');

      final money = Money.fromPaise(totalPaise);
      expect(money.paise, 165050);
      expect(money.formatted, '₹1,650.50');
    });

    test('2. PRD Expense Categories: Correctly records and filters PRD operational expense types', () async {
      final now = DateTime.now().toUtc();
      final today = '2026-10-31';

      final categories = [
        'rent',
        'salaries',
        'utilities',
        'supplies',
        'printer_consumables',
        'refreshments',
        'maintenance',
        'other',
      ];

      for (int i = 0; i < categories.length; i++) {
        final exp = Expense(
          expenseId: 'exp_cat_$i',
          clinicId: testClinicId,
          expenseDate: today,
          category: categories[i],
          description: 'Test expense for ${categories[i]}',
          amountMinor: (i + 1) * 10000, // ₹100, ₹200, ...
          paymentMethod: i % 2 == 0 ? PaymentMethod.cash : PaymentMethod.upi,
          createdByStaffId: testStaffAccountant,
          createdAt: now.add(Duration(minutes: i)),
          updatedAt: now.add(Duration(minutes: i)),
        );
        await expenseRepo.recordExpense(exp);
      }

      final recorded = await expenseRepo.getExpensesForDate(testClinicId, today);
      expect(recorded.length, categories.length);

      final retrievedCategories = recorded.map((e) => e.category).toSet();
      expect(retrievedCategories, containsAll(categories));
    });

    test('3. Cash Outflow Integration: Distinguishes physical cash expenses for Day Close net cash reconciliation', () async {
      final now = DateTime.now().toUtc();
      final today = '2026-10-31';

      // Cash expense: ₹500.00 = 50,000 paise (affects cash drawer)
      await expenseRepo.recordExpense(Expense(
        expenseId: 'exp_cash_01',
        clinicId: testClinicId,
        expenseDate: today,
        category: 'refreshments',
        description: 'Clinic staff tea & milk',
        amountMinor: 50000,
        paymentMethod: PaymentMethod.cash,
        createdByStaffId: testStaffAccountant,
        createdAt: now,
        updatedAt: now,
      ));

      // UPI expense: ₹15,000.00 = 1,500,000 paise (bank transfer, does not reduce cash drawer)
      await expenseRepo.recordExpense(Expense(
        expenseId: 'exp_upi_01',
        clinicId: testClinicId,
        expenseDate: today,
        category: 'rent',
        description: 'Monthly Clinic Room Rent',
        amountMinor: 1500000,
        paymentMethod: PaymentMethod.upi,
        paymentReferenceOptional: 'NEFT/HDFC/889211',
        createdByStaffId: testStaffOwner,
        createdAt: now,
        updatedAt: now,
      ));

      final totalExpenses = await expenseRepo.getTotalExpensesForDate(testClinicId, today);
      final cashExpenses = await expenseRepo.getCashExpensesForDate(testClinicId, today);

      expect(totalExpenses, 1550000);
      expect(cashExpenses, 50000, reason: 'Only cash payment method should be counted in cash expenses');

      // Verify net cash in hand formula:
      // netCashInHand = cashCollected - cashRefunds - cashExpenses
      const int dummyCashCollectedPaise = 200000; // ₹2,000 collected
      const int dummyCashRefundsPaise = 20000;    // ₹200 refunded
      final int netCashInHandPaise = dummyCashCollectedPaise - dummyCashRefundsPaise - cashExpenses;

      expect(netCashInHandPaise, 130000, reason: '200,000 - 20,000 - 50,000 = 130,000 paise (₹1,300.00)');
    });

    test('4. Soft Deletion & Audit Trail: Soft-deletes expense, stages sync outbox, and logs Audit_Events', () async {
      final now = DateTime.now().toUtc();
      final today = '2026-10-31';

      final expense = Expense(
        expenseId: 'exp_to_delete',
        clinicId: testClinicId,
        expenseDate: today,
        category: 'maintenance',
        description: 'AC Servicing (Duplicate Entry)',
        amountMinor: 80000,
        paymentMethod: PaymentMethod.cash,
        createdByStaffId: testStaffAccountant,
        createdAt: now,
        updatedAt: now,
      );

      await expenseRepo.recordExpense(expense);

      // Verify it is active
      var activeExpenses = await expenseRepo.getExpensesForDate(testClinicId, today);
      expect(activeExpenses.length, 1);

      // Soft delete
      await expenseRepo.deleteExpense(
        clinicId: testClinicId,
        expenseId: 'exp_to_delete',
        actorId: testStaffAccountant,
        reason: 'Duplicate entry detected by accountant',
      );

      // Verify excluded from active list
      activeExpenses = await expenseRepo.getExpensesForDate(testClinicId, today);
      expect(activeExpenses.isEmpty, isTrue);

      // Verify audit event recorded
      final auditRecords = memoryDb.query(
        'Audit_Events',
        where: (r) => r['action'] == 'expense.delete' && r['entity_id'] == 'exp_to_delete',
      );
      expect(auditRecords.length, 1);
      expect(auditRecords.first['actor_id'], testStaffAccountant);
      expect(auditRecords.first['reason_optional'], 'Duplicate entry detected by accountant');

      // Verify sync outbox has update event
      final outboxRecords = memoryDb.query(
        'sync_outbox',
        where: (r) => r['entity_id'] == 'exp_to_delete' && r['operation'] == 'update',
      );
      expect(outboxRecords.length, 1);
    });

    test('5. Acceptance Criterion: Expense CSV Export strictly excludes any patient data', () async {
      final now = DateTime.now().toUtc();
      final expenses = [
        Expense(
          expenseId: 'exp_csv_1',
          clinicId: testClinicId,
          expenseDate: '2026-10-31',
          category: 'supplies',
          description: 'Cotton rolls and Betadine',
          amountMinor: 65000,
          paymentMethod: PaymentMethod.cash,
          vendorOptional: 'Shree Pharma Dist',
          paymentReferenceOptional: 'BILL-4412',
          createdByStaffId: testStaffAccountant,
          createdAt: now,
          updatedAt: now,
        ),
        Expense(
          expenseId: 'exp_csv_2',
          clinicId: testClinicId,
          expenseDate: '2026-10-31',
          category: 'utilities',
          description: 'High-speed Broadband Connection',
          amountMinor: 119900,
          paymentMethod: PaymentMethod.upi,
          vendorOptional: 'Airtel Broadband',
          paymentReferenceOptional: 'UPI/BB/99128',
          createdByStaffId: testStaffOwner,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final csv = expenseRepo.exportExpensesToCsv(expenses);

      // Validate CSV headers
      expect(csv.startsWith('\uFEFF'), isTrue, reason: 'Must include UTF-8 BOM for Excel compatibility');
      expect(csv, contains('expense_id,date,category,description,amount_paise,amount_inr,payment_method,vendor,payment_reference,created_by_staff_id,created_at'));

      // Validate financial data present
      expect(csv, contains('exp_csv_1'));
      expect(csv, contains('Cotton rolls and Betadine'));
      expect(csv, contains('65000'));
      expect(csv, contains('650.00'));
      expect(csv, contains('Shree Pharma Dist'));

      expect(csv, contains('exp_csv_2'));
      expect(csv, contains('High-speed Broadband Connection'));
      expect(csv, contains('119900'));
      expect(csv, contains('1199.00'));
      expect(csv, contains('Airtel Broadband'));

      // Strictly verify NO patient data keywords exist
      final lowerCsv = csv.toLowerCase();
      expect(lowerCsv.contains('patient_id'), isFalse, reason: 'Expense export must strictly exclude patient data');
      expect(lowerCsv.contains('patient_name'), isFalse);
      expect(lowerCsv.contains('phone_number'), isFalse);
      expect(lowerCsv.contains('diagnosis'), isFalse);
      expect(lowerCsv.contains('rx'), isFalse);
      expect(lowerCsv.contains('prescription'), isFalse);
      expect(lowerCsv.contains('visit_id'), isFalse);
    });

    test('6. RBAC: Owner and Accountant have manageExpenses; Receptionist and Doctor are strictly denied', () {
      // Owner
      final ownerAllowed = AuthorizationService.hasPermission(
        role: UserRole.owner,
        permission: AppPermission.manageExpenses,
      );
      expect(ownerAllowed, isTrue, reason: 'Owner must have permission to manage expenses');

      // Accountant
      final accountantAllowed = AuthorizationService.hasPermission(
        role: UserRole.accountant,
        permission: AppPermission.manageExpenses,
      );
      expect(accountantAllowed, isTrue, reason: 'Accountant must have permission to manage expenses');

      // Doctor
      final doctorAllowed = AuthorizationService.hasPermission(
        role: UserRole.doctor,
        permission: AppPermission.manageExpenses,
      );
      expect(doctorAllowed, isFalse, reason: 'Doctor must be denied access to operational clinic expenses');

      // Receptionist
      final receptionistAllowed = AuthorizationService.hasPermission(
        role: UserRole.receptionist,
        permission: AppPermission.manageExpenses,
      );
      expect(receptionistAllowed, isFalse, reason: 'Receptionist must be denied access to operational clinic expenses');
    });
  });
}

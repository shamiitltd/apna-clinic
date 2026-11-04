// Apna Clinic - Concrete Expense Repository Implementation (Module 11)
// Primary source of truth: PRD Section 5 M11, Section 6.2, TRD Section 7 `Expenses`

import 'dart:convert';
import '../../domain/entities/audit_event.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_expense_repository.dart';
import '../database/local_database.dart';

class ExpenseRepository implements IExpenseRepository {
  final LocalDatabase _db;

  ExpenseRepository(this._db);

  @override
  Future<void> recordExpense(Expense expense) async {
    await _db.transaction((tx) async {
      await _db.upsert('Expenses', expense.expenseId, expense.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_exp_${expense.expenseId}',
        clinicId: expense.clinicId,
        entityType: 'Expenses',
        entityId: expense.expenseId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(expense.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'exp_${expense.expenseId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      final auditEvent = AuditEvent(
        auditEventId: 'audit_exp_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: expense.clinicId,
        actorId: expense.createdByStaffId,
        actorRole: 'accountant',
        deviceId: 'primary_workstation',
        action: 'expense.record',
        entityType: 'expense',
        entityId: expense.expenseId,
        occurredAt: DateTime.now().toUtc(),
        result: AuditResult.success,
        correlationId: expense.expenseId,
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<List<Expense>> getExpensesForDate(
    String clinicId,
    String localDate,
  ) async {
    final records = _db.query(
      'Expenses',
      where: (r) =>
          r['clinic_id'] == clinicId &&
          r['expense_date'] == localDate &&
          r['deleted_at'] == null,
    );
    final expenses = records.map((r) => Expense.fromMap(r)).toList();
    expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return expenses;
  }

  @override
  Future<List<Expense>> getExpensesForDateRange(
    String clinicId,
    String startDate,
    String endDate,
  ) async {
    final records = _db.query(
      'Expenses',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        if (r['deleted_at'] != null) return false;
        final date = r['expense_date'] as String? ?? '';
        return date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;
      },
    );
    final expenses = records.map((r) => Expense.fromMap(r)).toList();
    expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return expenses;
  }

  @override
  Future<void> deleteExpense({
    required String clinicId,
    required String expenseId,
    required String actorId,
    required String reason,
  }) async {
    final records = _db.query(
      'Expenses',
      where: (r) => r['clinic_id'] == clinicId && r['expense_id'] == expenseId,
    );
    if (records.isEmpty) return;

    final existing = Map<String, dynamic>.from(records.first);
    final now = DateTime.now().toUtc();
    existing['deleted_at'] = now.toIso8601String();
    existing['updated_at'] = now.toIso8601String();

    await _db.transaction((tx) async {
      await _db.upsert('Expenses', expenseId, existing, tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_exp_del_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        entityType: 'Expenses',
        entityId: expenseId,
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(existing),
        createdAt: now,
        idempotencyKey: 'exp_del_$expenseId',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      final auditEvent = AuditEvent(
        auditEventId: 'audit_exp_del_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: actorId,
        actorRole: 'accountant',
        deviceId: 'primary_workstation',
        action: 'expense.delete',
        entityType: 'expense',
        entityId: expenseId,
        occurredAt: now,
        result: AuditResult.success,
        reasonOptional: reason,
        correlationId: expenseId,
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<int> getTotalExpensesForDate(String clinicId, String localDate) async {
    final expenses = await getExpensesForDate(clinicId, localDate);
    int total = 0;
    for (final exp in expenses) {
      total += exp.amountMinor;
    }
    return total;
  }

  @override
  Future<int> getCashExpensesForDate(String clinicId, String localDate) async {
    final expenses = await getExpensesForDate(clinicId, localDate);
    int cashTotal = 0;
    for (final exp in expenses) {
      if (exp.paymentMethod == PaymentMethod.cash) {
        cashTotal += exp.amountMinor;
      }
    }
    return cashTotal;
  }

  @override
  String exportExpensesToCsv(List<Expense> expenses) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM
    buffer.writeln(
      'expense_id,date,category,description,amount_paise,amount_inr,payment_method,vendor,payment_reference,created_by_staff_id,created_at',
    );
    for (final exp in expenses) {
      final amountInr = (exp.amountMinor / 100).toStringAsFixed(2);
      buffer.writeln(
        '"${exp.expenseId}","${exp.expenseDate}","${exp.category}","${exp.description.replaceAll('"', '""')}","${exp.amountMinor}","$amountInr","${exp.paymentMethod.wireValue}","${(exp.vendorOptional ?? '').replaceAll('"', '""')}","${exp.paymentReferenceOptional ?? ''}","${exp.createdByStaffId}","${exp.createdAt.toIso8601String()}"',
      );
    }
    return buffer.toString();
  }
}

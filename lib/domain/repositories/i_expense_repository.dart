// Apna Clinic - Expense Repository Interface (Module 11)
// Primary source of truth: PRD Section 5 M11, Section 6.2 `expenses`, TRD Section 7 `Expenses`

import '../entities/expense.dart';

abstract class IExpenseRepository {
  /// Records a new clinic operating expense and stages sync outbox event
  Future<void> recordExpense(Expense expense);

  /// Retrieves all active (non-deleted) expenses for a specific clinic business date
  Future<List<Expense>> getExpensesForDate(String clinicId, String localDate);

  /// Retrieves active expenses within a given date range (inclusive)
  Future<List<Expense>> getExpensesForDateRange(
    String clinicId,
    String startDate,
    String endDate,
  );

  /// Soft deletes an expense with audit logging and sync outbox staging
  Future<void> deleteExpense({
    required String clinicId,
    required String expenseId,
    required String actorId,
    required String reason,
  });

  /// Calculates total expense amount in minor units (paise) for a date
  Future<int> getTotalExpensesForDate(String clinicId, String localDate);

  /// Calculates total cash expenses for a date (used in day-close cash in hand reconciliation)
  Future<int> getCashExpensesForDate(String clinicId, String localDate);

  /// Generates clean CSV content for expenses without ANY patient data.
  /// PRD Section 5 M11 Acceptance: "expense summaries exclude patient data and are exportable."
  String exportExpensesToCsv(List<Expense> expenses);
}


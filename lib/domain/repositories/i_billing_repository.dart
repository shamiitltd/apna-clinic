// Apna Clinic - Billing & Financial Repository Interface
// FINANCIAL IMMUTABILITY: Integer paise math, monotonic invoice numbers, no destructive edits.
// Primary source of truth: PRD Section 5 M06 & Section 6.2

import '../entities/entities.dart';

class DailyReconciliation {
  final int totalInvoicedMinor;
  final int totalCashCollectedMinor;
  final int totalUpiCollectedMinor;
  final int totalCardCollectedMinor;
  final int totalRefundedMinor;
  final int totalExpensesMinor;
  final int totalOutstandingMinor;

  const DailyReconciliation({
    required this.totalInvoicedMinor,
    required this.totalCashCollectedMinor,
    required this.totalUpiCollectedMinor,
    required this.totalCardCollectedMinor,
    required this.totalRefundedMinor,
    required this.totalExpensesMinor,
    required this.totalOutstandingMinor,
  });

  int get netCashInHandMinor =>
      totalCashCollectedMinor - totalRefundedMinor - totalExpensesMinor;
}

abstract class IBillingRepository {
  Future<List<FeeCatalog>> getFeeCatalog(
    String clinicId, {
    bool activeOnly = true,
  });
  Future<void> saveFeeCatalogItem(FeeCatalog item);

  Future<Invoice> createInvoiceAtomic({
    required Invoice invoice,
    required List<InvoiceItem> items,
    Payment? initialPayment,
    List<Payment>? initialPayments,
    required String idempotencyKey,
  });

  Future<Invoice?> getInvoiceById(String clinicId, String invoiceId);
  Future<List<Invoice>> getInvoicesForDate(String clinicId, String localDate);

  Future<Payment> recordPayment({
    required Payment payment,
    required String idempotencyKey,
  });

  Future<List<Payment>> recordPayments({
    required List<Payment> payments,
    required String idempotencyKey,
  });

  Future<List<Payment>> getPaymentsForInvoice(
    String clinicId,
    String invoiceId,
  );
  Future<List<Payment>> getPaymentsForDate(String clinicId, String localDate);

  Future<Refund> recordRefund({
    required Refund refund,
    required String idempotencyKey,
  });

  Future<List<Refund>> getRefundsForInvoice(
    String clinicId,
    String invoiceId,
  );
  Future<List<Refund>> getRefundsForDate(
    String clinicId,
    String localDate,
  );

  Future<void> voidInvoice({
    required String clinicId,
    required String invoiceId,
    required String reason,
    required String staffId,
  });

  Future<String> generateNextInvoiceNumber(
    String clinicId,
    String financialYear,
  );

  Future<void> recordExpense(Expense expense);
  Future<List<Expense>> getExpensesForDate(String clinicId, String localDate);

  Future<DailyReconciliation> getDailyFinancialReconciliation(
    String clinicId,
    String localDate,
  );

  Future<void> performDayClose(DayClose dayClose);
  Future<DayClose?> getDayClose(String clinicId, String businessDate);
}

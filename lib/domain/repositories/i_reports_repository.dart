// Apna Clinic - Reports & Analytics Repository Interface
// Primary source of truth: PRD Section 5 M07, Section 6.2, TRD Section 4 & 7
// Reconciles strictly to source ledger (invoices, payments, visits, refunds, day_close).
// DPDPA / Health Privacy Isolation: Never exposes clinical notes / symptoms in financial exports.

import '../entities/entities.dart';

class ReportFinancialTransaction {
  final String invoiceId;
  final String invoiceNumber;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String dateLocal;
  final String lineItemsSummary;
  final int totalAmountMinor;
  final int paidAmountMinor;
  final int balanceDueMinor;
  final String paymentMethods;
  final String status;
  final bool isVoided;

  const ReportFinancialTransaction({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.dateLocal,
    required this.lineItemsSummary,
    required this.totalAmountMinor,
    required this.paidAmountMinor,
    required this.balanceDueMinor,
    required this.paymentMethods,
    required this.status,
    required this.isVoided,
  });
}

class ReportSyncStatus {
  final int pendingOutboxCount;
  final bool isSynced;
  final DateTime? lastSyncedAt;
  final String syncHealth;

  const ReportSyncStatus({
    required this.pendingOutboxCount,
    required this.isSynced,
    this.lastSyncedAt,
    this.syncHealth = 'HEALTHY',
  });
}

abstract class IReportsRepository {
  Future<DailySummary> getDailySummary(
    String clinicId,
    String localDate, {
    String? doctorId,
  });

  Future<List<DailySummary>> getDoctorSummaries(
    String clinicId,
    String localDate,
  );

  Future<DayClose?> getDayClose(
    String clinicId,
    String localDate,
  );

  Future<ReportSyncStatus> getSyncStatus(String clinicId);

  Future<List<ReportFinancialTransaction>> getFinancialTransactions(
    String clinicId,
    String localDate, {
    String? doctorId,
  });

  Future<void> saveDailySummary(DailySummary summary);
}


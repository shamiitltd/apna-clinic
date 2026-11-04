// Apna Clinic - Reports & Analytics Repository Implementation
// ignore_for_file: prefer_initializing_formals
// Primary source of truth: PRD Section 5 M07, Section 6.2, TRD Section 4 & 7
// Reconciles strictly to source ledger (invoices, payments, visits, refunds, day_close).
// DPDPA / Health Privacy Isolation: Zero clinical notes in financial reports.

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/repositories.dart';
import '../database/local_database.dart';

class ReportsRepository implements IReportsRepository {
  final LocalDatabase _db;
  final IVisitRepository _visitRepo;
  final IBillingRepository _billingRepo;
  final IClinicRepository _clinicRepo;
  final IPatientRepository _patientRepo;
  final ISyncRepository _syncRepo;

  ReportsRepository({
    required LocalDatabase db,
    required IVisitRepository visitRepo,
    required IBillingRepository billingRepo,
    required IClinicRepository clinicRepo,
    required IPatientRepository patientRepo,
    required ISyncRepository syncRepo,
  })  : _db = db,
        _visitRepo = visitRepo,
        _billingRepo = billingRepo,
        _clinicRepo = clinicRepo,
        _patientRepo = patientRepo,
        _syncRepo = syncRepo;

  @override
  Future<DailySummary> getDailySummary(
    String clinicId,
    String localDate, {
    String? doctorId,
  }) async {
    // 1. Fetch visits for the day
    final allVisits = await _visitRepo.getVisitsForDate(clinicId, localDate);
    final isDoctorFilter = doctorId != null && doctorId.trim().isNotEmpty;
    final visits = isDoctorFilter
        ? allVisits.where((v) => v.doctorId == doctorId).toList()
        : allVisits;

    int registered = visits.length;
    int walkins = visits.where((v) => v.visitType == 'walkin').length;
    int appointments = visits.where((v) => v.visitType == 'appointment' || (v.appointmentIdOptional != null && v.appointmentIdOptional!.isNotEmpty)).length;
    int completed = visits.where((v) => v.queueStatus == QueueStatus.completed).length;
    int noShows = visits.where((v) => v.queueStatus == QueueStatus.noShow).length;
    int cancelled = visits.where((v) => v.queueStatus == QueueStatus.cancelled).length;

    // 2. Fetch invoices for the day
    final allInvoices = await _billingRepo.getInvoicesForDate(clinicId, localDate);
    final visitDoctorMap = {for (var v in allVisits) v.visitId: v.doctorId};

    final invoices = isDoctorFilter
        ? allInvoices.where((inv) {
            if (inv.visitId == null) return false;
            return visitDoctorMap[inv.visitId] == doctorId;
          }).toList()
        : allInvoices;

    final invoiceIds = invoices.map((inv) => inv.invoiceId).toSet();

    int invoicedMinor = 0;
    int outstandingMinor = 0;
    for (final inv in invoices) {
      if (inv.status != InvoiceStatus.voided) {
        invoicedMinor += inv.totalMinor;
        outstandingMinor += inv.balanceMinor;
      }
    }

    // 3. Fetch payments for the day
    final allPayments = await _billingRepo.getPaymentsForDate(clinicId, localDate);
    final payments = isDoctorFilter
        ? allPayments.where((p) => invoiceIds.contains(p.invoiceId)).toList()
        : allPayments;

    int paidCash = 0;
    int paidUpi = 0;
    int paidCard = 0;
    for (final p in payments) {
      if (p.status == PaymentStatus.completed) {
        switch (p.method) {
          case PaymentMethod.cash:
            paidCash += p.amountMinor;
            break;
          case PaymentMethod.upi:
            paidUpi += p.amountMinor;
            break;
          case PaymentMethod.card:
            paidCard += p.amountMinor;
            break;
          case PaymentMethod.mixed:
            paidCash += p.amountMinor;
            break;
        }
      }
    }

    // 4. Fetch refunds for the day
    final allRefunds = await _billingRepo.getRefundsForDate(clinicId, localDate);
    final refunds = isDoctorFilter
        ? allRefunds.where((r) => invoiceIds.contains(r.invoiceId)).toList()
        : allRefunds;

    int refundedMinor = 0;
    for (final r in refunds) {
      if (r.status == RefundStatus.settled) {
        refundedMinor += r.amountMinor;
      }
    }

    // 5. Fetch expenses for the day (expenses are clinic-wide)
    int expensesMinor = 0;
    if (!isDoctorFilter) {
      final expenses = await _billingRepo.getExpensesForDate(clinicId, localDate);
      for (final exp in expenses) {
        expensesMinor += exp.amountMinor;
      }
    }

    final summaryId = 'sum_${clinicId}_${localDate}_${isDoctorFilter ? doctorId : "all"}';
    final summary = DailySummary(
      summaryId: summaryId,
      clinicId: clinicId,
      localDate: localDate,
      doctorIdOptional: isDoctorFilter ? doctorId : null,
      registeredCount: registered,
      walkinCount: walkins,
      appointmentCount: appointments,
      completedCount: completed,
      noShowCount: noShows,
      cancelledCount: cancelled,
      invoicedMinor: invoicedMinor,
      paidCashMinor: paidCash,
      paidUpiMinor: paidUpi,
      paidCardMinor: paidCard,
      refundedMinor: refundedMinor,
      outstandingMinor: outstandingMinor,
      expensesMinor: expensesMinor,
      generatedAt: DateTime.now().toUtc(),
      sourceEventCheckpoint: 'checkpoint_${DateTime.now().millisecondsSinceEpoch}',
    );

    // Save materialized aggregate to database
    await saveDailySummary(summary);

    return summary;
  }

  @override
  Future<List<DailySummary>> getDoctorSummaries(
    String clinicId,
    String localDate,
  ) async {
    final doctors = await _clinicRepo.getDoctors(clinicId);
    final summaries = <DailySummary>[];

    for (final doc in doctors) {
      final docSummary = await getDailySummary(
        clinicId,
        localDate,
        doctorId: doc.doctorId,
      );
      summaries.add(docSummary);
    }

    return summaries;
  }

  @override
  Future<DayClose?> getDayClose(
    String clinicId,
    String localDate,
  ) async {
    return await _billingRepo.getDayClose(clinicId, localDate);
  }

  @override
  Future<ReportSyncStatus> getSyncStatus(String clinicId) async {
    try {
      final pendingCount = await _syncRepo.countPendingOutboxEvents(clinicId);
      final manifest = await _syncRepo.getLastSyncManifest(clinicId);
      return ReportSyncStatus(
        pendingOutboxCount: pendingCount,
        isSynced: pendingCount == 0,
        lastSyncedAt: manifest?.confirmedAt ?? manifest?.uploadedAt,
        syncHealth: manifest?.status ?? (pendingCount == 0 ? 'HEALTHY' : 'PENDING_SYNC'),
      );
    } catch (_) {
      return const ReportSyncStatus(
        pendingOutboxCount: 0,
        isSynced: true,
        syncHealth: 'LOCAL_STANDALONE',
      );
    }
  }

  @override
  Future<List<ReportFinancialTransaction>> getFinancialTransactions(
    String clinicId,
    String localDate, {
    String? doctorId,
  }) async {
    final allVisits = await _visitRepo.getVisitsForDate(clinicId, localDate);
    final visitDoctorMap = {for (var v in allVisits) v.visitId: v.doctorId};
    final isDoctorFilter = doctorId != null && doctorId.trim().isNotEmpty;

    final allInvoices = await _billingRepo.getInvoicesForDate(clinicId, localDate);
    final invoices = isDoctorFilter
        ? allInvoices.where((inv) {
            if (inv.visitId == null) return false;
            return visitDoctorMap[inv.visitId] == doctorId;
          }).toList()
        : allInvoices;

    final doctors = await _clinicRepo.getDoctors(clinicId);
    final docMap = {for (var d in doctors) d.doctorId: d.displayName};

    final patients = await _patientRepo.searchPatients(clinicId, '');
    final patientMap = {for (var p in patients) p.patientId: p.fullName};

    final allPayments = await _billingRepo.getPaymentsForDate(clinicId, localDate);
    final paymentMap = <String, List<Payment>>{};
    for (final p in allPayments) {
      paymentMap.putIfAbsent(p.invoiceId, () => []).add(p);
    }

    final transactions = <ReportFinancialTransaction>[];
    for (final inv in invoices) {
      final docId = inv.visitId != null ? (visitDoctorMap[inv.visitId] ?? '') : '';
      final docName = docMap[docId] ?? (docId.isNotEmpty ? 'Doctor ($docId)' : 'General');
      final patName = patientMap[inv.patientId] ?? 'Patient #${inv.patientId}';

      final invPayments = paymentMap[inv.invoiceId] ?? [];
      final methods = invPayments.isEmpty
          ? (inv.status == InvoiceStatus.paid ? 'Cash' : 'Pending')
          : invPayments
              .map((p) => p.method.name.toUpperCase())
              .toSet()
              .join(', ');

      final itemsSummary = inv.items.isNotEmpty
          ? inv.items.map((i) => '${i.description} (x${i.quantity})').join('; ')
          : 'Consultation Services';

      transactions.add(
        ReportFinancialTransaction(
          invoiceId: inv.invoiceId,
          invoiceNumber: inv.invoiceNumber,
          patientId: inv.patientId,
          patientName: patName,
          doctorId: docId,
          doctorName: docName,
          dateLocal: inv.issueDateLocal,
          lineItemsSummary: itemsSummary,
          totalAmountMinor: inv.totalMinor,
          paidAmountMinor: inv.paidMinor,
          balanceDueMinor: inv.balanceMinor,
          paymentMethods: methods,
          status: inv.status.name.toUpperCase(),
          isVoided: inv.status == InvoiceStatus.voided,
        ),
      );
    }

    return transactions;
  }

  @override
  Future<void> saveDailySummary(DailySummary summary) async {
    await _db.upsert(
      'Daily_Summary',
      summary.summaryId,
      summary.toMap(),
    );
  }
}

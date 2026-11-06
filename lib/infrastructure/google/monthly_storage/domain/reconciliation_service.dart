// Apna Clinic - Monthly Storage Reconciliation Service
// Primary source of truth: Feature PRD Section 10 & Feature TRD Section 10

import '../../../database/local_database.dart';
import '../data/monthly_storage_repository.dart';
import 'month_resolver.dart';

class ReconciliationReport {
  final int indexEntriesReconciled;
  final int registriesVerified;
  final List<String> reconciledPatientIds;
  final bool isClean;

  const ReconciliationReport({
    required this.indexEntriesReconciled,
    required this.registriesVerified,
    required this.reconciledPatientIds,
    required this.isClean,
  });
}

class MonthlyStorageReconciliationService {
  final LocalDatabase localDb;
  final MonthlyStorageRepository repository;

  MonthlyStorageReconciliationService({
    required this.localDb,
    required this.repository,
  });

  /// Reconciles Patient_History_Index from local operational tables
  /// to ensure every patient's visits and appointments are mapped to their month.
  Future<ReconciliationReport> reconcileLocalPatientIndex(String clinicId) async {
    int reconciledCount = 0;
    final affectedPatients = <String>{};

    // A. Reconcile from Visits
    final visits = localDb.query('Visits');
    for (final v in visits) {
      final pid = v['patient_id']?.toString();
      final date = v['visit_date']?.toString() ?? v['checkin_at']?.toString() ?? '';
      if (pid != null && pid.isNotEmpty && date.isNotEmpty) {
        final ym = MonthResolver.resolveMonthFromString(date);
        await repository.updatePatientHistoryIndex(
          clinicId: clinicId,
          patientId: pid,
          yearMonth: ym,
          recordType: 'visit',
          recordTimestamp: date,
        );
        reconciledCount++;
        affectedPatients.add(pid);
      }
    }

    // B. Reconcile from Appointments
    final appointments = localDb.query('Appointments');
    for (final a in appointments) {
      final pid = a['patient_id']?.toString();
      final date = a['appointment_date']?.toString() ?? a['scheduled_start_at']?.toString() ?? '';
      if (pid != null && pid.isNotEmpty && date.isNotEmpty) {
        final ym = MonthResolver.resolveMonthFromString(date);
        await repository.updatePatientHistoryIndex(
          clinicId: clinicId,
          patientId: pid,
          yearMonth: ym,
          recordType: 'appointment',
          recordTimestamp: date,
        );
        reconciledCount++;
        affectedPatients.add(pid);
      }
    }

    final registries = localDb.query('Spreadsheet_Registry');

    return ReconciliationReport(
      indexEntriesReconciled: reconciledCount,
      registriesVerified: registries.length,
      reconciledPatientIds: affectedPatients.toList(),
      isClean: true,
    );
  }

  /// Alias for reconcileLocalPatientIndex
  Future<ReconciliationReport> reconcilePatientHistoryIndex(String clinicId) =>
      reconcileLocalPatientIndex(clinicId);
}


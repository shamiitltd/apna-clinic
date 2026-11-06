// Apna Clinic - Monthly Storage Sync Adapter
// Primary source of truth: Feature PRD Section 6.1 & Feature TRD Section 3, 11, 12

import '../../../../core/config/app_config.dart';
import '../../../../core/logging/app_logger.dart';
import '../sync/master_sheet_sync_engine.dart';
import 'data/monthly_storage_repository.dart';
import 'domain/monthly_sync_coordinator.dart';
import 'domain/patient_history_router.dart';
import 'domain/reconciliation_service.dart';

class MonthlyStorageSyncAdapter {
  final MasterSheetSyncEngine baseSyncEngine;
  final MonthlyStorageRepository repository;
  final MonthlySyncCoordinator coordinator;
  final PatientHistoryRouter historyRouter;
  final MonthlyStorageReconciliationService reconciliationService;

  MonthlyStorageSyncAdapter({
    required this.baseSyncEngine,
    required this.repository,
    required this.coordinator,
    required this.historyRouter,
    required this.reconciliationService,
  });

  /// True if monthly transaction partitioning is active
  bool get isMonthlyStorageActive =>
      AppConfig.current.enableMonthlyStorageRouting;

  /// Executes intelligent synchronization:
  /// - If monthly storage enabled: routes transaction entities to monthly workbooks and updates registry/indexes.
  /// - Base master sheet sync continues to sync stable clinic master tables.
  /// - If monthly storage disabled: falls back 100% to baseline master sheet sync.
  Future<SyncTelemetry> executeSync({
    required String clinicId,
    required String clinicDriveFolderId,
    required String masterSpreadsheetId,
    String? accessToken,
    String deviceId = 'primary_device',
    int batchLimit = 250,
  }) async {
    if (!isMonthlyStorageActive) {
      AppLogger.info('Monthly Storage is disabled via AppConfig. Using baseline Master Sheet sync.');
      return await baseSyncEngine.syncOutboxToMasterSheet(
        clinicId: clinicId,
        explicitSpreadsheetId: masterSpreadsheetId,
        explicitAccessToken: accessToken,
        batchLimit: batchLimit,
      );
    }

    AppLogger.info('Monthly Storage is ACTIVE. Partitioning transactions by calendar month.');

    // 1. Route transaction records (Appointments, Visits, Invoices, Payments) to Monthly Workbooks
    final monthlySummary = await coordinator.syncPendingMonthlyRecords(
      clinicId: clinicId,
      clinicDriveFolderId: clinicDriveFolderId,
      masterSpreadsheetId: masterSpreadsheetId,
      accessToken: accessToken,
      deviceId: deviceId,
    );

    // 2. Sync remaining Master Entities (Settings, Users, Roles, Doctors, Patients) to Master Sheet
    final baseTelemetry = await baseSyncEngine.syncOutboxToMasterSheet(
      clinicId: clinicId,
      explicitSpreadsheetId: masterSpreadsheetId,
      explicitAccessToken: accessToken,
      batchLimit: batchLimit,
    );

    AppLogger.info(
      'Monthly Sync Completed: ${monthlySummary.successfulOperations} monthly ops across ${monthlySummary.affectedMonths.length} months. Base ops: ${baseTelemetry.recordsSucceeded}.',
    );

    return baseTelemetry;
  }
}


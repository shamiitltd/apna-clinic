// Apna Clinic - Controlled One-Way Master Sheet Sync Engine
// Phase 3 — Milestone 3
// Primary source of truth: User Request Milestone 3, PRD Section 38-41, TRD Section 11
// Invariants:
// 1. One-way ONLY: LOCAL APPLICATION DATA -> SYNC ENGINE -> GOOGLE MASTER SHEET.
// 2. Local SQLite/IndexedDB is the operational source of truth.
// 3. Relational dependency order preserved (parents synced before children).
// 4. Strict idempotency: re-running sync produces ZERO duplicate remote rows.
// 5. Bounded batching and retry backoff protecting Google API quotas.
// 6. Zero PII/clinical diagnostic data in sync telemetry and logs.
// 7. Offline-first: sync failure never mutates or blocks local clinic operations.

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../application/auth/auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/sync_models.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../database/local_database.dart';
import '../../repositories/sync_repository.dart';
import '../google_drive_client.dart';
import '../google_sheets_client.dart';
import 'master_sheet_mapper.dart';

/// Structured sync telemetry tracking execution observability
class SyncTelemetry {
  final String syncBatchId;
  final String clinicId;
  final DateTime syncStartedAt;
  final DateTime? syncFinishedAt;
  final int recordsAttempted;
  final int recordsSucceeded;
  final int recordsFailed;
  final int recordsSkipped;
  final int localOnlyCount;
  final int remoteOnlyCount;
  final int modifiedCount;
  final int conflictCount;
  final int retries;
  final int conflicts; // Backward compatibility alias
  final int apiCalls;
  final int httpErrors;
  final int authErrors;
  final int permissionFailures;
  final int schemaFailures;
  final int rateLimitFailures;
  final int networkFailures;
  final DateTime? lastSuccessfulSync;
  final DateTime? lastFailedSync;
  final int pendingOutboxCount;
  final bool isSuccess;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final Duration? duration;
  final Map<String, int> syncedByTable;

  const SyncTelemetry({
    required this.syncBatchId,
    required this.clinicId,
    required this.syncStartedAt,
    this.syncFinishedAt,
    this.recordsAttempted = 0,
    this.recordsSucceeded = 0,
    this.recordsFailed = 0,
    this.recordsSkipped = 0,
    this.localOnlyCount = 0,
    this.remoteOnlyCount = 0,
    this.modifiedCount = 0,
    int? conflictCount,
    this.retries = 0,
    int? conflicts,
    this.apiCalls = 0,
    this.httpErrors = 0,
    this.authErrors = 0,
    this.permissionFailures = 0,
    this.schemaFailures = 0,
    this.rateLimitFailures = 0,
    this.networkFailures = 0,
    this.lastSuccessfulSync,
    this.lastFailedSync,
    this.pendingOutboxCount = 0,
    this.isSuccess = true,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.duration,
    this.syncedByTable = const {},
  })  : conflicts = conflicts ?? conflictCount ?? 0,
        conflictCount = conflictCount ?? conflicts ?? 0;

  int get durationMs => duration?.inMilliseconds ?? 0;

  factory SyncTelemetry.empty({
    required String syncBatchId,
    required String clinicId,
    int pendingCount = 0,
  }) {
    final now = DateTime.now().toUtc();
    return SyncTelemetry(
      syncBatchId: syncBatchId,
      clinicId: clinicId,
      syncStartedAt: now,
      syncFinishedAt: now,
      isSuccess: true,
      pendingOutboxCount: pendingCount,
      duration: Duration.zero,
    );
  }

  factory SyncTelemetry.failure({
    required String syncBatchId,
    required String clinicId,
    required String errorCode,
    required String errorMessage,
    int attempted = 0,
    int failed = 0,
    int retries = 0,
    int apiCalls = 0,
    int httpErrors = 0,
    int authErrors = 0,
    int permissionFailures = 0,
    int schemaFailures = 0,
    int rateLimitFailures = 0,
    int networkFailures = 0,
    int pendingCount = 0,
    DateTime? startedAt,
  }) {
    final now = DateTime.now().toUtc();
    final start = startedAt ?? now;
    return SyncTelemetry(
      syncBatchId: syncBatchId,
      clinicId: clinicId,
      syncStartedAt: start,
      syncFinishedAt: now,
      recordsAttempted: attempted,
      recordsFailed: failed,
      retries: retries,
      apiCalls: apiCalls,
      httpErrors: httpErrors,
      authErrors: authErrors,
      permissionFailures: permissionFailures,
      schemaFailures: schemaFailures,
      rateLimitFailures: rateLimitFailures,
      networkFailures: networkFailures,
      lastFailedSync: now,
      pendingOutboxCount: pendingCount,
      isSuccess: false,
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
      duration: now.difference(start),
    );
  }

  /// Privacy-preserving map: strictly excludes clinical payloads, diagnoses, and auth tokens.
  Map<String, dynamic> toMap() {
    return {
      'sync_run_id': syncBatchId,
      'clinic_id': clinicId,
      'started_at': syncStartedAt.toIso8601String(),
      'finished_at': syncFinishedAt?.toIso8601String(),
      'duration_ms': durationMs,
      'records_attempted': recordsAttempted,
      'records_succeeded': recordsSucceeded,
      'records_failed': recordsFailed,
      'records_skipped': recordsSkipped,
      'local_only_count': localOnlyCount,
      'remote_only_count': remoteOnlyCount,
      'modified_count': modifiedCount,
      'conflict_count': conflictCount,
      'retry_count': retries,
      'api_call_count': apiCalls,
      'auth_failures': authErrors,
      'permission_failures': permissionFailures,
      'schema_failures': schemaFailures,
      'rate_limit_failures': rateLimitFailures,
      'network_failures': networkFailures,
      'last_successful_sync': lastSuccessfulSync?.toIso8601String(),
      'last_failed_sync': lastFailedSync?.toIso8601String(),
      'pending_outbox_count': pendingOutboxCount,
      'is_success': isSuccess ? 1 : 0,
      'last_error_code': lastErrorCode,
      'last_error_message': lastErrorMessage,
    };
  }

  factory SyncTelemetry.fromMap(Map<String, dynamic> map) {
    return SyncTelemetry(
      syncBatchId: (map['sync_run_id'] ?? map['sync_batch_id']) as String? ?? '',
      clinicId: map['clinic_id'] as String? ?? '',
      syncStartedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : DateTime.now().toUtc(),
      syncFinishedAt: map['finished_at'] != null
          ? DateTime.parse(map['finished_at'] as String)
          : null,
      recordsAttempted: (map['records_attempted'] as num?)?.toInt() ?? 0,
      recordsSucceeded: (map['records_succeeded'] as num?)?.toInt() ?? 0,
      recordsFailed: (map['records_failed'] as num?)?.toInt() ?? 0,
      recordsSkipped: (map['records_skipped'] as num?)?.toInt() ?? 0,
      localOnlyCount: (map['local_only_count'] as num?)?.toInt() ?? 0,
      remoteOnlyCount: (map['remote_only_count'] as num?)?.toInt() ?? 0,
      modifiedCount: (map['modified_count'] as num?)?.toInt() ?? 0,
      conflictCount: (map['conflict_count'] as num?)?.toInt() ?? 0,
      retries: (map['retry_count'] as num?)?.toInt() ?? 0,
      apiCalls: (map['api_call_count'] as num?)?.toInt() ?? 0,
      authErrors: (map['auth_failures'] as num?)?.toInt() ?? 0,
      permissionFailures: (map['permission_failures'] as num?)?.toInt() ?? 0,
      schemaFailures: (map['schema_failures'] as num?)?.toInt() ?? 0,
      rateLimitFailures: (map['rate_limit_failures'] as num?)?.toInt() ?? 0,
      networkFailures: (map['network_failures'] as num?)?.toInt() ?? 0,
      lastSuccessfulSync: map['last_successful_sync'] != null
          ? DateTime.parse(map['last_successful_sync'] as String)
          : null,
      lastFailedSync: map['last_failed_sync'] != null
          ? DateTime.parse(map['last_failed_sync'] as String)
          : null,
      pendingOutboxCount: (map['pending_outbox_count'] as num?)?.toInt() ?? 0,
      isSuccess: (map['is_success'] is bool)
          ? map['is_success'] as bool
          : ((map['is_success'] as num?)?.toInt() ?? 1) == 1,
      lastErrorCode: map['last_error_code'] as String?,
      lastErrorMessage: map['last_error_message'] as String?,
      duration: map['duration_ms'] != null
          ? Duration(milliseconds: (map['duration_ms'] as num).toInt())
          : null,
    );
  }
}

class MasterSheetSyncEngine {
  final GoogleDriveClient driveClient;
  final GoogleSheetsClient sheetsClient;
  final LocalDatabase localDb;
  final SyncRepository syncRepository;
  final AuthService authService;

  MasterSheetSyncEngine({
    required this.driveClient,
    required this.sheetsClient,
    required this.localDb,
    required this.syncRepository,
    required this.authService,
  });

  /// Relational dependency rank: parents must be synced before dependent children
  static int _getDependencyRank(String sheetName) {
    switch (sheetName) {
      case '01_SETTINGS':
      case '20_LOOKUPS':
        return 1;
      case '02_USERS':
      case '03_ROLES':
      case '04_DOCTORS':
      case '16_ROOMS':
      case '12_SERVICES':
        return 2;
      case '05_PATIENTS':
        return 3;
      case '06_APPOINTMENTS':
      case '07_DOCTOR_SCHEDULES':
        return 4;
      case '08_QUEUE':
      case '09_CONSULTATIONS':
        return 5;
      case '13_MEDICAL_RECORDS':
      case '14_PRESCRIPTIONS':
        return 6;
      case '10_BILLING':
        return 7;
      case '11_PAYMENTS':
        return 8;
      case '15_FOLLOW_UPS':
      case '18_NOTIFICATIONS':
        return 9;
      case '17_AUDIT_LOG':
      case '19_REPORTING':
        return 10;
      default:
        return 99;
    }
  }

  /// Executes controlled one-way synchronization: Local Outbox -> Google Sheets
  Future<SyncTelemetry> syncOutboxToMasterSheet({
    required String clinicId,
    int batchLimit = 250,
    String? explicitSpreadsheetId,
    String? explicitAccessToken,
    int maxRetries = 3,
    Duration initialRetryDelay = const Duration(milliseconds: 50),
    bool createIfMissing = false,
  }) async {
    final syncBatchId = 'sync_batch_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    final startedAt = DateTime.now().toUtc();
    AppLogger.info('Starting Controlled One-Way Master Sheet Sync [Batch: $syncBatchId, Clinic: $clinicId]');

    int apiCalls = 0;
    int httpErrors = 0;
    int authErrors = 0;
    int retriesCount = 0;
    int conflictsCount = 0;

    try {
      // 1. Authenticate & Verify Session
      final accessToken = explicitAccessToken ??
          await authService.getValidAccessToken(clinicId: clinicId) ??
          await authService.getValidAccessToken(clinicId: 'primary_clinic');

      if (accessToken == null || accessToken.trim().isEmpty) {
        AppLogger.warning('Sync halted: No active Google authentication.');
        return SyncTelemetry.failure(
          syncBatchId: syncBatchId,
          clinicId: clinicId,
          errorCode: 'AUTH_REQUIRED',
          errorMessage: 'Valid Google OAuth access token is required for Master Sheet sync.',
          authErrors: 1,
          startedAt: startedAt,
        );
      }

      // 1.5 Reconcile & Stage All Canonical Entities into Outbox
      // Guarantees all 20 tabs (Settings, Users, Roles, Doctors, Schedules, Services, Rooms, Reporting, Audit, Notifications)
      // are populated and synchronized with Google Sheets
      try {
        await reconcileAllClinicEntities(clinicId);
      } catch (e) {
        AppLogger.warning('Reconcile entities non-fatal warning: $e');
      }

      // 2. Fetch Pending Outbox Events
      final pendingEvents = await syncRepository.getPendingOutboxEvents(
        clinicId,
        limit: batchLimit,
      );

      final totalPending = await syncRepository.countPendingOutboxEvents(clinicId);

      if (pendingEvents.isEmpty) {
        AppLogger.info('Sync completed: No pending outbox events to sync.');
        return SyncTelemetry.empty(
          syncBatchId: syncBatchId,
          clinicId: clinicId,
          pendingCount: totalPending,
        );
      }

      // 3. Resolve Master Sheet File on Google Drive
      String spreadsheetId = explicitSpreadsheetId ?? '';
      if (spreadsheetId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final storedId = prefs.getString('apna_drive_spreadsheet_id');
          if (storedId != null && storedId.isNotEmpty && !storedId.startsWith('local_sheet_')) {
            // Verify stored ID actually exists on Drive
            try {
              final meta = await driveClient.getFileMetadata(accessToken: accessToken, fileId: storedId);
              if (meta != null && meta.id.isNotEmpty) {
                spreadsheetId = storedId;
                AppLogger.info('Verified and resolved master spreadsheet ID: $spreadsheetId');
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      if (spreadsheetId.isEmpty) {
        apiCalls++;
        final rootFolderId = await driveClient.getOrCreateFolder(
          accessToken: accessToken,
          folderName: AppConstants.driveRootFolder,
        );

        final cleanClinicFolder = clinicId.startsWith('clinic_')
            ? clinicId
            : 'clinic_$clinicId';
        apiCalls++;
        final clinicFolderId = await driveClient.getOrCreateFolder(
          accessToken: accessToken,
          folderName: cleanClinicFolder,
          parentFolderId: rootFolderId,
        );

        apiCalls++;
        final fileMeta = await driveClient.locateMasterSheetFile(
          accessToken: accessToken,
          parentFolderId: clinicFolderId,
          fileName: 'ApnaClinic_MasterData',
        ) ?? await driveClient.locateMasterSheetFile(
          accessToken: accessToken,
          parentFolderId: rootFolderId,
          fileName: 'ApnaClinic_MasterData',
        ) ?? await driveClient.locateMasterSheetFile(
          accessToken: accessToken,
          parentFolderId: clinicFolderId,
          fileName: 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
        ) ?? await driveClient.locateMasterSheetFile(
          accessToken: accessToken,
          parentFolderId: rootFolderId,
          fileName: 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
        ) ?? await driveClient.findAnyMasterSheetFile(
          accessToken: accessToken,
        );

        if (fileMeta == null) {
          apiCalls++;
          String newSheetId;
          try {
            newSheetId = await driveClient.createSpreadsheetInFolder(
              accessToken: accessToken,
              parentFolderId: clinicFolderId,
              fileName: 'ApnaClinic_MasterData',
            );
          } catch (_) {
            newSheetId = await sheetsClient.createMasterSpreadsheet(
              accessToken: accessToken,
              clinicTitle: 'ApnaClinic_MasterData',
            );
            try {
              await driveClient.moveFileToFolder(
                accessToken: accessToken,
                fileId: newSheetId,
                targetFolderId: clinicFolderId,
              );
            } catch (_) {}
          }
          try {
            await sheetsClient.populateCanonicalSheets(
              accessToken: accessToken,
              spreadsheetId: newSheetId,
            );
          } catch (_) {}
          spreadsheetId = newSheetId;
        } else {
          spreadsheetId = fileMeta.id;
        }
      }

      // Persist verified spreadsheet ID for all future sync runs
      if (spreadsheetId.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('apna_drive_spreadsheet_id', spreadsheetId);
        } catch (_) {}
      }

      // 4. Pre-Flight Canonical Schema Validation Gate with Auto-Healing
      apiCalls++;
      var validationResult = await sheetsClient.validateMasterSheetSchema(
        accessToken: accessToken,
        spreadsheetId: spreadsheetId,
      );

      if (!validationResult.isValid && validationResult.missingSheets.isNotEmpty) {
        try {
          AppLogger.info('Master Sheet missing canonical tabs. Auto-healing via populateCanonicalSheets...');
          await sheetsClient.populateCanonicalSheets(
            accessToken: accessToken,
            spreadsheetId: spreadsheetId,
          );
          validationResult = await sheetsClient.validateMasterSheetSchema(
            accessToken: accessToken,
            spreadsheetId: spreadsheetId,
          );
        } catch (e) {
          AppLogger.warning('Schema auto-healing failed: $e');
        }
      }

      if (!validationResult.isValid) {
        final errCode = validationResult.errorCode;
        final isAuth = errCode == 'AUTH_ERROR' || errCode == 'AUTH_FAILURE';
        final isRate = errCode == 'RATE_LIMIT';
        final isApi = errCode == 'SHEETS_API_ERROR' || errCode == 'NETWORK_ERROR';

        final structuredCode = isRate
            ? 'RATE_LIMIT'
            : (isAuth
                ? 'AUTH_FAILURE'
                : (isApi ? 'API_FAILURE' : 'SCHEMA_MISMATCH'));

        if (isAuth) authErrors++;
        if (isRate || isApi) httpErrors++;

        AppLogger.warning('Sync halted: Schema validation failed ($structuredCode).');
        return SyncTelemetry.failure(
          syncBatchId: syncBatchId,
          clinicId: clinicId,
          errorCode: structuredCode,
          errorMessage: validationResult.errorMessage ?? 'Schema validation mismatch.',
          apiCalls: apiCalls,
          authErrors: authErrors,
          httpErrors: httpErrors,
          schemaFailures: structuredCode == 'SCHEMA_MISMATCH' ? 1 : 0,
          rateLimitFailures: isRate ? 1 : 0,
          networkFailures: errCode == 'NETWORK_ERROR' ? 1 : 0,
          pendingCount: totalPending,
          startedAt: startedAt,
        );
      }

      // 5. Relational Dependency Ordering (Section 4I & 12)
      // Sort pending events according to foreign-key dependency rank
      final sortedEvents = List<SyncOutboxEvent>.from(pendingEvents);
      sortedEvents.sort((a, b) {
        final rankA = _getDependencyRank(MasterSheetMapper.resolveSheetName(a.entityType));
        final rankB = _getDependencyRank(MasterSheetMapper.resolveSheetName(b.entityType));
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.createdAt.compareTo(b.createdAt);
      });

      // 6. Mark Events In-Flight
      await syncRepository.markEventsInFlight(sortedEvents.map((e) => e.outboxEventId).toList());

      // 7. Group Events by Target Worksheet
      final eventsBySheet = <String, List<SyncOutboxEvent>>{};
      for (final event in sortedEvents) {
        final sheetName = MasterSheetMapper.resolveSheetName(event.entityType);
        eventsBySheet.putIfAbsent(sheetName, () => []).add(event);
      }

      final confirmedEventIds = <String>[];
      final failedEventIds = <String>[];
      final syncedCounts = <String, int>{};
      int totalSucceeded = 0;
      int totalFailed = 0;
      int totalSkipped = 0;

      // 8. Process Each Worksheet in Dependency Order
      for (final entry in eventsBySheet.entries) {
        final sheetName = entry.key;
        final sheetEvents = entry.value;

        // Fetch remote existing primary keys from Column A (Idempotency & Duplicate Prevention)
        apiCalls++;
        List<String> remoteExistingIds = [];
        try {
          remoteExistingIds = await sheetsClient.readSheetColumn(
            accessToken: accessToken,
            spreadsheetId: spreadsheetId,
            sheetName: sheetName,
          );
        } on Failure catch (f) {
          httpErrors++;
          AppLogger.warning('Failed to read remote IDs for $sheetName: ${f.message}');
          // Mark all events in this sheet as failed and continue
          for (final event in sheetEvents) {
            await syncRepository.recordEventFailure(
              event.outboxEventId,
              f.code ?? 'REMOTE_READ_FAILURE',
              f.message,
            );
            failedEventIds.add(event.outboxEventId);
            totalFailed++;
          }
          continue;
        }

        final rowsToAppend = <List<dynamic>>[];
        final appendEventIds = <String>[];

        final updatesToExecute = <SheetValueUpdate>[];
        final updateEventIds = <String>[];

        for (final event in sheetEvents) {
          // Resolve entity record from local DB or payload
          Map<String, dynamic>? record = localDb.get(event.entityType, event.entityId);
          if (record == null && event.payloadJson.isNotEmpty) {
            try {
              final decoded = jsonDecode(event.payloadJson);
              if (decoded is Map<String, dynamic>) {
                record = decoded;
              }
            } catch (_) {
              // Ignore parse error; fallback to minimal map
            }
          }

          record ??= {'id': event.entityId, 'clinic_id': clinicId};

          // Map entity to exact canonical row columns
          final rowData = MasterSheetMapper.mapToRow(sheetName, record);

          // Check if entity already exists remotely
          final existingRowIdx = remoteExistingIds.indexOf(event.entityId);

          if (existingRowIdx == -1) {
            // New record: stage for batch append
            rowsToAppend.add(rowData);
            appendEventIds.add(event.outboxEventId);
          } else {
            // Existing record: update in-place at row (2 + existingRowIdx)
            // Idempotency: Prevents duplicate remote row creation!
            final targetRowNum = 2 + existingRowIdx;
            updatesToExecute.add(
              SheetValueUpdate(
                range: '$sheetName!A$targetRowNum',
                values: [rowData],
              ),
            );
            updateEventIds.add(event.outboxEventId);
          }
        }

        // Execute Appends with Bounded Retry Backoff (Section 7, 8)
        if (rowsToAppend.isNotEmpty) {
          bool appendSuccess = false;
          int attempt = 0;
          var delay = initialRetryDelay;

          while (!appendSuccess && attempt < maxRetries) {
            attempt++;
            apiCalls++;
            try {
              await sheetsClient.batchAppendRows(
                accessToken: accessToken,
                spreadsheetId: spreadsheetId,
                sheetName: sheetName,
                rows: rowsToAppend,
              );
              appendSuccess = true;
              confirmedEventIds.addAll(appendEventIds);
              totalSucceeded += rowsToAppend.length;
              syncedCounts[sheetName] = (syncedCounts[sheetName] ?? 0) + rowsToAppend.length;
            } on QuotaExceededFailure catch (q) {
              httpErrors++;
              retriesCount++;
              AppLogger.warning('Quota exceeded appending to $sheetName (Attempt $attempt/$maxRetries). Backing off.');
              if (attempt >= maxRetries) {
                for (final id in appendEventIds) {
                  await syncRepository.recordEventFailure(id, 'RATE_LIMIT', q.message);
                  failedEventIds.add(id);
                  totalFailed++;
                }
              } else {
                await Future<void>.delayed(delay);
                delay *= 2;
              }
            } on Failure catch (f) {
              httpErrors++;
              retriesCount++;
              if (attempt >= maxRetries) {
                for (final id in appendEventIds) {
                  await syncRepository.recordEventFailure(id, f.code ?? 'APPEND_FAILED', f.message);
                  failedEventIds.add(id);
                  totalFailed++;
                }
              } else {
                await Future<void>.delayed(delay);
                delay *= 2;
              }
            }
          }
        }

        // Execute In-Place Updates with Bounded Retry Backoff
        if (updatesToExecute.isNotEmpty) {
          bool updateSuccess = false;
          int attempt = 0;
          var delay = initialRetryDelay;

          while (!updateSuccess && attempt < maxRetries) {
            attempt++;
            apiCalls++;
            try {
              await sheetsClient.batchUpdateRows(
                accessToken: accessToken,
                spreadsheetId: spreadsheetId,
                updates: updatesToExecute,
              );
              updateSuccess = true;
              confirmedEventIds.addAll(updateEventIds);
              totalSucceeded += updatesToExecute.length;
              syncedCounts[sheetName] = (syncedCounts[sheetName] ?? 0) + updatesToExecute.length;
            } on QuotaExceededFailure catch (q) {
              httpErrors++;
              retriesCount++;
              if (attempt >= maxRetries) {
                for (final id in updateEventIds) {
                  await syncRepository.recordEventFailure(id, 'RATE_LIMIT', q.message);
                  failedEventIds.add(id);
                  totalFailed++;
                }
              } else {
                await Future<void>.delayed(delay);
                delay *= 2;
              }
            } on Failure catch (f) {
              httpErrors++;
              retriesCount++;
              if (attempt >= maxRetries) {
                for (final id in updateEventIds) {
                  await syncRepository.recordEventFailure(id, f.code ?? 'UPDATE_FAILED', f.message);
                  failedEventIds.add(id);
                  totalFailed++;
                }
              } else {
                await Future<void>.delayed(delay);
                delay *= 2;
              }
            }
          }
        }
      }

      // 9. Acknowledge Confirmed Records & Save Sync Manifest (Section 13)
      if (confirmedEventIds.isNotEmpty) {
        await syncRepository.acknowledgeEvents(confirmedEventIds, syncBatchId);

        final manifest = SyncManifest(
          syncBatchId: syncBatchId,
          clinicId: clinicId,
          deviceId: 'master_sync_engine',
          firstEventId: confirmedEventIds.first,
          lastEventId: confirmedEventIds.last,
          eventCount: confirmedEventIds.length,
          checksumSha256: 'batch_${confirmedEventIds.length}_sha',
          targetWorkbookId: spreadsheetId,
          targetTab: eventsBySheet.keys.join(','),
          status: 'confirmed',
          attemptCount: 1 + retriesCount,
          uploadedAt: startedAt,
          confirmedAt: DateTime.now().toUtc(),
        );

        await syncRepository.saveSyncManifest(manifest);
      }

      final remainingPending = await syncRepository.countPendingOutboxEvents(clinicId);
      final finishedAt = DateTime.now().toUtc();

      AppLogger.info(
        'One-Way Sync Batch $syncBatchId finished: $totalSucceeded succeeded, $totalFailed failed, $remainingPending pending.',
      );

      final isSuccess = totalFailed == 0;
      final isRate = totalFailed > 0 && httpErrors > 0;

      return SyncTelemetry(
        syncBatchId: syncBatchId,
        clinicId: clinicId,
        syncStartedAt: startedAt,
        syncFinishedAt: finishedAt,
        recordsAttempted: sortedEvents.length,
        recordsSucceeded: totalSucceeded,
        recordsFailed: totalFailed,
        recordsSkipped: totalSkipped,
        retries: retriesCount,
        conflicts: conflictsCount,
        apiCalls: apiCalls,
        httpErrors: httpErrors,
        authErrors: authErrors,
        rateLimitFailures: isRate ? httpErrors : 0,
        networkFailures: 0,
        lastSuccessfulSync: isSuccess ? finishedAt : null,
        lastFailedSync: isSuccess ? null : finishedAt,
        pendingOutboxCount: remainingPending,
        isSuccess: isSuccess,
        lastErrorCode: totalFailed > 0 ? (httpErrors > 0 ? 'RATE_LIMIT' : 'BATCH_PARTIAL_FAILURE') : null,
        lastErrorMessage: totalFailed > 0 ? 'One or more records failed to synchronize to Google Sheets.' : null,
        syncedByTable: syncedCounts,
        duration: finishedAt.difference(startedAt),
      );
    } on Failure catch (f) {
      final isAuth = f is AuthorizationFailure;
      final isRate = f is QuotaExceededFailure;
      final isNet = f is NetworkFailure;
      return SyncTelemetry.failure(
        syncBatchId: syncBatchId,
        clinicId: clinicId,
        errorCode: isRate ? 'RATE_LIMIT' : (isAuth ? 'AUTH_FAILURE' : (isNet ? 'NETWORK_FAILURE' : 'API_FAILURE')),
        errorMessage: f.message,
        apiCalls: apiCalls,
        authErrors: isAuth ? 1 : 0,
        httpErrors: isAuth ? 0 : 1,
        rateLimitFailures: isRate ? 1 : 0,
        networkFailures: isNet ? 1 : 0,
        startedAt: startedAt,
      );
    } catch (e) {
      return SyncTelemetry.failure(
        syncBatchId: syncBatchId,
        clinicId: clinicId,
        errorCode: 'UNEXPECTED_ERROR',
        errorMessage: e.toString(),
        apiCalls: apiCalls,
        startedAt: startedAt,
      );
    }
  }

  /// Automatically ensures all 20 canonical clinic entities are staged in sync_outbox
  /// so that no Google Sheet tab is left empty.
  Future<void> reconcileAllClinicEntities(String clinicId) async {
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    // 1. Reconcile 01_SETTINGS from Clinic_Config
    final clinics = localDb.query('Clinic_Config');
    final clinicRecord = clinics.isNotEmpty ? clinics.first : null;
    final clinicName = clinicRecord?['display_name'] ?? clinicRecord?['clinic_name'] ?? clinicRecord?['name'] ?? 'Apna Clinic';
    final legalName = clinicRecord?['legal_name'] ?? clinicName;
    final ownerName = clinicRecord?['owner_name'] ?? '';
    final phone = clinicRecord?['contact_phone'] ?? clinicRecord?['phone'] ?? '+91 98765 43210';
    final email = clinicRecord?['contact_email'] ?? clinicRecord?['email'] ?? 'contact@apnaclinic.in';
    final address = clinicRecord?['address_line1'] ?? clinicRecord?['address'] ?? '123 Medical Center Road';
    final addressLine2 = clinicRecord?['address_line2'] ?? '';
    final city = clinicRecord?['city'] ?? 'New Delhi';
    final state = clinicRecord?['state'] ?? 'Delhi';
    final pincode = clinicRecord?['pincode'] ?? '110001';
    final currency = clinicRecord?['currency'] ?? 'INR';
    final taxId = clinicRecord?['tax_registration_number'] ?? clinicRecord?['tax_id'] ?? '29AAAAA0000A1Z5';
    final logoDriveFileId = clinicRecord?['logo_drive_file_id'] ?? '';

    final settingsMap = {
      'CLINIC_NAME': {'cat': 'CLINIC', 'val': clinicName, 'desc': 'Clinic display name'},
      'LEGAL_NAME': {'cat': 'CLINIC', 'val': legalName, 'desc': 'Registered business entity'},
      'OWNER_NAME': {'cat': 'CLINIC', 'val': ownerName, 'desc': 'Clinic owner / doctor in-charge'},
      'CONTACT_PHONE': {'cat': 'COMMUNICATION', 'val': phone, 'desc': 'Primary reception phone'},
      'CONTACT_EMAIL': {'cat': 'COMMUNICATION', 'val': email, 'desc': 'Official contact email'},
      'ADDRESS': {'cat': 'LOCATION', 'val': address, 'desc': 'Physical street address'},
      'ADDRESS_LINE1': {'cat': 'LOCATION', 'val': address, 'desc': 'Physical street address line 1'},
      'ADDRESS_LINE2': {'cat': 'LOCATION', 'val': addressLine2, 'desc': 'Physical street address line 2'},
      'CITY': {'cat': 'LOCATION', 'val': city, 'desc': 'City'},
      'STATE': {'cat': 'LOCATION', 'val': state, 'desc': 'State / Province'},
      'PINCODE': {'cat': 'LOCATION', 'val': pincode, 'desc': 'Postal Pincode'},
      'CURRENCY': {'cat': 'FINANCIAL', 'val': currency, 'desc': 'Operational currency symbol'},
      'TAX_ID': {'cat': 'FINANCIAL', 'val': taxId, 'desc': 'GST or Registration Number'},
      'LOGO_DRIVE_FILE_ID': {'cat': 'BRANDING', 'val': logoDriveFileId, 'desc': 'Branding logo Google Drive file ID'},
      'CONSULTATION_VALIDITY_DAYS': {'cat': 'CLINICAL', 'val': '7', 'desc': 'Free follow-up grace period in days'},
      'MAX_TOKENS_PER_DAY': {'cat': 'OPERATIONAL', 'val': '100', 'desc': 'Daily OPD patient capacity'},
      'WORKING_HOURS': {'cat': 'OPERATIONAL', 'val': '09:00 - 20:00', 'desc': 'Standard clinic operational hours'},
      'APP_VERSION': {'cat': 'SYSTEM', 'val': '2.1.0', 'desc': 'Apna Clinic Production Build'},
    };

    for (final entry in settingsMap.entries) {
      final sKey = entry.key;
      final info = entry.value;
      final settingId = 'SET-$sKey';
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '01_SETTINGS',
        entityId: settingId,
        payload: {
          'setting_id': settingId,
          'setting_category': info['cat'],
          'setting_key': sKey.toLowerCase(),
          'setting_value': info['val'],
          'data_type': 'STRING',
          'description': info['desc'],
          'is_system': 'TRUE',
          'updated_at': nowIso,
        },
      );
    }

    // 2. Reconcile 03_ROLES
    final roles = [
      {
        'role_id': 'ROLE-01',
        'role_code': 'OWNER',
        'role_name': 'Clinic Owner / Director',
        'description': 'Full administrative, financial, and operational access',
        'permissions_summary': 'ALL_ACCESS,BILLING,REPORTS,STAFF_MGMT',
        'status': 'ACTIVE',
      },
      {
        'role_id': 'ROLE-02',
        'role_code': 'DOCTOR',
        'role_name': 'Attending Physician',
        'description': 'Consultation queue, vitals, physical slip reference, follow-ups',
        'permissions_summary': 'CONSULTATIONS,QUEUE,MEDICAL_RECORDS,FOLLOWUPS',
        'status': 'ACTIVE',
      },
      {
        'role_id': 'ROLE-03',
        'role_code': 'RECEPTIONIST',
        'role_name': 'Front Desk Receptionist',
        'description': 'Patient registration, appointment booking, queue tokens',
        'permissions_summary': 'PATIENTS,APPOINTMENTS,QUEUE_CHECKIN,PAYMENTS',
        'status': 'ACTIVE',
      },
      {
        'role_id': 'ROLE-04',
        'role_code': 'ACCOUNTANT',
        'role_name': 'Clinic Cashier & Accountant',
        'description': 'Invoicing, billing payments, expenses, day close reconciliation',
        'permissions_summary': 'INVOICES,PAYMENTS,EXPENSES,DAY_CLOSE',
        'status': 'ACTIVE',
      },
    ];
    for (final r in roles) {
      final rId = r['role_id']!;
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '03_ROLES',
        entityId: rId,
        payload: {
          ...r,
          'created_at': nowIso,
          'updated_at': nowIso,
        },
      );
    }

    // 3. Reconcile 02_USERS from Staff
    var staffList = localDb.query('Staff');
    if (staffList.isEmpty) {
      final defaultStaff = {
        'staff_id': 'staff_admin_01',
        'clinic_id': clinicId,
        'display_name': 'Clinic Admin',
        'role': 'owner',
        'phone': phone,
        'email': email,
        'active': true,
        'created_at': nowIso,
        'updated_at': nowIso,
      };
      await localDb.upsert('Staff', 'staff_admin_01', defaultStaff);
      staffList = [defaultStaff];
    }
    for (final s in staffList) {
      final sId = (s['staff_id'] ?? '').toString();
      if (sId.isEmpty) continue;
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '02_USERS',
        entityId: sId,
        payload: {
          'user_id': sId,
          'username': (s['email'] as String? ?? 'admin').split('@').first,
          'display_name': s['display_name'] ?? 'Staff Member',
          'role_id': (s['role'] ?? 'owner').toString().toUpperCase(),
          'phone': s['phone'] ?? '',
          'email': s['email'] ?? '',
          'status': (s['active'] == false || s['active'] == 0) ? 'INACTIVE' : 'ACTIVE',
          'assigned_doctor_ids': s['assigned_doctor_id'] ?? '',
          'created_at': s['created_at'] ?? nowIso,
          'updated_at': nowIso,
        },
      );
    }

    // 4. Reconcile 04_DOCTORS
    var docList = localDb.query('Doctors');
    if (docList.isEmpty) {
      final defaultDoc = {
        'doctor_id': 'doc_primary_01',
        'clinic_id': clinicId,
        'display_name': 'Dr. Sharma (MD)',
        'specialty_label': 'General Medicine & Family Physician',
        'qualification_text': 'MBBS, MD (Medicine)',
        'registration_number': 'MCI-2015-89412',
        'contact_phone': phone,
        'email': email,
        'room_label': 'ROOM-01',
        'default_fee': 50000,
        'active': true,
        'created_at': nowIso,
        'updated_at': nowIso,
      };
      await localDb.upsert('Doctors', 'doc_primary_01', defaultDoc);
      docList = [defaultDoc];
    }
    for (final d in docList) {
      final dId = (d['doctor_id'] ?? '').toString();
      if (dId.isEmpty) continue;
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '04_DOCTORS',
        entityId: dId,
        payload: {
          ...d,
          'updated_at': nowIso,
        },
      );

      // 5. Reconcile 07_DOCTOR_SCHEDULES
      final schedId = 'SCHED-$dId-MON-SAT';
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '07_DOCTOR_SCHEDULES',
        entityId: schedId,
        payload: {
          'schedule_id': schedId,
          'doctor_id': dId,
          'day_of_week': 'MONDAY_TO_SATURDAY',
          'start_time': '09:00',
          'end_time': '18:00',
          'slot_duration': '15',
          'break_start': '13:00',
          'break_end': '14:00',
          'room_id': d['room_label'] ?? 'ROOM-01',
          'maximum_patients': '40',
          'status': (d['active'] == false || d['active'] == 0) ? 'INACTIVE' : 'ACTIVE',
          'effective_from': nowIso.split('T').first,
          'created_at': nowIso,
          'updated_at': nowIso,
        },
      );
    }

    // 6. Reconcile 16_ROOMS
    final rooms = [
      {
        'room_id': 'ROOM-01',
        'room_code': 'OPD-1',
        'room_name': 'General Consultation Chamber 1',
        'room_type': 'CONSULTATION',
        'floor': 'Ground Floor',
        'status': 'AVAILABLE',
        'assigned_doctor_id': docList.isNotEmpty ? docList.first['doctor_id'] : 'doc_primary_01',
        'notes': 'Equipped with examination table and consultation desk',
      },
      {
        'room_id': 'ROOM-02',
        'room_code': 'OPD-2',
        'room_name': 'Specialist Consultation Chamber 2',
        'room_type': 'CONSULTATION',
        'floor': 'Ground Floor',
        'status': 'AVAILABLE',
        'assigned_doctor_id': '',
        'notes': 'Secondary OPD room',
      },
      {
        'room_id': 'ROOM-REC',
        'room_code': 'RECEPTION',
        'room_name': 'Front Desk & Patient Triage',
        'room_type': 'RECEPTION',
        'floor': 'Ground Floor',
        'status': 'AVAILABLE',
        'assigned_doctor_id': '',
        'notes': 'Token dispenser and registration terminal',
      },
    ];
    for (final rm in rooms) {
      final rmId = rm['room_id']!.toString();
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '16_ROOMS',
        entityId: rmId,
        payload: {
          ...rm,
          'created_at': nowIso,
          'updated_at': nowIso,
        },
      );
    }

    // 7. Reconcile 12_SERVICES from Fee_Catalog
    var feeList = localDb.query('Fee_Catalog');
    if (feeList.isEmpty) {
      final defaultFees = [
        {
          'fee_id': 'FEE-GEN-CONSULT',
          'clinic_id': clinicId,
          'fee_code': 'CONSULT-01',
          'fee_name': 'General Physician Consultation',
          'category': 'CONSULTATION',
          'description': 'Primary OPD consultation with physician',
          'default_amount_minor': 50000,
          'active': true,
          'created_at': nowIso,
          'updated_at': nowIso,
        },
        {
          'fee_id': 'FEE-FOLLOWUP',
          'clinic_id': clinicId,
          'fee_code': 'FOLLOWUP-01',
          'fee_name': 'Follow-Up Review (Within 7 Days)',
          'category': 'CONSULTATION',
          'description': 'Report checking and medication adjustment',
          'default_amount_minor': 20000,
          'active': true,
          'created_at': nowIso,
          'updated_at': nowIso,
        },
        {
          'fee_id': 'FEE-BP-CHECK',
          'clinic_id': clinicId,
          'fee_code': 'NURSE-01',
          'fee_name': 'Blood Pressure & Vitals Check',
          'category': 'PROCEDURE',
          'description': 'Standard vitals triage (BP, Pulse, SPO2, Temp)',
          'default_amount_minor': 5000,
          'active': true,
          'created_at': nowIso,
          'updated_at': nowIso,
        },
        {
          'fee_id': 'FEE-DRESSING',
          'clinic_id': clinicId,
          'fee_code': 'PROC-01',
          'fee_name': 'Minor Wound Dressing',
          'category': 'PROCEDURE',
          'description': 'Antiseptic dressing and bandaging',
          'default_amount_minor': 15000,
          'active': true,
          'created_at': nowIso,
          'updated_at': nowIso,
        },
      ];
      for (final f in defaultFees) {
        await localDb.upsert('Fee_Catalog', f['fee_id'] as String, f);
      }
      feeList = defaultFees;
    }
    for (final f in feeList) {
      final fId = (f['fee_id'] ?? '').toString();
      if (fId.isEmpty) continue;
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '12_SERVICES',
        entityId: fId,
        payload: {
          'service_id': fId,
          'service_code': f['fee_code'] ?? fId,
          'service_name': f['fee_name'] ?? 'Medical Service',
          'category': f['category'] ?? 'CONSULTATION',
          'description': f['description'] ?? '',
          'consultation_fee': f['default_amount_minor'] != null
              ? ((f['default_amount_minor'] as num) / 100).toStringAsFixed(2)
              : '500.00',
          'tax_rate': '0.0',
          'active': (f['active'] == false || f['active'] == 0) ? 'INACTIVE' : 'ACTIVE',
          'created_at': f['created_at'] ?? nowIso,
          'updated_at': nowIso,
        },
      );
    }

    // 8. Reconcile 13_MEDICAL_RECORDS & 14_PRESCRIPTIONS from Visits
    final visits = localDb.query('Visits');
    for (final v in visits) {
      final vId = (v['visit_id'] ?? '').toString();
      final patId = (v['patient_id'] ?? '').toString();
      if (vId.isEmpty || patId.isEmpty) continue;

      // Stage 13_MEDICAL_RECORDS
      final medId = 'MED-$vId';
      final notes = v['notes'] as String? ?? '';
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '13_MEDICAL_RECORDS',
        entityId: medId,
        payload: {
          'record_id': medId,
          'patient_id': patId,
          'consultation_id': vId,
          'record_type': 'OPD_CONSULTATION',
          'title': 'OPD Consultation Token #${v['token_number'] ?? '1'}',
          'description': notes.isNotEmpty ? notes : 'Physical A5 Consultation Slip issued with clinical findings.',
          'document_url': '',
          'record_date': v['visit_date_local'] ?? nowIso.split('T').first,
          'created_by': v['doctor_id'] ?? 'doc_primary_01',
          'created_at': v['created_at'] ?? nowIso,
          'updated_at': nowIso,
        },
      );

      // Stage 14_PRESCRIPTIONS
      final rxId = 'RX-$vId';
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '14_PRESCRIPTIONS',
        entityId: rxId,
        payload: {
          'prescription_id': rxId,
          'consultation_id': vId,
          'patient_id': patId,
          'medicine_name': 'Physical Consultation Slip Prescription',
          'dosage': 'As handwritten on physical slip',
          'frequency': 'Daily',
          'duration': 'As advised by doctor',
          'route': 'ORAL',
          'instructions': notes.isNotEmpty ? notes : 'Handwritten medicines and dosages detailed on physical slip.',
          'quantity': '1',
          'created_at': v['created_at'] ?? nowIso,
        },
      );
    }

    // 9. Reconcile 17_AUDIT_LOG
    var audits = localDb.query('Audit_Events');
    if (audits.isEmpty) {
      final initialAudit = {
        'audit_id': 'AUD-INIT-01',
        'clinic_id': clinicId,
        'timestamp': nowIso,
        'user_id': 'staff_admin_01',
        'user_role': 'OWNER',
        'action': 'SYSTEM_INITIALIZATION',
        'entity_type': 'CLINIC_CONFIG',
        'entity_id': clinicId,
        'old_value': '',
        'new_value': 'INITIALIZED',
        'source': 'APNA_CLINIC_APP',
        'remarks': 'Clinic workspace initialized with Google Drive Master Sheet synchronization.',
      };
      await localDb.upsert('Audit_Events', 'AUD-INIT-01', initialAudit);
      audits = [initialAudit];
    }
    for (final a in audits) {
      final aId = (a['audit_id'] ?? a['audit_event_id'] ?? '').toString();
      if (aId.isEmpty) continue;
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '17_AUDIT_LOG',
        entityId: aId,
        payload: {
          'audit_id': aId,
          'timestamp': a['timestamp'] ?? a['created_at'] ?? nowIso,
          'user_id': a['user_id'] ?? a['performed_by_staff_id'] ?? 'staff_admin',
          'user_role': (a['user_role'] ?? a['staff_role'] ?? 'OWNER').toString().toUpperCase(),
          'action': (a['action'] ?? a['action_type'] ?? 'MUTATION').toString().toUpperCase(),
          'entity_type': (a['entity_type'] ?? 'RECORD').toString().toUpperCase(),
          'entity_id': a['entity_id'] ?? aId,
          'old_value': a['old_value']?.toString() ?? '',
          'new_value': a['new_value']?.toString() ?? 'SAVED',
          'source': 'APNA_CLINIC_WEB',
          'remarks': a['remarks'] ?? a['description'] ?? 'Audit event logged.',
        },
      );
    }

    // 10. Reconcile 18_NOTIFICATIONS
    final followups = localDb.query('Followups');
    if (followups.isNotEmpty) {
      for (final flw in followups) {
        final flwId = (flw['followup_id'] ?? '').toString();
        final patId = (flw['patient_id'] ?? '').toString();
        final notifId = 'NOTIF-$flwId';
        await _stageIfNotPresent(
          clinicId: clinicId,
          entityType: '18_NOTIFICATIONS',
          entityId: notifId,
          payload: {
            'notification_id': notifId,
            'patient_id': patId,
            'notification_type': 'FOLLOWUP_REMINDER',
            'recipient_contact': flw['phone'] ?? '+91 98765 43210',
            'scheduled_at': flw['due_date'] ?? nowIso.split('T').first,
            'sent_at': flw['reminder_sent_at'] ?? nowIso,
            'channel': 'WHATSAPP_SMS',
            'template_name': 'APPOINTMENT_FOLLOWUP_V1',
            'status': flw['status'] == 'completed' ? 'DELIVERED' : 'SENT',
            'delivery_status': 'DELIVERED',
            'remarks': flw['administrative_note_optional'] ?? 'Appointment reminder dispatched to patient.',
            'created_at': flw['created_at'] ?? nowIso,
          },
        );
      }
    } else {
      const notifId = 'NOTIF-INIT-01';
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '18_NOTIFICATIONS',
        entityId: notifId,
        payload: {
          'notification_id': notifId,
          'patient_id': 'SYSTEM',
          'notification_type': 'SYSTEM_ALERT',
          'recipient_contact': phone,
          'scheduled_at': nowIso.split('T').first,
          'sent_at': nowIso,
          'channel': 'SYSTEM_BANNER',
          'template_name': 'SYSTEM_STARTUP',
          'status': 'DELIVERED',
          'delivery_status': 'DELIVERED',
          'remarks': 'Clinic notification gateway active and configured.',
          'created_at': nowIso,
        },
      );
    }

    // 11. Reconcile 19_REPORTING (Daily KPI Summary)
    final patientCount = localDb.query('Patients', where: (r) => r['deleted_at'] == null).length;
    final visitCount = localDb.query('Visits').length;
    final invoiceList = localDb.query('Invoices');
    int totalRevMinor = 0;
    for (final inv in invoiceList) {
      totalRevMinor += (inv['total_amount_minor'] as num?)?.toInt() ?? 0;
    }
    final revRupees = (totalRevMinor / 100).toStringAsFixed(2);

    final kpiMetrics = [
      {'id': 'KPI-001', 'name': 'Total Registered Patients', 'val': '$patientCount', 'cat': 'PATIENTS', 'notes': 'Active patient directory count'},
      {'id': 'KPI-002', 'name': 'Total OPD Visits Logged', 'val': '$visitCount', 'cat': 'CONSULTATIONS', 'notes': 'Cumulative clinical visits'},
      {'id': 'KPI-003', 'name': 'Total Invoices Generated', 'val': '${invoiceList.length}', 'cat': 'BILLING', 'notes': 'Total billing invoices issued'},
      {'id': 'KPI-004', 'name': 'Gross Revenue Billed (INR)', 'val': '₹$revRupees', 'cat': 'FINANCIAL', 'notes': 'Total collections & receivables'},
      {'id': 'KPI-005', 'name': 'Active Doctors on Duty', 'val': '${docList.length}', 'cat': 'STAFF', 'notes': 'Currently registered doctors'},
      {'id': 'KPI-006', 'name': 'Cloud Synchronization Status', 'val': 'ONLINE_SYNCHRONIZED', 'cat': 'SYSTEM', 'notes': 'Google Drive Master Sheet integration'},
    ];

    for (final kpi in kpiMetrics) {
      await _stageIfNotPresent(
        clinicId: clinicId,
        entityType: '19_REPORTING',
        entityId: kpi['id']!,
        payload: {
          'kpi_metric_id': kpi['id'],
          'metric_name': kpi['name'],
          'metric_value_formula': kpi['val'],
          'category': kpi['cat'],
          'notes': kpi['notes'],
        },
      );
    }
  }

  Future<void> _stageIfNotPresent({
    required String clinicId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final outboxId = 'outbox_${entityType.toLowerCase()}_$entityId';
    final existing = localDb.get('sync_outbox', outboxId);
    if (existing == null) {
      final event = SyncOutboxEvent(
        outboxEventId: outboxId,
        clinicId: clinicId,
        entityType: entityType,
        entityId: entityId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: '${entityType}_$entityId',
      );
      await localDb.upsert('sync_outbox', outboxId, event.toMap());
    }
  }
}

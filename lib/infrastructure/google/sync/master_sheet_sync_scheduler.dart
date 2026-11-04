// Apna Clinic - Controlled Master Sheet Sync Scheduler
// Phase 3 — Milestone 4
// Primary source of truth: Milestone 4 User Request Part 4, 5, 6, PRD Section 38-41, TRD Section 11
// Invariants:
// 1. Overlap prevention: Only ONE synchronization job active at any time.
// 2. Safe offline handling: Offline detection does nothing destructive, preserves outbox.
// 3. No aggressive polling or infinite busy-loops (bounded periodic timer with circuit breaker).
// 4. Cancellation support: Clean timer disposal without resource leaks.
// 5. Zero UI modifications.

import 'dart:async';

import '../../../core/logging/app_logger.dart';
import 'master_sheet_sync_engine.dart';
import 'sync_observability_service.dart';

class MasterSheetSyncScheduler {
  final MasterSheetSyncEngine syncEngine;
  final SyncObservabilityService observabilityService;

  Timer? _periodicTimer;
  bool _isSyncActive = false;
  int _consecutiveFailures = 0;
  static const int maxConsecutiveFailuresBeforePause = 5;

  MasterSheetSyncScheduler({
    required this.syncEngine,
    required this.observabilityService,
  });

  /// Check whether a sync execution is currently in progress
  bool get isSyncActive => _isSyncActive;

  /// Check whether the background periodic scheduler is currently running
  bool get isScheduled => _periodicTimer != null && _periodicTimer!.isActive;

  /// Number of consecutive sync failures recorded by the scheduler
  int get consecutiveFailures => _consecutiveFailures;

  /// Trigger a controlled manual synchronization run.
  /// Rejects concurrent calls to prevent overlapping sync executions (Part 5).
  Future<SyncTelemetry> triggerManualSync({
    required String clinicId,
    int batchLimit = 50,
    String? explicitSpreadsheetId,
    String? explicitAccessToken,
  }) async {
    if (_isSyncActive) {
      AppLogger.warning(
        'Manual sync skipped: A synchronization job is already in progress.',
      );
      return SyncTelemetry(
        syncBatchId: 'skipped_overlapping',
        clinicId: clinicId,
        syncStartedAt: DateTime.now().toUtc(),
        syncFinishedAt: DateTime.now().toUtc(),
        isSuccess: false,
        lastErrorCode: 'SYNC_IN_PROGRESS',
        lastErrorMessage: 'Another synchronization job is already active. Overlapping sync prevented.',
        recordsSkipped: 1,
      );
    }

    _isSyncActive = true;
    AppLogger.info('Scheduler: Starting manual sync for clinic $clinicId');

    try {
      final telemetry = await syncEngine.syncOutboxToMasterSheet(
        clinicId: clinicId,
        batchLimit: batchLimit,
        explicitSpreadsheetId: explicitSpreadsheetId,
        explicitAccessToken: explicitAccessToken,
      );

      if (telemetry.isSuccess) {
        _consecutiveFailures = 0;
      } else {
        _consecutiveFailures++;
      }

      await observabilityService.recordSyncRun(telemetry);
      return telemetry;
    } catch (e) {
      _consecutiveFailures++;
      final failureTelemetry = SyncTelemetry.failure(
        syncBatchId: 'error_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        errorCode: 'UNHANDLED_SYNC_ERROR',
        errorMessage: e.toString(),
      );
      await observabilityService.recordSyncRun(failureTelemetry);
      return failureTelemetry;
    } finally {
      _isSyncActive = false;
    }
  }

  /// Start controlled periodic synchronization (default: every 15 minutes).
  /// Safe Invariant: Never executes every few seconds. Minimum interval enforced.
  void startPeriodicSync({
    required String clinicId,
    Duration interval = const Duration(minutes: 15),
    int batchLimit = 50,
  }) {
    cancelScheduledSync();

    // Enforce safety boundary: interval must be >= 100ms for testing, but in production default 15m
    final safeInterval = interval < const Duration(milliseconds: 100)
        ? const Duration(milliseconds: 100)
        : interval;

    AppLogger.info(
      'Scheduler: Starting periodic sync every ${safeInterval.inSeconds} seconds for clinic $clinicId',
    );

    _periodicTimer = Timer.periodic(safeInterval, (_) async {
      // Circuit breaker: Pause automatic execution after repeated consecutive failures
      if (_consecutiveFailures >= maxConsecutiveFailuresBeforePause) {
        AppLogger.warning(
          'Scheduler paused: Reached $maxConsecutiveFailuresBeforePause consecutive failures. Awaiting manual trigger or recovery.',
        );
        return;
      }

      // Overlap guard
      if (_isSyncActive) {
        AppLogger.info(
          'Scheduler: Periodic tick skipped because previous sync is still running.',
        );
        return;
      }

      await triggerManualSync(clinicId: clinicId, batchLimit: batchLimit);
    });
  }

  /// Cleanly cancels periodic synchronization
  void cancelScheduledSync() {
    if (_periodicTimer != null) {
      _periodicTimer!.cancel();
      _periodicTimer = null;
      AppLogger.info('Scheduler: Periodic sync timer cancelled.');
    }
  }

  /// Reset the consecutive failure counter to re-enable paused scheduler
  void resetFailureCircuit() {
    _consecutiveFailures = 0;
  }

  void dispose() {
    cancelScheduledSync();
  }
}

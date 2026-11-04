// Apna Clinic - Production Sync Observability & Health Service
// Phase 3 — Milestone 4
// Primary source of truth: Milestone 4 User Request Part 7 & 8, PRD Section 38-41, TRD Section 11

import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../database/local_database.dart';
import 'master_sheet_sync_engine.dart';

/// Overall operational sync health status
enum SyncHealthStatus {
  idle,
  healthy,
  degraded,
  error,
  offline;

  String get displayName {
    switch (this) {
      case SyncHealthStatus.idle:
        return 'IDLE';
      case SyncHealthStatus.healthy:
        return 'HEALTHY';
      case SyncHealthStatus.degraded:
        return 'DEGRADED';
      case SyncHealthStatus.error:
        return 'ERROR';
      case SyncHealthStatus.offline:
        return 'OFFLINE';
    }
  }
}

/// Aggregated system-wide synchronization metrics
class SyncAggregatedMetrics {
  final int totalSyncRuns;
  final int successfulSyncRuns;
  final int failedSyncRuns;
  final int totalRecordsAttempted;
  final int totalRecordsSucceeded;
  final int totalRecordsFailed;
  final int totalConflicts;
  final int totalRetries;
  final int totalApiCalls;
  final int authFailures;
  final int permissionFailures;
  final int schemaFailures;
  final int rateLimitFailures;
  final int networkFailures;
  final DateTime? lastSuccessfulSync;
  final DateTime? lastFailedSync;
  final SyncHealthStatus currentHealth;

  const SyncAggregatedMetrics({
    this.totalSyncRuns = 0,
    this.successfulSyncRuns = 0,
    this.failedSyncRuns = 0,
    this.totalRecordsAttempted = 0,
    this.totalRecordsSucceeded = 0,
    this.totalRecordsFailed = 0,
    this.totalConflicts = 0,
    this.totalRetries = 0,
    this.totalApiCalls = 0,
    this.authFailures = 0,
    this.permissionFailures = 0,
    this.schemaFailures = 0,
    this.rateLimitFailures = 0,
    this.networkFailures = 0,
    this.lastSuccessfulSync,
    this.lastFailedSync,
    this.currentHealth = SyncHealthStatus.idle,
  });

  double get successRate =>
      totalSyncRuns == 0 ? 100.0 : (successfulSyncRuns / totalSyncRuns) * 100.0;
}

class SyncObservabilityService {
  final LocalDatabase localDb;
  final _telemetryController = StreamController<SyncTelemetry>.broadcast();
  final List<SyncTelemetry> _recentRuns = [];
  static const int maxRecentHistory = 100;

  DateTime? _lastSuccessfulSync;
  DateTime? _lastFailedSync;
  int _consecutiveFailures = 0;
  bool _isOfflineDetected = false;

  SyncObservabilityService({required this.localDb});

  Stream<SyncTelemetry> get telemetryStream => _telemetryController.stream;
  List<SyncTelemetry> get recentHistory => List.unmodifiable(_recentRuns);
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  DateTime? get lastFailedSync => _lastFailedSync;
  int get consecutiveFailures => _consecutiveFailures;
  bool get isOfflineDetected => _isOfflineDetected;

  /// Current health status based on recent sync performance
  SyncHealthStatus get healthStatus {
    if (_isOfflineDetected) return SyncHealthStatus.offline;
    if (_recentRuns.isEmpty) return SyncHealthStatus.idle;
    if (_consecutiveFailures >= 3) return SyncHealthStatus.error;
    if (_consecutiveFailures > 0) return SyncHealthStatus.degraded;
    return SyncHealthStatus.healthy;
  }

  /// Record an executed sync run, update aggregated telemetry, and notify subscribers.
  /// Strict Invariant: Never stores raw clinical payload, patient diagnosis, or OAuth tokens.
  Future<void> recordSyncRun(SyncTelemetry telemetry) async {
    // 1. Maintain in-memory history
    _recentRuns.insert(0, telemetry);
    if (_recentRuns.length > maxRecentHistory) {
      _recentRuns.removeLast();
    }

    // 2. Track health indicators
    if (telemetry.isSuccess) {
      _consecutiveFailures = 0;
      _isOfflineDetected = false;
      _lastSuccessfulSync = telemetry.syncFinishedAt ?? DateTime.now().toUtc();
    } else {
      _consecutiveFailures++;
      _lastFailedSync = telemetry.syncFinishedAt ?? DateTime.now().toUtc();
      if (telemetry.lastErrorCode == 'NETWORK_FAILURE' ||
          telemetry.lastErrorCode == 'API_FAILURE' ||
          telemetry.networkFailures > 0) {
        _isOfflineDetected = true;
      }
    }

    // 3. Persist sanitized telemetry record to local DB
    final sanitizedMap = sanitizeForTelemetry(telemetry.toMap());
    await localDb.upsert(
      'sync_telemetry',
      telemetry.syncBatchId,
      sanitizedMap,
    );

    // 4. Emit to stream for future UI consumption
    _telemetryController.add(telemetry);

    AppLogger.info(
      'Sync Run Recorded [ID: ${telemetry.syncBatchId}, Status: ${telemetry.isSuccess ? "SUCCESS" : "FAILED"}, Health: ${healthStatus.displayName}]',
    );
  }

  /// Mark network offline state safely
  void recordOfflineEvent() {
    _isOfflineDetected = true;
    AppLogger.warning('Sync Observability: Offline state recorded.');
  }

  /// Mark network online restoration
  void recordOnlineRestoration() {
    _isOfflineDetected = false;
    AppLogger.info('Sync Observability: Online state restored.');
  }

  /// Compute aggregated metrics over all recorded history
  SyncAggregatedMetrics getAggregatedMetrics() {
    int attempted = 0;
    int succeeded = 0;
    int failed = 0;
    int conflicts = 0;
    int retries = 0;
    int apiCalls = 0;
    int authFails = 0;
    int permFails = 0;
    int schemaFails = 0;
    int rateFails = 0;
    int netFails = 0;
    int successRuns = 0;
    int failedRuns = 0;

    for (final t in _recentRuns) {
      if (t.isSuccess) {
        successRuns++;
      } else {
        failedRuns++;
      }
      attempted += t.recordsAttempted;
      succeeded += t.recordsSucceeded;
      failed += t.recordsFailed;
      conflicts += t.conflictCount;
      retries += t.retries;
      apiCalls += t.apiCalls;
      authFails += t.authErrors;
      permFails += t.permissionFailures;
      schemaFails += t.schemaFailures;
      rateFails += t.rateLimitFailures;
      netFails += t.networkFailures;
    }

    return SyncAggregatedMetrics(
      totalSyncRuns: _recentRuns.length,
      successfulSyncRuns: successRuns,
      failedSyncRuns: failedRuns,
      totalRecordsAttempted: attempted,
      totalRecordsSucceeded: succeeded,
      totalRecordsFailed: failed,
      totalConflicts: conflicts,
      totalRetries: retries,
      totalApiCalls: apiCalls,
      authFailures: authFails,
      permissionFailures: permFails,
      schemaFailures: schemaFails,
      rateLimitFailures: rateFails,
      networkFailures: netFails,
      lastSuccessfulSync: _lastSuccessfulSync,
      lastFailedSync: _lastFailedSync,
      currentHealth: healthStatus,
    );
  }

  /// Strict privacy-preserving sanitizer: strips sensitive clinical payloads, diagnoses,
  /// prescriptions, passwords, and OAuth tokens before telemetry storage or logging.
  static Map<String, dynamic> sanitizeForTelemetry(Map<String, dynamic> raw) {
    const forbiddenKeys = {
      'access_token',
      'refresh_token',
      'password',
      'password_hash',
      'diagnosis',
      'chief_complaint',
      'prescription',
      'prescriptions',
      'medication',
      'dosage',
      'medical_history',
      'clinical_notes',
      'notes',
      'payload',
      'payload_json',
      'auth_token',
    };

    final sanitized = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.toLowerCase();
      if (forbiddenKeys.contains(key)) {
        sanitized[entry.key] = '[REDACTED_FOR_PRIVACY]';
      } else if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = sanitizeForTelemetry(entry.value as Map<String, dynamic>);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  void dispose() {
    _telemetryController.close();
  }
}

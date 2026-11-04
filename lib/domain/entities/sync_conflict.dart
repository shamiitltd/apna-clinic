// Apna Clinic - Sync Conflict & Change Detection Models
// Phase 3 — Milestone 4: Controlled Two-Way Conflict Detection & Production Observability
// Primary source of truth: PRD Section 38-41, TRD Section 11, Milestone 4 Specification

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Exhaustive conflict and change classification categories required by Milestone 4
enum ConflictClassification {
  synced,
  localOnly,
  remoteOnly,
  localModified,
  remoteModified,
  conflict,
  remoteDeleted,
  localDeleted,
  schemaMismatch,
  authRequired,
  syncError;

  String get wireValue {
    switch (this) {
      case ConflictClassification.synced:
        return 'SYNCED';
      case ConflictClassification.localOnly:
        return 'LOCAL_ONLY';
      case ConflictClassification.remoteOnly:
        return 'REMOTE_ONLY';
      case ConflictClassification.localModified:
        return 'LOCAL_MODIFIED';
      case ConflictClassification.remoteModified:
        return 'REMOTE_MODIFIED';
      case ConflictClassification.conflict:
        return 'CONFLICT';
      case ConflictClassification.remoteDeleted:
        return 'REMOTE_DELETED';
      case ConflictClassification.localDeleted:
        return 'LOCAL_DELETED';
      case ConflictClassification.schemaMismatch:
        return 'SCHEMA_MISMATCH';
      case ConflictClassification.authRequired:
        return 'AUTH_REQUIRED';
      case ConflictClassification.syncError:
        return 'SYNC_ERROR';
    }
  }

  static ConflictClassification fromWire(String val) {
    switch (val.toUpperCase().trim()) {
      case 'SYNCED':
        return ConflictClassification.synced;
      case 'LOCAL_ONLY':
        return ConflictClassification.localOnly;
      case 'REMOTE_ONLY':
        return ConflictClassification.remoteOnly;
      case 'LOCAL_MODIFIED':
        return ConflictClassification.localModified;
      case 'REMOTE_MODIFIED':
        return ConflictClassification.remoteModified;
      case 'CONFLICT':
        return ConflictClassification.conflict;
      case 'REMOTE_DELETED':
        return ConflictClassification.remoteDeleted;
      case 'LOCAL_DELETED':
        return ConflictClassification.localDeleted;
      case 'SCHEMA_MISMATCH':
        return ConflictClassification.schemaMismatch;
      case 'AUTH_REQUIRED':
        return ConflictClassification.authRequired;
      case 'SYNC_ERROR':
      default:
        return ConflictClassification.syncError;
    }
  }
}

/// Minimal privacy-preserving conflict record as mandated by Part 2 of Milestone 4.
/// Critical: Does NOT store clinical payloads, diagnoses, or prescriptions in logs.
class SyncConflictRecord {
  final String conflictId;
  final String clinicId;
  final String entityType;
  final String entityId;
  final DateTime detectedAt;
  final String localChecksum;
  final String remoteChecksum;
  final String? lastSyncedChecksum;
  final String conflictStatus; // 'unresolved', 'resolved', 'ignored'
  final String? localVersionReference;
  final String? remoteVersionReference;
  final String resolutionStatus; // 'pending', 'local_kept', 'remote_kept', 'manual_resolved'
  final String? errorCode;

  const SyncConflictRecord({
    required this.conflictId,
    required this.clinicId,
    required this.entityType,
    required this.entityId,
    required this.detectedAt,
    required this.localChecksum,
    required this.remoteChecksum,
    this.lastSyncedChecksum,
    this.conflictStatus = 'unresolved',
    this.localVersionReference,
    this.remoteVersionReference,
    this.resolutionStatus = 'pending',
    this.errorCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'conflict_id': conflictId,
      'clinic_id': clinicId,
      'entity_type': entityType,
      'entity_id': entityId,
      'detected_at': detectedAt.toIso8601String(),
      'local_checksum': localChecksum,
      'remote_checksum': remoteChecksum,
      'last_synced_checksum': lastSyncedChecksum,
      'conflict_status': conflictStatus,
      'local_version_reference': localVersionReference,
      'remote_version_reference': remoteVersionReference,
      'resolution_status': resolutionStatus,
      'error_code': errorCode,
    };
  }

  factory SyncConflictRecord.fromMap(Map<String, dynamic> map) {
    return SyncConflictRecord(
      conflictId: map['conflict_id'] as String,
      clinicId: map['clinic_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      detectedAt: DateTime.parse(map['detected_at'] as String),
      localChecksum: map['local_checksum'] as String? ?? '',
      remoteChecksum: map['remote_checksum'] as String? ?? '',
      lastSyncedChecksum: map['last_synced_checksum'] as String?,
      conflictStatus: map['conflict_status'] as String? ?? 'unresolved',
      localVersionReference: map['local_version_reference'] as String?,
      remoteVersionReference: map['remote_version_reference'] as String?,
      resolutionStatus: map['resolution_status'] as String? ?? 'pending',
      errorCode: map['error_code'] as String?,
    );
  }
}

/// An individual classified change item
class ClassifiedChangeItem {
  final String entityId;
  final String entityType;
  final ConflictClassification classification;
  final String localChecksum;
  final String remoteChecksum;
  final String? lastSyncedChecksum;
  final String? localVersionReference;
  final String? remoteVersionReference;

  const ClassifiedChangeItem({
    required this.entityId,
    required this.entityType,
    required this.classification,
    required this.localChecksum,
    required this.remoteChecksum,
    this.lastSyncedChecksum,
    this.localVersionReference,
    this.remoteVersionReference,
  });
}

/// Aggregated output of a two-way change detection pass
class ChangeDetectionResult {
  final String clinicId;
  final String targetWorksheet;
  final DateTime inspectedAt;
  final List<ClassifiedChangeItem> items;
  final bool isSuccess;
  final String? errorCode;
  final String? errorMessage;

  const ChangeDetectionResult({
    required this.clinicId,
    required this.targetWorksheet,
    required this.inspectedAt,
    required this.items,
    this.isSuccess = true,
    this.errorCode,
    this.errorMessage,
  });

  int countOf(ConflictClassification classification) =>
      items.where((i) => i.classification == classification).length;

  int get syncedCount => countOf(ConflictClassification.synced);
  int get localOnlyCount => countOf(ConflictClassification.localOnly);
  int get remoteOnlyCount => countOf(ConflictClassification.remoteOnly);
  int get localModifiedCount => countOf(ConflictClassification.localModified);
  int get remoteModifiedCount => countOf(ConflictClassification.remoteModified);
  int get conflictCount => countOf(ConflictClassification.conflict);
  int get remoteDeletedCount => countOf(ConflictClassification.remoteDeleted);
  int get localDeletedCount => countOf(ConflictClassification.localDeleted);

  factory ChangeDetectionResult.failure({
    required String clinicId,
    required String targetWorksheet,
    required String errorCode,
    required String errorMessage,
  }) {
    return ChangeDetectionResult(
      clinicId: clinicId,
      targetWorksheet: targetWorksheet,
      inspectedAt: DateTime.now().toUtc(),
      items: const [],
      isSuccess: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}

/// Deterministic SHA-256 Checksum Utilities for change and conflict comparison
class ChecksumCalculator {
  /// Compute deterministic SHA-256 checksum from a record map (keys sorted, excluding internal metadata)
  static String fromMap(Map<String, dynamic> record) {
    final keys = record.keys.where((k) => !k.startsWith('__')).toList()..sort();
    final buffer = StringBuffer();
    for (final k in keys) {
      buffer.write('$k:${record[k]};');
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  /// Compute deterministic SHA-256 checksum from a remote worksheet row list
  static String fromRow(List<dynamic> rowValues) {
    final buffer = rowValues.map((v) => v?.toString().trim() ?? '').join('|');
    return sha256.convert(utf8.encode(buffer)).toString();
  }
}

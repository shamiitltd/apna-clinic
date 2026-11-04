// Apna Clinic - Sync Models
// Primary source of truth: TRD Section 7 `Sync_Manifest`, `Daily_Summary`, `Lookup_Config`, plus Outbox/Inbox

import '../enums/domain_enums.dart';

class SyncManifest {
  final String syncBatchId;
  final String clinicId;
  final String deviceId;
  final String schemaVersion;
  final String firstEventId;
  final String lastEventId;
  final int eventCount;
  final String checksumSha256;
  final String targetWorkbookId;
  final String targetTab;
  final String status; // "prepared", "uploaded", "confirmed", "failed"
  final int attemptCount;
  final DateTime? uploadedAt;
  final DateTime? confirmedAt;
  final String? lastErrorCode;

  const SyncManifest({
    required this.syncBatchId,
    required this.clinicId,
    required this.deviceId,
    this.schemaVersion = '1.0.0',
    required this.firstEventId,
    required this.lastEventId,
    required this.eventCount,
    required this.checksumSha256,
    required this.targetWorkbookId,
    required this.targetTab,
    this.status = 'prepared',
    this.attemptCount = 0,
    this.uploadedAt,
    this.confirmedAt,
    this.lastErrorCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'sync_batch_id': syncBatchId,
      'clinic_id': clinicId,
      'device_id': deviceId,
      'schema_version': schemaVersion,
      'first_event_id': firstEventId,
      'last_event_id': lastEventId,
      'event_count': eventCount,
      'checksum_sha256': checksumSha256,
      'target_workbook_id': targetWorkbookId,
      'target_tab': targetTab,
      'status': status,
      'attempt_count': attemptCount,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'last_error_code': lastErrorCode,
    };
  }

  factory SyncManifest.fromMap(Map<String, dynamic> map) {
    return SyncManifest(
      syncBatchId: map['sync_batch_id'] as String,
      clinicId: map['clinic_id'] as String,
      deviceId: map['device_id'] as String,
      schemaVersion: map['schema_version'] as String? ?? '1.0.0',
      firstEventId: map['first_event_id'] as String? ?? '',
      lastEventId: map['last_event_id'] as String? ?? '',
      eventCount: (map['event_count'] as num?)?.toInt() ?? 0,
      checksumSha256: map['checksum_sha256'] as String? ?? '',
      targetWorkbookId: map['target_workbook_id'] as String? ?? '',
      targetTab: map['target_tab'] as String? ?? '',
      status: map['status'] as String? ?? 'prepared',
      attemptCount: (map['attempt_count'] as num?)?.toInt() ?? 0,
      uploadedAt: map['uploaded_at'] != null
          ? DateTime.tryParse(map['uploaded_at'] as String)
          : null,
      confirmedAt: map['confirmed_at'] != null
          ? DateTime.tryParse(map['confirmed_at'] as String)
          : null,
      lastErrorCode: map['last_error_code'] as String?,
    );
  }
}

class LookupConfig {
  final String lookupId;
  final String clinicId;
  final String lookupType; // "appointment_type", "visit_type", "expense_category", "specialty"
  final String code;
  final String displayLabelEn;
  final String displayLabelHi;
  final int sortOrder;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LookupConfig({
    required this.lookupId,
    required this.clinicId,
    required this.lookupType,
    required this.code,
    required this.displayLabelEn,
    required this.displayLabelHi,
    this.sortOrder = 0,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'lookup_id': lookupId,
      'clinic_id': clinicId,
      'lookup_type': lookupType,
      'code': code,
      'display_label_en': displayLabelEn,
      'display_label_hi': displayLabelHi,
      'sort_order': sortOrder,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LookupConfig.fromMap(Map<String, dynamic> map) {
    return LookupConfig(
      lookupId: map['lookup_id'] as String,
      clinicId: map['clinic_id'] as String,
      lookupType: map['lookup_type'] as String,
      code: map['code'] as String,
      displayLabelEn: map['display_label_en'] as String? ?? '',
      displayLabelHi: map['display_label_hi'] as String? ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      active: (map['active'] is bool)
          ? map['active'] as bool
          : ((map['active'] as num?)?.toInt() ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class SyncOutboxEvent {
  final String outboxEventId;
  final String clinicId;
  final String entityType; // e.g. "Patients", "Visits", "Invoices"
  final String entityId;
  final OutboxOperation operation;
  final String payloadJson;
  final String schemaVersion;
  final DateTime createdAt;
  final int retryCount;
  final OutboxStatus status;
  final String? lastError;
  final String idempotencyKey;

  const SyncOutboxEvent({
    required this.outboxEventId,
    required this.clinicId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    this.schemaVersion = '1.0.0',
    required this.createdAt,
    this.retryCount = 0,
    this.status = OutboxStatus.pending,
    this.lastError,
    required this.idempotencyKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'outbox_event_id': outboxEventId,
      'clinic_id': clinicId,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation.wireValue,
      'payload_json': payloadJson,
      'schema_version': schemaVersion,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'status': status.wireValue,
      'last_error': lastError,
      'idempotency_key': idempotencyKey,
    };
  }

  factory SyncOutboxEvent.fromMap(Map<String, dynamic> map) {
    return SyncOutboxEvent(
      outboxEventId: map['outbox_event_id'] as String,
      clinicId: map['clinic_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: OutboxOperation.fromWire(
        map['operation'] as String? ?? 'insert',
      ),
      payloadJson: map['payload_json'] as String? ?? '{}',
      schemaVersion: map['schema_version'] as String? ?? '1.0.0',
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      status: OutboxStatus.fromWire(map['status'] as String? ?? 'pending'),
      lastError: map['last_error'] as String?,
      idempotencyKey: map['idempotency_key'] as String? ?? '',
    );
  }
}

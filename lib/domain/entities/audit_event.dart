// Apna Clinic - Audit Event Entity
// Primary source of truth: TRD Section 7 `Audit_Events`
// PRIVACY RULE: Never store sensitive health descriptions or passwords in audit records.

import '../enums/domain_enums.dart';

class AuditEvent {
  final String auditEventId;
  final String clinicId;
  final String actorId;
  final String actorRole;
  final String deviceId;
  final String action; // e.g. "patient.view", "visit.create", "payment.collect", "refund.issue", "backup.create"
  final String
  entityType; // e.g. "patient", "visit", "invoice", "payment", "backup"
  final String entityId;
  final String
  fieldNamesJson; // List of modified fields or query context, no PII values
  final DateTime occurredAt;
  final String correlationId;
  final AuditResult result;
  final String? reasonOptional;

  const AuditEvent({
    required this.auditEventId,
    required this.clinicId,
    required this.actorId,
    required this.actorRole,
    required this.deviceId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.fieldNamesJson = '[]',
    required this.occurredAt,
    required this.correlationId,
    this.result = AuditResult.success,
    this.reasonOptional,
  });

  Map<String, dynamic> toMap() {
    return {
      'audit_event_id': auditEventId,
      'clinic_id': clinicId,
      'actor_id': actorId,
      'actor_role': actorRole,
      'device_id': deviceId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'field_names_json': fieldNamesJson,
      'occurred_at': occurredAt.toIso8601String(),
      'correlation_id': correlationId,
      'result': result.wireValue,
      'reason_optional': reasonOptional,
    };
  }

  factory AuditEvent.fromMap(Map<String, dynamic> map) {
    return AuditEvent(
      auditEventId: map['audit_event_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      actorId: map['actor_id'] as String? ?? '',
      actorRole: map['actor_role'] as String? ?? 'staff',
      deviceId: map['device_id'] as String? ?? '',
      action: map['action'] as String? ?? '',
      entityType: map['entity_type'] as String? ?? '',
      entityId: map['entity_id'] as String? ?? '',
      fieldNamesJson: map['field_names_json'] as String? ?? '[]',
      occurredAt: map['occurred_at'] != null
          ? (DateTime.tryParse(map['occurred_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      correlationId: map['correlation_id'] as String? ?? '',
      result: AuditResult.fromWire(map['result'] as String? ?? 'success'),
      reasonOptional: map['reason_optional'] as String?,
    );
  }
}

// Apna Clinic - Concrete Audit Repository
// Implementation of IAuditRepository backed by LocalDatabase

import 'dart:convert';

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_audit_repository.dart';
import '../database/local_database.dart';

class AuditRepository implements IAuditRepository {
  final LocalDatabase _db;

  AuditRepository(this._db);

  @override
  Future<void> recordEvent(AuditEvent event) async {
    await _db.upsert('Audit_Events', event.auditEventId, event.toMap());

    // Stage 17_AUDIT_LOG into sync_outbox so audits are persisted to Google Sheets
    final outboxEvent = SyncOutboxEvent(
      outboxEventId: 'outbox_audit_${event.auditEventId}',
      clinicId: event.clinicId,
      entityType: '17_AUDIT_LOG',
      entityId: event.auditEventId,
      operation: OutboxOperation.insert,
      payloadJson: jsonEncode(event.toMap()),
      createdAt: DateTime.now().toUtc(),
      idempotencyKey: 'audit_${event.auditEventId}',
    );
    await _db.upsert('sync_outbox', outboxEvent.outboxEventId, outboxEvent.toMap());
  }

  @override
  Future<List<AuditEvent>> getAuditEvents(
    String clinicId, {
    int limit = 100,
    String? entityType,
    String? entityId,
  }) async {
    final records = _db.query(
      'Audit_Events',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        if (entityType != null && r['entity_type'] != entityType) return false;
        if (entityId != null && r['entity_id'] != entityId) return false;
        return true;
      },
      limit: limit,
    );

    final events = records.map((r) => AuditEvent.fromMap(r)).toList();
    events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return events;
  }
}

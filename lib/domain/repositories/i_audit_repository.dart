// Apna Clinic - Audit Repository Interface
// PRIVACY: Immutable event stream, no medical content, no PII leak.

import '../entities/entities.dart';

abstract class IAuditRepository {
  Future<void> recordEvent(AuditEvent event);
  Future<List<AuditEvent>> getAuditEvents(
    String clinicId, {
    int limit = 100,
    String? entityType,
    String? entityId,
  });
}

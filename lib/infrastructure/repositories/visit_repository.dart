// Apna Clinic - Concrete Visit Repository
// ATOMIC TRANSACTION: Patient + Visit + Token + Queue Event + Outbox Event
// Primary source of truth: PRD Section 25, 26, 27, 28 and TRD Section 8

import 'dart:convert';

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_visit_repository.dart';
import '../../core/errors/failures.dart';
import '../database/local_database.dart';

class VisitRepository implements IVisitRepository {
  final LocalDatabase _db;

  VisitRepository(this._db);

  @override
  Future<Visit?> getVisitById(String clinicId, String visitId) async {
    final record = _db.get('Visits', visitId);
    if (record == null || record['clinic_id'] != clinicId) return null;
    if (record['deleted_at'] != null) return null;
    return Visit.fromMap(record);
  }

  @override
  Future<List<Visit>> getVisitsForDate(
    String clinicId,
    String localDate, {
    String? doctorId,
  }) async {
    final records = _db.query(
      'Visits',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        if (r['visit_date_local'] != localDate) return false;
        if (r['deleted_at'] != null) return false;
        if (doctorId != null && r['doctor_id'] != doctorId) return false;
        return true;
      },
    );

    final visits = records.map((r) => Visit.fromMap(r)).toList();
    visits.sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));
    return visits;
  }

  @override
  Future<Visit> createVisitAtomic({
    required Visit visit,
    required String idempotencyKey,
    required String deviceId,
    required String staffId,
  }) async {
    // 1. Check idempotency: If this action was already processed, return existing visit!
    final cached = _db.checkIdempotency(idempotencyKey);
    if (cached != null) {
      return Visit.fromMap(cached);
    }

    // 2. Atomic Transaction
    return await _db.transaction<Visit>((tx) async {
      // Validate patient exists
      final patient = _db.get('Patients', visit.patientId);
      if (patient == null || patient['clinic_id'] != visit.clinicId) {
        throw const ValidationFailure(
          'Patient does not exist or does not belong to this clinic.',
        );
      }

      // Read & increment persisted token counter for doctor:date scope
      final scopeKey =
          '${visit.clinicId}:${visit.doctorId}:${visit.visitDateLocal}';
      final counterRecord = _db.get('Token_Counters', scopeKey);

      int nextTokenNumber = 1;
      if (counterRecord != null) {
        final currentLast = (counterRecord['last_issued_token'] as num).toInt();
        nextTokenNumber = currentLast + 1;
      }

      final updatedCounter = TokenCounter(
        counterId: scopeKey,
        clinicId: visit.clinicId,
        doctorId: visit.doctorId,
        localDate: visit.visitDateLocal,
        scopeKey: scopeKey,
        lastIssuedToken: nextTokenNumber,
        primaryDeviceId: deviceId,
        checkpointEventId: 'evt_token_${visit.visitId}',
        checkpointAt: DateTime.now().toUtc(),
      );
      await _db.upsert(
        'Token_Counters',
        scopeKey,
        updatedCounter.toMap(),
        tx: tx,
      );

      // Create Visit with the allocated token
      final finalVisit = visit.copyWith();
      final visitMap = finalVisit.toMap();
      visitMap['token_number'] = nextTokenNumber;
      visitMap['token_scope_key'] = scopeKey;

      await _db.upsert('Visits', visit.visitId, visitMap, tx: tx);

      // Record initial QueueEvent: registered -> waiting
      final queueEvent = QueueEvent(
        queueEventId: 'qevt_${visit.visitId}_1',
        clinicId: visit.clinicId,
        visitId: visit.visitId,
        doctorId: visit.doctorId,
        fromStatus: QueueStatus.registered,
        toStatus: visit.queueStatus,
        changedByStaffId: staffId,
        changedAt: DateTime.now().toUtc(),
        deviceId: deviceId,
        sourceEventId: 'visit_create_${visit.visitId}',
      );
      await _db.upsert(
        'Queue_Events',
        queueEvent.queueEventId,
        queueEvent.toMap(),
        tx: tx,
      );

      // Create SyncOutbox event
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_visit_${visit.visitId}',
        clinicId: visit.clinicId,
        entityType: 'Visits',
        entityId: visit.visitId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(visitMap),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: idempotencyKey,
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      // Cache for idempotency upon commit
      tx.onCommit(() {
        _db.recordIdempotency(idempotencyKey, visitMap);
      });

      return Visit.fromMap(visitMap);
    });
  }

  @override
  Future<Visit> updateQueueStatus({
    required String clinicId,
    required String visitId,
    required QueueStatus newStatus,
    required String staffId,
    required String deviceId,
  }) async {
    return await _db.transaction<Visit>((tx) async {
      final existingRecord = _db.get('Visits', visitId);
      if (existingRecord == null || existingRecord['clinic_id'] != clinicId) {
        throw const DatabaseFailure('Visit not found');
      }

      final currentVisit = Visit.fromMap(existingRecord);
      final currentStatus = currentVisit.queueStatus;

      // Validate transition according to queue state machine rules
      if (!currentStatus.canTransitionTo(newStatus)) {
        throw ValidationFailure(
          'Invalid queue transition from ${currentStatus.name} to ${newStatus.name}',
        );
      }

      DateTime? startedAt = currentVisit.consultationStartedAt;
      DateTime? completedAt = currentVisit.consultationCompletedAt;

      if (newStatus == QueueStatus.inConsultation && startedAt == null) {
        startedAt = DateTime.now().toUtc();
      } else if (newStatus == QueueStatus.completed && completedAt == null) {
        completedAt = DateTime.now().toUtc();
      }

      final updatedVisit = currentVisit.copyWith(
        queueStatus: newStatus,
        consultationStartedAt: startedAt,
        consultationCompletedAt: completedAt,
        updatedAt: DateTime.now().toUtc(),
      );

      await _db.upsert('Visits', visitId, updatedVisit.toMap(), tx: tx);

      // Record immutable transition QueueEvent
      final queueEvent = QueueEvent(
        queueEventId:
            'qevt_${visitId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        visitId: visitId,
        doctorId: currentVisit.doctorId,
        fromStatus: currentStatus,
        toStatus: newStatus,
        changedByStaffId: staffId,
        changedAt: DateTime.now().toUtc(),
        deviceId: deviceId,
      );
      await _db.upsert(
        'Queue_Events',
        queueEvent.queueEventId,
        queueEvent.toMap(),
        tx: tx,
      );

      // Record SyncOutbox event
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_qevt_${queueEvent.queueEventId}',
        clinicId: clinicId,
        entityType: 'Queue_Events',
        entityId: queueEvent.queueEventId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(queueEvent.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: queueEvent.queueEventId,
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      return updatedVisit;
    });
  }

  @override
  Future<Visit> updateVisitPriority({
    required String clinicId,
    required String visitId,
    required QueuePriority newPriority,
    required String staffId,
    required String deviceId,
  }) async {
    return await _db.transaction<Visit>((tx) async {
      final existingRecord = _db.get('Visits', visitId);
      if (existingRecord == null || existingRecord['clinic_id'] != clinicId) {
        throw const DatabaseFailure('Visit not found');
      }

      final currentVisit = Visit.fromMap(existingRecord);
      final updatedVisit = currentVisit.copyWith(
        priority: newPriority,
        updatedAt: DateTime.now().toUtc(),
      );

      final visitMap = updatedVisit.toMap();
      await _db.upsert('Visits', visitId, visitMap, tx: tx);

      // Record QueueEvent
      final queueEvent = QueueEvent(
        queueEventId:
            'qevt_prio_${visitId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        visitId: visitId,
        doctorId: currentVisit.doctorId,
        fromStatus: currentVisit.queueStatus,
        toStatus: currentVisit.queueStatus,
        changedByStaffId: staffId,
        changedAt: DateTime.now().toUtc(),
        deviceId: deviceId,
        sourceEventId: 'priority_override_${newPriority.wireValue}',
      );
      await _db.upsert(
        'Queue_Events',
        queueEvent.queueEventId,
        queueEvent.toMap(),
        tx: tx,
      );

      // Create SyncOutbox update event
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_prio_${queueEvent.queueEventId}',
        clinicId: clinicId,
        entityType: 'Queue_Events',
        entityId: queueEvent.queueEventId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(queueEvent.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: queueEvent.queueEventId,
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      return updatedVisit;
    });
  }

  @override
  Future<void> incrementSlipPrintCount({
    required String clinicId,
    required String visitId,
    required String paperSize,
    String? staffId,
    String? deviceId,
  }) async {
    await _db.transaction((tx) async {
      final existingRecord = _db.get('Visits', visitId);
      if (existingRecord == null || existingRecord['clinic_id'] != clinicId) {
        return;
      }

      final current = Visit.fromMap(existingRecord);
      final newCount = current.slipPrintCount + 1;
      final now = DateTime.now().toUtc();

      final updated = current.copyWith(
        slipPrintCount: newCount,
        lastSlipPrintedAt: now,
        updatedAt: now,
      );

      await _db.upsert('Visits', visitId, updated.toMap(), tx: tx);

      // Record local PrintJob
      final printJob = PrintJob(
        printJobId: 'print_${visitId}_$newCount',
        clinicId: clinicId,
        visitId: visitId,
        jobType: 'consultation_slip',
        paperSize: paperSize,
        reprintCount: newCount > 1 ? newCount - 1 : 0,
        status: 'printed',
        createdAt: now,
        printedAt: now,
      );
      await _db.upsert(
        'pending_print_jobs',
        printJob.printJobId,
        printJob.toMap(),
        tx: tx,
      );

      // Record immutable Audit_Events entry
      final isReprint = newCount > 1;
      final auditEvent = AuditEvent(
        auditEventId: 'audit_print_${visitId}_$newCount',
        clinicId: clinicId,
        actorId: staffId ?? 'system',
        actorRole: 'receptionist',
        deviceId: deviceId ?? 'primary_device',
        action: isReprint ? 'consultation_slip.reprint' : 'consultation_slip.print',
        entityType: 'Visits',
        entityId: visitId,
        fieldNamesJson: jsonEncode(['slip_print_count', 'last_slip_printed_at', 'paper_size']),
        occurredAt: now,
        correlationId: 'corr_print_$visitId',
        result: AuditResult.success,
        reasonOptional: isReprint
            ? 'Duplicate consultation slip reprint (Copy #$newCount)'
            : 'Initial consultation slip print',
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );

      // Enqueue SyncOutbox event for Visits update
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_print_${visitId}_$newCount',
        clinicId: clinicId,
        entityType: 'Visits',
        entityId: visitId,
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(updated.toMap()),
        createdAt: now,
        idempotencyKey: 'print_${visitId}_$newCount',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<List<QueueEvent>> getQueueEventsForVisit(
    String clinicId,
    String visitId,
  ) async {
    final records = _db.query(
      'Queue_Events',
      where: (r) => r['clinic_id'] == clinicId && r['visit_id'] == visitId,
    );
    final events = records.map((r) => QueueEvent.fromMap(r)).toList();
    events.sort((a, b) => a.changedAt.compareTo(b.changedAt));
    return events;
  }

  @override
  Future<int> getNextTokenNumber({
    required String clinicId,
    required String doctorId,
    required String localDate,
  }) async {
    final scopeKey = '$clinicId:$doctorId:$localDate';
    final counterRecord = _db.get('Token_Counters', scopeKey);
    if (counterRecord == null) return 1;
    return (counterRecord['last_issued_token'] as num).toInt() + 1;
  }
}

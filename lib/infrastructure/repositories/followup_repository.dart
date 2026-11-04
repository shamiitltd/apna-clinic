// Apna Clinic - Concrete Follow-up Repository Implementation (Module 12)
// Primary source of truth: PRD Section 5 M12 & TRD Section 7 `Followups`
// CLINICAL BOUNDARY: Administrative scheduling and reminder tracking only.

import 'dart:convert';
import '../../core/utils/phone_normalizer.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/audit_event.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/followup.dart';
import '../../domain/entities/patient.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_followup_repository.dart';
import '../database/local_database.dart';

class FollowupRepository implements IFollowupRepository {
  final LocalDatabase _db;

  FollowupRepository(this._db);

  @override
  Future<void> scheduleFollowup(Followup followup) async {
    await _db.transaction((tx) async {
      await _db.upsert(
        'Followups',
        followup.followupId,
        followup.toMap(),
        tx: tx,
      );

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_flw_${followup.followupId}',
        clinicId: followup.clinicId,
        entityType: 'Followups',
        entityId: followup.followupId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(followup.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'flw_${followup.followupId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      // Stage 18_NOTIFICATIONS
      final schedNotifId = 'NOTIF_${DateTime.now().millisecondsSinceEpoch}';
      final channelPref = followup.channelPreference.isNotEmpty ? followup.channelPreference : 'WHATSAPP';
      final notifPayload = {
        'notification_id': schedNotifId,
        'patient_id': followup.patientId,
        'notification_type': 'FOLLOWUP_REMINDER',
        'recipient_contact': channelPref,
        'scheduled_at': followup.dueDate,
        'sent_at': followup.createdAt.toIso8601String(),
        'channel': channelPref.toUpperCase(),
        'template_name': 'FOLLOWUP_REMINDER_V1',
        'status': followup.status.toUpperCase(),
        'delivery_status': 'PENDING',
        'remarks': followup.administrativeNoteOptional ?? 'Followup reminder scheduled',
        'created_at': followup.createdAt.toIso8601String(),
      };
      final notifOutbox = SyncOutboxEvent(
        outboxEventId: 'outbox_notif_$schedNotifId',
        clinicId: followup.clinicId,
        entityType: '18_NOTIFICATIONS',
        entityId: schedNotifId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(notifPayload),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'notif_$schedNotifId',
      );
      await _db.upsert(
        'sync_outbox',
        notifOutbox.outboxEventId,
        notifOutbox.toMap(),
        tx: tx,
      );

      final auditEvent = AuditEvent(
        auditEventId: 'audit_flw_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: followup.clinicId,
        actorId: followup.doctorId,
        actorRole: 'staff',
        deviceId: 'primary_workstation',
        action: 'followup.schedule',
        entityType: 'followup',
        entityId: followup.followupId,
        occurredAt: DateTime.now().toUtc(),
        result: AuditResult.success,
        correlationId: followup.followupId,
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<Followup?> getFollowupById(String clinicId, String followupId) async {
    final records = _db.query(
      'Followups',
      where: (r) =>
          r['clinic_id'] == clinicId && r['followup_id'] == followupId,
    );
    if (records.isEmpty) return null;
    return Followup.fromMap(records.first);
  }

  @override
  Future<List<Followup>> getFollowupsForDate(
    String clinicId,
    String dueDate,
  ) async {
    final records = _db.query(
      'Followups',
      where: (r) => r['clinic_id'] == clinicId && r['due_date'] == dueDate,
    );
    final followups = records.map((r) => Followup.fromMap(r)).toList();
    followups.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return followups;
  }

  @override
  Future<List<Followup>> getFollowupsForDateRange(
    String clinicId,
    String startDate,
    String endDate,
  ) async {
    final records = _db.query(
      'Followups',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        final date = r['due_date'] as String? ?? '';
        return date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;
      },
    );
    final followups = records.map((r) => Followup.fromMap(r)).toList();
    followups.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return followups;
  }

  @override
  Future<List<Followup>> getFollowupsForPatient(
    String clinicId,
    String patientId,
  ) async {
    final records = _db.query(
      'Followups',
      where: (r) => r['clinic_id'] == clinicId && r['patient_id'] == patientId,
    );
    final followups = records.map((r) => Followup.fromMap(r)).toList();
    followups.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return followups;
  }

  @override
  Future<List<Followup>> getFollowupsForDoctor(
    String clinicId,
    String doctorId, {
    String? status,
  }) async {
    final records = _db.query(
      'Followups',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        if (r['doctor_id'] != doctorId) return false;
        if (status != null && r['status'] != status) return false;
        return true;
      },
    );
    final followups = records.map((r) => Followup.fromMap(r)).toList();
    followups.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return followups;
  }

  @override
  Future<List<Followup>> getAllFollowups(
    String clinicId, {
    String? status,
  }) async {
    final records = _db.query(
      'Followups',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        if (status != null && r['status'] != status) return false;
        return true;
      },
    );
    final followups = records.map((r) => Followup.fromMap(r)).toList();
    followups.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return followups;
  }

  @override
  Future<void> updateFollowupStatus({
    required String clinicId,
    required String followupId,
    required String status,
    String? reason,
    required String actorId,
  }) async {
    final records = _db.query(
      'Followups',
      where: (r) =>
          r['clinic_id'] == clinicId && r['followup_id'] == followupId,
    );
    if (records.isEmpty) return;

    final existing = Followup.fromMap(records.first);
    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      status: status,
      updatedAt: now,
    );

    await _db.transaction((tx) async {
      await _db.upsert('Followups', followupId, updated.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_flw_upd_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        entityType: 'Followups',
        entityId: followupId,
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(updated.toMap()),
        createdAt: now,
        idempotencyKey: 'flw_upd_$followupId',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      final auditEvent = AuditEvent(
        auditEventId: 'audit_flw_stat_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: actorId,
        actorRole: 'staff',
        deviceId: 'primary_workstation',
        action: 'followup.update_status',
        entityType: 'followup',
        entityId: followupId,
        occurredAt: now,
        result: AuditResult.success,
        reasonOptional: reason ?? 'Status changed to $status',
        correlationId: followupId,
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<void> recordReminderNotification({
    required String clinicId,
    required String followupId,
    required String status,
    required String channel,
    required String actorId,
  }) async {
    final records = _db.query(
      'Followups',
      where: (r) =>
          r['clinic_id'] == clinicId && r['followup_id'] == followupId,
    );
    if (records.isEmpty) return;

    final existing = Followup.fromMap(records.first);
    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      reminderStatus: status,
      channelPreference: channel,
      reminderSentAt: status == 'sent' ? now : existing.reminderSentAt,
      updatedAt: now,
    );

    await _db.transaction((tx) async {
      await _db.upsert('Followups', followupId, updated.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_flw_notif_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        entityType: 'Followups',
        entityId: followupId,
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(updated.toMap()),
        createdAt: now,
        idempotencyKey: 'flw_notif_$followupId',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      // Stage 18_NOTIFICATIONS
      final notifId = 'NOTIF_${now.millisecondsSinceEpoch}';
      final notifPayload = {
        'notification_id': notifId,
        'patient_id': existing.patientId,
        'notification_type': 'FOLLOWUP_REMINDER',
        'recipient_contact': channel,
        'scheduled_at': existing.dueDate,
        'sent_at': now.toIso8601String(),
        'channel': channel.toUpperCase(),
        'template_name': 'FOLLOWUP_REMINDER_V1',
        'status': status.toUpperCase(),
        'delivery_status': status == 'sent' ? 'DELIVERED' : 'FAILED',
        'remarks': 'Followup reminder dispatched via $channel',
        'created_at': now.toIso8601String(),
      };
      final notifOutbox = SyncOutboxEvent(
        outboxEventId: 'outbox_notif_$notifId',
        clinicId: clinicId,
        entityType: '18_NOTIFICATIONS',
        entityId: notifId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(notifPayload),
        createdAt: now,
        idempotencyKey: 'notif_$notifId',
      );
      await _db.upsert(
        'sync_outbox',
        notifOutbox.outboxEventId,
        notifOutbox.toMap(),
        tx: tx,
      );

      final auditEvent = AuditEvent(
        auditEventId: 'audit_flw_notif_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: actorId,
        actorRole: 'staff',
        deviceId: 'primary_workstation',
        action: 'followup.reminder_$status',
        entityType: 'followup',
        entityId: followupId,
        occurredAt: now,
        result: AuditResult.success,
        reasonOptional: 'Reminder via $channel: $status',
        correlationId: followupId,
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<void> convertToAppointment({
    required String clinicId,
    required String followupId,
    required Appointment appointment,
    required String actorId,
  }) async {
    final records = _db.query(
      'Followups',
      where: (r) =>
          r['clinic_id'] == clinicId && r['followup_id'] == followupId,
    );
    if (records.isEmpty) return;

    final existing = Followup.fromMap(records.first);
    final now = DateTime.now().toUtc();
    final updatedFollowup = existing.copyWith(
      status: 'completed',
      convertedAppointmentIdOptional: appointment.appointmentId,
      updatedAt: now,
    );

    await _db.transaction((tx) async {
      // 1. Persist the new appointment
      await _db.upsert(
        'Appointments',
        appointment.appointmentId,
        appointment.toMap(),
        tx: tx,
      );

      // 2. Mark followup completed & link appointment
      await _db.upsert(
        'Followups',
        followupId,
        updatedFollowup.toMap(),
        tx: tx,
      );

      // 3. Stage outbox for appointment
      final outboxApp = SyncOutboxEvent(
        outboxEventId: 'outbox_app_${appointment.appointmentId}',
        clinicId: clinicId,
        entityType: 'Appointments',
        entityId: appointment.appointmentId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(appointment.toMap()),
        createdAt: now,
        idempotencyKey: 'app_${appointment.appointmentId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxApp.outboxEventId,
        outboxApp.toMap(),
        tx: tx,
      );

      // 4. Stage outbox for followup
      final outboxFlw = SyncOutboxEvent(
        outboxEventId: 'outbox_flw_conv_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        entityType: 'Followups',
        entityId: followupId,
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(updatedFollowup.toMap()),
        createdAt: now,
        idempotencyKey: 'flw_conv_$followupId',
      );
      await _db.upsert(
        'sync_outbox',
        outboxFlw.outboxEventId,
        outboxFlw.toMap(),
        tx: tx,
      );

      // 5. Audit event
      final auditEvent = AuditEvent(
        auditEventId: 'audit_flw_conv_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: actorId,
        actorRole: 'staff',
        deviceId: 'primary_workstation',
        action: 'followup.convert_to_appointment',
        entityType: 'followup',
        entityId: followupId,
        occurredAt: now,
        result: AuditResult.success,
        reasonOptional: 'Converted to appointment ${appointment.appointmentId}',
        correlationId: appointment.appointmentId,
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  String exportFollowupsToCsv(
    List<Followup> followups,
    Map<String, Patient> patientMap,
    Map<String, Doctor> doctorMap,
  ) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM for Excel
    buffer.writeln(
      'followup_id,due_date,patient_number,patient_name,patient_phone_masked,doctor_name,status,reminder_consent,channel_preference,reminder_status,reminder_sent_at,converted_appointment_id,administrative_note,created_at',
    );

    for (final f in followups) {
      final p = patientMap[f.patientId];
      final d = doctorMap[f.doctorId];

      final pNum = p?.patientNumber ?? '';
      final pName = (p?.fullName ?? 'Unknown').replaceAll('"', '""');
      final pPhone = p?.phoneOptional != null
          ? PhoneNormalizer.mask(p!.phoneOptional!)
          : '';
      final docName = (d?.displayName ?? 'Doctor').replaceAll('"', '""');
      final note = (f.administrativeNoteOptional ?? '').replaceAll('"', '""');
      final sentAt = f.reminderSentAt?.toIso8601String() ?? '';
      final convApp = f.convertedAppointmentIdOptional ?? '';

      buffer.writeln(
        '"${f.followupId}","${f.dueDate}","$pNum","$pName","$pPhone","$docName","${f.status}","${f.reminderConsent ? 'YES' : 'NO'}","${f.channelPreference}","${f.reminderStatus}","$sentAt","$convApp","$note","${f.createdAt.toIso8601String()}"',
      );
    }

    return buffer.toString();
  }
}

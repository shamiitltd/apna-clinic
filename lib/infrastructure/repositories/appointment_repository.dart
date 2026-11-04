// Apna Clinic - Concrete Appointment Repository
// Implementation of IAppointmentRepository backed by LocalDatabase

import 'dart:convert';

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_appointment_repository.dart';
import '../database/local_database.dart';

class AppointmentRepository implements IAppointmentRepository {
  final LocalDatabase _db;

  AppointmentRepository(this._db);

  @override
  Future<List<Appointment>> getAppointmentsForDate(
    String clinicId,
    DateTime date, {
    String? doctorId,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;

    final records = _db.query(
      'Appointments',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        if (r['deleted_at'] != null) return false;
        if (doctorId != null && r['doctor_id'] != doctorId) return false;

        final start = r['scheduled_start_at'] as String? ?? '';
        return start.startsWith(dateStr);
      },
    );

    final apps = records.map((r) => Appointment.fromMap(r)).toList();
    apps.sort((a, b) => a.scheduledStartAt.compareTo(b.scheduledStartAt));
    return apps;
  }

  @override
  Future<Appointment?> getAppointmentById(
    String clinicId,
    String appointmentId,
  ) async {
    final record = _db.get('Appointments', appointmentId);
    if (record == null || record['clinic_id'] != clinicId) return null;
    if (record['deleted_at'] != null) return null;
    return Appointment.fromMap(record);
  }

  @override
  Future<void> saveAppointment(Appointment appointment) async {
    await _db.transaction((tx) async {
      await _db.upsert(
        'Appointments',
        appointment.appointmentId,
        appointment.toMap(),
        tx: tx,
      );

      // Stage for sync outbox
      final outboxEvent = SyncOutboxEvent(
        outboxEventId:
            'outbox_app_${appointment.appointmentId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: appointment.clinicId,
        entityType: 'Appointments',
        entityId: appointment.appointmentId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(appointment.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'app_${appointment.appointmentId}',
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
  Future<void> updateAppointmentStatus(
    String clinicId,
    String appointmentId,
    AppointmentStatus status, {
    String? cancelReason,
  }) async {
    await _db.transaction((tx) async {
      final existingRecord = _db.get('Appointments', appointmentId);
      if (existingRecord == null || existingRecord['clinic_id'] != clinicId) {
        return;
      }

      final current = Appointment.fromMap(existingRecord);
      final updated = current.copyWith(
        status: status,
        cancelReason: cancelReason,
        updatedAt: DateTime.now().toUtc(),
      );

      await _db.upsert('Appointments', appointmentId, updated.toMap(), tx: tx);

      // Stage for sync outbox
      final outboxEvent = SyncOutboxEvent(
        outboxEventId:
            'outbox_app_up_${appointmentId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        entityType: 'Appointments',
        entityId: appointmentId,
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(updated.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'app_up_${appointmentId}_${status.wireValue}',
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
  Future<bool> hasSlotConflict({
    required String clinicId,
    required String doctorId,
    required DateTime start,
    required DateTime end,
    String? excludeAppointmentId,
  }) async {
    final records = _db.query(
      'Appointments',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        if (r['doctor_id'] != doctorId) return false;
        if (r['deleted_at'] != null) return false;
        if (r['status'] == AppointmentStatus.cancelled.wireValue ||
            r['status'] == AppointmentStatus.noShow.wireValue) {
          return false;
        }
        if (excludeAppointmentId != null &&
            r['appointment_id'] == excludeAppointmentId) {
          return false;
        }

        final aStart = DateTime.parse(r['scheduled_start_at'] as String);
        final aEnd = DateTime.parse(r['scheduled_end_at'] as String);

        // Check time overlap: (start < aEnd) && (end > aStart)
        return start.isBefore(aEnd) && end.isAfter(aStart);
      },
    );

    return records.isNotEmpty;
  }

  @override
  Future<void> rescheduleAppointment({
    required String clinicId,
    required String appointmentId,
    required DateTime newStart,
    required DateTime newEnd,
    String? newDoctorId,
  }) async {
    await _db.transaction((tx) async {
      final existingRecord = _db.get('Appointments', appointmentId);
      if (existingRecord == null || existingRecord['clinic_id'] != clinicId) {
        return;
      }

      final current = Appointment.fromMap(existingRecord);
      final updated = current.copyWith(
        doctorId: newDoctorId ?? current.doctorId,
        scheduledStartAt: newStart,
        scheduledEndAt: newEnd,
        rescheduledFromId: current.appointmentId,
        status: AppointmentStatus.scheduled,
        updatedAt: DateTime.now().toUtc(),
      );

      await _db.upsert('Appointments', appointmentId, updated.toMap(), tx: tx);

      // Stage for sync outbox
      final outboxEvent = SyncOutboxEvent(
        outboxEventId:
            'outbox_app_resched_${appointmentId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        entityType: 'Appointments',
        entityId: appointmentId,
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(updated.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey:
            'app_resched_${appointmentId}_${newStart.millisecondsSinceEpoch}',
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
  Future<List<DateTime>> getAvailableSlots({
    required String clinicId,
    required String doctorId,
    required DateTime date,
    required int durationMinutes,
    int startHour = 9,
    int endHour = 18,
  }) async {
    final bookedAppointments = await getAppointmentsForDate(
      clinicId,
      date,
      doctorId: doctorId,
    );

    final activeBookings = bookedAppointments
        .where(
          (a) =>
              a.status != AppointmentStatus.cancelled &&
              a.status != AppointmentStatus.noShow,
        )
        .toList();

    final List<DateTime> availableSlots = [];
    var currentSlot = DateTime(date.year, date.month, date.day, startHour, 0);
    final dayEnd = DateTime(date.year, date.month, date.day, endHour, 0);

    while (currentSlot.add(Duration(minutes: durationMinutes)).isBefore(dayEnd) ||
        currentSlot.add(Duration(minutes: durationMinutes)).isAtSameMomentAs(dayEnd)) {
      final slotEnd = currentSlot.add(Duration(minutes: durationMinutes));
      final hasConflict = activeBookings.any(
        (a) => currentSlot.isBefore(a.scheduledEndAt) && slotEnd.isAfter(a.scheduledStartAt),
      );

      if (!hasConflict) {
        availableSlots.add(currentSlot);
      }
      currentSlot = slotEnd;
    }

    return availableSlots;
  }
}

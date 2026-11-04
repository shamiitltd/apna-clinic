// Apna Clinic - Appointment Repository Interface

import '../entities/entities.dart';
import '../enums/domain_enums.dart';

abstract class IAppointmentRepository {
  Future<List<Appointment>> getAppointmentsForDate(
    String clinicId,
    DateTime date, {
    String? doctorId,
  });

  Future<Appointment?> getAppointmentById(
    String clinicId,
    String appointmentId,
  );

  Future<void> saveAppointment(Appointment appointment);

  Future<void> updateAppointmentStatus(
    String clinicId,
    String appointmentId,
    AppointmentStatus status, {
    String? cancelReason,
  });

  Future<bool> hasSlotConflict({
    required String clinicId,
    required String doctorId,
    required DateTime start,
    required DateTime end,
    String? excludeAppointmentId,
  });

  Future<void> rescheduleAppointment({
    required String clinicId,
    required String appointmentId,
    required DateTime newStart,
    required DateTime newEnd,
    String? newDoctorId,
  });

  Future<List<DateTime>> getAvailableSlots({
    required String clinicId,
    required String doctorId,
    required DateTime date,
    required int durationMinutes,
    int startHour = 9,
    int endHour = 18,
  });
}

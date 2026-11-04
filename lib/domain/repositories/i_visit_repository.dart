// Apna Clinic - Visit & Queue Repository Interface
// ATOMIC TRANSACTION: Patient + Visit + Token + Queue Event + Outbox Event

import '../entities/entities.dart';
import '../enums/domain_enums.dart';

abstract class IVisitRepository {
  Future<Visit?> getVisitById(String clinicId, String visitId);
  Future<List<Visit>> getVisitsForDate(
    String clinicId,
    String localDate, {
    String? doctorId,
  });

  /// Transactionally creates a Visit, increments the daily TokenCounter,
  /// records the initial QueueEvent, and writes to SyncOutbox.
  Future<Visit> createVisitAtomic({
    required Visit visit,
    required String idempotencyKey,
    required String deviceId,
    required String staffId,
  });

  /// Transactionally transitions queue status, recording QueueEvent and SyncOutbox.
  Future<Visit> updateQueueStatus({
    required String clinicId,
    required String visitId,
    required QueueStatus newStatus,
    required String staffId,
    required String deviceId,
  });

  /// Transactionally updates visit priority, recording QueueEvent and SyncOutbox.
  Future<Visit> updateVisitPriority({
    required String clinicId,
    required String visitId,
    required QueuePriority newPriority,
    required String staffId,
    required String deviceId,
  });

  Future<void> incrementSlipPrintCount({
    required String clinicId,
    required String visitId,
    required String paperSize,
    String? staffId,
    String? deviceId,
  });

  Future<List<QueueEvent>> getQueueEventsForVisit(
    String clinicId,
    String visitId,
  );

  Future<int> getNextTokenNumber({
    required String clinicId,
    required String doctorId,
    required String localDate,
  });
}

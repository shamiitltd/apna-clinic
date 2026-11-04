// Apna Clinic - Queue Event Entity
// Primary source of truth: TRD Section 7 `Queue_Events`

import '../enums/domain_enums.dart';

class QueueEvent {
  final String queueEventId;
  final String clinicId;
  final String visitId;
  final String doctorId;
  final QueueStatus fromStatus;
  final QueueStatus toStatus;
  final String changedByStaffId;
  final DateTime changedAt;
  final String deviceId;
  final String? sourceEventId;

  const QueueEvent({
    required this.queueEventId,
    required this.clinicId,
    required this.visitId,
    required this.doctorId,
    required this.fromStatus,
    required this.toStatus,
    required this.changedByStaffId,
    required this.changedAt,
    required this.deviceId,
    this.sourceEventId,
  });

  Map<String, dynamic> toMap() {
    return {
      'queue_event_id': queueEventId,
      'clinic_id': clinicId,
      'visit_id': visitId,
      'doctor_id': doctorId,
      'from_status': fromStatus.wireValue,
      'to_status': toStatus.wireValue,
      'changed_by_staff_id': changedByStaffId,
      'changed_at': changedAt.toIso8601String(),
      'device_id': deviceId,
      'source_event_id': sourceEventId,
    };
  }

  factory QueueEvent.fromMap(Map<String, dynamic> map) {
    return QueueEvent(
      queueEventId: map['queue_event_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      visitId: map['visit_id']?.toString() ?? '',
      doctorId: map['doctor_id']?.toString() ?? '',
      fromStatus: QueueStatus.fromWire(
        map['from_status'] as String? ?? 'waiting',
      ),
      toStatus: QueueStatus.fromWire(map['to_status'] as String? ?? 'called'),
      changedByStaffId: map['changed_by_staff_id'] as String? ?? '',
      changedAt: map['changed_at'] != null
          ? (DateTime.tryParse(map['changed_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      deviceId: map['device_id'] as String? ?? '',
      sourceEventId: map['source_event_id'] as String?,
    );
  }
}

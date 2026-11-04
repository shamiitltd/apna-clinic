// Apna Clinic - Module 13: Multi-Doctor & Multi-Device Live Collaboration
// Primary Source of Truth: PRD Section 5 (M13), Section 7.3, TRD Section 2, Section 8, ADR-003, ADR-011.

import '../../core/permissions/roles.dart';

/// Role classification for devices operating in the clinic environment.
enum DeviceRole {
  primaryReception,
  secondaryReception,
  doctorDesk,
  ownerStation,
  mobileViewer;

  String get wireValue {
    switch (this) {
      case DeviceRole.primaryReception:
        return 'PRIMARY_RECEPTION';
      case DeviceRole.secondaryReception:
        return 'SECONDARY_RECEPTION';
      case DeviceRole.doctorDesk:
        return 'DOCTOR_DESK';
      case DeviceRole.ownerStation:
        return 'OWNER_STATION';
      case DeviceRole.mobileViewer:
        return 'MOBILE_VIEWER';
    }
  }

  static DeviceRole fromWire(String val) {
    switch (val.toUpperCase().trim()) {
      case 'PRIMARY_RECEPTION':
        return DeviceRole.primaryReception;
      case 'SECONDARY_RECEPTION':
        return DeviceRole.secondaryReception;
      case 'DOCTOR_DESK':
        return DeviceRole.doctorDesk;
      case 'OWNER_STATION':
        return DeviceRole.ownerStation;
      case 'MOBILE_VIEWER':
      default:
        return DeviceRole.mobileViewer;
    }
  }

  String get displayName {
    switch (this) {
      case DeviceRole.primaryReception:
        return 'Primary Reception Workstation';
      case DeviceRole.secondaryReception:
        return 'Secondary Reception Counter';
      case DeviceRole.doctorDesk:
        return 'Doctor Desk Terminal';
      case DeviceRole.ownerStation:
        return 'Owner Administration Workstation';
      case DeviceRole.mobileViewer:
        return 'Mobile Roster Viewer';
    }
  }
}

/// Lifecycle status for device write leases (Single-Writer MVP rule).
enum DeviceLeaseStatus {
  active,
  expired,
  released,
  forceRevoked;

  String get wireValue {
    switch (this) {
      case DeviceLeaseStatus.active:
        return 'ACTIVE';
      case DeviceLeaseStatus.expired:
        return 'EXPIRED';
      case DeviceLeaseStatus.released:
        return 'RELEASED';
      case DeviceLeaseStatus.forceRevoked:
        return 'FORCE_REVOKED';
    }
  }

  static DeviceLeaseStatus fromWire(String val) {
    switch (val.toUpperCase().trim()) {
      case 'ACTIVE':
        return DeviceLeaseStatus.active;
      case 'EXPIRED':
        return DeviceLeaseStatus.expired;
      case 'RELEASED':
        return DeviceLeaseStatus.released;
      case 'FORCE_REVOKED':
      default:
        return DeviceLeaseStatus.forceRevoked;
    }
  }
}

/// Registration record for an authorized clinic workstation/device.
class DeviceRegistration {
  final String deviceId;
  final String clinicId;
  final String deviceName;
  final DeviceRole deviceRole;
  final String platformInfo;
  final String appVersion;
  final DateTime registeredAt;
  final DateTime lastHeartbeatAt;

  const DeviceRegistration({
    required this.deviceId,
    required this.clinicId,
    required this.deviceName,
    required this.deviceRole,
    required this.platformInfo,
    required this.appVersion,
    required this.registeredAt,
    required this.lastHeartbeatAt,
  });

  /// Evaluates whether the device has sent a heartbeat recently (within 3 minutes).
  bool get isOnline {
    final diff = DateTime.now().toUtc().difference(lastHeartbeatAt.toUtc()).inSeconds;
    return diff < 180;
  }

  DeviceRegistration copyWith({
    String? deviceId,
    String? clinicId,
    String? deviceName,
    DeviceRole? deviceRole,
    String? platformInfo,
    String? appVersion,
    DateTime? registeredAt,
    DateTime? lastHeartbeatAt,
  }) {
    return DeviceRegistration(
      deviceId: deviceId ?? this.deviceId,
      clinicId: clinicId ?? this.clinicId,
      deviceName: deviceName ?? this.deviceName,
      deviceRole: deviceRole ?? this.deviceRole,
      platformInfo: platformInfo ?? this.platformInfo,
      appVersion: appVersion ?? this.appVersion,
      registeredAt: registeredAt ?? this.registeredAt,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'clinic_id': clinicId,
      'device_name': deviceName,
      'device_role': deviceRole.wireValue,
      'platform_info': platformInfo,
      'app_version': appVersion,
      'registered_at': registeredAt.toIso8601String(),
      'last_heartbeat_at': lastHeartbeatAt.toIso8601String(),
    };
  }

  factory DeviceRegistration.fromMap(Map<String, dynamic> map) {
    return DeviceRegistration(
      deviceId: map['device_id'] as String? ?? '',
      clinicId: map['clinic_id'] as String? ?? '',
      deviceName: map['device_name'] as String? ?? 'Clinic Terminal',
      deviceRole: DeviceRole.fromWire(map['device_role'] as String? ?? 'MOBILE_VIEWER'),
      platformInfo: map['platform_info'] as String? ?? 'Web / Flutter',
      appVersion: map['app_version'] as String? ?? '1.0.0',
      registeredAt: DateTime.tryParse(map['registered_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      lastHeartbeatAt:
          DateTime.tryParse(map['last_heartbeat_at'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

/// Single-writer lease ensuring only one primary operational device commits authoritative mutations.
class DeviceLease {
  final String leaseId;
  final String clinicId;
  final String holderDeviceId;
  final String holderStaffId;
  final UserRole holderRole;
  final DateTime acquiredAt;
  final DateTime expiresAt;
  final int durationSeconds;
  final DeviceLeaseStatus status;

  const DeviceLease({
    required this.leaseId,
    required this.clinicId,
    required this.holderDeviceId,
    required this.holderStaffId,
    required this.holderRole,
    required this.acquiredAt,
    required this.expiresAt,
    this.durationSeconds = 300,
    this.status = DeviceLeaseStatus.active,
  });

  /// Returns true if this lease is currently active and not yet expired.
  bool get isActive {
    if (status != DeviceLeaseStatus.active) return false;
    return DateTime.now().toUtc().isBefore(expiresAt.toUtc());
  }

  /// Returns true if this lease has expired by wall-clock time.
  bool get isExpired {
    return DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  }

  DeviceLease copyWith({
    String? leaseId,
    String? clinicId,
    String? holderDeviceId,
    String? holderStaffId,
    UserRole? holderRole,
    DateTime? acquiredAt,
    DateTime? expiresAt,
    int? durationSeconds,
    DeviceLeaseStatus? status,
  }) {
    return DeviceLease(
      leaseId: leaseId ?? this.leaseId,
      clinicId: clinicId ?? this.clinicId,
      holderDeviceId: holderDeviceId ?? this.holderDeviceId,
      holderStaffId: holderStaffId ?? this.holderStaffId,
      holderRole: holderRole ?? this.holderRole,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      expiresAt: expiresAt ?? this.expiresAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lease_id': leaseId,
      'clinic_id': clinicId,
      'holder_device_id': holderDeviceId,
      'holder_staff_id': holderStaffId,
      'holder_role': holderRole.wireValue,
      'acquired_at': acquiredAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'status': status.wireValue,
    };
  }

  factory DeviceLease.fromMap(Map<String, dynamic> map) {
    return DeviceLease(
      leaseId: map['lease_id'] as String? ?? '',
      clinicId: map['clinic_id'] as String? ?? '',
      holderDeviceId: map['holder_device_id'] as String? ?? '',
      holderStaffId: map['holder_staff_id'] as String? ?? '',
      holderRole: UserRole.fromWire(map['holder_role'] as String? ?? 'receptionist'),
      acquiredAt: DateTime.tryParse(map['acquired_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      expiresAt: DateTime.tryParse(map['expires_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(seconds: 300)),
      durationSeconds: map['duration_seconds'] as int? ?? 300,
      status: DeviceLeaseStatus.fromWire(map['status'] as String? ?? 'ACTIVE'),
    );
  }
}

/// A visible conflict record between concurrent updates across multiple devices.
/// Strictly excludes medical prescriptions and sensitive clinical notes as per DPDP.
class CollaborationConflict {
  final String conflictId;
  final String clinicId;
  final String entityType; // 'appointment', 'visit_token', 'queue_status', 'invoice'
  final String entityId;
  final String localDeviceId;
  final String remoteDeviceId;
  final String conflictType; // 'overlapping_slot', 'stale_state_override', 'token_counter_divergence', 'concurrent_status_mutation'
  final DateTime detectedAt;
  final String localSummary; // Non-clinical summary (e.g. "Slot 10:00-10:15 Dr. Sharma")
  final String remoteSummary;
  final String resolutionStatus; // 'unresolved', 'resolved_keep_local', 'resolved_keep_remote', 'resolved_manual'
  final DateTime? resolvedAt;
  final String? resolvedByStaffId;
  final String? resolutionNotes;

  const CollaborationConflict({
    required this.conflictId,
    required this.clinicId,
    required this.entityType,
    required this.entityId,
    required this.localDeviceId,
    required this.remoteDeviceId,
    required this.conflictType,
    required this.detectedAt,
    required this.localSummary,
    required this.remoteSummary,
    this.resolutionStatus = 'unresolved',
    this.resolvedAt,
    this.resolvedByStaffId,
    this.resolutionNotes,
  });

  bool get isResolved => resolutionStatus != 'unresolved';

  CollaborationConflict copyWith({
    String? conflictId,
    String? clinicId,
    String? entityType,
    String? entityId,
    String? localDeviceId,
    String? remoteDeviceId,
    String? conflictType,
    DateTime? detectedAt,
    String? localSummary,
    String? remoteSummary,
    String? resolutionStatus,
    DateTime? resolvedAt,
    String? resolvedByStaffId,
    String? resolutionNotes,
  }) {
    return CollaborationConflict(
      conflictId: conflictId ?? this.conflictId,
      clinicId: clinicId ?? this.clinicId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      localDeviceId: localDeviceId ?? this.localDeviceId,
      remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
      conflictType: conflictType ?? this.conflictType,
      detectedAt: detectedAt ?? this.detectedAt,
      localSummary: localSummary ?? this.localSummary,
      remoteSummary: remoteSummary ?? this.remoteSummary,
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedByStaffId: resolvedByStaffId ?? this.resolvedByStaffId,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conflict_id': conflictId,
      'clinic_id': clinicId,
      'entity_type': entityType,
      'entity_id': entityId,
      'local_device_id': localDeviceId,
      'remote_device_id': remoteDeviceId,
      'conflict_type': conflictType,
      'detected_at': detectedAt.toIso8601String(),
      'local_summary': localSummary,
      'remote_summary': remoteSummary,
      'resolution_status': resolutionStatus,
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by_staff_id': resolvedByStaffId,
      'resolution_notes': resolutionNotes,
    };
  }

  factory CollaborationConflict.fromMap(Map<String, dynamic> map) {
    return CollaborationConflict(
      conflictId: map['conflict_id'] as String? ?? '',
      clinicId: map['clinic_id'] as String? ?? '',
      entityType: map['entity_type'] as String? ?? 'appointment',
      entityId: map['entity_id'] as String? ?? '',
      localDeviceId: map['local_device_id'] as String? ?? '',
      remoteDeviceId: map['remote_device_id'] as String? ?? '',
      conflictType: map['conflict_type'] as String? ?? 'overlapping_slot',
      detectedAt: DateTime.tryParse(map['detected_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      localSummary: map['local_summary'] as String? ?? '',
      remoteSummary: map['remote_summary'] as String? ?? '',
      resolutionStatus: map['resolution_status'] as String? ?? 'unresolved',
      resolvedAt: map['resolved_at'] != null
          ? DateTime.tryParse(map['resolved_at'] as String)?.toUtc()
          : null,
      resolvedByStaffId: map['resolved_by_staff_id'] as String?,
      resolutionNotes: map['resolution_notes'] as String?,
    );
  }
}


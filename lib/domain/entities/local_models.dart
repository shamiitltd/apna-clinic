// Apna Clinic - Local-only Domain Models
// Primary source of truth: TRD Section 7 & 12
// Recommended local-only tables: local_keys, sync_outbox, sync_inbox, pending_print_jobs, browser_device_state, local_migrations, auth_session_metadata, reason_for_visit_secrets

class DeviceState {
  final String deviceId;
  final String clinicId;
  final bool isPrimaryWriter;
  final String deviceLabel;
  final DateTime registeredAt;
  final DateTime lastActiveAt;

  const DeviceState({
    required this.deviceId,
    required this.clinicId,
    this.isPrimaryWriter = true,
    required this.deviceLabel,
    required this.registeredAt,
    required this.lastActiveAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'clinic_id': clinicId,
      'is_primary_writer': isPrimaryWriter ? 1 : 0,
      'device_label': deviceLabel,
      'registered_at': registeredAt.toIso8601String(),
      'last_active_at': lastActiveAt.toIso8601String(),
    };
  }

  factory DeviceState.fromMap(Map<String, dynamic> map) {
    return DeviceState(
      deviceId: map['device_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      isPrimaryWriter: (map['is_primary_writer'] is bool)
          ? map['is_primary_writer'] as bool
          : ((map['is_primary_writer'] as num?)?.toInt() ?? 1) == 1,
      deviceLabel: map['device_label'] as String? ?? 'Reception PC',
      registeredAt: map['registered_at'] != null
          ? (DateTime.tryParse(map['registered_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      lastActiveAt: map['last_active_at'] != null
          ? (DateTime.tryParse(map['last_active_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }
}

class LocalKeyMetadata {
  final String keyId;
  final String clinicId;
  final String algorithm; // e.g. "AES-GCM-256"
  final DateTime createdAt;
  final bool isActive;
  final int rotationSequence;

  const LocalKeyMetadata({
    required this.keyId,
    required this.clinicId,
    this.algorithm = 'AES-GCM-256',
    required this.createdAt,
    this.isActive = true,
    this.rotationSequence = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'key_id': keyId,
      'clinic_id': clinicId,
      'algorithm': algorithm,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'rotation_sequence': rotationSequence,
    };
  }

  factory LocalKeyMetadata.fromMap(Map<String, dynamic> map) {
    return LocalKeyMetadata(
      keyId: map['key_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      algorithm: map['algorithm'] as String? ?? 'AES-GCM-256',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      isActive: (map['is_active'] is bool)
          ? map['is_active'] as bool
          : ((map['is_active'] as num?)?.toInt() ?? 1) == 1,
      rotationSequence: (map['rotation_sequence'] as num?)?.toInt() ?? 1,
    );
  }
}

class PrintJob {
  final String printJobId;
  final String clinicId;
  final String visitId;
  final String jobType; // "consultation_slip", "receipt"
  final String paperSize; // "A5", "A4"
  final int reprintCount;
  final String status; // "pending", "rendered", "printed", "failed"
  final DateTime createdAt;
  final DateTime? printedAt;

  const PrintJob({
    required this.printJobId,
    required this.clinicId,
    required this.visitId,
    this.jobType = 'consultation_slip',
    this.paperSize = 'A5',
    this.reprintCount = 0,
    this.status = 'pending',
    required this.createdAt,
    this.printedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'print_job_id': printJobId,
      'clinic_id': clinicId,
      'visit_id': visitId,
      'job_type': jobType,
      'paper_size': paperSize,
      'reprint_count': reprintCount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'printed_at': printedAt?.toIso8601String(),
    };
  }

  factory PrintJob.fromMap(Map<String, dynamic> map) {
    return PrintJob(
      printJobId: map['print_job_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      visitId: map['visit_id']?.toString() ?? '',
      jobType: map['job_type'] as String? ?? 'consultation_slip',
      paperSize: map['paper_size'] as String? ?? 'A5',
      reprintCount: (map['reprint_count'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'pending',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      printedAt: map['printed_at'] != null
          ? DateTime.tryParse(map['printed_at'].toString())
          : null,
    );
  }
}

class BackupManifest {
  final String backupId;
  final String clinicId;
  final String deviceId;
  final DateTime backupTimestamp;
  final String schemaVersion;
  final String recordCountsJson;
  final String ciphertextSha256;
  final String? driveFileId;
  final DateTime? verifiedAt;
  final String verificationStatus; // "unverified", "verified", "failed"

  const BackupManifest({
    required this.backupId,
    required this.clinicId,
    required this.deviceId,
    required this.backupTimestamp,
    this.schemaVersion = '1.0.0',
    required this.recordCountsJson,
    required this.ciphertextSha256,
    this.driveFileId,
    this.verifiedAt,
    this.verificationStatus = 'unverified',
  });

  Map<String, dynamic> toMap() {
    return {
      'backup_id': backupId,
      'clinic_id': clinicId,
      'device_id': deviceId,
      'backup_timestamp': backupTimestamp.toIso8601String(),
      'schema_version': schemaVersion,
      'record_counts_json': recordCountsJson,
      'ciphertext_sha256': ciphertextSha256,
      'drive_file_id': driveFileId,
      'verified_at': verifiedAt?.toIso8601String(),
      'verification_status': verificationStatus,
    };
  }

  factory BackupManifest.fromMap(Map<String, dynamic> map) {
    return BackupManifest(
      backupId: map['backup_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      deviceId: map['device_id']?.toString() ?? '',
      backupTimestamp: map['backup_timestamp'] != null
          ? (DateTime.tryParse(map['backup_timestamp'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      schemaVersion: map['schema_version'] as String? ?? '1.0.0',
      recordCountsJson: map['record_counts_json'] as String? ?? '{}',
      ciphertextSha256: map['ciphertext_sha256'] as String? ?? '',
      driveFileId: map['drive_file_id'] as String?,
      verifiedAt: map['verified_at'] != null
          ? DateTime.tryParse(map['verified_at'].toString())
          : null,
      verificationStatus: map['verification_status'] as String? ?? 'unverified',
    );
  }
}

/// SENSITIVE CLINICAL BOUNDARY ISOLATION
/// Patient-reported reason for visit is stored separately from ordinary spreadsheet sync
/// and encrypted with the clinic's local AES-GCM key.
class ReasonForVisitSecret {
  final String refId;
  final String clinicId;
  final String patientId;
  final String ciphertextBase64;
  final String ivBase64;
  final DateTime createdAt;

  const ReasonForVisitSecret({
    required this.refId,
    required this.clinicId,
    required this.patientId,
    required this.ciphertextBase64,
    required this.ivBase64,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'ref_id': refId,
      'clinic_id': clinicId,
      'patient_id': patientId,
      'ciphertext_base64': ciphertextBase64,
      'iv_base64': ivBase64,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReasonForVisitSecret.fromMap(Map<String, dynamic> map) {
    return ReasonForVisitSecret(
      refId: map['ref_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      ciphertextBase64: map['ciphertext_base64']?.toString() ?? '',
      ivBase64: map['iv_base64']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }
}

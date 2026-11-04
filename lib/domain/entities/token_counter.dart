// Apna Clinic - Token Counter Entity
// Primary source of truth: TRD Section 7 `Token_Counters`

class TokenCounter {
  final String counterId;
  final String clinicId;
  final String doctorId;
  final String localDate; // YYYY-MM-DD
  final String scopeKey; // {clinic_id}:{doctor_id}:{local_date}
  final int lastIssuedToken;
  final String primaryDeviceId;
  final String? checkpointEventId;
  final DateTime checkpointAt;

  const TokenCounter({
    required this.counterId,
    required this.clinicId,
    required this.doctorId,
    required this.localDate,
    required this.scopeKey,
    required this.lastIssuedToken,
    required this.primaryDeviceId,
    this.checkpointEventId,
    required this.checkpointAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'counter_id': counterId,
      'clinic_id': clinicId,
      'doctor_id': doctorId,
      'local_date': localDate,
      'scope_key': scopeKey,
      'last_issued_token': lastIssuedToken,
      'primary_device_id': primaryDeviceId,
      'checkpoint_event_id': checkpointEventId,
      'checkpoint_at': checkpointAt.toIso8601String(),
    };
  }

  factory TokenCounter.fromMap(Map<String, dynamic> map) {
    return TokenCounter(
      counterId: map['counter_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      doctorId: map['doctor_id']?.toString() ?? '',
      localDate: map['local_date']?.toString() ?? '',
      scopeKey: map['scope_key']?.toString() ?? '',
      lastIssuedToken: (map['last_issued_token'] as num?)?.toInt() ?? 0,
      primaryDeviceId: map['primary_device_id']?.toString() ?? '',
      checkpointEventId: map['checkpoint_event_id'] as String?,
      checkpointAt: map['checkpoint_at'] != null
          ? (DateTime.tryParse(map['checkpoint_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }

  TokenCounter copyWith({
    int? lastIssuedToken,
    String? checkpointEventId,
    DateTime? checkpointAt,
  }) {
    return TokenCounter(
      counterId: counterId,
      clinicId: clinicId,
      doctorId: doctorId,
      localDate: localDate,
      scopeKey: scopeKey,
      lastIssuedToken: lastIssuedToken ?? this.lastIssuedToken,
      primaryDeviceId: primaryDeviceId,
      checkpointEventId: checkpointEventId ?? this.checkpointEventId,
      checkpointAt: checkpointAt ?? DateTime.now().toUtc(),
    );
  }
}

// Apna Clinic - Patient History Index Entry Model
// Primary source of truth: Feature PRD Section 7.1 & Feature TRD Section 5.2

class PatientHistoryIndexEntry {
  final String clinicId;
  final String patientId;
  final String yearMonth; // Format: YYYY-MM
  final String recordType; // 'visit', 'appointment', 'billing', 'payment'
  final String firstRecordAt;
  final String lastRecordAt;
  final int recordCount;
  final String lastUpdatedAt;

  const PatientHistoryIndexEntry({
    required this.clinicId,
    required this.patientId,
    required this.yearMonth,
    required this.recordType,
    required this.firstRecordAt,
    required this.lastRecordAt,
    required this.recordCount,
    required this.lastUpdatedAt,
  });

  String get compositeKey => '$clinicId:$patientId:$yearMonth:$recordType';

  Map<String, dynamic> toMap() {
    return {
      'clinic_id': clinicId,
      'patient_id': patientId,
      'year_month': yearMonth,
      'record_type': recordType,
      'first_record_at': firstRecordAt,
      'last_record_at': lastRecordAt,
      'record_count': recordCount,
      'last_updated_at': lastUpdatedAt,
    };
  }

  factory PatientHistoryIndexEntry.fromMap(Map<String, dynamic> map) {
    return PatientHistoryIndexEntry(
      clinicId: map['clinic_id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      yearMonth: map['year_month']?.toString() ?? '',
      recordType: map['record_type']?.toString() ?? 'visit',
      firstRecordAt: map['first_record_at']?.toString() ?? '',
      lastRecordAt: map['last_record_at']?.toString() ?? '',
      recordCount: int.tryParse(map['record_count']?.toString() ?? '1') ?? 1,
      lastUpdatedAt: map['last_updated_at']?.toString() ?? '',
    );
  }

  List<dynamic> toRow() {
    return [
      clinicId,
      patientId,
      yearMonth,
      recordType,
      firstRecordAt,
      lastRecordAt,
      recordCount,
      lastUpdatedAt,
    ];
  }

  factory PatientHistoryIndexEntry.fromRow(List<dynamic> row) {
    return PatientHistoryIndexEntry(
      clinicId: row.isNotEmpty ? row[0].toString() : '',
      patientId: row.length > 1 ? row[1].toString() : '',
      yearMonth: row.length > 2 ? row[2].toString() : '',
      recordType: row.length > 3 ? row[3].toString() : 'visit',
      firstRecordAt: row.length > 4 ? row[4].toString() : '',
      lastRecordAt: row.length > 5 ? row[5].toString() : '',
      recordCount: row.length > 6 ? int.tryParse(row[6].toString()) ?? 1 : 1,
      lastUpdatedAt: row.length > 7 ? row[7].toString() : '',
    );
  }

  PatientHistoryIndexEntry copyWith({
    String? clinicId,
    String? patientId,
    String? yearMonth,
    String? recordType,
    String? firstRecordAt,
    String? lastRecordAt,
    int? recordCount,
    String? lastUpdatedAt,
  }) {
    return PatientHistoryIndexEntry(
      clinicId: clinicId ?? this.clinicId,
      patientId: patientId ?? this.patientId,
      yearMonth: yearMonth ?? this.yearMonth,
      recordType: recordType ?? this.recordType,
      firstRecordAt: firstRecordAt ?? this.firstRecordAt,
      lastRecordAt: lastRecordAt ?? this.lastRecordAt,
      recordCount: recordCount ?? this.recordCount,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}


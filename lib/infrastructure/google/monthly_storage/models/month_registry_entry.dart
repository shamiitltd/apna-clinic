// Apna Clinic - Monthly Workbook Registry Entry Model
// Primary source of truth: Feature PRD Section 7.1 & Feature TRD Section 5.2

class MonthRegistryEntry {
  final String clinicId;
  final String yearMonth; // Format: YYYY-MM (e.g. '2026-11')
  final String spreadsheetId;
  final String status; // 'ACTIVE', 'PROVISIONING', 'ARCHIVED', 'ERROR'
  final String schemaVersion;
  final String createdAt;
  final String createdBy;
  final String lastVerifiedAt;

  const MonthRegistryEntry({
    required this.clinicId,
    required this.yearMonth,
    required this.spreadsheetId,
    this.status = 'ACTIVE',
    this.schemaVersion = '1.0.0',
    required this.createdAt,
    required this.createdBy,
    required this.lastVerifiedAt,
  });

  String get compositeKey => '$clinicId:$yearMonth';

  Map<String, dynamic> toMap() {
    return {
      'clinic_id': clinicId,
      'year_month': yearMonth,
      'spreadsheet_id': spreadsheetId,
      'status': status,
      'schema_version': schemaVersion,
      'created_at': createdAt,
      'created_by': createdBy,
      'last_verified_at': lastVerifiedAt,
    };
  }

  factory MonthRegistryEntry.fromMap(Map<String, dynamic> map) {
    return MonthRegistryEntry(
      clinicId: map['clinic_id']?.toString() ?? '',
      yearMonth: map['year_month']?.toString() ?? '',
      spreadsheetId: map['spreadsheet_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'ACTIVE',
      schemaVersion: map['schema_version']?.toString() ?? '1.0.0',
      createdAt: map['created_at']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      lastVerifiedAt: map['last_verified_at']?.toString() ?? '',
    );
  }

  List<dynamic> toRow() {
    return [
      clinicId,
      yearMonth,
      spreadsheetId,
      status,
      schemaVersion,
      createdAt,
      createdBy,
      lastVerifiedAt,
    ];
  }

  factory MonthRegistryEntry.fromRow(List<dynamic> row) {
    return MonthRegistryEntry(
      clinicId: row.isNotEmpty ? row[0].toString() : '',
      yearMonth: row.length > 1 ? row[1].toString() : '',
      spreadsheetId: row.length > 2 ? row[2].toString() : '',
      status: row.length > 3 ? row[3].toString() : 'ACTIVE',
      schemaVersion: row.length > 4 ? row[4].toString() : '1.0.0',
      createdAt: row.length > 5 ? row[5].toString() : '',
      createdBy: row.length > 6 ? row[6].toString() : '',
      lastVerifiedAt: row.length > 7 ? row[7].toString() : '',
    );
  }

  MonthRegistryEntry copyWith({
    String? clinicId,
    String? yearMonth,
    String? spreadsheetId,
    String? status,
    String? schemaVersion,
    String? createdAt,
    String? createdBy,
    String? lastVerifiedAt,
  }) {
    return MonthRegistryEntry(
      clinicId: clinicId ?? this.clinicId,
      yearMonth: yearMonth ?? this.yearMonth,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      status: status ?? this.status,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }
}


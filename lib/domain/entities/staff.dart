// Apna Clinic - Staff Entity
// Primary source of truth: TRD Section 7 `Staff` & PRD Section 5 `M08 — Staff and access (P0)`
// Supports salted SHA-256 PIN authentication for single shared reception workstation.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/permissions/roles.dart';

class Staff {
  final String staffId;
  final String clinicId;
  final String displayName;
  final UserRole role;
  final String phone;
  final String email;
  final bool active;
  final List<String> assignedDoctorIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? pinHash;
  final String? pinSalt;

  const Staff({
    required this.staffId,
    required this.clinicId,
    required this.displayName,
    required this.role,
    this.phone = '',
    this.email = '',
    this.active = true,
    this.assignedDoctorIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.pinHash,
    this.pinSalt,
  });

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty && pinSalt != null;

  /// Verifies entered PIN against stored salted SHA-256 hash
  bool verifyPin(String pin) {
    if (!hasPin || pin.isEmpty) return false;
    final hash = sha256.convert(utf8.encode('$pinSalt:${pin.trim()}')).toString();
    return hash == pinHash;
  }

  /// Cryptographically derives a 16-byte random salt and SHA-256 hash for a PIN
  static Map<String, String> generatePinHash(String pin) {
    final rand = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final salt = base64Encode(saltBytes);
    final hash = sha256.convert(utf8.encode('$salt:${pin.trim()}')).toString();
    return {'pin_hash': hash, 'pin_salt': salt};
  }

  Map<String, dynamic> toMap() {
    return {
      'staff_id': staffId,
      'clinic_id': clinicId,
      'display_name': displayName,
      'role': role.wireValue,
      'phone': phone,
      'email': email,
      'active': active ? 1 : 0,
      'assigned_doctor_ids_json': jsonEncode(assignedDoctorIds),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'pin_hash': pinHash,
      'pin_salt': pinSalt,
    };
  }

  factory Staff.fromMap(Map<String, dynamic> map) {
    List<String> doctors = [];
    final rawDocs = map['assigned_doctor_ids_json'];
    if (rawDocs is String && rawDocs.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDocs);
        if (decoded is List) {
          doctors = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawDocs is List) {
      doctors = rawDocs.map((e) => e.toString()).toList();
    }

    return Staff(
      staffId: map['staff_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      displayName: map['display_name'] as String? ?? '',
      role: UserRole.fromWire(map['role'] as String? ?? 'receptionist'),
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      active: (map['active'] is bool)
          ? map['active'] as bool
          : ((map['active'] as num?)?.toInt() ?? 1) == 1,
      assignedDoctorIds: doctors,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'].toString())
          : null,
      pinHash: map['pin_hash'] as String?,
      pinSalt: map['pin_salt'] as String?,
    );
  }

  Staff copyWith({
    String? displayName,
    UserRole? role,
    String? phone,
    String? email,
    bool? active,
    List<String>? assignedDoctorIds,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? pinHash,
    String? pinSalt,
  }) {
    return Staff(
      staffId: staffId,
      clinicId: clinicId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      active: active ?? this.active,
      assignedDoctorIds: assignedDoctorIds ?? this.assignedDoctorIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      deletedAt: deletedAt ?? this.deletedAt,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
    );
  }
}

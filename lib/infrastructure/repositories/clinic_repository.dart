// Apna Clinic - Concrete Clinic Repository
// Implementation of IClinicRepository backed by LocalDatabase

import 'dart:convert';

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_clinic_repository.dart';
import '../database/local_database.dart';

class ClinicRepository implements IClinicRepository {
  final LocalDatabase _db;

  ClinicRepository(this._db);

  @override
  Future<Clinic?> getClinic(String clinicId) async {
    final record = _db.get('Clinic_Config', clinicId);
    if (record != null) {
      return Clinic.fromMap(record);
    }
    // Fallback: check if ANY clinic config exists in local database
    final allClinics = _db.query('Clinic_Config');
    if (allClinics.isNotEmpty) {
      return Clinic.fromMap(allClinics.first);
    }
    return null;
  }

  @override
  Future<void> saveClinic(Clinic clinic) async {
    final existing = _db.get('Clinic_Config', clinic.clinicId) ?? {};
    final mergedMap = {
      ...existing,
      ...clinic.toMap(),
    };
    await _db.upsert('Clinic_Config', clinic.clinicId, mergedMap);

    // Stage 01_SETTINGS into sync_outbox so settings are persisted to Google Sheets
    final settingsMap = {
      'CLINIC_NAME': {'cat': 'CLINIC', 'val': clinic.displayName, 'desc': 'Clinic display name'},
      'LEGAL_NAME': {'cat': 'CLINIC', 'val': clinic.legalName, 'desc': 'Registered business entity'},
      'OWNER_NAME': {'cat': 'CLINIC', 'val': clinic.ownerName, 'desc': 'Clinic owner / doctor in-charge'},
      'CONTACT_PHONE': {'cat': 'COMMUNICATION', 'val': clinic.contactPhone, 'desc': 'Primary reception phone'},
      'CONTACT_EMAIL': {'cat': 'COMMUNICATION', 'val': clinic.contactEmail, 'desc': 'Official contact email'},
      'ADDRESS': {'cat': 'LOCATION', 'val': clinic.addressLine1, 'desc': 'Physical street address'},
      'ADDRESS_LINE1': {'cat': 'LOCATION', 'val': clinic.addressLine1, 'desc': 'Physical street address line 1'},
      'ADDRESS_LINE2': {'cat': 'LOCATION', 'val': clinic.addressLine2, 'desc': 'Physical street address line 2'},
      'CITY': {'cat': 'LOCATION', 'val': clinic.city, 'desc': 'City'},
      'STATE': {'cat': 'LOCATION', 'val': clinic.state, 'desc': 'State / Province'},
      'PINCODE': {'cat': 'LOCATION', 'val': clinic.pincode, 'desc': 'Postal Pincode'},
      'CURRENCY': {'cat': 'FINANCIAL', 'val': clinic.currency, 'desc': 'Operational currency symbol'},
      'TAX_ID': {'cat': 'FINANCIAL', 'val': clinic.taxRegistrationNumber ?? '', 'desc': 'GST or Registration Number'},
      'LOGO_DRIVE_FILE_ID': {'cat': 'BRANDING', 'val': clinic.logoDriveFileId ?? '', 'desc': 'Branding logo Google Drive file ID'},
      'TAGLINE': {'cat': 'CLINIC', 'val': 'Caring for your health', 'desc': 'Clinic motto / tagline'},
      'CONSULTATION_VALIDITY_DAYS': {'cat': 'CLINICAL', 'val': '7', 'desc': 'Free follow-up grace period in days'},
      'MAX_TOKENS_PER_DAY': {'cat': 'OPERATIONAL', 'val': '100', 'desc': 'Daily OPD patient capacity'},
    };

    final now = DateTime.now().toUtc();
    for (final entry in settingsMap.entries) {
      if (entry.value['val'] != null && entry.value['val']!.toString().isNotEmpty) {
        final settingId = 'SET-${entry.key}';
        final payload = {
          'setting_id': settingId,
          'setting_category': entry.value['cat'],
          'setting_key': entry.key.toLowerCase(),
          'setting_value': entry.value['val'],
          'data_type': 'STRING',
          'description': entry.value['desc'],
          'is_system': 'FALSE',
          'updated_at': now.toIso8601String(),
        };
        final outboxEvent = SyncOutboxEvent(
          outboxEventId: 'outbox_setting_${clinic.clinicId}_${entry.key}',
          clinicId: clinic.clinicId,
          entityType: '01_SETTINGS',
          entityId: settingId,
          operation: OutboxOperation.insert,
          payloadJson: jsonEncode(payload),
          createdAt: now,
          idempotencyKey: 'setting_${clinic.clinicId}_${entry.key}',
        );
        await _db.upsert('sync_outbox', outboxEvent.outboxEventId, outboxEvent.toMap());
      }
    }
  }

  @override
  Future<List<Doctor>> getDoctors(
    String clinicId, {
    bool activeOnly = false,
  }) async {
    var records = _db.query(
      'Doctors',
      where: (r) {
        if (r['clinic_id'] != clinicId) {
          return false;
        }
        if (r['deleted_at'] != null) {
          return false;
        }
        if (activeOnly && (r['active'] == 0 || r['active'] == false)) {
          return false;
        }
        return true;
      },
    );
    if (records.isEmpty) {
      // Fallback: query Doctors table if clinicId was modified or in transit
      records = _db.query(
        'Doctors',
        where: (r) {
          if (r['deleted_at'] != null) return false;
          if (activeOnly && (r['active'] == 0 || r['active'] == false)) {
            return false;
          }
          return true;
        },
      );
    }
    return records.map((r) => Doctor.fromMap(r)).toList();
  }

  @override
  Future<Doctor?> getDoctor(String clinicId, String doctorId) async {
    final record = _db.get('Doctors', doctorId);
    if (record != null && record['deleted_at'] == null) {
      return Doctor.fromMap(record);
    }
    final byId = _db.query(
      'Doctors',
      where: (r) => r['doctor_id'] == doctorId && r['deleted_at'] == null,
    );
    if (byId.isNotEmpty) {
      return Doctor.fromMap(byId.first);
    }
    final all = await getDoctors(clinicId, activeOnly: true);
    if (all.isNotEmpty) {
      return all.first;
    }
    final now = DateTime.now().toUtc();
    return Doctor(
      doctorId: doctorId.isNotEmpty ? doctorId : 'doc_primary',
      clinicId: clinicId,
      displayName: 'Doctor In-Charge',
      qualificationText: 'MBBS',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> saveDoctor(Doctor doctor) async {
    await _db.upsert('Doctors', doctor.doctorId, doctor.toMap());

    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    // 1. Stage 04_DOCTORS
    final docOutbox = SyncOutboxEvent(
      outboxEventId: 'outbox_doctor_${doctor.doctorId}',
      clinicId: doctor.clinicId,
      entityType: '04_DOCTORS',
      entityId: doctor.doctorId,
      operation: OutboxOperation.insert,
      payloadJson: jsonEncode(doctor.toMap()),
      createdAt: now,
      idempotencyKey: 'doctor_${doctor.doctorId}',
    );
    await _db.upsert('sync_outbox', docOutbox.outboxEventId, docOutbox.toMap());

    // 2. Stage 07_DOCTOR_SCHEDULES
    final scheduleId = 'SCHED-${doctor.doctorId}-ALL';
    final schedulePayload = {
      'schedule_id': scheduleId,
      'doctor_id': doctor.doctorId,
      'day_of_week': 'MONDAY_TO_SATURDAY',
      'start_time': '09:00',
      'end_time': '18:00',
      'slot_duration': '15',
      'break_start': '13:00',
      'break_end': '14:00',
      'room_id': doctor.roomLabel.isNotEmpty ? doctor.roomLabel : 'ROOM-01',
      'maximum_patients': '40',
      'status': doctor.active ? 'ACTIVE' : 'INACTIVE',
      'effective_from': nowIso.split('T').first,
      'created_at': nowIso,
      'updated_at': nowIso,
    };
    final schedOutbox = SyncOutboxEvent(
      outboxEventId: 'outbox_sched_${doctor.doctorId}',
      clinicId: doctor.clinicId,
      entityType: '07_DOCTOR_SCHEDULES',
      entityId: scheduleId,
      operation: OutboxOperation.insert,
      payloadJson: jsonEncode(schedulePayload),
      createdAt: now,
      idempotencyKey: 'sched_${doctor.doctorId}',
    );
    await _db.upsert('sync_outbox', schedOutbox.outboxEventId, schedOutbox.toMap());

    // 3. Stage 16_ROOMS
    final roomId = doctor.roomLabel.isNotEmpty ? doctor.roomLabel : 'ROOM-01';
    final roomPayload = {
      'room_id': roomId,
      'room_code': roomId,
      'room_name': 'OPD Consultation Room ($roomId)',
      'room_type': 'CONSULTATION',
      'floor': '1',
      'status': 'AVAILABLE',
      'assigned_doctor_id': doctor.doctorId,
      'notes': 'Doctor ${doctor.displayName} consultation chamber',
      'created_at': nowIso,
      'updated_at': nowIso,
    };
    final roomOutbox = SyncOutboxEvent(
      outboxEventId: 'outbox_room_$roomId',
      clinicId: doctor.clinicId,
      entityType: '16_ROOMS',
      entityId: roomId,
      operation: OutboxOperation.insert,
      payloadJson: jsonEncode(roomPayload),
      createdAt: now,
      idempotencyKey: 'room_$roomId',
    );
    await _db.upsert('sync_outbox', roomOutbox.outboxEventId, roomOutbox.toMap());
  }

  @override
  Future<List<Staff>> getStaffMembers(
    String clinicId, {
    bool activeOnly = false,
  }) async {
    final records = _db.query(
      'Staff',
      where: (r) {
        if (r['clinic_id'] != clinicId) {
          return false;
        }
        if (r['deleted_at'] != null) {
          return false;
        }
        if (activeOnly && (r['active'] == 0 || r['active'] == false)) {
          return false;
        }
        return true;
      },
    );
    return records.map((r) => Staff.fromMap(r)).toList();
  }

  @override
  Future<Staff?> getStaff(String clinicId, String staffId) async {
    final record = _db.get('Staff', staffId);
    if (record == null || record['clinic_id'] != clinicId) return null;
    if (record['deleted_at'] != null) return null;
    return Staff.fromMap(record);
  }

  @override
  Future<Staff?> getStaffByEmail(String clinicId, String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    final records = _db.query(
      'Staff',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        if (r['deleted_at'] != null) return false;
        final staffEmail = (r['email'] as String? ?? '').trim().toLowerCase();
        return staffEmail == cleanEmail;
      },
    );
    if (records.isEmpty) return null;
    return Staff.fromMap(records.first);
  }

  @override
  Future<void> saveStaff(Staff staff) async {
    await _db.upsert('Staff', staff.staffId, staff.toMap());

    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    // 1. Stage 02_USERS
    final userOutbox = SyncOutboxEvent(
      outboxEventId: 'outbox_staff_${staff.staffId}',
      clinicId: staff.clinicId,
      entityType: '02_USERS',
      entityId: staff.staffId,
      operation: OutboxOperation.insert,
      payloadJson: jsonEncode(staff.toMap()),
      createdAt: now,
      idempotencyKey: 'staff_${staff.staffId}',
    );
    await _db.upsert('sync_outbox', userOutbox.outboxEventId, userOutbox.toMap());

    // 2. Stage 03_ROLES
    final roleId = 'ROLE_${staff.role.name.toUpperCase()}';
    final rolePayload = {
      'role_id': roleId,
      'role_code': staff.role.wireValue.toUpperCase(),
      'role_name': staff.role.name.toUpperCase(),
      'description': 'Staff role for ${staff.role.name}',
      'permissions_summary': staff.role.name == 'owner'
          ? 'ALL_ACCESS,BILLING,REPORTS,STAFF_MGMT'
          : (staff.role.name == 'doctor'
              ? 'CONSULTATIONS,QUEUE,MEDICAL_RECORDS,FOLLOWUPS'
              : 'PATIENTS,APPOINTMENTS,QUEUE_CHECKIN,PAYMENTS'),
      'status': staff.active ? 'ACTIVE' : 'INACTIVE',
      'created_at': nowIso,
      'updated_at': nowIso,
    };
    final roleOutbox = SyncOutboxEvent(
      outboxEventId: 'outbox_role_${staff.role.name}',
      clinicId: staff.clinicId,
      entityType: '03_ROLES',
      entityId: roleId,
      operation: OutboxOperation.insert,
      payloadJson: jsonEncode(rolePayload),
      createdAt: now,
      idempotencyKey: 'role_${staff.role.name}',
    );
    await _db.upsert('sync_outbox', roleOutbox.outboxEventId, roleOutbox.toMap());
  }

  @override
  Future<void> deleteStaff(String staffId) async {
    await _db.delete('Staff', staffId);
  }
}

// Apna Clinic - Module 12: Follow-up Reminders Test Suite
// Verifies PRD Section 5 M12, Section 6.2, TRD Section 7 `Followups`:
// 1. Administrative Follow-up scheduling without clinical treatment history or prescriptions.
// 2. DPDP reminder consent and preferred communication channels (SMS / WhatsApp / Call).
// 3. Status transitions & lifecycle tracking (scheduled -> completed / cancelled / missed).
// 4. Due date queries: Due today, upcoming (7 days), overdue detection.
// 5. Reminder notification logging with immutable Audit_Events trail.
// 6. Atomic conversion of Follow-up into a confirmed Appointment slot.
// 7. Privacy boundary: CSV export contains masked phones and zero clinical symptoms/diagnoses.
// 8. Strict RBAC: Owner, Receptionist, Doctor granted manageFollowups; Accountant denied.

import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/core/utils/phone_normalizer.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/repositories/followup_repository.dart';

void main() {
  group('MODULE 12 — FOLLOW-UP REMINDERS (PRD M12)', () {
    late LocalDatabase memoryDb;
    late FollowupRepository followupRepo;

    const testClinicId = 'clinic_m12_test';
    const testDoctorId = 'doc_anita_01';
    const testPatientId = 'pat_ramesh_01';
    const testStaffId = 'staff_rec_01';

    setUp(() async {
      memoryDb = LocalDatabase(MemoryStorageAdapter());
      await memoryDb.initialize();

      final now = DateTime.now().toUtc();

      // Seed Clinic
      final clinic = Clinic(
        clinicId: testClinicId,
        legalName: 'Apex Health Clinic',
        displayName: 'Apex Clinic',
        ownerName: 'Dr. Anita Desai',
        contactPhone: '9876543210',
        contactEmail: 'anita@apexclinic.com',
        addressLine1: '12 MG Road',
        city: 'Indore',
        district: 'Indore',
        state: 'Madhya Pradesh',
        pincode: '452001',
        createdAt: now,
        updatedAt: now,
      );
      await memoryDb.upsert('Clinic_Config', testClinicId, clinic.toMap());

      // Seed Doctor
      final doctor = Doctor(
        doctorId: testDoctorId,
        clinicId: testClinicId,
        displayName: 'Dr. Anita Desai',
        qualificationText: 'MBBS, MD',
        specialtyLabel: 'General Physician',
        defaultFee: 50000,
        consultationDurationMinutes: 15,
        active: true,
        createdAt: now,
        updatedAt: now,
      );
      await memoryDb.upsert('Doctors', testDoctorId, doctor.toMap());

      // Seed Patient
      final patient = Patient(
        patientId: testPatientId,
        clinicId: testClinicId,
        patientNumber: 'P-1001',
        fullName: 'Ramesh Patel',
        phoneOptional: '9876543210',
        createdAt: now,
        updatedAt: now,
      );
      await memoryDb.upsert('Patients', testPatientId, patient.toMap());

      followupRepo = FollowupRepository(memoryDb);
    });

    test('1. Administrative Scheduling: Creates follow-up without storing clinical prescriptions or symptoms', () async {
      final now = DateTime.now().toUtc();
      final followup = Followup(
        followupId: 'flw_001',
        clinicId: testClinicId,
        patientId: testPatientId,
        sourceVisitIdOptional: 'vis_initial_01',
        doctorId: testDoctorId,
        dueDate: '2026-11-07',
        administrativeNoteOptional: 'BP check & review after 7 days',
        reminderConsent: true,
        channelPreference: 'whatsapp',
        createdAt: now,
        updatedAt: now,
      );

      await followupRepo.scheduleFollowup(followup);

      final retrieved = await followupRepo.getFollowupById(testClinicId, 'flw_001');
      expect(retrieved, isNotNull);
      expect(retrieved!.dueDate, '2026-11-07');
      expect(retrieved.status, 'scheduled');
      expect(retrieved.reminderConsent, isTrue);
      expect(retrieved.channelPreference, 'whatsapp');
      expect(retrieved.administrativeNoteOptional, 'BP check & review after 7 days');

      // Verify Audit_Events entry
      final audits = memoryDb.query(
        'Audit_Events',
        where: (r) => r['action'] == 'followup.schedule' && r['entity_id'] == 'flw_001',
      );
      expect(audits.length, 1);

      // Verify sync_outbox staging
      final outbox = memoryDb.query(
        'sync_outbox',
        where: (r) => r['entity_id'] == 'flw_001' && r['operation'] == 'insert',
      );
      expect(outbox.length, 1);
    });

    test('2. DPDP Reminder Consent: Supports explicit consent toggle and multi-channel preferences', () async {
      final now = DateTime.now().toUtc();

      // Consent granted with WhatsApp preference
      final flwConsentYes = Followup(
        followupId: 'flw_consent_yes',
        clinicId: testClinicId,
        patientId: testPatientId,
        doctorId: testDoctorId,
        dueDate: '2026-11-10',
        reminderConsent: true,
        channelPreference: 'whatsapp',
        createdAt: now,
        updatedAt: now,
      );

      // Consent not granted (SMS opt-out)
      final flwConsentNo = Followup(
        followupId: 'flw_consent_no',
        clinicId: testClinicId,
        patientId: testPatientId,
        doctorId: testDoctorId,
        dueDate: '2026-11-10',
        reminderConsent: false,
        channelPreference: 'call',
        createdAt: now,
        updatedAt: now,
      );

      await followupRepo.scheduleFollowup(flwConsentYes);
      await followupRepo.scheduleFollowup(flwConsentNo);

      final retrievedYes = await followupRepo.getFollowupById(testClinicId, 'flw_consent_yes');
      final retrievedNo = await followupRepo.getFollowupById(testClinicId, 'flw_consent_no');

      expect(retrievedYes!.reminderConsent, isTrue);
      expect(retrievedYes.channelPreference, 'whatsapp');

      expect(retrievedNo!.reminderConsent, isFalse);
      expect(retrievedNo.channelPreference, 'call');
    });

    test('3. Date Categorization: Correctly evaluates Due Today, Upcoming, and Overdue statuses', () {
      final now = DateTime.now().toUtc();
      const today = '2026-10-31';

      final dueToday = Followup(
        followupId: 'flw_today',
        clinicId: testClinicId,
        patientId: testPatientId,
        doctorId: testDoctorId,
        dueDate: today,
        createdAt: now,
        updatedAt: now,
      );

      final overdue = Followup(
        followupId: 'flw_overdue',
        clinicId: testClinicId,
        patientId: testPatientId,
        doctorId: testDoctorId,
        dueDate: '2026-10-25',
        createdAt: now,
        updatedAt: now,
      );

      final upcoming = Followup(
        followupId: 'flw_upcoming',
        clinicId: testClinicId,
        patientId: testPatientId,
        doctorId: testDoctorId,
        dueDate: '2026-11-05',
        createdAt: now,
        updatedAt: now,
      );

      expect(dueToday.isDueToday(today), isTrue);
      expect(dueToday.isOverdue(today), isFalse);

      expect(overdue.isOverdue(today), isTrue);
      expect(overdue.isDueToday(today), isFalse);

      expect(upcoming.isDueToday(today), isFalse);
      expect(upcoming.isOverdue(today), isFalse);
    });

    test('4. Date Range & Doctor Queries: Filters follow-ups by due date range and doctor scope', () async {
      final now = DateTime.now().toUtc();

      for (int i = 1; i <= 5; i++) {
        await followupRepo.scheduleFollowup(Followup(
          followupId: 'flw_range_$i',
          clinicId: testClinicId,
          patientId: testPatientId,
          doctorId: testDoctorId,
          dueDate: '2026-11-0$i',
          createdAt: now,
          updatedAt: now,
        ));
      }

      final range = await followupRepo.getFollowupsForDateRange(
        testClinicId,
        '2026-11-02',
        '2026-11-04',
      );
      expect(range.length, 3);
      expect(range.map((f) => f.dueDate).toList(), ['2026-11-02', '2026-11-03', '2026-11-04']);

      final doctorFollowups = await followupRepo.getFollowupsForDoctor(testClinicId, testDoctorId);
      expect(doctorFollowups.length, 5);
    });

    test('5. Reminder Notification Logging: Marks reminder sent with channel and timestamp audit trail', () async {
      final now = DateTime.now().toUtc();
      final followup = Followup(
        followupId: 'flw_notif_01',
        clinicId: testClinicId,
        patientId: testPatientId,
        doctorId: testDoctorId,
        dueDate: '2026-10-31',
        reminderConsent: true,
        channelPreference: 'sms',
        createdAt: now,
        updatedAt: now,
      );

      await followupRepo.scheduleFollowup(followup);

      await followupRepo.recordReminderNotification(
        clinicId: testClinicId,
        followupId: 'flw_notif_01',
        status: 'sent',
        channel: 'sms',
        actorId: testStaffId,
      );

      final updated = await followupRepo.getFollowupById(testClinicId, 'flw_notif_01');
      expect(updated!.reminderStatus, 'sent');
      expect(updated.reminderSentAt, isNotNull);

      // Verify Audit_Events entry
      final audits = memoryDb.query(
        'Audit_Events',
        where: (r) => r['action'] == 'followup.reminder_sent' && r['entity_id'] == 'flw_notif_01',
      );
      expect(audits.length, 1);
      expect(audits.first['reason_optional'], 'Reminder via sms: sent');
    });

    test('6. Convert Follow-up to Appointment: Atomically links appointment and marks follow-up completed', () async {
      final now = DateTime.now().toUtc();
      final followup = Followup(
        followupId: 'flw_convert_01',
        clinicId: testClinicId,
        patientId: testPatientId,
        doctorId: testDoctorId,
        dueDate: '2026-11-02',
        administrativeNoteOptional: 'Re-evaluation post medication',
        createdAt: now,
        updatedAt: now,
      );

      await followupRepo.scheduleFollowup(followup);

      // Create target appointment
      final appointment = Appointment(
        appointmentId: 'app_from_flw_01',
        clinicId: testClinicId,
        patientId: testPatientId,
        doctorId: testDoctorId,
        scheduledStartAt: DateTime.utc(2026, 11, 2, 10, 0),
        scheduledEndAt: DateTime.utc(2026, 11, 2, 10, 15),
        appointmentType: 'followup',
        status: AppointmentStatus.scheduled,
        bookingSource: 'reception_followup',
        createdByStaffId: testStaffId,
        createdAt: now,
        updatedAt: now,
      );

      await followupRepo.convertToAppointment(
        clinicId: testClinicId,
        followupId: 'flw_convert_01',
        appointment: appointment,
        actorId: testStaffId,
      );

      // Verify followup is completed and linked
      final updatedFollowup = await followupRepo.getFollowupById(testClinicId, 'flw_convert_01');
      expect(updatedFollowup!.status, 'completed');
      expect(updatedFollowup.convertedAppointmentIdOptional, 'app_from_flw_01');

      // Verify appointment is saved
      final appRecords = memoryDb.query(
        'Appointments',
        where: (r) => r['appointment_id'] == 'app_from_flw_01',
      );
      expect(appRecords.length, 1);
      expect(appRecords.first['appointment_type'], 'followup');
      expect(appRecords.first['booking_source'], 'reception_followup');
    });

    test('7. Privacy Boundary & CSV Export: Strictly preserves confidentiality with masked phones & zero clinical data', () async {
      final now = DateTime.now().toUtc();
      final followups = [
        Followup(
          followupId: 'flw_csv_01',
          clinicId: testClinicId,
          patientId: testPatientId,
          doctorId: testDoctorId,
          dueDate: '2026-11-05',
          administrativeNoteOptional: 'Annual checkup routine',
          reminderConsent: true,
          channelPreference: 'whatsapp',
          status: 'scheduled',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final patient = Patient(
        patientId: testPatientId,
        clinicId: testClinicId,
        patientNumber: 'P-1001',
        fullName: 'Ramesh Patel',
        phoneOptional: '9876543210',
        createdAt: now,
        updatedAt: now,
      );

      final doctor = Doctor(
        doctorId: testDoctorId,
        clinicId: testClinicId,
        displayName: 'Dr. Anita Desai',
        qualificationText: 'MBBS',
        specialtyLabel: 'General Physician',
        defaultFee: 50000,
        consultationDurationMinutes: 15,
        active: true,
        createdAt: now,
        updatedAt: now,
      );

      final csv = followupRepo.exportFollowupsToCsv(
        followups,
        {testPatientId: patient},
        {testDoctorId: doctor},
      );

      // Verify UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);

      // Verify headers
      expect(csv, contains('followup_id,due_date,patient_number,patient_name,patient_phone_masked,doctor_name,status,reminder_consent,channel_preference,reminder_status,reminder_sent_at,converted_appointment_id,administrative_note,created_at'));

      // Verify administrative content
      expect(csv, contains('flw_csv_01'));
      expect(csv, contains('2026-11-05'));
      expect(csv, contains('P-1001'));
      expect(csv, contains('Ramesh Patel'));
      expect(csv, contains('Dr. Anita Desai'));
      expect(csv, contains(PhoneNormalizer.mask('9876543210')));
      expect(csv, contains('Annual checkup routine'));

      // Strictly verify NO clinical keywords
      final lowerCsv = csv.toLowerCase();
      expect(lowerCsv.contains('diagnosis'), isFalse);
      expect(lowerCsv.contains('rx'), isFalse);
      expect(lowerCsv.contains('prescription'), isFalse);
      expect(lowerCsv.contains('symptoms'), isFalse);
    });

    test('8. Strict RBAC: Owner, Receptionist, Doctor have manageFollowups; Accountant strictly denied', () {
      final ownerAllowed = AuthorizationService.hasPermission(
        role: UserRole.owner,
        permission: AppPermission.manageFollowups,
      );
      expect(ownerAllowed, isTrue, reason: 'Owner must have permission to manage follow-ups');

      final receptionistAllowed = AuthorizationService.hasPermission(
        role: UserRole.receptionist,
        permission: AppPermission.manageFollowups,
      );
      expect(receptionistAllowed, isTrue, reason: 'Receptionist must have permission to manage follow-ups');

      final doctorAllowed = AuthorizationService.hasPermission(
        role: UserRole.doctor,
        permission: AppPermission.manageFollowups,
      );
      expect(doctorAllowed, isTrue, reason: 'Doctor must have permission to manage follow-ups');

      final accountantAllowed = AuthorizationService.hasPermission(
        role: UserRole.accountant,
        permission: AppPermission.manageFollowups,
      );
      expect(accountantAllowed, isFalse, reason: 'Accountant must be strictly denied access to follow-ups');
    });
  });
}

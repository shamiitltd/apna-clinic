import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/core/routing/app_router.dart';
import 'package:apna_clinic/core/utils/money.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/application/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 1 PRODUCTION BLOCKER FIXES — VERIFICATION SUITE', () {
    late LocalDatabase memoryDb;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      memoryDb = LocalDatabase(MemoryStorageAdapter());
      await memoryDb.initialize();

      container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(memoryDb),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      isClinicConfiguredOverride = null;
    });

    test('P0 / BUG-01: Empty database starts with 0 patients, 0 visits, 0 doctors (no auto-seeding)', () async {
      final patientRepo = container.read(patientRepositoryProvider);
      final visitRepo = container.read(visitRepositoryProvider);
      final clinicRepo = container.read(clinicRepositoryProvider);

      final patients = await patientRepo.searchPatients('test_clinic', '');
      final visits = await visitRepo.getVisitsForDate('test_clinic', '2026-10-04');
      final doctors = await clinicRepo.getDoctors('test_clinic');

      expect(patients, isEmpty, reason: 'Must not seed demo patients automatically');
      expect(visits, isEmpty, reason: 'Must not seed demo visits automatically');
      expect(doctors, isEmpty, reason: 'Must not seed fake doctors automatically');
    });

    test('P1 / BUG-03: Startup routing detects unconfigured clinic vs configured clinic', () async {
      final clinicRepo = container.read(clinicRepositoryProvider);

      // 1. Unconfigured state
      final unconfigured = await clinicRepo.getClinic('clinic-p1-test');
      expect(unconfigured, isNull);

      final isConfiguredInitially = memoryDb.query('Clinic_Config').isNotEmpty;
      expect(isConfiguredInitially, isFalse, reason: 'Unconfigured clinic must trigger onboarding redirect');

      // 2. Configure clinic
      final clinic = Clinic(
        clinicId: 'clinic-p1-test',
        legalName: 'Apollo Care',
        displayName: 'Apollo Care',
        ownerName: 'Dr. Sharma',
        contactPhone: '9876543210',
        contactEmail: 'care@apollo.in',
        addressLine1: '123 Health Street',
        city: 'New Delhi',
        district: 'New Delhi',
        state: 'Delhi',
        pincode: '110001',
        defaultConsultationFee: 50000,
        defaultPaperSize: 'A4',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await clinicRepo.saveClinic(clinic);

      // 3. Configured state
      final configured = await clinicRepo.getClinic('clinic-p1-test');
      expect(configured, isNotNull);
      expect(configured!.displayName, equals('Apollo Care'));

      final isConfiguredNow = memoryDb.query('Clinic_Config').isNotEmpty;
      expect(isConfiguredNow, isTrue, reason: 'Configured clinic must route to Dashboard');
    });

    test('P1 / BUG-02: Onboarding atomic persistence with integer Money (paise)', () async {
      final clinicRepo = container.read(clinicRepositoryProvider);
      final billingRepo = container.read(billingRepositoryProvider);

      const feePaise = 65000; // ₹650.00
      final feeMoney = Money.fromPaise(feePaise);
      expect(feeMoney.minorUnits, equals(65000));
      expect(feeMoney.formatted, equals('₹650.00'));

      final clinic = Clinic(
        clinicId: 'clinic-onboarded-01',
        legalName: 'LifeLine Family Clinic',
        displayName: 'LifeLine Family Clinic',
        ownerName: 'Dr. Aditi Verma',
        contactPhone: '9876501234',
        contactEmail: 'lifeline@clinic.com',
        addressLine1: 'Sector 14',
        city: 'Gurugram',
        district: 'Gurugram',
        state: 'Haryana',
        pincode: '122001',
        defaultConsultationFee: feeMoney.minorUnits,
        defaultPaperSize: 'A4',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final doctor = Doctor(
        doctorId: 'doc-onboarded-01',
        clinicId: clinic.clinicId,
        displayName: 'Dr. Aditi Verma',
        qualificationText: 'MBBS, MD (Medicine)',
        registrationNumber: 'MCI-987654',
        defaultFee: feeMoney.minorUnits,
        active: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final feeItem = FeeCatalog(
        feeId: 'CONSULT-GEN',
        clinicId: clinic.clinicId,
        feeCode: 'CONSULT-GEN',
        feeName: 'General Consultation',
        defaultAmountMinor: feeMoney.minorUnits,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save atomically
      await clinicRepo.saveClinic(clinic);
      await clinicRepo.saveDoctor(doctor);
      await billingRepo.saveFeeCatalogItem(feeItem);

      // Verify persistence
      final savedClinic = await clinicRepo.getClinic(clinic.clinicId);
      expect(savedClinic, isNotNull);
      expect(savedClinic!.displayName, equals('LifeLine Family Clinic'));
      expect(savedClinic.defaultConsultationFee, equals(65000));

      final savedDoctors = await clinicRepo.getDoctors(clinic.clinicId);
      expect(savedDoctors.length, equals(1));
      expect(savedDoctors.first.displayName, equals('Dr. Aditi Verma'));
      expect(savedDoctors.first.defaultFee, equals(65000));
      expect(savedDoctors.first.registrationNumber, equals('MCI-987654'));

      final savedFees = await billingRepo.getFeeCatalog(clinic.clinicId);
      expect(savedFees.any((f) => f.feeCode == 'CONSULT-GEN' && f.defaultAmountMinor == 65000), isTrue);
    });

    test('P2 / Role Persistence: switchRole persists wire value to SharedPreferences and restores on restart', () async {
      final sessionNotifier = container.read(sessionProvider.notifier);

      // Initial default role is receptionist
      expect(container.read(sessionProvider).role, equals(UserRole.receptionist));

      // Switch to Doctor
      sessionNotifier.switchRole(UserRole.doctor);
      expect(container.read(sessionProvider).role, equals(UserRole.doctor));

      // Allow microtask to complete SharedPreferences write
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify written to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('apna_clinic_active_user_role'), equals(UserRole.doctor.wireValue));

      // Create a fresh session notifier simulating browser reload
      final reloadedContainer = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(memoryDb),
        ],
      );
      addTearDown(reloadedContainer.dispose);

      final reloadedNotifier = reloadedContainer.read(sessionProvider.notifier);
      await reloadedNotifier.restoreSavedRole();

      // Verify restored role is Doctor
      expect(reloadedContainer.read(sessionProvider).role, equals(UserRole.doctor));

      // Switch to Accountant and verify
      reloadedNotifier.switchRole(UserRole.accountant);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(prefs.getString('apna_clinic_active_user_role'), equals(UserRole.accountant.wireValue));

      final secondReloadContainer = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(memoryDb),
        ],
      );
      addTearDown(secondReloadContainer.dispose);

      await secondReloadContainer.read(sessionProvider.notifier).restoreSavedRole();
      expect(secondReloadContainer.read(sessionProvider).role, equals(UserRole.accountant));
    });
  });
}

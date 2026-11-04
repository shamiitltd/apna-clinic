// Apna Clinic - Module 14: Multi-Branch & Third-Party Integrations Tests
// Primary Source of Truth: PRD Section 5 (M14), TRD Section 1, Section 5, Section 7.
// Non-clinical interoperability, consolidated reporting, and strict RBAC.

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/errors/failures.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/repositories/branch_repository.dart';

void main() {
  group('MODULE 14 — MULTI-BRANCH & THIRD-PARTY INTEGRATIONS (PRD M14)', () {
    late LocalDatabase db;
    late BranchRepository branchRepo;

    const testClinicId = 'clinic_m14_test';
    const testOwnerStaffId = 'staff_owner_m14';

    setUp(() async {
      final storage = MemoryStorageAdapter();
      db = LocalDatabase(storage);
      await db.initialize();
      branchRepo = BranchRepository(db);
    });

    test('1. Default Flagship Branch Initialization: Auto-provisions BR-01 main flagship', () async {
      final branches = await branchRepo.getBranches(testClinicId);
      expect(branches.length, equals(1));

      final flagship = branches.first;
      expect(flagship.isMainBranch, isTrue);
      expect(flagship.branchCode, equals('BR-01'));
      expect(flagship.clinicId, equals(testClinicId));
      expect(flagship.isActive, isTrue);
    });

    test('2. Multi-Branch Registration: Registers secondary branch facility', () async {
      await branchRepo.getBranches(testClinicId); // initializes main

      final now = DateTime.now().toUtc();
      final branch2 = Branch(
        branchId: 'br_m14_south_ex',
        clinicId: testClinicId,
        branchCode: 'BR-02',
        branchName: 'South Extension OPD Center',
        contactPhone: '+919811223344',
        contactEmail: 'southex@apnaclinic.in',
        addressLine1: 'Block E, Ring Road, South Extension Part II',
        city: 'New Delhi',
        state: 'Delhi',
        pincode: '110049',
        isMainBranch: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await branchRepo.saveBranch(branch2);

      final roster = await branchRepo.getBranches(testClinicId);
      expect(roster.length, equals(2));

      // Flagship branch is sorted first
      expect(roster.first.isMainBranch, isTrue);
      expect(roster.last.branchCode, equals('BR-02'));
    });

    test('3. Branch Deactivation & Flagship Invariant: Blocks deactivation of primary flagship', () async {
      final branches = await branchRepo.getBranches(testClinicId);
      final flagship = branches.first;

      // Attempt to deactivate main flagship branch is blocked
      expect(
        () async => await branchRepo.deleteBranch(testClinicId, flagship.branchId, staffId: testOwnerStaffId),
        throwsA(isA<ValidationFailure>()),
      );

      // Register and deactivate secondary branch
      final now = DateTime.now().toUtc();
      final branch2 = Branch(
        branchId: 'br_temp_deact',
        clinicId: testClinicId,
        branchCode: 'BR-03',
        branchName: 'Temporary Satellite Counter',
        contactPhone: '+919999999999',
        addressLine1: 'Sector 62',
        city: 'Noida',
        state: 'Uttar Pradesh',
        pincode: '201301',
        isMainBranch: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await branchRepo.saveBranch(branch2);

      await branchRepo.deleteBranch(testClinicId, 'br_temp_deact', staffId: testOwnerStaffId);

      final activeOnly = await branchRepo.getBranches(testClinicId, activeOnly: true);
      expect(activeOnly.any((b) => b.branchId == 'br_temp_deact'), isFalse);

      final allBranches = await branchRepo.getBranches(testClinicId, activeOnly: false);
      final deact = allBranches.firstWhere((b) => b.branchId == 'br_temp_deact');
      expect(deact.isActive, isFalse);
    });

    test('4. Consolidated Multi-Branch Reporting: Aggregates visits, appointments & collections', () async {
      await branchRepo.getBranches(testClinicId); // BR-01 main

      final now = DateTime.now().toUtc();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final branch2 = Branch(
        branchId: 'br_m14_noida',
        clinicId: testClinicId,
        branchCode: 'BR-02',
        branchName: 'Noida Sector 18 Clinic',
        contactPhone: '+919876543211',
        addressLine1: 'Atta Market, Sector 18',
        city: 'Noida',
        state: 'Uttar Pradesh',
        pincode: '201301',
        isMainBranch: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await branchRepo.saveBranch(branch2);

      // Seed visits for branch 1
      await db.upsert('Visits', 'vis_b1_1', {
        'visit_id': 'vis_b1_1',
        'clinic_id': testClinicId,
        'branch_id': 'br_main_$testClinicId',
        'visit_date_local': dateStr,
      });

      // Seed visits for branch 2
      await db.upsert('Visits', 'vis_b2_1', {
        'visit_id': 'vis_b2_1',
        'clinic_id': testClinicId,
        'branch_id': 'br_m14_noida',
        'visit_date_local': dateStr,
      });

      // Seed payment for branch 2 (₹600 = 60000 paise)
      await db.upsert('Payments', 'pay_b2_1', {
        'payment_id': 'pay_b2_1',
        'clinic_id': testClinicId,
        'branch_id': 'br_m14_noida',
        'amount_minor': 60000,
      });

      final report = await branchRepo.getConsolidatedReport(testClinicId, date: now);

      expect(report.totalBranches, equals(2));
      expect(report.grandTotalVisits, equals(2));
      expect(report.grandTotalCollectionsMinor, equals(60000));

      final b2Metric = report.branchMetrics.firstWhere((m) => m.branchId == 'br_m14_noida');
      expect(b2Metric.totalVisitsToday, equals(1));
      expect(b2Metric.totalCollectedMinor, equals(60000));
    });

    test('5. Confidentiality & CSV Export: Consolidated export strictly excludes patient clinical data', () async {
      await branchRepo.getBranches(testClinicId);
      final report = await branchRepo.getConsolidatedReport(testClinicId);

      final csv = await branchRepo.exportConsolidatedReportCsv(report);

      expect(csv.startsWith('\uFEFF'), isTrue); // UTF-8 BOM
      expect(csv, contains('branch_code,branch_name,total_patients,total_visits_today'));
      expect(csv, contains('BR-01'));
      expect(csv, contains(testClinicId));

      // Strict privacy assertions
      expect(csv.contains('diagnosis'), isFalse);
      expect(csv.contains('prescription'), isFalse);
      expect(csv.contains('symptoms'), isFalse);
      expect(csv.contains('fever'), isFalse);
    });

    test('6. ABDM Facility Configuration: Stores HFR facility & gateway bridge credentials', () async {
      final config = await branchRepo.getAbdmConfig(testClinicId);
      expect(config.facilityId, isNotEmpty);
      expect(config.bridgeStatus, equals('disconnected'));

      final updatedConfig = config.copyWith(
        facilityName: 'City Health Multi-Specialty Clinic',
        hprDoctorId: '12-3456-7890-1234',
        bridgeStatus: 'sandbox_connected',
        isAbdmEnabled: true,
      );

      await branchRepo.saveAbdmConfig(testClinicId, updatedConfig);

      final retrieved = await branchRepo.getAbdmConfig(testClinicId);
      expect(retrieved.facilityName, equals('City Health Multi-Specialty Clinic'));
      expect(retrieved.hprDoctorId, equals('12-3456-7890-1234'));
      expect(retrieved.bridgeStatus, equals('sandbox_connected'));
      expect(retrieved.isAbdmEnabled, isTrue);
    });

    test('7. ABHA Patient Demographic Linking: Requires explicit DPDP consent', () async {
      const patientId = 'pat_m14_abha_test';

      final unconsentedProfile = AbhaProfile(
        abhaNumber: '91-1234-5678-9012',
        abhaAddress: 'vikram.joshi@abdm',
        patientId: patientId,
        clinicId: testClinicId,
        verificationStatus: 'verified',
        dpdpConsentGiven: false,
      );
      // Consent is mandatory for verified health ID linking
      expect(unconsentedProfile.isVerified, isFalse);

      final validProfile = unconsentedProfile.copyWith(
        dpdpConsentGiven: true,
        linkedAt: DateTime.now().toUtc(),
      );
      expect(validProfile.isVerified, isTrue);

      await branchRepo.linkPatientAbha(validProfile);

      final retrieved = await branchRepo.getPatientAbha(testClinicId, patientId);
      expect(retrieved, isNotNull);
      expect(retrieved!.abhaNumber, equals('91-1234-5678-9012'));
      expect(retrieved.abhaAddress, equals('vikram.joshi@abdm'));
      expect(retrieved.dpdpConsentGiven, isTrue);
    });

    test('8. Strict RBAC: Owner has full branch & ABDM authority; Accountant has reports; Staff restricted', () {
      // Owner
      expect(
        AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.manageBranches),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.switchBranch),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.viewConsolidatedReports),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.manageAbdmIntegration),
        isTrue,
      );

      // Accountant (can view consolidated financial reports, cannot alter branch infrastructure)
      expect(
        AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.viewConsolidatedReports),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.manageBranches),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.manageAbdmIntegration),
        isFalse,
      );

      // Receptionist (strictly denied branch creation and ABDM configuration)
      expect(
        AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.manageBranches),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.manageAbdmIntegration),
        isFalse,
      );

      // Doctor (strictly denied administrative multi-branch configuration)
      expect(
        AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.manageBranches),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.viewConsolidatedReports),
        isFalse,
      );
    });
  });
}


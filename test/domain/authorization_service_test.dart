// AuthorizationService Unit Tests - Testing Deny-By-Default Security
// Requirements: Section 13, 14

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';

void main() {
  group('AuthorizationService Tests', () {
    test('Owner has full administrative privileges', () {
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.owner,
          permission: AppPermission.manageClinicConfig,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.owner,
          permission: AppPermission.bulkExportPatients,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.owner,
          permission: AppPermission.restoreBackup,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.owner,
          permission: AppPermission.rotateKeys,
        ),
        isTrue,
      );
    });

    test('Receptionist cannot export patients, manage subscriptions, or restore backups', () {
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.registerPatient,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.createVisit,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.printConsultationSlip,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.collectPayment,
        ),
        isTrue,
      );

      // DENIED PERMISSIONS:
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.bulkExportPatients,
        ),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.manageSubscriptions,
        ),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.restoreBackup,
        ),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.rotateKeys,
        ),
        isFalse,
      );
    });

    test('Doctor role has scoped queue access and reason for visit, but no unrestricted exports', () {
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.doctor,
          permission: AppPermission.viewDoctorQueue,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.doctor,
          permission: AppPermission.viewReasonForVisit,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.doctor,
          permission: AppPermission.updateQueueStatus,
        ),
        isTrue,
      );

      // DENIED PERMISSIONS:
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.doctor,
          permission: AppPermission.bulkExportPatients,
        ),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.doctor,
          permission: AppPermission.restoreBackup,
        ),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.doctor,
          permission: AppPermission.manageFees,
        ),
        isFalse,
      );
    });

    test('Accountant role has financial reports access, but no clinical illness visibility', () {
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.accountant,
          permission: AppPermission.viewDailyReports,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.accountant,
          permission: AppPermission.viewFinancialLedger,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.accountant,
          permission: AppPermission.approveRefund,
        ),
        isTrue,
      );

      // DENIED: Reason for visit / illness details
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.accountant,
          permission: AppPermission.viewReasonForVisit,
        ),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.accountant,
          permission: AppPermission.bulkExportPatients,
        ),
        isFalse,
      );
    });

    test('checkClinicScope throws or denies cross-clinic access', () {
      expect(
        AuthorizationService.isClinicScopeValid(
          sessionClinicId: 'clinic_001',
          targetClinicId: 'clinic_001',
        ),
        isTrue,
      );
      expect(
        AuthorizationService.isClinicScopeValid(
          sessionClinicId: 'clinic_001',
          targetClinicId: 'clinic_999',
        ),
        isFalse,
      );
    });
  });
}

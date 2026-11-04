import '../../core/errors/failures.dart';
import '../../core/permissions/roles.dart';

/// Deny-by-default domain-level authorization service.
///
/// CRITICAL SECURITY RULE:
/// UI-level hiding of buttons is NEVER sufficient. Every domain operation
/// must validate caller session, role, clinic scope, and entity permissions.
class AuthorizationService {
  static final Map<UserRole, Set<AppPermission>> _staticRolePermissions = {
    UserRole.owner: {
      AppPermission.manageClinicConfig,
      AppPermission.manageDoctors,
      AppPermission.manageStaff,
      AppPermission.manageFees,
      AppPermission.manageSubscriptions,
      AppPermission.registerPatient,
      AppPermission.searchPatient,
      AppPermission.editPatient,
      AppPermission.bulkExportPatients,
      AppPermission.deletePatientRecord,
      AppPermission.createVisit,
      AppPermission.createAppointment,
      AppPermission.cancelAppointment,
      AppPermission.manageFollowups,
      AppPermission.reassignQueue,
      AppPermission.updateQueueStatus,
      AppPermission.viewDoctorQueue,
      AppPermission.viewAllQueues,
      AppPermission.printConsultationSlip,
      AppPermission.reprintConsultationSlip,
      AppPermission.viewReasonForVisit,
      AppPermission.createInvoice,
      AppPermission.collectPayment,
      AppPermission.manageExpenses,
      AppPermission.viewDailyReports,
      AppPermission.exportReports,
      AppPermission.viewFinancialLedger,
      AppPermission.approveRefund,
      AppPermission.voidInvoice,
      AppPermission.performDayClose,
      AppPermission.triggerBackup,
      AppPermission.restoreBackup,
      AppPermission.rotateKeys,
      AppPermission.viewAuditLogs,
      AppPermission.manageDeviceLease,
      AppPermission.resolveConflicts,
      AppPermission.manageBranches,
      AppPermission.switchBranch,
      AppPermission.viewConsolidatedReports,
      AppPermission.manageAbdmIntegration,
    },
    UserRole.receptionist: {
      AppPermission.registerPatient,
      AppPermission.searchPatient,
      AppPermission.editPatient,
      AppPermission.createVisit,
      AppPermission.createAppointment,
      AppPermission.cancelAppointment,
      AppPermission.manageFollowups,
      AppPermission.reassignQueue,
      AppPermission.updateQueueStatus,
      AppPermission.viewAllQueues,
      AppPermission.printConsultationSlip,
      AppPermission.reprintConsultationSlip,
      AppPermission.viewReasonForVisit,
      AppPermission.createInvoice,
      AppPermission.collectPayment,
      AppPermission.viewDailyReports,
      AppPermission.performDayClose,
      AppPermission.manageDeviceLease,
      AppPermission.resolveConflicts,
    },
    UserRole.doctor: {
      AppPermission.searchPatient,
      AppPermission.viewDoctorQueue,
      AppPermission.updateQueueStatus,
      AppPermission.manageFollowups,
      AppPermission.viewReasonForVisit,
      AppPermission.printConsultationSlip,
    },
    UserRole.accountant: {
      AppPermission.viewDailyReports,
      AppPermission.exportReports,
      AppPermission.viewFinancialLedger,
      AppPermission.collectPayment,
      AppPermission.manageExpenses,
      AppPermission.approveRefund,
      AppPermission.voidInvoice,
      AppPermission.performDayClose,
      AppPermission.viewConsolidatedReports,
    },
  };

  static bool hasPermission({
    required UserRole role,
    required AppPermission permission,
  }) {
    return _staticRolePermissions[role]?.contains(permission) ?? false;
  }

  static bool isClinicScopeValid({
    required String sessionClinicId,
    required String targetClinicId,
  }) {
    return sessionClinicId.isNotEmpty && sessionClinicId == targetClinicId;
  }

  void requirePermission({
    required UserRole role,
    required AppPermission permission,
    required String currentClinicId,
    required String targetClinicId,
  }) {
    if (!isClinicScopeValid(
      sessionClinicId: currentClinicId,
      targetClinicId: targetClinicId,
    )) {
      throw const AuthorizationFailure(
        'Clinic scope mismatch: Access to external clinic data is denied.',
      );
    }

    if (!hasPermission(role: role, permission: permission)) {
      throw AuthorizationFailure(
        'Role ${role.name.toUpperCase()} is not authorized for ${permission.name}.',
      );
    }
  }

  /// Validates whether the given [role] is authorized to access [routePath]
  /// per PRD Section 2 (Role Boundaries) and Section 5 M08 (Staff & Access Authorization).
  static bool isRouteAllowed({
    required UserRole role,
    required String routePath,
  }) {
    // Strip query parameters and hash anchors for clean path comparison
    final cleanPath = routePath.split('?').first.split('#').last;
    final normalized = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';

    // 1. Settings Screen: Strictly Owner / Administrator only
    if (normalized.startsWith('/settings')) {
      return role == UserRole.owner;
    }

    // 2. Doctor Desk: Strictly Doctor and Owner
    if (normalized.startsWith('/doctor')) {
      return role == UserRole.doctor || role == UserRole.owner;
    }

    // 3. Billing & Payments: Owner, Receptionist, Accountant (Blocked for Doctor)
    if (normalized.startsWith('/billing')) {
      return role != UserRole.doctor;
    }

    // 4. Reports & Analytics: Owner, Receptionist, Accountant (Blocked for Doctor)
    if (normalized.startsWith('/reports')) {
      return role != UserRole.doctor;
    }

    // 5. Live Queue Desk: Owner, Receptionist, Doctor (Blocked for Accountant)
    if (normalized.startsWith('/queue')) {
      return role != UserRole.accountant;
    }

    // 6. Appointments Desk: Owner, Receptionist, Doctor (Blocked for Accountant)
    if (normalized.startsWith('/appointments')) {
      return role != UserRole.accountant;
    }

    // 7. Patients Directory: Owner, Receptionist, Doctor (Blocked for Accountant)
    if (normalized.startsWith('/patients')) {
      return role != UserRole.accountant;
    }

    // 8. Reception Dashboard (/dashboard, /app): Blocked for Doctor (Doctor workspace is /doctor)
    if (normalized == '/dashboard' || normalized == '/app') {
      return role != UserRole.doctor;
    }

    return true;
  }
}

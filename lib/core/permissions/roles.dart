enum UserRole {
  owner,
  receptionist,
  doctor,
  accountant;

  String get wireValue {
    switch (this) {
      case UserRole.owner:
        return 'owner';
      case UserRole.receptionist:
        return 'receptionist';
      case UserRole.doctor:
        return 'doctor';
      case UserRole.accountant:
        return 'accountant';
    }
  }

  static UserRole fromWire(String val) {
    return UserRole.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => UserRole.receptionist,
    );
  }
}

enum AppPermission {
  // Clinic & Staff Administration
  manageClinicConfig,
  manageDoctors,
  manageStaff,
  manageFees,
  manageSubscriptions,

  // Patient & Registration
  registerPatient,
  searchPatient,
  editPatient,
  bulkExportPatients,
  deletePatientRecord,

  // Visit & Queue
  createVisit,
  createAppointment,
  cancelAppointment,
  manageFollowups,
  reassignQueue,
  updateQueueStatus,
  viewDoctorQueue,
  viewAllQueues,

  // Consultation Slip & Printing
  printConsultationSlip,
  reprintConsultationSlip,

  // Clinical Visibility
  viewReasonForVisit,

  // Billing & Finance
  createInvoice,
  collectPayment,
  manageExpenses,
  viewDailyReports,
  exportReports,
  viewFinancialLedger,
  approveRefund,
  voidInvoice,
  performDayClose,

  // Backup & Recovery
  triggerBackup,
  restoreBackup,
  rotateKeys,
  viewAuditLogs,

  // Multi-Device Collaboration
  manageDeviceLease,
  resolveConflicts,

  // Multi-Branch & Third-Party Integrations (Module 14)
  manageBranches,
  switchBranch,
  viewConsolidatedReports,
  manageAbdmIntegration,
}

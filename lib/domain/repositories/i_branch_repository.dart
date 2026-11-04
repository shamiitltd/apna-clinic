// Apna Clinic - Module 14: Multi-Branch & Third-Party Integrations Repository Interface
// Primary Source of Truth: PRD Section 5 (M14), TRD Section 1, Section 5, Section 7.

import '../entities/branch.dart';

abstract class IBranchRepository {
  /// Returns all registered branches for the parent clinic.
  Future<List<Branch>> getBranches(String clinicId, {bool activeOnly = true});

  /// Retrieves a specific branch by branchId.
  Future<Branch?> getBranch(String clinicId, String branchId);

  /// Saves or updates a clinic branch record.
  Future<void> saveBranch(Branch branch);

  /// Soft-deactivates a clinic branch with audit logging.
  Future<void> deleteBranch(String clinicId, String branchId, {required String staffId});

  /// Generates consolidated multi-branch operational & financial report for Clinic Owner.
  Future<ConsolidatedClinicReport> getConsolidatedReport(String clinicId, {DateTime? date});

  /// Generates privacy-safe CSV export of consolidated branch metrics (zero clinical data).
  Future<String> exportConsolidatedReportCsv(ConsolidatedClinicReport report);

  /// Retrieves ABDM facility configuration and bridge credentials.
  Future<AbdmIntegrationConfig> getAbdmConfig(String clinicId);

  /// Updates ABDM facility configuration.
  Future<void> saveAbdmConfig(String clinicId, AbdmIntegrationConfig config);

  /// Retrieves ABHA account linked to a patient.
  Future<AbhaProfile?> getPatientAbha(String clinicId, String patientId);

  /// Links or updates verified ABHA details with explicit DPDP consent.
  Future<void> linkPatientAbha(AbhaProfile profile);
}


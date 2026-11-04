// Apna Clinic - Module 14: Multi-Branch & Third-Party Integrations
// Primary Source of Truth: PRD Section 5 (M14), TRD Section 1, Section 5, Section 7.

/// Individual clinic branch facility entity under a parent clinic organization.
class Branch {
  final String branchId;
  final String clinicId;
  final String branchCode;
  final String branchName;
  final String contactPhone;
  final String contactEmail;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String pincode;
  final bool isMainBranch;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Branch({
    required this.branchId,
    required this.clinicId,
    required this.branchCode,
    required this.branchName,
    required this.contactPhone,
    this.contactEmail = '',
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.state,
    required this.pincode,
    this.isMainBranch = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Branch copyWith({
    String? branchId,
    String? clinicId,
    String? branchCode,
    String? branchName,
    String? contactPhone,
    String? contactEmail,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
    bool? isMainBranch,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Branch(
      branchId: branchId ?? this.branchId,
      clinicId: clinicId ?? this.clinicId,
      branchCode: branchCode ?? this.branchCode,
      branchName: branchName ?? this.branchName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      isMainBranch: isMainBranch ?? this.isMainBranch,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branch_id': branchId,
      'clinic_id': clinicId,
      'branch_code': branchCode,
      'branch_name': branchName,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'is_main_branch': isMainBranch ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      branchId: map['branch_id'] as String? ?? '',
      clinicId: map['clinic_id'] as String? ?? '',
      branchCode: map['branch_code'] as String? ?? '',
      branchName: map['branch_name'] as String? ?? 'Clinic Branch',
      contactPhone: map['contact_phone'] as String? ?? '',
      contactEmail: map['contact_email'] as String? ?? '',
      addressLine1: map['address_line1'] as String? ?? '',
      addressLine2: map['address_line2'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      pincode: map['pincode'] as String? ?? '',
      isMainBranch: map['is_main_branch'] == 1 || map['is_main_branch'] == true,
      isActive: map['is_active'] == null || map['is_active'] == 1 || map['is_active'] == true,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

/// Aggregated performance and financial metrics for a single branch.
class BranchSummaryMetric {
  final String branchId;
  final String branchName;
  final String branchCode;
  final int totalPatients;
  final int totalVisitsToday;
  final int totalAppointmentsToday;
  final int totalCollectedMinor; // in integer paise
  final int totalPendingMinor;
  final int netCashInHandMinor;

  const BranchSummaryMetric({
    required this.branchId,
    required this.branchName,
    required this.branchCode,
    required this.totalPatients,
    required this.totalVisitsToday,
    required this.totalAppointmentsToday,
    required this.totalCollectedMinor,
    required this.totalPendingMinor,
    required this.netCashInHandMinor,
  });

  Map<String, dynamic> toMap() {
    return {
      'branch_id': branchId,
      'branch_name': branchName,
      'branch_code': branchCode,
      'total_patients': totalPatients,
      'total_visits_today': totalVisitsToday,
      'total_appointments_today': totalAppointmentsToday,
      'total_collected_minor': totalCollectedMinor,
      'total_pending_minor': totalPendingMinor,
      'net_cash_in_hand_minor': netCashInHandMinor,
    };
  }

  factory BranchSummaryMetric.fromMap(Map<String, dynamic> map) {
    return BranchSummaryMetric(
      branchId: map['branch_id'] as String? ?? '',
      branchName: map['branch_name'] as String? ?? '',
      branchCode: map['branch_code'] as String? ?? '',
      totalPatients: (map['total_patients'] as num?)?.toInt() ?? 0,
      totalVisitsToday: (map['total_visits_today'] as num?)?.toInt() ?? 0,
      totalAppointmentsToday: (map['total_appointments_today'] as num?)?.toInt() ?? 0,
      totalCollectedMinor: (map['total_collected_minor'] as num?)?.toInt() ?? 0,
      totalPendingMinor: (map['total_pending_minor'] as num?)?.toInt() ?? 0,
      netCashInHandMinor: (map['net_cash_in_hand_minor'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Consolidated multi-branch enterprise report for Clinic Owners.
class ConsolidatedClinicReport {
  final String clinicId;
  final DateTime reportDate;
  final int totalBranches;
  final int activeBranches;
  final int grandTotalVisits;
  final int grandTotalAppointments;
  final int grandTotalCollectionsMinor; // in paise
  final int grandTotalPendingMinor;
  final List<BranchSummaryMetric> branchMetrics;

  const ConsolidatedClinicReport({
    required this.clinicId,
    required this.reportDate,
    required this.totalBranches,
    required this.activeBranches,
    required this.grandTotalVisits,
    required this.grandTotalAppointments,
    required this.grandTotalCollectionsMinor,
    required this.grandTotalPendingMinor,
    required this.branchMetrics,
  });

  Map<String, dynamic> toMap() {
    return {
      'clinic_id': clinicId,
      'report_date': reportDate.toIso8601String(),
      'total_branches': totalBranches,
      'active_branches': activeBranches,
      'grand_total_visits': grandTotalVisits,
      'grand_total_appointments': grandTotalAppointments,
      'grand_total_collections_minor': grandTotalCollectionsMinor,
      'grand_total_pending_minor': grandTotalPendingMinor,
      'branch_metrics': branchMetrics.map((m) => m.toMap()).toList(),
    };
  }

  factory ConsolidatedClinicReport.fromMap(Map<String, dynamic> map) {
    return ConsolidatedClinicReport(
      clinicId: map['clinic_id'] as String? ?? '',
      reportDate: DateTime.tryParse(map['report_date'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      totalBranches: (map['total_branches'] as num?)?.toInt() ?? 0,
      activeBranches: (map['active_branches'] as num?)?.toInt() ?? 0,
      grandTotalVisits: (map['grand_total_visits'] as num?)?.toInt() ?? 0,
      grandTotalAppointments: (map['grand_total_appointments'] as num?)?.toInt() ?? 0,
      grandTotalCollectionsMinor:
          (map['grand_total_collections_minor'] as num?)?.toInt() ?? 0,
      grandTotalPendingMinor: (map['grand_total_pending_minor'] as num?)?.toInt() ?? 0,
      branchMetrics: (map['branch_metrics'] as List<dynamic>? ?? [])
          .map((m) => BranchSummaryMetric.fromMap(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Ayushman Bharat Digital Mission (ABDM) facility registration & interoperability configuration.
/// Non-clinical administrative boundary only — zero digital prescription or clinical transmission in MVP.
class AbdmIntegrationConfig {
  final String facilityId; // Health Facility Registry (HFR) Facility ID
  final String facilityName;
  final String? hprDoctorId; // Healthcare Professional Registry (HPR) ID
  final String gatewayClientId;
  final String bridgeStatus; // 'disconnected', 'sandbox_connected', 'production_certified'
  final String consentManagerUrl;
  final bool isAbdmEnabled;
  final DateTime? lastVerifiedAt;

  const AbdmIntegrationConfig({
    required this.facilityId,
    required this.facilityName,
    this.hprDoctorId,
    required this.gatewayClientId,
    this.bridgeStatus = 'disconnected',
    this.consentManagerUrl = 'https://consent.abdm.gov.in',
    this.isAbdmEnabled = false,
    this.lastVerifiedAt,
  });

  AbdmIntegrationConfig copyWith({
    String? facilityId,
    String? facilityName,
    String? hprDoctorId,
    String? gatewayClientId,
    String? bridgeStatus,
    String? consentManagerUrl,
    bool? isAbdmEnabled,
    DateTime? lastVerifiedAt,
  }) {
    return AbdmIntegrationConfig(
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      hprDoctorId: hprDoctorId ?? this.hprDoctorId,
      gatewayClientId: gatewayClientId ?? this.gatewayClientId,
      bridgeStatus: bridgeStatus ?? this.bridgeStatus,
      consentManagerUrl: consentManagerUrl ?? this.consentManagerUrl,
      isAbdmEnabled: isAbdmEnabled ?? this.isAbdmEnabled,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'facility_id': facilityId,
      'facility_name': facilityName,
      'hpr_doctor_id': hprDoctorId,
      'gateway_client_id': gatewayClientId,
      'bridge_status': bridgeStatus,
      'consent_manager_url': consentManagerUrl,
      'is_abdm_enabled': isAbdmEnabled ? 1 : 0,
      'last_verified_at': lastVerifiedAt?.toIso8601String(),
    };
  }

  factory AbdmIntegrationConfig.fromMap(Map<String, dynamic> map) {
    return AbdmIntegrationConfig(
      facilityId: map['facility_id'] as String? ?? '',
      facilityName: map['facility_name'] as String? ?? '',
      hprDoctorId: map['hpr_doctor_id'] as String?,
      gatewayClientId: map['gateway_client_id'] as String? ?? '',
      bridgeStatus: map['bridge_status'] as String? ?? 'disconnected',
      consentManagerUrl: map['consent_manager_url'] as String? ?? 'https://consent.abdm.gov.in',
      isAbdmEnabled: map['is_abdm_enabled'] == 1 || map['is_abdm_enabled'] == true,
      lastVerifiedAt: map['last_verified_at'] != null
          ? DateTime.tryParse(map['last_verified_at'] as String)?.toUtc()
          : null,
    );
  }
}

/// ABHA (Ayushman Bharat Health Account) linking record for a patient.
class AbhaProfile {
  final String abhaNumber; // 14-digit format: XX-XXXX-XXXX-XXXX
  final String abhaAddress; // e.g. name@abdm
  final String patientId;
  final String clinicId;
  final String? branchId;
  final String verificationStatus; // 'unverified', 'verified', 'consent_pending'
  final bool dpdpConsentGiven;
  final DateTime? linkedAt;

  const AbhaProfile({
    required this.abhaNumber,
    required this.abhaAddress,
    required this.patientId,
    required this.clinicId,
    this.branchId,
    this.verificationStatus = 'unverified',
    this.dpdpConsentGiven = false,
    this.linkedAt,
  });

  bool get isVerified => verificationStatus == 'verified' && dpdpConsentGiven;

  AbhaProfile copyWith({
    String? abhaNumber,
    String? abhaAddress,
    String? patientId,
    String? clinicId,
    String? branchId,
    String? verificationStatus,
    bool? dpdpConsentGiven,
    DateTime? linkedAt,
  }) {
    return AbhaProfile(
      abhaNumber: abhaNumber ?? this.abhaNumber,
      abhaAddress: abhaAddress ?? this.abhaAddress,
      patientId: patientId ?? this.patientId,
      clinicId: clinicId ?? this.clinicId,
      branchId: branchId ?? this.branchId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      dpdpConsentGiven: dpdpConsentGiven ?? this.dpdpConsentGiven,
      linkedAt: linkedAt ?? this.linkedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'abha_number': abhaNumber,
      'abha_address': abhaAddress,
      'patient_id': patientId,
      'clinic_id': clinicId,
      'branch_id': branchId,
      'verification_status': verificationStatus,
      'dpdp_consent_given': dpdpConsentGiven ? 1 : 0,
      'linked_at': linkedAt?.toIso8601String(),
    };
  }

  factory AbhaProfile.fromMap(Map<String, dynamic> map) {
    return AbhaProfile(
      abhaNumber: map['abha_number'] as String? ?? '',
      abhaAddress: map['abha_address'] as String? ?? '',
      patientId: map['patient_id'] as String? ?? '',
      clinicId: map['clinic_id'] as String? ?? '',
      branchId: map['branch_id'] as String?,
      verificationStatus: map['verification_status'] as String? ?? 'unverified',
      dpdpConsentGiven: map['dpdp_consent_given'] == 1 || map['dpdp_consent_given'] == true,
      linkedAt: map['linked_at'] != null
          ? DateTime.tryParse(map['linked_at'] as String)?.toUtc()
          : null,
    );
  }
}


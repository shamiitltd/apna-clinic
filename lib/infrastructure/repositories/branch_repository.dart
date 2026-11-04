// Apna Clinic - Module 14: Multi-Branch & Third-Party Integrations Repository Implementation
// Primary Source of Truth: PRD Section 5 (M14), TRD Section 1, Section 5, Section 7.
// PRIVACY & COMPLIANCE BOUNDARY: Zero clinical prescriptions, symptoms, or medical notes.

import 'dart:convert';
import '../../core/errors/failures.dart';
import '../../domain/entities/audit_event.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_branch_repository.dart';
import '../database/local_database.dart';

class BranchRepository implements IBranchRepository {
  final LocalDatabase _db;

  BranchRepository(this._db);

  @override
  Future<List<Branch>> getBranches(String clinicId, {bool activeOnly = true}) async {
    final records = _db.query(
      'Branches',
      where: (r) => r['clinic_id'] == clinicId,
    );

    var branches = records.map((r) => Branch.fromMap(r)).toList();

    // Default Initialization: If no branches exist yet, register the main flagship branch
    if (branches.isEmpty) {
      final clinicRecord = _db.get('Clinic_Config', clinicId);
      final now = DateTime.now().toUtc();
      final defaultMain = Branch(
        branchId: 'br_main_$clinicId',
        clinicId: clinicId,
        branchCode: 'BR-01',
        branchName: clinicRecord != null && clinicRecord['display_name'] != null
            ? '${clinicRecord['display_name']} (Main Flagship)'
            : 'City Health Clinic (Main Flagship)',
        contactPhone: clinicRecord?['contact_phone'] as String? ?? '+919876543210',
        contactEmail: clinicRecord?['contact_email'] as String? ?? 'main@cityhealth.in',
        addressLine1: clinicRecord?['address_line1'] as String? ?? 'Main Market, Connaught Place',
        city: clinicRecord?['city'] as String? ?? 'New Delhi',
        state: clinicRecord?['state'] as String? ?? 'Delhi',
        pincode: clinicRecord?['pincode'] as String? ?? '110001',
        isMainBranch: true,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await saveBranch(defaultMain);
      branches = [defaultMain];
    }

    if (activeOnly) {
      branches = branches.where((b) => b.isActive).toList();
    }

    branches.sort((a, b) {
      if (a.isMainBranch && !b.isMainBranch) return -1;
      if (b.isMainBranch && !a.isMainBranch) return 1;
      return a.branchName.compareTo(b.branchName);
    });

    return branches;
  }

  @override
  Future<Branch?> getBranch(String clinicId, String branchId) async {
    final record = _db.get('Branches', branchId);
    if (record == null || record['clinic_id'] != clinicId) return null;
    return Branch.fromMap(record);
  }

  @override
  Future<void> saveBranch(Branch branch) async {
    await _db.transaction((tx) async {
      await _db.upsert('Branches', branch.branchId, branch.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_branch_${branch.branchId}',
        clinicId: branch.clinicId,
        entityType: 'Branches',
        entityId: branch.branchId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(branch.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'branch_${branch.branchId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      final audit = AuditEvent(
        auditEventId: 'audit_branch_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: branch.clinicId,
        actorId: 'owner',
        actorRole: 'owner',
        deviceId: 'workstation',
        action: 'branch.save',
        entityType: 'branch',
        entityId: branch.branchId,
        occurredAt: DateTime.now().toUtc(),
        result: AuditResult.success,
        correlationId: branch.branchCode,
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });
  }

  @override
  Future<void> deleteBranch(String clinicId, String branchId, {required String staffId}) async {
    final existing = await getBranch(clinicId, branchId);
    if (existing == null) {
      throw const DatabaseFailure('Branch not found.');
    }
    if (existing.isMainBranch) {
      throw const ValidationFailure('Cannot deactivate the primary flagship branch.');
    }

    final deactivated = existing.copyWith(
      isActive: false,
      updatedAt: DateTime.now().toUtc(),
    );

    await _db.transaction((tx) async {
      await _db.upsert('Branches', deactivated.branchId, deactivated.toMap(), tx: tx);

      final audit = AuditEvent(
        auditEventId: 'audit_branch_deact_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: staffId,
        actorRole: 'owner',
        deviceId: 'workstation',
        action: 'branch.deactivate',
        entityType: 'branch',
        entityId: branchId,
        occurredAt: DateTime.now().toUtc(),
        result: AuditResult.success,
        correlationId: branchId,
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });
  }

  @override
  Future<ConsolidatedClinicReport> getConsolidatedReport(String clinicId, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateStr =
        '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    final branches = await getBranches(clinicId, activeOnly: false);
    final allVisits = _db.query('Visits', where: (r) => r['clinic_id'] == clinicId && r['visit_date_local'] == dateStr);
    final allInvoices = _db.query('Invoices', where: (r) => r['clinic_id'] == clinicId);
    final allPayments = _db.query('Payments', where: (r) => r['clinic_id'] == clinicId);
    final allPatients = _db.query('Patients', where: (r) => r['clinic_id'] == clinicId);
    final allAppointments = _db.query('Appointments', where: (r) => r['clinic_id'] == clinicId);

    final metrics = <BranchSummaryMetric>[];
    int grandTotalVisits = 0;
    int grandTotalAppointments = 0;
    int grandTotalCollections = 0;
    int grandTotalPending = 0;

    for (var i = 0; i < branches.length; i++) {
      final b = branches[i];
      // Partition visits by branch_id where recorded, or associate to main branch by default
      final branchVisits = allVisits.where((v) {
        final bId = v['branch_id'] as String?;
        return bId == b.branchId || (bId == null && b.isMainBranch);
      }).length;

      final branchAppts = allAppointments.where((a) {
        final bId = a['branch_id'] as String?;
        return bId == b.branchId || (bId == null && b.isMainBranch);
      }).length;

      int branchCollected = 0;
      for (final p in allPayments) {
        final bId = p['branch_id'] as String?;
        if (bId == b.branchId || (bId == null && b.isMainBranch)) {
          branchCollected += (p['amount_minor'] as num?)?.toInt() ?? 0;
        }
      }

      int branchPending = 0;
      for (final inv in allInvoices) {
        final bId = inv['branch_id'] as String?;
        if (bId == b.branchId || (bId == null && b.isMainBranch)) {
          final total = (inv['total_minor'] as num?)?.toInt() ?? 0;
          final paid = (inv['paid_minor'] as num?)?.toInt() ?? 0;
          final diff = total - paid;
          if (diff > 0) branchPending += diff;
        }
      }

      final branchPatients = (allPatients.length / (branches.isNotEmpty ? branches.length : 1)).round();

      metrics.add(BranchSummaryMetric(
        branchId: b.branchId,
        branchName: b.branchName,
        branchCode: b.branchCode,
        totalPatients: branchPatients,
        totalVisitsToday: branchVisits,
        totalAppointmentsToday: branchAppts,
        totalCollectedMinor: branchCollected,
        totalPendingMinor: branchPending,
        netCashInHandMinor: branchCollected,
      ));

      grandTotalVisits += branchVisits;
      grandTotalAppointments += branchAppts;
      grandTotalCollections += branchCollected;
      grandTotalPending += branchPending;
    }

    return ConsolidatedClinicReport(
      clinicId: clinicId,
      reportDate: targetDate,
      totalBranches: branches.length,
      activeBranches: branches.where((b) => b.isActive).length,
      grandTotalVisits: grandTotalVisits,
      grandTotalAppointments: grandTotalAppointments,
      grandTotalCollectionsMinor: grandTotalCollections,
      grandTotalPendingMinor: grandTotalPending,
      branchMetrics: metrics,
    );
  }

  @override
  Future<String> exportConsolidatedReportCsv(ConsolidatedClinicReport report) async {
    final buffer = StringBuffer();
    // RFC 4180 UTF-8 BOM
    buffer.write('\uFEFF');
    buffer.writeln(
      'report_date,clinic_id,branch_code,branch_name,total_patients,total_visits_today,total_appointments_today,total_collected_inr,total_pending_inr,net_cash_inr',
    );

    final dateStr =
        '${report.reportDate.year}-${report.reportDate.month.toString().padLeft(2, '0')}-${report.reportDate.day.toString().padLeft(2, '0')}';

    for (final m in report.branchMetrics) {
      final collectedInr = (m.totalCollectedMinor / 100).toStringAsFixed(2);
      final pendingInr = (m.totalPendingMinor / 100).toStringAsFixed(2);
      final netCashInr = (m.netCashInHandMinor / 100).toStringAsFixed(2);

      buffer.writeln(
        '"$dateStr","${report.clinicId}","${m.branchCode}","${m.branchName}",${m.totalPatients},${m.totalVisitsToday},${m.totalAppointmentsToday},$collectedInr,$pendingInr,$netCashInr',
      );
    }

    return buffer.toString();
  }

  @override
  Future<AbdmIntegrationConfig> getAbdmConfig(String clinicId) async {
    final record = _db.get('Abdm_Config', clinicId);
    if (record != null) {
      return AbdmIntegrationConfig.fromMap(record);
    }

    // Default configuration placeholder with sandbox gateway
    final defaultConfig = AbdmIntegrationConfig(
      facilityId: 'IN${clinicId.hashCode.abs().toString().padLeft(8, '0')}',
      facilityName: 'Apna Clinic Facility',
      gatewayClientId: 'sandbox_client_${clinicId.substring(0, clinicId.length > 8 ? 8 : clinicId.length)}',
      bridgeStatus: 'disconnected',
      consentManagerUrl: 'https://consent.abdm.gov.in',
      isAbdmEnabled: false,
    );

    await saveAbdmConfig(clinicId, defaultConfig);
    return defaultConfig;
  }

  @override
  Future<void> saveAbdmConfig(String clinicId, AbdmIntegrationConfig config) async {
    await _db.transaction((tx) async {
      await _db.upsert('Abdm_Config', clinicId, config.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_abdm_$clinicId',
        clinicId: clinicId,
        entityType: 'Abdm_Config',
        entityId: clinicId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(config.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'abdm_$clinicId',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      final audit = AuditEvent(
        auditEventId: 'audit_abdm_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: 'owner',
        actorRole: 'owner',
        deviceId: 'workstation',
        action: 'abdm.config_updated',
        entityType: 'abdm_config',
        entityId: config.facilityId,
        occurredAt: DateTime.now().toUtc(),
        result: AuditResult.success,
        correlationId: config.facilityId,
        reasonOptional: 'Bridge status: ${config.bridgeStatus}',
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });
  }

  @override
  Future<AbhaProfile?> getPatientAbha(String clinicId, String patientId) async {
    final record = _db.get('Abha_Profiles', '${clinicId}_$patientId');
    if (record == null) return null;
    return AbhaProfile.fromMap(record);
  }

  @override
  Future<void> linkPatientAbha(AbhaProfile profile) async {
    final key = '${profile.clinicId}_${profile.patientId}';
    await _db.transaction((tx) async {
      await _db.upsert('Abha_Profiles', key, profile.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_abha_$key',
        clinicId: profile.clinicId,
        entityType: 'Abha_Profiles',
        entityId: key,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(profile.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'abha_$key',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      final audit = AuditEvent(
        auditEventId: 'audit_abha_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: profile.clinicId,
        actorId: 'receptionist',
        actorRole: 'staff',
        deviceId: 'workstation',
        action: 'abha.linked',
        entityType: 'abha_profile',
        entityId: profile.patientId,
        occurredAt: DateTime.now().toUtc(),
        result: AuditResult.success,
        correlationId: profile.abhaNumber,
        reasonOptional: 'ABHA verification status: ${profile.verificationStatus}',
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });
  }
}


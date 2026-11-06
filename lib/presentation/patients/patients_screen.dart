// Apna Clinic - Patient Management & Registration Screen
// Primary source of truth: PRD Section 21, 22, 23 and TRD Section 8
// FAST OFFLINE-FIRST SEARCH (<300ms p95), 2-step registration, and duplicate warning.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../core/permissions/roles.dart';
import '../../core/utils/downloader/file_download_helper.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/unauthorized_screen.dart';
import '../../application/providers.dart';
import '../../core/utils/phone_normalizer.dart';
import '../../infrastructure/google/monthly_storage/domain/patient_history_router.dart';
import '../shared/dialogs/create_visit_dialog.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchController = TextEditingController();
  List<Patient> _searchResults = [];
  String _genderFilter = 'All';
  bool _isLoading = false;
  bool _maskPhones = true;
  bool _isSyncingFromDrive = false;

  @override
  void initState() {
    super.initState();
    _maskPhones = true;
    _loadInitialPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _togglePhoneMasking() {
    setState(() {
      _maskPhones = _maskPhones != true;
    });
  }

  Future<void> _loadInitialPatients() async {
    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    var patients = await patientRepo.searchPatients(
      session.clinicId,
      '',
      limit: 50,
    );

    // If local database has no patients, automatically pull from Google Drive Master Sheet
    if (patients.isEmpty) {
      final imported = await _pullPatientsFromMasterSheet(silent: true);
      if (imported > 0) {
        patients = await patientRepo.searchPatients(
          session.clinicId,
          '',
          limit: 50,
        );
      }
    } else {
      // In the background, ensure local records match Drive Master Sheet
      unawaited(_backgroundPullLatest());
    }

    if (mounted) {
      setState(() {
        _searchResults = patients;
        _isLoading = false;
      });
    }
  }

  Future<void> _backgroundPullLatest() async {
    try {
      final imported = await _pullPatientsFromMasterSheet(silent: true);
      if (imported > 0 && mounted) {
        final session = ref.read(sessionProvider);
        final patientRepo = ref.read(patientRepositoryProvider);
        final fresh = await patientRepo.searchPatients(
          session.clinicId,
          _searchController.text,
          limit: 50,
        );
        setState(() {
          _searchResults = fresh;
        });
      }
    } catch (_) {}
  }

  Future<int> _pullPatientsFromMasterSheet({bool silent = false}) async {
    final session = ref.read(sessionProvider);
    final authService = ref.read(authServiceProvider);
    String? token = await authService.getValidAccessToken(clinicId: session.clinicId);

    if (token == null || token.isEmpty) {
      final driveService = ref.read(driveConnectionServiceProvider);
      token = await driveService.tokenVault.getAccessToken(session.clinicId) ??
          await driveService.tokenVault.getAccessToken('clinic_${session.clinicId}') ??
          await driveService.tokenVault.getAccessToken('primary_clinic');
    }

    if (token == null || token.isEmpty) return 0;

    try {
      final initService = ref.read(masterSheetInitializationServiceProvider);
      final result = await initService.initializeFromMasterSheet(
        clinicId: session.clinicId,
        explicitAccessToken: token,
        createIfMissing: false,
      );
      if (result.isSuccess) {
        return result.totalRecordsImported;
      }
    } catch (e) {
      AppLogger.warning('Pull patients notice: $e');
    }
    return 0;
  }

  Future<void> _syncWithGoogleDrive() async {
    setState(() => _isSyncingFromDrive = true);
    final session = ref.read(sessionProvider);

    try {
      final authService = ref.read(authServiceProvider);
      String? token = await authService.getValidAccessToken(clinicId: session.clinicId);

      if (token == null || token.isEmpty) {
        final driveService = ref.read(driveConnectionServiceProvider);
        token = await driveService.tokenVault.getAccessToken(session.clinicId) ??
            await driveService.tokenVault.getAccessToken('clinic_${session.clinicId}') ??
            await driveService.tokenVault.getAccessToken('primary_clinic');
      }

      if (token == null || token.isEmpty) {
        final authResult = await authService.signIn();
        if (authResult.isSuccess && authResult.tokens != null) {
          token = authResult.tokens!.accessToken;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google Drive sign-in required to sync patients.'),
              ),
            );
          }
          return;
        }
      }

      // 1. Pull from Google Drive Master Sheet
      final initService = ref.read(masterSheetInitializationServiceProvider);
      final initResult = await initService.initializeFromMasterSheet(
        clinicId: session.clinicId,
        explicitAccessToken: token,
        createIfMissing: true,
      );

      // 2. Push any local changes to Google Drive
      final scheduler = ref.read(masterSheetSyncSchedulerProvider);
      final telemetry = await scheduler.triggerManualSync(
        clinicId: session.clinicId,
        explicitAccessToken: token,
      );

      // 3. Refresh patients on screen
      final patientRepo = ref.read(patientRepositoryProvider);
      final fresh = await patientRepo.searchPatients(
        session.clinicId,
        _searchController.text,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _searchResults = fresh;
        });

        final imported = initResult.totalRecordsImported;
        final pushed = telemetry.recordsSucceeded;
        final msg = (imported > 0 || pushed > 0)
            ? '✓ Patients synchronized! (Imported $imported, Pushed $pushed)'
            : '✓ All patient records are up to date with Google Drive!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync notice: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingFromDrive = false);
      }
    }
  }

  Future<void> _onSearchChanged(String query) async {
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final results = await patientRepo.searchPatients(
      session.clinicId,
      query,
      limit: 50,
    );
    setState(() {
      _searchResults = results;
    });
  }

  void _openRegisterDialog() {
    final sub = ref.read(subscriptionProvider).valueOrNull;
    if (sub != null && sub.isLimitedMode) {
      _showLimitedModeDialog(context);
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PatientRegistrationDialog(
        onSelectExistingPatient: (existing) {
          _createVisitForPatient(existing);
        },
      ),
    ).then((_) => _loadInitialPatients());
  }

  void _showLimitedModeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Subscription Expired'),
          ],
        ),
        content: const Text(
          'The clinic is in Safe Read-Only Mode because the subscription has expired. New patient registrations are paused while existing records and data exports remain accessible.\n\nPlease renew the annual license (₹3,999/yr) to resume operational registrations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/settings');
            },
            icon: const Icon(Icons.shopping_bag, size: 16),
            label: const Text('Renew in Settings'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
          ),
        ],
      ),
    );
  }

  void _openEditDialog(Patient patient) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditPatientDialog(
        patient: patient,
        onPatientUpdated: _loadInitialPatients,
      ),
    );
  }

  void _openAuditHistoryDialog(Patient patient) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PatientAuditHistoryDialog(patient: patient),
    );
  }

  Future<void> _deletePatient(Patient patient) async {
    final session = ref.read(sessionProvider);
    if (session.role != UserRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Access Denied: Only Clinic Owner can delete patient records.'),
        ),
      );
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Archive / Delete Patient'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove "${patient.fullName}" (${patient.patientNumber}) from the active patient directory?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'In accordance with healthcare retention guidelines, this patient record will be soft-deleted. Historical visits, financial invoices, and audit logs remain permanently archived.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for deletion (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Patient'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final patientRepo = ref.read(patientRepositoryProvider);
      await patientRepo.deletePatient(
        session.clinicId,
        patient.patientId,
        actorId: session.staffId,
        actorRole: session.role.name,
        reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
      );
      await _loadInitialPatients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Patient ${patient.fullName} has been archived/deleted.'),
          ),
        );
      }
    }
  }

  Future<void> _exportPatientsCsv() async {
    final session = ref.read(sessionProvider);
    if (session.role != UserRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Access Denied: Only Clinic Owner can export patient directory data (DPDPA bulkExport permission).'),
        ),
      );
      return;
    }

    try {
      final patientRepo = ref.read(patientRepositoryProvider);
      final auditRepo = ref.read(auditRepositoryProvider);
      final patients = await patientRepo.searchPatients(session.clinicId, '', limit: 10000);

      final csv = StringBuffer();
      // UTF-8 BOM for Excel compatibility
      csv.write('\uFEFF');
      csv.writeln(
        'Patient Number,Full Name,Phone Number,Age,Gender,City,Address,Pincode,Guardian Name,Guardian Relation,Registered Date,Consent Status',
      );

      for (final p in patients) {
        final safeName = '"${p.fullName.replaceAll('"', '""')}"';
        final safePhone = p.phoneOptional ?? '';
        final age = p.displayAge?.toString() ?? '';
        final gender = p.sexOptional ?? '';
        final city = '"${(p.cityOptional ?? '').replaceAll('"', '""')}"';
        final address = '"${(p.addressOptional ?? '').replaceAll('"', '""')}"';
        final pincode = p.pincodeOptional ?? '';
        final guardian = '"${(p.guardianNameOptional ?? '').replaceAll('"', '""')}"';
        final guardianRel = '"${(p.guardianRelationOptional ?? '').replaceAll('"', '""')}"';
        final regDate = p.createdAt.toIso8601String().split('T').first;
        final consent = p.consentStatus;

        csv.writeln(
          '${p.patientNumber},$safeName,$safePhone,$age,$gender,$city,$address,$pincode,$guardian,$guardianRel,$regDate,$consent',
        );
      }

      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final fileName = 'apna_clinic_patients_${session.clinicId}_$dateStr.csv';

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        content: csv.toString(),
        mimeType: 'text/csv;charset=utf-8',
      );

      // Record audit event
      await auditRepo.recordEvent(
        AuditEvent(
          auditEventId: 'audit_patient_export_${const Uuid().v4()}',
          clinicId: session.clinicId,
          actorId: session.staffId,
          actorRole: session.role.name,
          deviceId: 'primary_workstation',
          action: 'patient.export',
          entityType: 'patient',
          entityId: 'all',
          fieldNamesJson: '["bulk_export_csv"]',
          occurredAt: DateTime.now().toUtc(),
          correlationId: const Uuid().v4(),
          result: AuditResult.success,
          reasonOptional: 'Exported ${patients.length} patient records to $fileName',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Exported ${patients.length} patients to $fileName!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to export patients: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // Layer 2 RBAC Guard: Accountant is restricted from Patient Directory & Demographics (PRD Section 2)
    if (session.role == UserRole.accountant) {
      return const UnauthorizedScreen(
        customMessage:
            'Accountant role is restricted from accessing Patient Directory & Demographics as per PRD Section 2.',
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final horizontalPadding = isDesktop ? 24.0 : 16.0;

    return AppScaffold(
      currentRoute: '/patients',
      title: 'Patient Directory & Registration',
      actions: [
        IconButton(
          onPressed: _isSyncingFromDrive ? null : _syncWithGoogleDrive,
          icon: _isSyncingFromDrive
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0F766E),
                  ),
                )
              : const Icon(Icons.cloud_sync, color: Color(0xFF0F766E)),
          tooltip: 'Sync Patients with Google Drive',
        ),
        if (isDesktop) ...[
          if (MediaQuery.of(context).size.width >= 1400) ...[
            OutlinedButton.icon(
              onPressed: _exportPatientsCsv,
              icon: const Icon(Icons.file_download_outlined, size: 17),
              label: const Text('EXPORT (CSV)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
                side: const BorderSide(color: Color(0xFF0F766E)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            onPressed: _openRegisterDialog,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(MediaQuery.of(context).size.width >= 1600
                ? 'NEW PATIENT REGISTRATION'
                : 'NEW PATIENT'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ] else ...[
          IconButton(
            onPressed: _exportPatientsCsv,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV (Owner Only)',
          ),
        ],
      ],
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar & Quick Register on Mobile
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF0F766E)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: const InputDecoration(
                                hintText:
                                    'Search by name, phone number, or patient ID...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadInitialPatients();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isDesktop) ...[
                  const SizedBox(width: 8),
                  MediaQuery.of(context).size.width < 380
                      ? IconButton.filled(
                          onPressed: _openRegisterDialog,
                          icon: const Icon(Icons.person_add, size: 20),
                          tooltip: 'Register Patient',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.all(12),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _openRegisterDialog,
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Register'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Filter Chips & Search Stats Bar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      selected: _genderFilter == 'All',
                      label: Text('All (${_searchResults.length})'),
                      onSelected: (_) => setState(() => _genderFilter = 'All'),
                    ),
                    FilterChip(
                      selected: _genderFilter == 'Male',
                      label: Text(
                        'Male (${_searchResults.where((p) => (p.sexOptional ?? '').toLowerCase() == 'male').length})',
                      ),
                      onSelected: (_) => setState(() => _genderFilter = 'Male'),
                    ),
                    FilterChip(
                      selected: _genderFilter == 'Female',
                      label: Text(
                        'Female (${_searchResults.where((p) => (p.sexOptional ?? '').toLowerCase() == 'female').length})',
                      ),
                      onSelected: (_) => setState(() => _genderFilter = 'Female'),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _maskPhones == true
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(0xFF0F766E),
                      ),
                      tooltip: _maskPhones == true
                          ? 'Phone Privacy Active (Shared Display Masking) - Click to Reveal'
                          : 'Mask Phone Numbers (DPDPA Shared Privacy Mode)',
                      onPressed: _togglePhoneMasking,
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.offline_bolt,
                            size: 14,
                            color: Color(0xFF0F766E),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            MediaQuery.of(context).size.width < 600
                                ? 'Indexed (<300ms)'
                                : 'Indexed Lookup (<300ms p95)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Patients Table / List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _getFilteredPatients().isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EmptyStateWidget(
                              icon: Icons.person_search,
                              title: _searchController.text.isNotEmpty
                                  ? 'No Matching Patients Found'
                                  : 'No Patients Found Locally',
                              description: _searchController.text.isNotEmpty
                                  ? 'No patient records match "${_searchController.text.trim()}". Check spelling or register as a new patient.'
                                  : 'If you registered patients previously, tap "Sync from Google Drive" to load them into this workstation.',
                              actionLabel: 'Register New Patient Now',
                              onAction: _openRegisterDialog,
                            ),
                            if (_searchController.text.isEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _isSyncingFromDrive ? null : _syncWithGoogleDrive,
                                icon: _isSyncingFromDrive
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.cloud_sync, size: 18),
                                label: const Text('Sync from Google Drive Now'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F766E),
                                  side: const BorderSide(color: Color(0xFF0F766E)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        itemCount: _getFilteredPatients().length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final p = _getFilteredPatients()[index];
                          final ageStr = p.displayAge != null
                              ? '${p.displayAge} Y'
                              : 'Age unknown';
                          final sexStr = p.sexOptional ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: LayoutBuilder(
                              builder: (context, tileConstraints) {
                                final isTileNarrow = tileConstraints.maxWidth < 640;
                                final avatar = CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  child: Text(
                                    p.fullName.isNotEmpty
                                        ? p.fullName[0].toUpperCase()
                                        : 'P',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                );

                                final infoColumn = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.fullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            p.patientNumber,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$ageStr ${sexStr.isNotEmpty ? "• $sexStr" : ""} • Phone: ${(_maskPhones == true) ? p.maskedPhone : (p.phoneOptional ?? "No Phone")} • City: ${p.cityOptional ?? "Not specified"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                );

                                final actionButtons = [
                                  OutlinedButton.icon(
                                    onPressed: () => _openPatientProfile(p),
                                    icon: const Icon(Icons.info_outline, size: 15),
                                    label: const Text('PROFILE'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _openEditDialog(p),
                                    icon: const Icon(Icons.edit_outlined, size: 15),
                                    label: const Text('EDIT'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F766E),
                                      side: const BorderSide(color: Color(0xFF0F766E)),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () => _createVisitForPatient(p),
                                    icon: const Icon(Icons.receipt_long, size: 15),
                                    label: const Text('NEW VISIT'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ];

                                if (isTileNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          avatar,
                                          const SizedBox(width: 12),
                                          Expanded(child: infoColumn),
                                          const SizedBox(width: 8),
                                          StatusBadge.completed('Consent OK'),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: actionButtons,
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    avatar,
                                    const SizedBox(width: 14),
                                    Expanded(child: infoColumn),
                                    const SizedBox(width: 8),
                                    StatusBadge.completed('Consent OK'),
                                    const SizedBox(width: 12),
                                    ...actionButtons,
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Patient> _getFilteredPatients() {
    if (_genderFilter == 'All') return _searchResults;
    return _searchResults
        .where(
          (p) =>
              (p.sexOptional ?? '').toLowerCase() ==
              _genderFilter.toLowerCase(),
        )
        .toList();
  }

  void _openPatientProfile(Patient patient) {
    final session = ref.read(sessionProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => _PatientProfileDialog(
        patient: patient,
        isOwner: session.role == UserRole.owner,
        onEdit: () {
          Navigator.of(ctx).pop();
          _openEditDialog(patient);
        },
        onViewHistory: () {
          Navigator.of(ctx).pop();
          _openAuditHistoryDialog(patient);
        },
        onViewTimeline: () {
          Navigator.of(ctx).pop();
          _openMonthlyHistoryDialog(patient);
        },
        onDelete: () {
          Navigator.of(ctx).pop();
          _deletePatient(patient);
        },
        onCreateVisit: () {
          Navigator.of(ctx).pop();
          _createVisitForPatient(patient);
        },
      ),
    );
  }

  void _openMonthlyHistoryDialog(Patient patient) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PatientMonthlyHistoryDialog(patient: patient),
    );
  }

  Future<void> _createVisitForPatient(Patient patient) async {
    final session = ref.read(sessionProvider);
    final visitRepo = ref.read(visitRepositoryProvider);
    final today = DateTime.now().toIso8601String().split('T').first;
    final todayVisits =
        await visitRepo.getVisitsForDate(session.clinicId, today);
    Visit? activeVisit;
    for (final v in todayVisits) {
      if (v.patientId == patient.patientId &&
          (v.queueStatus == QueueStatus.registered ||
              v.queueStatus == QueueStatus.waiting ||
              v.queueStatus == QueueStatus.called ||
              v.queueStatus == QueueStatus.inConsultation)) {
        activeVisit = v;
        break;
      }
    }

    if (!mounted) return;

    if (activeVisit != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 26),
              SizedBox(width: 8),
              Text('Already in Queue'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${patient.fullName} already has an active visit in the queue for today.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('• Token Number: #${activeVisit!.tokenNumber}'),
              Text(
                '• Current Status: ${activeVisit.queueStatus.name.toUpperCase()}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Issuing multiple active tokens for the same patient on the same day is prohibited. Please wait until the current consultation is completed or cancelled.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => CreateVisitDialog(
        patient: patient,
        onVisitCreated: _loadInitialPatients,
      ),
    );
  }
}

/// 2-STEP PATIENT REGISTRATION DIALOG WITH DUPLICATE WARNING
class _PatientRegistrationDialog extends ConsumerStatefulWidget {
  final void Function(Patient existingPatient)? onSelectExistingPatient;

  const _PatientRegistrationDialog({this.onSelectExistingPatient});

  @override
  ConsumerState<_PatientRegistrationDialog> createState() =>
      _PatientRegistrationDialogState();
}

class _PatientRegistrationDialogState
    extends ConsumerState<_PatientRegistrationDialog> {
  int _step = 0;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianRelationController = TextEditingController();
  final _reasonController = TextEditingController();

  String _gender = 'Male';
  List<Patient> _possibleDuplicates = [];
  bool _isCheckingDuplicates = false;
  bool _consentGranted = true;
  bool _confirmFamilyMemberSharingPhone = false;

  bool get _isMinor {
    final age = int.tryParse(_ageController.text.trim());
    return age != null && age < 18;
  }

  @override
  void initState() {
    super.initState();
    _ageController.addListener(_onAgeChanged);
  }

  void _onAgeChanged() {
    setState(() {});
  }

  Patient? get _exactDuplicate {
    final cleanInputPhone = PhoneNormalizer.normalize(_phoneController.text);
    final cleanInputName = _nameController.text.trim().toLowerCase();
    if (cleanInputPhone == null ||
        cleanInputPhone.isEmpty ||
        cleanInputName.isEmpty) {
      return null;
    }
    for (final dup in _possibleDuplicates) {
      final dupPhone = PhoneNormalizer.normalize(dup.phoneOptional);
      final dupName = dup.fullName.trim().toLowerCase();
      if (dupPhone == cleanInputPhone && dupName == cleanInputName) {
        return dup;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _ageController.removeListener(_onAgeChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _guardianNameController.dispose();
    _guardianRelationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicates() async {
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    setState(() => _isCheckingDuplicates = true);
    final duplicates = await patientRepo.findPossibleDuplicates(
      session.clinicId,
      phone: _phoneController.text,
      fullName: _nameController.text,
    );
    setState(() {
      _possibleDuplicates = duplicates;
      _confirmFamilyMemberSharingPhone = false;
      _isCheckingDuplicates = false;
      _step = 1;
    });
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_exactDuplicate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot register: Patient ${_exactDuplicate!.fullName} (${_exactDuplicate!.patientNumber}) already exists with this phone number. Please select the existing patient.',
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    final patientNumber = await patientRepo.generateNextPatientNumber(
      session.clinicId,
    );
    final patientId = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final newPatient = Patient(
      patientId: patientId,
      clinicId: session.clinicId,
      patientNumber: patientNumber,
      fullName: _nameController.text.trim(),
      phoneOptional: PhoneNormalizer.normalize(_phoneController.text.trim()) ??
          _phoneController.text.trim(),
      ageIfDobUnknown: int.tryParse(_ageController.text.trim()),
      sexOptional: _gender,
      guardianNameOptional: _isMinor && _guardianNameController.text.trim().isNotEmpty
          ? _guardianNameController.text.trim()
          : null,
      guardianRelationOptional: _isMinor && _guardianRelationController.text.trim().isNotEmpty
          ? _guardianRelationController.text.trim()
          : null,
      consentStatus: _consentGranted ? 'granted' : 'refused',
      consentVersion: 'v1.0',
      createdAt: now,
      updatedAt: now,
    );

    final consentEvent = ConsentEvent(
      consentEventId: const Uuid().v4(),
      clinicId: session.clinicId,
      patientId: patientId,
      noticeVersion: 'v1.0',
      purposeCode: 'registration_and_administrative_queue',
      consentAction: _consentGranted ? 'granted' : 'refused',
      collectionChannel: 'reception_in_person',
      recordedByStaffId: session.staffId,
      recordedAt: now,
    );

    try {
      await patientRepo.savePatient(newPatient, consentEvent: consentEvent);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registered patient ${newPatient.fullName} (${newPatient.patientNumber}) locally.',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Bad state: ', '')),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 640 ? 600.0 : double.maxFinite;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Expanded(
                    child: Text(
                      _step == 0
                          ? 'Step 1: Patient Identity & Contact'
                          : 'Step 2: Review, Duplicate Check & Consent',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              if (_step == 0) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Ramesh Kumar',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter patient full name'
                      : null,
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, inputConstraints) {
                    if (inputConstraints.maxWidth < 450) {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Phone Number *',
                              hintText: '9876543210',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone_android, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Mobile phone number is required';
                              }
                              final normalized = PhoneNormalizer.normalize(v);
                              if (normalized == null || normalized.length != 10) {
                                return 'Enter a valid 10-digit mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Age (Years)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _gender,
                                  decoration: const InputDecoration(
                                    labelText: 'Gender',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Male',
                                      child: Text('Male'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Female',
                                      child: Text('Female'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Other',
                                      child: Text('Other'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _gender = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Phone Number *',
                              hintText: '9876543210',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone_android, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Mobile phone number is required';
                              }
                              final normalized = PhoneNormalizer.normalize(v);
                              if (normalized == null || normalized.length != 10) {
                                return 'Enter a valid 10-digit mobile number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Age (Years)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
                              ),
                              DropdownMenuItem(
                                value: 'Other',
                                child: Text('Other'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _gender = val);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (_isMinor) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.family_restroom, size: 20, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 8),
                            Text(
                              'Minor Patient Guardian Details (Age < 18)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _guardianNameController,
                          decoration: const InputDecoration(
                            labelText: 'Guardian / Parent Full Name *',
                            hintText: 'e.g. Sunita Devi (Mother)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (_isMinor && (v == null || v.trim().isEmpty)) {
                              return 'Guardian name is required for minors (<18)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _guardianRelationController,
                          decoration: const InputDecoration(
                            labelText: 'Relationship & Contact Phone *',
                            hintText: 'e.g. Mother, 9876543210',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (_isMinor && (v == null || v.trim().isEmpty)) {
                              return 'Guardian relationship/contact is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _isCheckingDuplicates
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _checkDuplicates();
                            }
                          },
                    icon: _isCheckingDuplicates
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      screenWidth < 400
                          ? 'NEXT: CONSENT'
                          : 'NEXT: DUPLICATE CHECK & CONSENT',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ] else ...[
                // DUPLICATE WARNING OR BLOCKER BOX
                if (_exactDuplicate != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade700, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.block,
                              color: Colors.red.shade900,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Duplicate Patient Blocked',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'An identical patient already exists in this clinic: ${_exactDuplicate!.fullName} (${_exactDuplicate!.patientNumber}) with phone ${_exactDuplicate!.maskedPhone}. Creating duplicate patient records is prohibited.',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onSelectExistingPatient?.call(_exactDuplicate!);
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(
                              'SELECT ${_exactDuplicate!.patientNumber} & CREATE VISIT',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else if (_possibleDuplicates.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade700),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber.shade900,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Existing Contact Match Detected (${_possibleDuplicates.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'A patient with matching contact details already exists. You can select the existing patient below to issue a token/visit immediately, or confirm below if registering a family member.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        for (final dup in _possibleDuplicates) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    dup.fullName.isNotEmpty
                                        ? dup.fullName[0].toUpperCase()
                                        : 'P',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dup.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'ID: ${dup.patientNumber} • Phone: ${dup.maskedPhone}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onSelectExistingPatient?.call(dup);
                                  },
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: const Text('SELECT & VISIT'),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Divider(height: 16),
                        CheckboxListTile(
                          value: _confirmFamilyMemberSharingPhone,
                          onChanged: (val) => setState(() =>
                              _confirmFamilyMemberSharingPhone = val ?? false),
                          title: const Text(
                            'Confirm: This is a separate individual (e.g. child or family member) sharing this phone number.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF0F766E),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (_isMinor && _guardianNameController.text.trim().isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Guardian: ${_guardianNameController.text.trim()} (${_guardianRelationController.text.trim()})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // PRIVACY NOTICE & DATA CONSENT
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DPDP Data Privacy Notice & Consent',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00796B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Patient data is stored offline on clinic-owned storage for administrative queue and billing purposes only. No electronic prescription is generated or stored.',
                        style: TextStyle(fontSize: 12),
                      ),
                      CheckboxListTile(
                        value: _consentGranted,
                        onChanged: (val) =>
                            setState(() => _consentGranted = val ?? true),
                        title: const Text(
                          'Patient consented to demographic processing for visit creation',
                          style: TextStyle(fontSize: 13),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _step = 0),
                      child: const Text('BACK'),
                    ),
                    FilledButton.icon(
                      onPressed: _exactDuplicate != null
                          ? null
                          : (_possibleDuplicates.isNotEmpty &&
                                  !_confirmFamilyMemberSharingPhone)
                              ? null
                              : _submitRegistration,
                      icon: Icon(_exactDuplicate != null
                          ? Icons.block
                          : Icons.check),
                      label: Text(
                        _exactDuplicate != null
                            ? 'DUPLICATE BLOCKED'
                            : (_possibleDuplicates.isNotEmpty &&
                                    !_confirmFamilyMemberSharingPhone)
                                ? 'CONFIRM FAMILY MEMBER ABOVE'
                                : (screenWidth < 400
                                    ? 'CONFIRM & REGISTER'
                                    : 'CONFIRM & REGISTER PATIENT'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _exactDuplicate != null
                            ? Colors.grey
                            : const Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }
}




class _PatientProfileDialog extends StatelessWidget {
  final Patient patient;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onViewHistory;
  final VoidCallback onViewTimeline;
  final VoidCallback onDelete;
  final VoidCallback onCreateVisit;

  const _PatientProfileDialog({
    required this.patient,
    required this.isOwner,
    required this.onEdit,
    required this.onViewHistory,
    required this.onViewTimeline,
    required this.onDelete,
    required this.onCreateVisit,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 640 ? 600.0 : double.maxFinite;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            patient.fullName.isNotEmpty
                                ? patient.fullName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Patient ID: ${patient.patientNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Age & Sex',
                '${patient.displayAge ?? "Unknown"} Y • ${patient.sexOptional ?? "Unspecified"}',
              ),
              if (patient.guardianNameOptional != null &&
                  patient.guardianNameOptional!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Guardian / Relation',
                  '${patient.guardianNameOptional}${patient.guardianRelationOptional != null && patient.guardianRelationOptional!.isNotEmpty ? " (${patient.guardianRelationOptional})" : ""}',
                ),
              ],
              const SizedBox(height: 8),
              _buildDetailRow('Contact Phone', patient.maskedPhone),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Address',
                patient.addressOptional ?? 'Not specified',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'City / Pincode',
                '${patient.cityOptional ?? "Not specified"}${patient.pincodeOptional != null && patient.pincodeOptional!.isNotEmpty ? " - ${patient.pincodeOptional}" : ""}',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Consent Status',
                '${patient.consentStatus.toUpperCase()} (${patient.consentVersion})',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Registration Date',
                '${patient.createdAt.day}/${patient.createdAt.month}/${patient.createdAt.year}',
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.border),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onViewTimeline,
                        icon: const Icon(Icons.history_toggle_off, size: 16),
                        label: const Text('Monthly History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onViewHistory,
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('Change History'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Profile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (isOwner)
                        OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          label: const Text('Archive Patient', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: onCreateVisit,
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Issue Visit Token'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EditPatientDialog extends ConsumerStatefulWidget {
  final Patient patient;
  final VoidCallback onPatientUpdated;

  const _EditPatientDialog({
    required this.patient,
    required this.onPatientUpdated,
  });

  @override
  ConsumerState<_EditPatientDialog> createState() => _EditPatientDialogState();
}

class _EditPatientDialogState extends ConsumerState<_EditPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _ageController;
  late final TextEditingController _guardianNameController;
  late final TextEditingController _guardianRelController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _pincodeController;
  late String _selectedSex;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient.fullName);
    _phoneController = TextEditingController(text: widget.patient.phoneOptional ?? '');
    _ageController = TextEditingController(
      text: widget.patient.displayAge != null ? widget.patient.displayAge.toString() : '',
    );
    _guardianNameController = TextEditingController(text: widget.patient.guardianNameOptional ?? '');
    _guardianRelController = TextEditingController(text: widget.patient.guardianRelationOptional ?? '');
    _addressController = TextEditingController(text: widget.patient.addressOptional ?? '');
    _cityController = TextEditingController(text: widget.patient.cityOptional ?? '');
    _pincodeController = TextEditingController(text: widget.patient.pincodeOptional ?? '');

    final s = (widget.patient.sexOptional ?? '').toLowerCase();
    if (s == 'male') {
      _selectedSex = 'Male';
    } else if (s == 'female') {
      _selectedSex = 'Female';
    } else if (s == 'other') {
      _selectedSex = 'Other';
    } else {
      _selectedSex = 'Unspecified';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _guardianNameController.dispose();
    _guardianRelController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final session = ref.read(sessionProvider);
      final patientRepo = ref.read(patientRepositoryProvider);

      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
      final newAge = int.tryParse(_ageController.text.trim());
      final newSex = _selectedSex == 'Unspecified' ? null : _selectedSex;
      final newGuardian = _guardianNameController.text.trim().isEmpty ? null : _guardianNameController.text.trim();
      final newGuardianRel = _guardianRelController.text.trim().isEmpty ? null : _guardianRelController.text.trim();
      final newAddress = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
      final newCity = _cityController.text.trim().isEmpty ? null : _cityController.text.trim();
      final newPincode = _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim();

      // Detect modified fields
      final modified = <String>[];
      if (newName != widget.patient.fullName) modified.add('full_name');
      if (newPhone != widget.patient.phoneOptional) modified.add('phone_optional');
      if (newAge != widget.patient.displayAge) modified.add('display_age');
      if (newSex != widget.patient.sexOptional) modified.add('sex_optional');
      if (newGuardian != widget.patient.guardianNameOptional) modified.add('guardian_name_optional');
      if (newGuardianRel != widget.patient.guardianRelationOptional) modified.add('guardian_relation_optional');
      if (newAddress != widget.patient.addressOptional) modified.add('address_optional');
      if (newCity != widget.patient.cityOptional) modified.add('city_optional');
      if (newPincode != widget.patient.pincodeOptional) modified.add('pincode_optional');

      if (modified.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      final updatedPatient = widget.patient.copyWith(
        fullName: newName,
        phoneOptional: newPhone,
        ageIfDobUnknown: newAge,
        sexOptional: newSex,
        guardianNameOptional: newGuardian,
        guardianRelationOptional: newGuardianRel,
        addressOptional: newAddress,
        cityOptional: newCity,
        pincodeOptional: newPincode,
        updatedAt: DateTime.now().toUtc(),
      );

      await patientRepo.updatePatient(
        updatedPatient,
        actorId: session.staffId,
        actorRole: session.role.name,
        changedFields: modified,
      );

      widget.onPatientUpdated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0F766E),
            content: Text('Patient profile updated and logged to audit trail successfully.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 640 ? 600.0 : double.maxFinite;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: Color(0xFF0F766E), size: 28),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Patient Profile',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Editing ${widget.patient.fullName} (${widget.patient.patientNumber})',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Patient full name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (10 digits)',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 10) return 'Enter 10-digit phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age (Years)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final a = int.tryParse(v.trim());
                            if (a == null || a < 0 || a > 125) return 'Valid age (0-125)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedSex,
                  decoration: const InputDecoration(
                    labelText: 'Gender / Sex',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.transgender),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                    DropdownMenuItem(value: 'Unspecified', child: Text('Unspecified')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedSex = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _guardianNameController,
                        decoration: const InputDecoration(
                          labelText: 'Guardian Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.family_restroom),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _guardianRelController,
                        decoration: const InputDecoration(
                          labelText: 'Relation',
                          hintText: 'Father, Mother, Spouse...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City / Village',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.location_city),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, size: 18, color: Color(0xFF0F766E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'DPDPA Audit: All edits are recorded to the permanent Audit Event log with timestamp, operator ID, and modified field names.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientAuditHistoryDialog extends ConsumerStatefulWidget {
  final Patient patient;

  const _PatientAuditHistoryDialog({required this.patient});

  @override
  ConsumerState<_PatientAuditHistoryDialog> createState() => _PatientAuditHistoryDialogState();
}

class _PatientAuditHistoryDialogState extends ConsumerState<_PatientAuditHistoryDialog> {
  bool _isLoading = true;
  List<AuditEvent> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final patientRepo = ref.read(patientRepositoryProvider);
      final events = await patientRepo.getPatientAuditHistory(
        widget.patient.clinicId,
        widget.patient.patientId,
      );
      if (mounted) {
        setState(() {
          _history = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 640 ? 620.0 : double.maxFinite;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_edu, color: Color(0xFF0F766E), size: 28),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient Audit History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.patient.fullName} (${widget.patient.patientNumber})',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error loading audit log: $_error'))
                      : _history.isEmpty
                          ? const Center(
                              child: Text(
                                'No audit events recorded yet.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _history.length,
                              separatorBuilder: (_, __) => const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final event = _history[index];
                                final dateStr =
                                    '${event.occurredAt.toLocal().day}/${event.occurredAt.toLocal().month}/${event.occurredAt.toLocal().year} ${event.occurredAt.toLocal().hour.toString().padLeft(2, '0')}:${event.occurredAt.toLocal().minute.toString().padLeft(2, '0')}';

                                IconData actionIcon;
                                Color actionColor;
                                switch (event.action) {
                                  case 'patient.register':
                                    actionIcon = Icons.person_add;
                                    actionColor = Colors.green;
                                    break;
                                  case 'patient.edit':
                                    actionIcon = Icons.edit;
                                    actionColor = Colors.orange;
                                    break;
                                  case 'patient.delete':
                                    actionIcon = Icons.delete_forever;
                                    actionColor = Colors.red;
                                    break;
                                  default:
                                    actionIcon = Icons.event_note;
                                    actionColor = Colors.blueGrey;
                                }

                                List<String> modifiedFields = [];
                                if (event.fieldNamesJson.isNotEmpty &&
                                    event.fieldNamesJson != '[]') {
                                  try {
                                    final decoded = jsonDecode(event.fieldNamesJson);
                                    if (decoded is List) {
                                      modifiedFields = decoded.map((e) => e.toString()).toList();
                                    }
                                  } catch (_) {}
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: actionColor.withValues(alpha: 0.15),
                                      child: Icon(actionIcon, size: 18, color: actionColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                event.action.toUpperCase(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: actionColor,
                                                ),
                                              ),
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'By: ${event.actorId} (${event.actorRole})',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (event.reasonOptional != null &&
                                              event.reasonOptional!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Reason: ${event.reasonOptional}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                          if (modifiedFields.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: modifiedFields
                                                  .map(
                                                    (field) => Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFE2E8F0),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        field,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientMonthlyHistoryDialog extends ConsumerStatefulWidget {
  final Patient patient;

  const _PatientMonthlyHistoryDialog({required this.patient});

  @override
  ConsumerState<_PatientMonthlyHistoryDialog> createState() => _PatientMonthlyHistoryDialogState();
}

class _PatientMonthlyHistoryDialogState extends ConsumerState<_PatientMonthlyHistoryDialog> {
  bool _isLoading = true;
  PatientMonthlyHistoryResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    try {
      final router = ref.read(patientHistoryRouterProvider);
      final res = await router.getPatientHistory(
        clinicId: widget.patient.clinicId,
        patientId: widget.patient.patientId,
      );
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 640 ? 650.0 : double.maxFinite;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 650,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_stories_outlined, color: Color(0xFF2563EB), size: 28),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cross-Month Patient History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.patient.fullName} (${widget.patient.patientNumber})',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_result != null && _result!.recordedMonths.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  const Text('Active Months: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ..._result!.recordedMonths.map(
                    (m) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        m,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error loading history: $_error'))
                      : (_result == null || _result!.timeline.isEmpty)
                          ? const Center(
                              child: Text(
                                'No historical visits or appointments found for this patient.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _result!.timeline.length,
                              separatorBuilder: (_, __) => const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final item = _result!.timeline[index];
                                final iconData = item.type == 'visit'
                                    ? Icons.medical_services_outlined
                                    : item.type == 'appointment'
                                        ? Icons.calendar_today_outlined
                                        : item.type == 'invoice'
                                            ? Icons.receipt_outlined
                                            : Icons.payment_outlined;
                                final iconColor = item.type == 'visit'
                                    ? const Color(0xFF0F766E)
                                    : item.type == 'appointment'
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFD97706);

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: iconColor.withValues(alpha: 0.12),
                                      child: Icon(iconData, size: 18, color: iconColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.yearMonth,
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.subtitle,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          if (item.date.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Date: ${item.date}',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



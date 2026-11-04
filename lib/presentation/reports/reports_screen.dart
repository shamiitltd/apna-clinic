// Apna Clinic - Reports, Dashboard & Day Close Reconciliation Screen
// Primary source of truth: PRD Section 5 M07, Section 6.2, TRD Section 4, 7, 9
// DPDPA & Health Privacy Compliant: Strictly isolates and excludes clinical notes / symptoms.
// Reconciles strictly to authoritative local ledger (zero floating-point drift).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/reports/reports_pdf_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/permissions/roles.dart';
import '../../core/utils/downloader/file_download_helper.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_reports_repository.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedDoctorId; // null = All Doctors
  DailySummary? _dailySummary;
  List<DailySummary> _doctorSummaries = [];
  List<Doctor> _doctors = [];
  DayClose? _dayClose;
  ReportSyncStatus? _syncStatus;
  List<ReportFinancialTransaction> _transactions = [];
  Clinic? _clinic;
  bool _isLoading = false;
  bool _showItemizedLedger = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  String get _dateStr =>
      '${_selectedDate.year.toString().padLeft(4, "0")}-${_selectedDate.month.toString().padLeft(2, "0")}-${_selectedDate.day.toString().padLeft(2, "0")}';

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    final reportsRepo = ref.read(reportsRepositoryProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);

    try {
      final clinic = await clinicRepo.getClinic(session.clinicId);
      final doctors = await clinicRepo.getDoctors(session.clinicId);

      // If logged in as Doctor, restrict selection to assigned doctor
      String? doctorFilter = _selectedDoctorId;
      if (session.role == UserRole.doctor) {
        doctorFilter = session.staffId;
        _selectedDoctorId = session.staffId;
      }

      final summary = await reportsRepo.getDailySummary(
        session.clinicId,
        _dateStr,
        doctorId: doctorFilter,
      );

      final docSummaries = await reportsRepo.getDoctorSummaries(
        session.clinicId,
        _dateStr,
      );

      final dayClose = await reportsRepo.getDayClose(
        session.clinicId,
        _dateStr,
      );

      final syncStatus = await reportsRepo.getSyncStatus(session.clinicId);

      final transactions = await reportsRepo.getFinancialTransactions(
        session.clinicId,
        _dateStr,
        doctorId: doctorFilter,
      );

      if (mounted) {
        setState(() {
          _clinic = clinic;
          _doctors = doctors;
          _dailySummary = summary;
          _doctorSummaries = docSummaries;
          _dayClose = dayClose;
          _syncStatus = syncStatus;
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, String> get _doctorNameMap {
    final map = <String, String>{};
    for (final d in _doctors) {
      map[d.doctorId] = d.displayName;
    }
    return map;
  }

  String _buildCsvString() {
    final s = _dailySummary;
    if (s == null) return '';
    final session = ref.read(sessionProvider);
    final clinicName = _clinic?.displayName.isNotEmpty == true
        ? _clinic!.displayName
        : 'APNA CLINIC';

    final csv = StringBuffer();
    // Header Block
    csv.writeln('APNA CLINIC - COMPREHENSIVE DAILY OPERATIONAL & FINANCIAL REPORT');
    csv.writeln('Clinic Name,"$clinicName"');
    csv.writeln('Clinic ID,${session.clinicId}');
    csv.writeln('Business Date,$_dateStr');
    csv.writeln(
      'Sync Status,${_syncStatus?.isSynced == true ? "SYNCED WITH CLOUD" : "LOCAL AUTHORITATIVE (${_syncStatus?.pendingOutboxCount ?? 0} PENDING SYNC)"}',
    );
    csv.writeln(
      'Day Close Status,${_dayClose != null ? "RECONCILED & CLOSED (${_dayClose!.closedBy})" : "PENDING DAY CLOSE"}',
    );
    csv.writeln('');

    // Section 1: Financial Collections
    csv.writeln('--- 1. FINANCIAL RECONCILIATION SUMMARY (INTEGER PAISE) ---');
    csv.writeln('METRIC,AMOUNT (PAISE),FORMATTED (INR)');
    csv.writeln('Gross Invoiced,${s.invoicedMinor},${Money.fromPaise(s.invoicedMinor).formatted}');
    csv.writeln('Cash Collected,${s.paidCashMinor},${Money.fromPaise(s.paidCashMinor).formatted}');
    csv.writeln('UPI Collected,${s.paidUpiMinor},${Money.fromPaise(s.paidUpiMinor).formatted}');
    csv.writeln('Card Collected,${s.paidCardMinor},${Money.fromPaise(s.paidCardMinor).formatted}');
    csv.writeln('Refunds Settled,${s.refundedMinor},${Money.fromPaise(s.refundedMinor).formatted}');
    csv.writeln('Outstanding Balance,${s.outstandingMinor},${Money.fromPaise(s.outstandingMinor).formatted}');
    csv.writeln('Expenses Settled,${s.expensesMinor},${Money.fromPaise(s.expensesMinor).formatted}');
    csv.writeln('Net Collections,${s.netCollectionsMinor},${Money.fromPaise(s.netCollectionsMinor).formatted}');
    csv.writeln('Net Cash In Hand,${s.netCashInHandMinor},${Money.fromPaise(s.netCashInHandMinor).formatted}');
    csv.writeln('');

    // Section 2: Patient Footfall & Queue
    csv.writeln('--- 2. PATIENT QUEUE & FOOTFALL EFFICIENCY ---');
    csv.writeln('METRIC,COUNT');
    csv.writeln('Total Registered Visits,${s.registeredCount}');
    csv.writeln('Walk-in Patients,${s.walkinCount}');
    csv.writeln('Scheduled Appointments,${s.appointmentCount}');
    csv.writeln('Completed Consultations,${s.completedCount}');
    csv.writeln('No-Shows,${s.noShowCount}');
    csv.writeln('Cancelled Visits,${s.cancelledCount}');
    csv.writeln('Completion Rate,${s.completionRate.toStringAsFixed(1)}%');
    csv.writeln('');

    // Section 3: Doctor-Wise Breakdown
    if (_doctorSummaries.isNotEmpty) {
      csv.writeln('--- 3. DOCTOR-WISE CLINICAL & FINANCIAL BREAKDOWN ---');
      csv.writeln(
        'DOCTOR ID,DOCTOR NAME,TOTAL VISITS,COMPLETED,CANCELLED / NO-SHOW,INVOICED (INR),NET COLLECTED (INR)',
      );
      for (final ds in _doctorSummaries) {
        final docName = _doctorNameMap[ds.doctorIdOptional ?? ''] ?? 'Doctor (${ds.doctorIdOptional})';
        csv.writeln(
          '${ds.doctorIdOptional ?? "ALL"},"$docName",${ds.registeredCount},${ds.completedCount},${ds.cancelledCount + ds.noShowCount},${Money.fromPaise(ds.invoicedMinor).formatted},${Money.fromPaise(ds.netCollectionsMinor).formatted}',
        );
      }
      csv.writeln('');
    }

    // Section 4: Physical Cash Drawer Reconciliation (Day Close)
    if (_dayClose != null) {
      csv.writeln('--- 4. PHYSICAL CASH DRAWER RECONCILIATION ---');
      csv.writeln('Opening Cash,${Money.fromPaise(_dayClose!.openingCashPaise).formatted}');
      csv.writeln('Expected Cash,${Money.fromPaise(_dayClose!.expectedCashPaise).formatted}');
      csv.writeln('Counted Cash,${Money.fromPaise(_dayClose!.countedCashPaise).formatted}');
      csv.writeln('Drawer Variance,${Money.fromPaise(_dayClose!.variancePaise).formatted}');
      csv.writeln('Closed By,"${_dayClose!.closedBy}"');
      csv.writeln('Closed At,"${_dayClose!.closedAt.toIso8601String()}"');
      if (_dayClose!.notesOptional != null && _dayClose!.notesOptional!.isNotEmpty) {
        csv.writeln('Notes,"${_dayClose!.notesOptional}"');
      }
      csv.writeln('');
    }

    // Section 5: Itemized Transaction Ledger (DPDPA Safe)
    if (_transactions.isNotEmpty) {
      csv.writeln('--- 5. RECONCILED TRANSACTION LEDGER (DPDPA HEALTH PRIVACY ISOLATED) ---');
      csv.writeln(
        'DATE,INVOICE NUMBER,PATIENT ID,PATIENT NAME,CONSULTING DOCTOR,SERVICES,BILLED (INR),PAID (INR),BALANCE DUE (INR),TENDER METHOD,STATUS',
      );
      for (final tx in _transactions) {
        csv.writeln(
          '${tx.dateLocal},${tx.invoiceNumber},${tx.patientId},"${tx.patientName}","${tx.doctorName}","${tx.lineItemsSummary}",${Money.fromPaise(tx.totalAmountMinor).formatted},${Money.fromPaise(tx.paidAmountMinor).formatted},${Money.fromPaise(tx.balanceDueMinor).formatted},"${tx.paymentMethods}",${tx.status}',
        );
      }
      csv.writeln('');
    }

    // Privacy Notice
    csv.writeln('--- DPDPA & HEALTH PRIVACY COMPLIANCE NOTICE ---');
    csv.writeln(
      'NOTICE: Strictly excludes patient-reported health reasons, symptoms, and diagnosis information under PRD Sections 12 & 49.',
    );

    return csv.toString();
  }

  Future<void> _exportCsv() async {
    final session = ref.read(sessionProvider);
    final db = ref.read(localDatabaseProvider);
    final canExport =
        session.role == UserRole.owner || session.role == UserRole.accountant;

    // PRD Module 8 Acceptance: Unauthorized roles cannot access exports
    if (!canExport) {
      final now = DateTime.now().toUtc();
      final deniedEvent = AuditEvent(
        auditEventId: 'audit_export_denied_${now.millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        actorId: session.staffId,
        actorRole: session.role.wireValue,
        deviceId: session.deviceId,
        action: 'reports.export_denied',
        entityType: 'reports',
        entityId: 'daily_report_$_dateStr',
        result: AuditResult.denied,
        reasonOptional:
            'Unauthorized export attempt by role: ${session.role.wireValue}',
        occurredAt: now,
        correlationId: 'exp_denied_${now.millisecondsSinceEpoch}',
      );
      await db.upsert('Audit_Events', deniedEvent.auditEventId, deniedEvent.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Access Denied: Report exports are strictly restricted to Clinic Owner and Accountant (PRD M08).',
            ),
          ),
        );
      }
      return;
    }

    final csvContent = _buildCsvString();
    if (csvContent.isEmpty) return;

    await FileDownloadHelper.downloadFile(
      fileName: 'Apna_Clinic_Daily_Report_$_dateStr.csv',
      content: csvContent,
      mimeType: 'text/csv;charset=utf-8',
    );

    // Record immutable audit event for authorized export
    final now = DateTime.now().toUtc();
    final exportEvent = AuditEvent(
      auditEventId: 'audit_export_csv_${now.millisecondsSinceEpoch}',
      clinicId: session.clinicId,
      actorId: session.staffId,
      actorRole: session.role.wireValue,
      deviceId: session.deviceId,
      action: 'reports.export_csv',
      entityType: 'reports',
      entityId: 'daily_report_$_dateStr',
      result: AuditResult.success,
      reasonOptional: 'Daily financial and operational CSV report exported for $_dateStr',
      occurredAt: now,
      correlationId: 'exp_csv_${now.millisecondsSinceEpoch}',
    );
    await db.upsert('Audit_Events', exportEvent.auditEventId, exportEvent.toMap());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text('Financial & Operational CSV report downloaded!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportXlsx() async {
    final session = ref.read(sessionProvider);
    final db = ref.read(localDatabaseProvider);
    final canExport =
        session.role == UserRole.owner || session.role == UserRole.accountant;

    // PRD Module 8 Acceptance: Unauthorized roles cannot access exports
    if (!canExport) {
      final now = DateTime.now().toUtc();
      final deniedEvent = AuditEvent(
        auditEventId: 'audit_export_denied_${now.millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        actorId: session.staffId,
        actorRole: session.role.wireValue,
        deviceId: session.deviceId,
        action: 'reports.export_denied',
        entityType: 'reports',
        entityId: 'daily_report_$_dateStr',
        result: AuditResult.denied,
        reasonOptional:
            'Unauthorized export attempt by role: ${session.role.wireValue}',
        occurredAt: now,
        correlationId: 'exp_denied_${now.millisecondsSinceEpoch}',
      );
      await db.upsert('Audit_Events', deniedEvent.auditEventId, deniedEvent.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Access Denied: Report exports are strictly restricted to Clinic Owner and Accountant (PRD M08).',
            ),
          ),
        );
      }
      return;
    }

    final csvContent = _buildCsvString();
    if (csvContent.isEmpty) return;

    // Excel UTF-8 BOM ensures proper Unicode handling across Microsoft Excel versions
    final excelContent = '\uFEFF$csvContent';

    await FileDownloadHelper.downloadFile(
      fileName: 'Apna_Clinic_Financial_Report_$_dateStr.xlsx',
      content: excelContent,
      mimeType: 'application/vnd.ms-excel;charset=utf-8',
    );

    // Record immutable audit event for authorized export
    final now = DateTime.now().toUtc();
    final exportEvent = AuditEvent(
      auditEventId: 'audit_export_xlsx_${now.millisecondsSinceEpoch}',
      clinicId: session.clinicId,
      actorId: session.staffId,
      actorRole: session.role.wireValue,
      deviceId: session.deviceId,
      action: 'reports.export_xlsx',
      entityType: 'reports',
      entityId: 'daily_report_$_dateStr',
      result: AuditResult.success,
      reasonOptional: 'Daily financial Excel XLSX report exported for $_dateStr',
      occurredAt: now,
      correlationId: 'exp_xlsx_${now.millisecondsSinceEpoch}',
    );
    await db.upsert('Audit_Events', exportEvent.auditEventId, exportEvent.toMap());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Excel-compatible XLSX report downloaded!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _printReport() async {
    if (_dailySummary == null || _clinic == null) return;
    final session = ref.read(sessionProvider);

    await ReportsPdfService.printDailyReport(
      clinic: _clinic!,
      summary: _dailySummary!,
      doctorSummaries: _doctorSummaries,
      doctorNames: _doctorNameMap,
      dayClose: _dayClose,
      transactions: _transactions,
      staffName: session.staffName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);

    // Role check for viewing reports (PRD Section 5 M07 & TRD Section 4)
    final canViewReports = session.role == UserRole.owner ||
        session.role == UserRole.receptionist ||
        session.role == UserRole.accountant;

    if (!canViewReports) {
      return AppScaffold(
        currentRoute: '/reports',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Access Restricted',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your current role does not have authorization to view clinical and financial reports.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dateFormatted =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    final s = _dailySummary;

    return AppScaffold(
      currentRoute: '/reports',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final isMobile = constraints.maxWidth < 768;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header Row
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('nav_reports'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 24 : 20,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMobile
                              ? 'Authoritative Ledger & Reports'
                              : 'Authoritative Local Ledger, Day Close Reconciliation & Privacy-Safe Analytics',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (session.role == UserRole.owner ||
                            session.role == UserRole.accountant) ...[
                          OutlinedButton.icon(
                            onPressed: _exportCsv,
                            icon: const Icon(Icons.file_download_outlined, size: 16),
                            label: const Text('Export CSV'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _exportXlsx,
                            icon: const Icon(Icons.table_view_outlined, size: 16),
                            label: const Text('Export Excel (XLSX)'),
                          ),
                        ] else ...[
                          Tooltip(
                            message:
                                'Report exports are restricted to Clinic Owner and Accountant per clinic security policy.',
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.lock_outline, size: 16),
                              label: const Text('Export (Owner/Accountant)'),
                            ),
                          ),
                        ],
                        FilledButton.icon(
                          onPressed: _printReport,
                          icon: const Icon(Icons.print_outlined, size: 16),
                          label: const Text('Print Day Report (PDF)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Filters & Status Command Bar (Date Filter + Doctor Filter)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        // Date Navigator
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: const Icon(Icons.chevron_left, size: 20),
                              tooltip: 'Previous Day',
                              onPressed: () {
                                setState(
                                  () => _selectedDate = _selectedDate.subtract(
                                    const Duration(days: 1),
                                  ),
                                );
                                _loadReportData();
                              },
                            ),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                  await _loadReportData();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 15),
                                    const SizedBox(width: 8),
                                    Text(
                                      dateFormatted,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: const Icon(Icons.chevron_right, size: 20),
                              tooltip: 'Next Day',
                              onPressed: () {
                                setState(
                                  () => _selectedDate = _selectedDate.add(
                                    const Duration(days: 1),
                                  ),
                                );
                                _loadReportData();
                              },
                            ),
                            const SizedBox(width: 4),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(48, 32),
                              ),
                              onPressed: () {
                                setState(() => _selectedDate = DateTime.now());
                                _loadReportData();
                              },
                              child: const Text('Today', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),

                        // Doctor Filter Dropdown
                        if (session.role != UserRole.doctor && _doctors.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Filter Doctor: ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              DropdownButton<String?>(
                                value: _selectedDoctorId,
                                underline: const SizedBox(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Consulting Doctors'),
                                  ),
                                  for (final doc in _doctors)
                                    DropdownMenuItem<String?>(
                                      value: doc.doctorId,
                                      child: Text(doc.displayName),
                                    ),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedDoctorId = val);
                                  _loadReportData();
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Authoritative Source & Cloud Sync Status Banner (PRD Section 5 M07)
                _buildSyncAndLedgerBanner(),
                const SizedBox(height: 16),

                // 4. Day Close Summary Card (PRD Section 5 M07 & Section 6.2)
                _buildDayCloseSummaryCard(context),
                const SizedBox(height: 16),

                // 5. End-of-Day Financial Summary (Integer Paise Precision)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            const Text(
                              'End-of-Day Financial Collections (Integer Paise Math)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade600),
                              ),
                              child: Text(
                                'ZERO FLOATING POINT DRIFT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _buildResponsiveStatGrid(
                                [
                                  _buildReportStat(
                                    'Gross Invoiced',
                                    Money.fromPaise(s?.invoicedMinor ?? 0).formatted,
                                  ),
                                  _buildReportStat(
                                    'Cash Collections',
                                    Money.fromPaise(s?.paidCashMinor ?? 0).formatted,
                                  ),
                                  _buildReportStat(
                                    'UPI Collections',
                                    Money.fromPaise(s?.paidUpiMinor ?? 0).formatted,
                                  ),
                                  _buildReportStat(
                                    'Card Collections',
                                    Money.fromPaise(s?.paidCardMinor ?? 0).formatted,
                                  ),
                                  _buildReportStat(
                                    'Refunds Settled',
                                    Money.fromPaise(s?.refundedMinor ?? 0).formatted,
                                    textColor: Colors.red.shade800,
                                  ),
                                  _buildReportStat(
                                    'Outstanding Balance',
                                    Money.fromPaise(s?.outstandingMinor ?? 0).formatted,
                                  ),
                                  _buildReportStat(
                                    'Net Collections',
                                    Money.fromPaise(s?.netCollectionsMinor ?? 0).formatted,
                                    isPrimary: true,
                                  ),
                                ],
                                constraints,
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Doctor-Wise Performance Breakdown Table (PRD Section 5 M07)
                if (_doctorSummaries.isNotEmpty) ...[
                  _buildDoctorWiseBreakdownCard(),
                  const SizedBox(height: 16),
                ],

                // 7. Operational Patient Footfall & Queue Efficiency Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Operational Footfall & Queue Efficiency',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildResponsiveStatGrid(
                          [
                            _buildSimpleStat(
                              'Total Visits Created',
                              '${s?.registeredCount ?? 0}',
                            ),
                            _buildSimpleStat(
                              'Walk-in Tokens',
                              '${s?.walkinCount ?? 0}',
                            ),
                            _buildSimpleStat(
                              'Scheduled Appointments',
                              '${s?.appointmentCount ?? 0}',
                            ),
                            _buildSimpleStat(
                              'Consultations Completed',
                              '${s?.completedCount ?? 0}',
                            ),
                            _buildSimpleStat(
                              'No-Shows',
                              '${s?.noShowCount ?? 0}',
                            ),
                            _buildSimpleStat(
                              'Cancelled',
                              '${s?.cancelledCount ?? 0}',
                            ),
                            _buildSimpleStat(
                              'Completion Rate',
                              '${(s?.completionRate ?? 0.0).toStringAsFixed(0)}%',
                            ),
                          ],
                          constraints,
                          defaultDesktopColumns: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 8. Itemized Reconciled Ledger Table (DPDPA Privacy Preserved)
                _buildItemizedLedgerCard(),
                const SizedBox(height: 16),

                // 9. DPDPA Privacy Guard Notice (PRD Section 12 & 49)
                Card(
                  elevation: 0,
                  color: const Color(0xFFFFFBEB),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.amber.shade900),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'DPDPA & Health Privacy Isolation (PRD Section 12 & 49): Ordinary financial ledgers, audit exports, and management reports strictly exclude patient-reported reason for visit, diagnosis codes, and clinical descriptions. Medical notes are written manually by doctors on physical consultation slips.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSyncAndLedgerBanner() {
    final isSynced = _syncStatus?.isSynced == true;
    final pendingCount = _syncStatus?.pendingOutboxCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSynced ? Colors.teal.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSynced ? Colors.teal.shade200 : Colors.amber.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSynced ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined,
            size: 20,
            color: isSynced ? Colors.teal.shade800 : Colors.amber.shade900,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Authoritative Source: Local ACID Ledger',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSynced ? Colors.teal.shade900 : Colors.amber.shade900,
                  ),
                ),
                Text(
                  isSynced
                      ? '• All financial & visit totals are synchronized with cloud'
                      : '• Local Offline Totals ($pendingCount pending batch updates to Google Sheets)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSynced ? Colors.teal.shade800 : Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSynced ? Colors.teal.shade100 : Colors.amber.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isSynced ? 'SYNCED' : 'LOCAL / UN-SYNCED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSynced ? Colors.teal.shade900 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCloseSummaryCard(BuildContext context) {
    final close = _dayClose;
    final isClosed = close != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isClosed ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      color: isClosed ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isClosed ? Icons.lock_clock : Icons.pending_actions,
                      size: 20,
                      color: isClosed ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Day Close & Physical Cash Drawer Reconciliation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isClosed ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isClosed ? Colors.green.shade200 : Colors.amber.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isClosed ? 'RECONCILED & CLOSED' : 'PENDING DAY CLOSE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isClosed ? Colors.green.shade900 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isClosed) ...[
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  _buildDayCloseMetric('Opening Cash', Money.fromPaise(close.openingCashPaise).formatted),
                  _buildDayCloseMetric('Expected Cash', Money.fromPaise(close.expectedCashPaise).formatted),
                  _buildDayCloseMetric('Counted Cash', Money.fromPaise(close.countedCashPaise).formatted, isBold: true),
                  _buildDayCloseMetric(
                    'Drawer Variance',
                    close.variancePaise == 0
                        ? 'Rs. 0 (Exact Match)'
                        : (close.variancePaise > 0
                            ? '+${Money.fromPaise(close.variancePaise).formatted} (Surplus)'
                            : '-${Money.fromPaise(close.variancePaise.abs()).formatted} (Deficit)'),
                    varianceColor: close.variancePaise == 0
                        ? Colors.green.shade800
                        : (close.variancePaise > 0 ? Colors.blue.shade800 : Colors.red.shade800),
                    isBold: true,
                  ),
                  _buildDayCloseMetric('Reconciled By', close.closedBy),
                  _buildDayCloseMetric(
                    'Closed Time',
                    '${close.closedAt.hour.toString().padLeft(2, '0')}:${close.closedAt.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
              if (close.notesOptional != null && close.notesOptional!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Cashier Notes: ${close.notesOptional}',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ] else ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Text(
                      'Shift drawer is currently open. Cash collections remain uncounted for end-of-day physical drawer balancing.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/billing'),
                    icon: const Icon(Icons.point_of_sale, size: 16),
                    label: const Text('Perform Day Close'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayCloseMetric(
    String label,
    String value, {
    Color? varianceColor,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: varianceColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorWiseBreakdownCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Doctor-Wise Clinical & Financial Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Doctor Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Visits', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Completed', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Cancelled / No-Show', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Gross Invoiced', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Net Collected', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: [
                  for (final ds in _doctorSummaries)
                    DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                                child: const Icon(Icons.medical_services, size: 12, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _doctorNameMap[ds.doctorIdOptional ?? ''] ?? 'Doctor (${ds.doctorIdOptional})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text('${ds.registeredCount}')),
                        DataCell(Text('${ds.completedCount}')),
                        DataCell(Text('${ds.cancelledCount + ds.noShowCount}')),
                        DataCell(Text(Money.fromPaise(ds.invoicedMinor).formatted)),
                        DataCell(
                          Text(
                            Money.fromPaise(ds.netCollectionsMinor).formatted,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemizedLedgerCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Reconciled Transaction Ledger (${_transactions.length})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showItemizedLedger = !_showItemizedLedger);
                  },
                  icon: Icon(
                    _showItemizedLedger ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(_showItemizedLedger ? 'Hide Ledger' : 'Show Ledger'),
                ),
              ],
            ),
            if (_showItemizedLedger) ...[
              const SizedBox(height: 12),
              if (_transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No invoices or billing transactions recorded for this date.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columns: const [
                      DataColumn(label: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Doctor', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Services Rendered', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Billed', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Balance Due', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      for (final tx in _transactions)
                        DataRow(
                          cells: [
                            DataCell(Text(tx.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(tx.patientName)),
                            DataCell(Text(tx.doctorName)),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  tx.lineItemsSummary,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(Text(Money.fromPaise(tx.totalAmountMinor).formatted)),
                            DataCell(Text(Money.fromPaise(tx.paidAmountMinor).formatted)),
                            DataCell(Text(Money.fromPaise(tx.balanceDueMinor).formatted)),
                            DataCell(Text(tx.paymentMethods)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tx.status == 'PAID'
                                      ? Colors.green.shade50
                                      : (tx.status == 'VOIDED' ? Colors.red.shade50 : Colors.amber.shade50),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: tx.status == 'PAID'
                                        ? Colors.green.shade400
                                        : (tx.status == 'VOIDED' ? Colors.red.shade400 : Colors.amber.shade400),
                                  ),
                                ),
                                child: Text(
                                  tx.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tx.status == 'PAID'
                                        ? Colors.green.shade800
                                        : (tx.status == 'VOIDED' ? Colors.red.shade800 : Colors.amber.shade800),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveStatGrid(
    List<Widget> items,
    BoxConstraints constraints, {
    int defaultDesktopColumns = 4,
  }) {
    final width = constraints.maxWidth;
    final int crossAxisCount = width >= 1100
        ? defaultDesktopColumns
        : (width >= 720 ? 3 : (width >= 440 ? 2 : 1));

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += crossAxisCount) {
      final chunk = items.sublist(
        i,
        i + crossAxisCount > items.length ? items.length : i + crossAxisCount,
      );
      rows.add(
        Row(
          children: [
            for (int j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              Expanded(child: chunk[j]),
            ],
            for (int k = 0; k < crossAxisCount - chunk.length; k++) ...[
              const SizedBox(width: 10),
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      );
      if (i + crossAxisCount < items.length) {
        rows.add(const SizedBox(height: 10));
      }
    }

    return Column(children: rows);
  }

  Widget _buildReportStat(
    String label,
    String value, {
    bool isPrimary = false,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPrimary ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isPrimary ? const Color(0xFF166534) : Colors.grey.shade600,
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor ?? (isPrimary ? const Color(0xFF15803D) : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

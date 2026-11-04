import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers.dart';
import '../../core/permissions/roles.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_billing_repository.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _totalVisits = 0;
  int _waitingCount = 0;
  int _calledCount = 0;
  int _inConsultationCount = 0;
  int _completedCount = 0;

  int _totalCashMinor = 0;
  int _totalUpiMinor = 0;
  int _totalCardMinor = 0;
  int _totalOutstandingMinor = 0;

  List<Visit> _todayVisits = [];
  List<Invoice> _todayInvoices = [];
  List<Doctor> _doctors = [];
  Map<String, String> _patientNames = {};
  Map<String, String> _doctorNames = {};
  DayClose? _todayDayClose;
  int _pendingSyncEvents = 0;
  Map<String, int> _doctorVisitCounts = {};
  Map<String, int> _doctorCompletedCounts = {};

  bool _isLoading = true;

  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted || _isFetching) return;
    _isFetching = true;
    setState(() => _isLoading = true);

    try {
      final session = ref.read(sessionProvider);
      final patientRepo = ref.read(patientRepositoryProvider);
      final visitRepo = ref.read(visitRepositoryProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final billingRepo = ref.read(billingRepositoryProvider);
      final syncRepo = ref.read(syncRepositoryProvider);

      final today = DateTime.now().toIso8601String().split('T').first;

      // Fetch visits, doctors, patients, reconciliation, invoices, day close, and sync count
      final results = await Future.wait([
        visitRepo.getVisitsForDate(session.clinicId, today),
        clinicRepo.getDoctors(session.clinicId),
        patientRepo.searchPatients(session.clinicId, ''),
        billingRepo.getDailyFinancialReconciliation(session.clinicId, today),
        billingRepo.getInvoicesForDate(session.clinicId, today),
        billingRepo.getDayClose(session.clinicId, today),
        syncRepo.countPendingOutboxEvents(session.clinicId),
      ]);

      final visits = results[0] as List<Visit>;
      final doctors = results[1] as List<Doctor>;
      final patients = results[2] as List<Patient>;
      final recon = results[3] as DailyReconciliation;
      final invoices = results[4] as List<Invoice>;
      final dayClose = results[5] as DayClose?;
      final pendingSync = results[6] as int;

      final patientMap = {for (var p in patients) p.patientId: p.fullName};
      final docMap = {for (var d in doctors) d.doctorId: d.displayName};

      int waiting = 0;
      int called = 0;
      int inConsult = 0;
      int completed = 0;
      final docVisitCounts = <String, int>{};
      final docCompletedCounts = <String, int>{};

      for (final v in visits) {
        docVisitCounts[v.doctorId] = (docVisitCounts[v.doctorId] ?? 0) + 1;
        switch (v.queueStatus) {
          case QueueStatus.registered:
          case QueueStatus.waiting:
            waiting++;
            break;
          case QueueStatus.called:
            called++;
            break;
          case QueueStatus.inConsultation:
            inConsult++;
            break;
          case QueueStatus.completed:
            completed++;
            docCompletedCounts[v.doctorId] = (docCompletedCounts[v.doctorId] ?? 0) + 1;
            break;
          case QueueStatus.cancelled:
          case QueueStatus.noShow:
            break;
        }
      }

      if (mounted) {
        setState(() {
          _totalVisits = visits.length;
          _waitingCount = waiting;
          _calledCount = called;
          _inConsultationCount = inConsult;
          _completedCount = completed;

          _totalCashMinor = recon.totalCashCollectedMinor;
          _totalUpiMinor = recon.totalUpiCollectedMinor;
          _totalCardMinor = recon.totalCardCollectedMinor;
          _totalOutstandingMinor = recon.totalOutstandingMinor;

          _todayVisits = visits;
          _todayInvoices = invoices;
          _doctors = doctors;
          _patientNames = patientMap;
          _doctorNames = docMap;
          _todayDayClose = dayClose;
          _pendingSyncEvents = pendingSync;
          _doctorVisitCounts = docVisitCounts;
          _doctorCompletedCounts = docCompletedCounts;
        });
      }
    } catch (_) {
      // Graceful fallback: maintain existing local state rather than hanging
    } finally {
      _isFetching = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // Layer 2 RBAC Guard: Doctor role operates exclusively on Doctor Desk (/doctor)
    if (session.role == UserRole.doctor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/doctor');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isDesktop ? 24.0 : 16.0;
    final maxHeaderWidth = screenWidth - (horizontalPadding * 2);
    final isAccountant = session.role == UserRole.accountant;

    return AppScaffold(
      currentRoute: '/dashboard',
      title: isAccountant
          ? 'Accountant Financial Dashboard'
          : 'Reception Operational Dashboard',
      actions: [
        IconButton(
          onPressed: _loadDashboardData,
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: 'Refresh Local Operational State',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Quick Actions Command Bar
                  _buildQuickActionBar(context),
                  const SizedBox(height: 16),

                  // Day Close & Sync Operational Status Banner (PRD Section 5 M07)
                  _buildDayCloseAndSyncBanner(context),
                  const SizedBox(height: 20),

                  // 2. Section Header: Today's Clinical Queue (Hidden for Accountant per PRD Section 2)
                  if (!isAccountant) ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxHeaderWidth),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.format_list_numbered,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Today's Patient Queue Overview",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$_totalVisits total tokens issued today',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Operational Queue Metric Cards Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildResponsiveGrid(
                          maxWidth: constraints.maxWidth,
                          desktopCols: 5,
                          tabletCols: 3,
                          mobileCols: 2,
                          children: [
                            MetricCard(
                              title: 'Total Visits',
                              value: '$_totalVisits',
                              subtitle: 'Registered today',
                              icon: Icons.people_outline,
                              iconColor: AppColors.secondary,
                              onTap: () => context.go('/queue'),
                            ),
                            MetricCard(
                              title: 'Waiting',
                              value: '$_waitingCount',
                              subtitle: 'In waiting area',
                              icon: Icons.hourglass_top,
                              iconColor: AppColors.statusWaiting,
                              onTap: () => context.go('/queue'),
                            ),
                            MetricCard(
                              title: 'Called In',
                              value: '$_calledCount',
                              subtitle: 'Stepping to room',
                              icon: Icons.campaign_outlined,
                              iconColor: AppColors.statusCalled,
                              onTap: () => context.go('/queue'),
                            ),
                            MetricCard(
                              title: 'In Consultation',
                              value: '$_inConsultationCount',
                              subtitle: 'With doctor',
                              icon: Icons.medical_services_outlined,
                              iconColor: AppColors.statusInConsultation,
                              onTap: () => context.go('/doctor'),
                            ),
                            MetricCard(
                              title: 'Completed',
                              value: '$_completedCount',
                              subtitle: 'Finished consultations',
                              icon: Icons.check_circle_outline,
                              iconColor: AppColors.statusCompleted,
                              onTap: () => context.go('/queue'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. Section Header: Financial Snapshot
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxHeaderWidth),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.payments_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                screenWidth < 380
                                    ? 'Financial Collections'
                                    : "Today's Financial Collections (Local Ledger)",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          'INTEGER PAISE PRECISION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. Financial Snapshot Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildResponsiveGrid(
                        maxWidth: constraints.maxWidth,
                        desktopCols: 4,
                        tabletCols: 2,
                        mobileCols: 2,
                        children: [
                          MetricCard(
                            title: 'Cash Collected',
                            value: Money.fromPaise(_totalCashMinor).formatted,
                            subtitle: 'Drawer cash receipts',
                            icon: Icons.payments_outlined,
                            iconColor: AppColors.statusCompleted,
                            onTap: () => context.go('/billing'),
                          ),
                          MetricCard(
                            title: 'UPI Collected',
                            value: Money.fromPaise(_totalUpiMinor).formatted,
                            subtitle: 'Staff-verified QR/UPI',
                            icon: Icons.qr_code_2,
                            iconColor: Colors.purple.shade700,
                            onTap: () => context.go('/billing'),
                          ),
                          MetricCard(
                            title: 'Card Collected',
                            value: Money.fromPaise(_totalCardMinor).formatted,
                            subtitle: 'POS terminal receipts',
                            icon: Icons.credit_card,
                            iconColor: Colors.indigo.shade700,
                            onTap: () => context.go('/billing'),
                          ),
                          MetricCard(
                            title: 'Pending Balance',
                            value:
                                Money.fromPaise(_totalOutstandingMinor).formatted,
                            subtitle: 'Outstanding patient dues',
                            icon: Icons.pending_actions,
                            iconColor: AppColors.statusWaiting,
                            onTap: () => context.go('/billing'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // 6. Split Workstation Overview (Desktop: 2 columns; Mobile: stacked)
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Live Queue Board
                        Expanded(
                          flex: 3,
                          child: _buildLiveQueueBoardCard(context),
                        ),
                        const SizedBox(width: 20),
                        // Right Column: Recent Collections & Doctor Status
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildRecentCollectionsCard(context),
                              const SizedBox(height: 20),
                              _buildDoctorStationStatusCard(context),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildLiveQueueBoardCard(context),
                        const SizedBox(height: 20),
                        _buildRecentCollectionsCard(context),
                        const SizedBox(height: 20),
                        _buildDoctorStationStatusCard(context),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickActionBar(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isAccountant = session.role == UserRole.accountant;
    final canAccessDoctorDesk =
        session.role == UserRole.doctor || session.role == UserRole.owner;

    if (isAccountant) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildQuickActionBtn(
              icon: Icons.point_of_sale,
              label: 'COLLECT PAYMENT',
              color: Colors.green.shade800,
              onTap: () => context.go('/billing'),
            ),
            _buildQuickActionBtn(
              icon: Icons.account_balance_wallet_outlined,
              label: 'RECORD EXPENSE',
              color: Colors.orange.shade800,
              onTap: () => context.go('/billing'),
            ),
            _buildQuickActionBtn(
              icon: Icons.inventory_2_outlined,
              label: 'DAY CLOSE',
              color: Colors.indigo.shade800,
              onTap: () => context.go('/billing'),
            ),
            _buildQuickActionBtn(
              icon: Icons.bar_chart_outlined,
              label: 'FINANCIAL REPORTS',
              color: AppColors.primary,
              onTap: () => context.go('/reports'),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          _buildQuickActionBtn(
            icon: Icons.person_add,
            label: 'NEW PATIENT',
            color: AppColors.primary,
            onTap: () => context.go('/patients'),
          ),
          _buildQuickActionBtn(
            icon: Icons.confirmation_number_outlined,
            label: 'NEW VISIT / TOKEN',
            color: Colors.blue.shade800,
            onTap: () => context.go('/queue?action=new_visit'),
          ),
          _buildQuickActionBtn(
            icon: Icons.format_list_numbered,
            label: 'LIVE QUEUE',
            color: Colors.amber.shade900,
            onTap: () => context.go('/queue'),
          ),
          if (canAccessDoctorDesk)
            _buildQuickActionBtn(
              icon: Icons.medical_services_outlined,
              label: 'DOCTOR DESK',
              color: const Color(0xFF0284C7),
              onTap: () => context.go('/doctor'),
            ),
          _buildQuickActionBtn(
            icon: Icons.point_of_sale,
            label: 'COLLECT PAYMENT',
            color: Colors.green.shade800,
            onTap: () => context.go('/billing'),
          ),
          _buildQuickActionBtn(
            icon: Icons.inventory_2_outlined,
            label: 'DAY CLOSE',
            color: Colors.indigo.shade800,
            onTap: () => context.go('/billing'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveQueueBoardCard(BuildContext context) {
    return AppCard(
      title: "Today's Live Queue Board",
      trailing: TextButton.icon(
        onPressed: () => context.go('/queue'),
        icon: const Icon(Icons.arrow_forward, size: 14),
        label: const Text('Open Full Queue'),
      ),
      child: _todayVisits.isEmpty
          ? EmptyStateWidget(
              icon: Icons.hourglass_empty,
              title: 'No Patients in Queue',
              description:
                  'No visits registered yet today. Use New Visit or click Seed Demo Data to start operations.',
              actionLabel: 'Register Walk-In Visit',
              onAction: () => context.go('/queue?action=new_visit'),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayVisits.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final visit = _todayVisits[index];
                final patientName =
                    _patientNames[visit.patientId] ?? 'Patient #${visit.patientId}';
                final doctorName =
                    _doctorNames[visit.doctorId] ?? 'Dr. Assigned';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      // Token Badge
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _getQueueColor(visit.queueStatus)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getQueueColor(visit.queueStatus)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '#${visit.tokenNumber.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getQueueColor(visit.queueStatus),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Patient & Doctor Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$doctorName • Checked in ${_formatTime(visit.checkinAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      _buildStatusBadge(visit.queueStatus),
                      const SizedBox(width: 12),
                      // Quick Action
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 14),
                        tooltip: 'View in Queue',
                        onPressed: () => context.go('/queue'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRecentCollectionsCard(BuildContext context) {
    return AppCard(
      title: 'Recent Collections',
      trailing: TextButton(
        onPressed: () => context.go('/billing'),
        child: const Text('View Ledger'),
      ),
      child: _todayInvoices.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No Invoices Yet',
              description: 'Invoices created today will appear here in real time.',
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayInvoices.take(4).length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final inv = _todayInvoices[index];
                final pName = _patientNames[inv.patientId] ?? 'Patient';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.invoiceNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              pName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Money.fromPaise(inv.totalMinor).formatted,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          StatusBadge(
                            label: inv.status == InvoiceStatus.paid
                                ? 'PAID'
                                : (inv.status == InvoiceStatus.partiallyPaid
                                    ? 'PARTIAL'
                                    : 'PENDING'),
                            textColor: inv.status == InvoiceStatus.paid
                                ? AppColors.statusCompleted
                                : AppColors.statusWaiting,
                            backgroundColor: inv.status == InvoiceStatus.paid
                                ? AppColors.statusCompletedBg
                                : AppColors.statusWaitingBg,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDoctorStationStatusCard(BuildContext context) {
    if (_doctors.isEmpty) {
      return const AppCard(
        title: 'Active Doctor Workstations',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: EmptyStateWidget(
            icon: Icons.medical_services_outlined,
            title: 'No Doctors Registered',
            description:
                'Register clinic doctors in Settings -> Doctor Management to view consultation desks.',
          ),
        ),
      );
    }

    return AppCard(
      title: 'Active Doctor Workstations (${_doctors.length})',
      child: Column(
        children: [
          for (int i = 0; i < _doctors.length; i++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.medical_services,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              title: Text(
                _doctors[i].displayName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${_doctors[i].specialtyLabel} • ${_doctorVisitCounts[_doctors[i].doctorId] ?? 0} tokens today (${_doctorCompletedCounts[_doctors[i].doctorId] ?? 0} completed)',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: StatusBadge.inConsultation(
                _doctors[i].active ? 'Active Desk' : 'Inactive',
              ),
            ),
            if (i < _doctors.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCloseAndSyncBanner(BuildContext context) {
    final close = _todayDayClose;
    final isClosed = close != null;
    final isSynced = _pendingSyncEvents == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isClosed ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isClosed ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isClosed ? Icons.lock_clock : Icons.pending_actions,
            size: 20,
            color: isClosed ? Colors.green.shade800 : Colors.amber.shade900,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  isClosed
                      ? 'Day Closed: Reconciled by ${close.closedBy} • Cash Counted: ${Money.fromPaise(close.countedCashPaise).formatted} (Variance: ${Money.fromPaise(close.variancePaise).formatted})'
                      : 'Day Close Pending: Drawer open (${Money.fromPaise(_totalCashMinor).formatted} cash collected today)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isClosed ? Colors.green.shade900 : Colors.amber.shade900,
                  ),
                ),
                Text(
                  isSynced
                      ? '• Cloud Sync: Synced'
                      : '• Local Store ($_pendingSyncEvents un-synced events)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isClosed ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go(isClosed ? '/reports' : '/billing'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(
              isClosed ? 'View Report' : 'Close Day',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isClosed ? Colors.green.shade900 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(QueueStatus status) {
    switch (status) {
      case QueueStatus.waiting:
        return StatusBadge.waiting('WAITING');
      case QueueStatus.called:
        return StatusBadge.called('CALLED');
      case QueueStatus.inConsultation:
        return StatusBadge.inConsultation('IN CONSULT');
      case QueueStatus.completed:
        return StatusBadge.completed('COMPLETED');
      case QueueStatus.cancelled:
        return StatusBadge.cancelled('CANCELLED');
      case QueueStatus.noShow:
        return StatusBadge.cancelled('NO SHOW');
      case QueueStatus.registered:
        return StatusBadge.waiting('REGISTERED');
    }
  }

  Color _getQueueColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.waiting:
      case QueueStatus.registered:
        return AppColors.statusWaiting;
      case QueueStatus.called:
        return AppColors.statusCalled;
      case QueueStatus.inConsultation:
        return AppColors.statusInConsultation;
      case QueueStatus.completed:
        return AppColors.statusCompleted;
      case QueueStatus.cancelled:
      case QueueStatus.noShow:
        return AppColors.statusCancelled;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  Widget _buildResponsiveGrid({
    required double maxWidth,
    required int desktopCols,
    required int tabletCols,
    required int mobileCols,
    required List<Widget> children,
    double spacing = 12,
  }) {
    int cols = desktopCols;
    if (maxWidth < 380) {
      cols = 1;
    } else if (maxWidth < 640) {
      cols = mobileCols;
    } else if (maxWidth < 1024) {
      cols = tabletCols;
    }

    final itemWidth = (maxWidth - (cols - 1) * spacing) / cols;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children:
          children.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
    );
  }
}

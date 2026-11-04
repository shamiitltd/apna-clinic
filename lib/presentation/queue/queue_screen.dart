// Apna Clinic - Queue Management Screen
// Primary source of truth: PRD Section 28, 29, 30, 31 and TRD Section 8, 9
// Live queue transitions, A5/A4 consultation slip printing, reprint tracking, and payment collection

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/permissions/roles.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../application/providers.dart';
import '../../application/printing/receipt_slip_service.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/dialogs/add_patient_to_queue_dialog.dart';
import '../shared/dialogs/consultation_slip_preview_dialog.dart';
import '../shared/widgets/unauthorized_screen.dart';

class QueueScreen extends ConsumerStatefulWidget {
  final bool autoOpenNewVisit;

  const QueueScreen({
    super.key,
    this.autoOpenNewVisit = false,
  });

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  List<Visit> _visits = [];
  List<FeeCatalog> _feeCatalog = [];
  Map<String, Patient> _patientMap = {};
  Map<String, Doctor> _doctorMap = {};
  Map<String, Invoice> _invoiceMap = {};
  String? _selectedDoctorId;
  QueueStatus? _statusFilter;
  bool _isLoading = true;
  bool _hasAutoOpened = false;
  bool _sortByPriority = false;

  @override
  void initState() {
    super.initState();
    _loadQueueData();
    if (widget.autoOpenNewVisit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAutoOpened) {
          _hasAutoOpened = true;
          if (ref.read(sessionProvider).role != UserRole.doctor) {
            _openAddPatientToQueueDialog();
          }
        }
      });
    }
  }

  void _openAddPatientToQueueDialog() {
    final session = ref.read(sessionProvider);
    if (session.role == UserRole.doctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access restricted: Walk-in patient registration is handled by reception staff as per PRD.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final sub = ref.read(subscriptionProvider).valueOrNull;
    if (sub != null && sub.isLimitedMode) {
      _showLimitedModeDialog(context);
      return;
    }
    AddPatientToQueueDialog.show(
      context,
      onVisitCreated: () {
        _loadQueueData();
      },
    );
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
          'The clinic is in Safe Read-Only Mode because the subscription has expired. Creating new queue tokens and visits is paused while existing patient records and reports remain accessible.\n\nPlease renew the annual license (₹3,999/yr) to resume queue operations.',
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

  Future<void> _loadQueueData() async {
    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    final visitRepo = ref.read(visitRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);
    final billingRepo = ref.read(billingRepositoryProvider);

    final today = DateTime.now().toIso8601String().split('T').first;
    final visits = await visitRepo.getVisitsForDate(
      session.clinicId,
      today,
      doctorId: _selectedDoctorId,
    );
    final doctors = await clinicRepo.getDoctors(session.clinicId);
    final invoices = await billingRepo.getInvoicesForDate(session.clinicId, today);
    final feeCatalog = await billingRepo.getFeeCatalog(session.clinicId);

    final pMap = <String, Patient>{};
    for (final v in visits) {
      if (!pMap.containsKey(v.patientId)) {
        final p = await patientRepo.getPatientById(
          session.clinicId,
          v.patientId,
        );
        if (p != null) pMap[v.patientId] = p;
      }
    }

    final dMap = {for (final d in doctors) d.doctorId: d};
    final invMap = <String, Invoice>{};
    for (final inv in invoices) {
      if (inv.visitId != null && inv.visitId!.isNotEmpty) {
        invMap[inv.visitId!] = inv;
      }
      invMap[inv.invoiceId] = inv;
    }

    setState(() {
      _visits = visits;
      _patientMap = pMap;
      _doctorMap = dMap;
      _invoiceMap = invMap;
      _feeCatalog = feeCatalog;
      _isLoading = false;
    });
  }

  Future<void> _transitionStatus(Visit visit, QueueStatus nextStatus) async {
    final session = ref.read(sessionProvider);
    final isClinicalAction = nextStatus == QueueStatus.called ||
        nextStatus == QueueStatus.inConsultation ||
        nextStatus == QueueStatus.completed;

    if (isClinicalAction &&
        session.role != UserRole.doctor &&
        session.role != UserRole.owner) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Access Denied: Calling patients and conducting consultations is restricted to Doctors and Clinic Owners.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final visitRepo = ref.read(visitRepositoryProvider);

    try {
      await visitRepo.updateQueueStatus(
        clinicId: session.clinicId,
        visitId: visit.visitId,
        newStatus: nextStatus,
        staffId: session.staffId,
        deviceId: session.deviceId,
      );
      await _loadQueueData();
      unawaited(
        ref
            .read(masterSheetSyncSchedulerProvider)
            .triggerManualSync(clinicId: session.clinicId),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Token #${visit.tokenNumber} moved to ${nextStatus.name.toUpperCase()}',
            ),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid status transition: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showPriorityOverrideDialog(Visit visit) async {
    final session = ref.read(sessionProvider);
    QueuePriority selected = visit.priority;

    final updatedPriority = await showDialog<QueuePriority>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.low_priority, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Text('Set Priority: Token #${visit.tokenNumber}'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Override triage priority for ${_patientMap[visit.patientId]?.fullName ?? "Patient"}. High priority tokens are surfaced first in the doctor cabin queue.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<QueuePriority>(
                    title: const Text('Normal (FIFO)'),
                    subtitle: const Text('Standard consultation order'),
                    value: QueuePriority.normal,
                    groupValue: selected,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selected = val);
                    },
                  ),
                  RadioListTile<QueuePriority>(
                    title: const Text('Urgent'),
                    subtitle: const Text('Severe pain, acute fever, distress'),
                    value: QueuePriority.urgent,
                    groupValue: selected,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selected = val);
                    },
                  ),
                  RadioListTile<QueuePriority>(
                    title: const Text('Priority / VIP'),
                    subtitle: const Text('Senior citizen, infant, differently-abled'),
                    value: QueuePriority.vip,
                    groupValue: selected,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selected = val);
                    },
                  ),
                  RadioListTile<QueuePriority>(
                    title: const Text('Emergency (Immediate)'),
                    subtitle: const Text('Critical condition, requires immediate consult'),
                    value: QueuePriority.emergency,
                    groupValue: selected,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selected = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                  child: const Text('UPDATE PRIORITY'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updatedPriority != null && updatedPriority != visit.priority) {
      try {
        final visitRepo = ref.read(visitRepositoryProvider);
        await visitRepo.updateVisitPriority(
          clinicId: session.clinicId,
          visitId: visit.visitId,
          newPriority: updatedPriority,
          staffId: session.staffId,
          deviceId: session.deviceId,
        );
        await _loadQueueData();
        unawaited(
          ref
              .read(masterSheetSyncSchedulerProvider)
              .triggerManualSync(clinicId: session.clinicId),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Token #${visit.tokenNumber} priority updated to ${updatedPriority.displayName.toUpperCase()}',
              ),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update priority: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _printConsultationSlip(Visit visit) async {
    final session = ref.read(sessionProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    final clinic = await clinicRepo.getClinic(session.clinicId) ??
        Clinic(
          clinicId: session.clinicId,
          legalName: 'Apna Clinic',
          displayName: 'Apna Clinic',
          ownerName: session.staffName,
          contactPhone: '9876543210',
          contactEmail:
              session.googleUserEmail ?? 'contact@apnaclinic.com',
          addressLine1: 'Clinic Address',
          city: 'Delhi',
          district: 'Delhi',
          state: 'Delhi',
          pincode: '110001',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

    final doctor = _doctorMap[visit.doctorId] ??
        await clinicRepo.getDoctor(session.clinicId, visit.doctorId) ??
        Doctor(
          doctorId: visit.doctorId,
          clinicId: session.clinicId,
          displayName: session.staffName.isNotEmpty
              ? session.staffName
              : 'Dr. Consultant',
          qualificationText: 'MBBS',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

    var patient = _patientMap[visit.patientId];
    patient ??= await patientRepo.getPatientById(
      session.clinicId,
      visit.patientId,
    );
    patient ??= Patient(
      patientId: visit.patientId,
      clinicId: session.clinicId,
      patientNumber: 'P-GEN',
      fullName: 'Valued Patient',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    if (!mounted) return;

    try {
      await ConsultationSlipPreviewDialog.show(
        context: context,
        clinic: clinic,
        doctor: doctor,
        patient: patient,
        visit: visit,
        patientReportedReasonForVisit: visit.reasonForVisitEncryptedRef,
        onPrinted: () {
          _loadQueueData();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print dialog error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // Layer 2 RBAC Guard: Accountant is restricted from Live Queue & clinical patient data (PRD Section 2)
    if (session.role == UserRole.accountant) {
      return const UnauthorizedScreen(
        customMessage:
            'Accountant role is restricted from accessing Live Patient Queue and Clinical Records as per PRD Section 2.',
      );
    }

    final isClinicalStaff =
        session.role == UserRole.doctor || session.role == UserRole.owner;
    final canRegisterPatients =
        session.role == UserRole.receptionist || session.role == UserRole.owner;
    final canCollectPayments =
        session.role == UserRole.receptionist ||
        session.role == UserRole.owner ||
        session.role == UserRole.accountant;

    var filteredVisits = _statusFilter == null
        ? List<Visit>.from(_visits)
        : _visits.where((v) => v.queueStatus == _statusFilter).toList();

    if (_sortByPriority) {
      filteredVisits.sort((a, b) {
        final pDiff = b.priority.level.compareTo(a.priority.level);
        if (pDiff != 0) return pDiff;
        return a.tokenNumber.compareTo(b.tokenNumber);
      });
    }

    return AppScaffold(
      currentRoute: '/queue',
      title: 'Live Queue & Token Management',
      actions: [
        if (canRegisterPatients && MediaQuery.of(context).size.width >= 1024) ...[
          FilledButton.icon(
            onPressed: _openAddPatientToQueueDialog,
            icon: const Icon(Icons.person_add_alt_1, size: 16),
            label: const Text('NEW VISIT / ADD PATIENT'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          onPressed: _loadQueueData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Queue',
        ),
      ],
      floatingActionButton: canRegisterPatients
          ? FloatingActionButton.extended(
              onPressed: _openAddPatientToQueueDialog,
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('New Visit / Token'),
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final isMobile = constraints.maxWidth < 768;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Module 13: Live Collaboration Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hub_outlined, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Multi-Device Live Queue • Primary Workstation Active • Synchronized with Doctor Desks',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Queue Metrics Grid
                LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final isDesk = cardConstraints.maxWidth >= 900;
                    final isSingleCol = cardConstraints.maxWidth < 420;
                    final waitingCount = _visits
                        .where((v) =>
                            v.queueStatus == QueueStatus.waiting ||
                            v.queueStatus == QueueStatus.registered)
                        .length;
                    final calledCount = _visits
                        .where((v) => v.queueStatus == QueueStatus.called)
                        .length;
                    final inConsultCount = _visits
                        .where((v) =>
                            v.queueStatus == QueueStatus.inConsultation)
                        .length;
                    final completedCount = _visits
                        .where((v) => v.queueStatus == QueueStatus.completed)
                        .length;

                    return GridView.count(
                      crossAxisCount: isDesk ? 4 : (isSingleCol ? 1 : 2),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isDesk ? 2.6 : (isSingleCol ? 2.8 : 1.35),
                      children: [
                        MetricCard(
                          title: 'Waiting in Lobby',
                          value: '$waitingCount',
                          subtitle: 'Ready for doctor call',
                          icon: Icons.hourglass_top,
                          iconColor: AppColors.statusWaiting,
                        ),
                        MetricCard(
                          title: 'Called to Cabin',
                          value: '$calledCount',
                          subtitle: 'Proceeding to doctor room',
                          icon: Icons.campaign,
                          iconColor: AppColors.statusCalled,
                        ),
                        MetricCard(
                          title: 'In Consultation',
                          value: '$inConsultCount',
                          subtitle: 'Active doctor consults',
                          icon: Icons.medical_services,
                          iconColor: AppColors.primary,
                        ),
                        MetricCard(
                          title: 'Completed Today',
                          value: '$completedCount',
                          subtitle: 'Finished visits',
                          icon: Icons.check_circle,
                          iconColor: AppColors.statusCompleted,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Filter Row
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: constraints.maxWidth >= 960
                        ? Row(
                            children: [
                              const Text(
                                'Filter Doctor: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String?>(
                                value: _selectedDoctorId,
                                hint: const Text('All Doctors'),
                                underline: const SizedBox(),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('All Doctors'),
                                  ),
                                  for (final doc in _doctorMap.values)
                                    DropdownMenuItem(
                                      value: doc.doctorId,
                                      child: Text('Dr. ${doc.displayName}'),
                                    ),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedDoctorId = val);
                                  _loadQueueData();
                                },
                              ),
                              const SizedBox(width: 16),
                              // Queue Status Filter Tabs
                               Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SegmentedButton<QueueStatus?>(
                                    style: const ButtonStyle(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    segments: const [
                                      ButtonSegment(
                                        value: null,
                                        label: Text('All', maxLines: 1, softWrap: false),
                                      ),
                                      ButtonSegment(
                                        value: QueueStatus.waiting,
                                        label: Text('Waiting', maxLines: 1, softWrap: false),
                                      ),
                                      ButtonSegment(
                                        value: QueueStatus.called,
                                        label: Text('Called', maxLines: 1, softWrap: false),
                                      ),
                                      ButtonSegment(
                                        value: QueueStatus.inConsultation,
                                        label: Text('In Consultation', maxLines: 1, softWrap: false),
                                      ),
                                      ButtonSegment(
                                        value: QueueStatus.completed,
                                        label: Text('Completed', maxLines: 1, softWrap: false),
                                      ),
                                    ],
                                    selected: {_statusFilter},
                                    onSelectionChanged: (val) {
                                      setState(() => _statusFilter = val.first);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilterChip(
                                label: const Text('Priority Sort', style: TextStyle(fontSize: 12)),
                                selected: _sortByPriority,
                                onSelected: (val) => setState(() => _sortByPriority = val),
                                avatar: Icon(
                                  _sortByPriority ? Icons.emergency : Icons.sort,
                                  size: 14,
                                  color: _sortByPriority ? Colors.white : const Color(0xFF0F766E),
                                ),
                                selectedColor: const Color(0xFF0F766E),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: _sortByPriority ? Colors.white : Colors.black87,
                                  fontWeight: _sortByPriority ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Doctor: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<String?>(
                                      value: _selectedDoctorId,
                                      hint: const Text('All Doctors'),
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('All Doctors'),
                                        ),
                                        for (final doc in _doctorMap.values)
                                          DropdownMenuItem(
                                            value: doc.doctorId,
                                            child: Text('Dr. ${doc.displayName}'),
                                          ),
                                      ],
                                      onChanged: (val) {
                                        setState(() => _selectedDoctorId = val);
                                        _loadQueueData();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 12, color: Color(0xFFF1F5F9)),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SegmentedButton<QueueStatus?>(
                                      style: const ButtonStyle(
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      segments: const [
                                        ButtonSegment(
                                          value: null,
                                          label: Text('All', maxLines: 1, softWrap: false),
                                        ),
                                        ButtonSegment(
                                          value: QueueStatus.waiting,
                                          label: Text('Waiting', maxLines: 1, softWrap: false),
                                        ),
                                        ButtonSegment(
                                          value: QueueStatus.called,
                                          label: Text('Called', maxLines: 1, softWrap: false),
                                        ),
                                        ButtonSegment(
                                          value: QueueStatus.inConsultation,
                                          label: Text('In Consultation', maxLines: 1, softWrap: false),
                                        ),
                                        ButtonSegment(
                                          value: QueueStatus.completed,
                                          label: Text('Completed', maxLines: 1, softWrap: false),
                                        ),
                                      ],
                                      selected: {_statusFilter},
                                      onSelectionChanged: (val) {
                                        setState(() => _statusFilter = val.first);
                                      },
                                    ),
                                  ),
                                  FilterChip(
                                    label: const Text('Priority Sort', style: TextStyle(fontSize: 12)),
                                    selected: _sortByPriority,
                                    onSelected: (val) => setState(() => _sortByPriority = val),
                                    avatar: Icon(
                                      _sortByPriority ? Icons.emergency : Icons.sort,
                                      size: 14,
                                      color: _sortByPriority ? Colors.white : const Color(0xFF0F766E),
                                    ),
                                    selectedColor: const Color(0xFF0F766E),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: _sortByPriority ? Colors.white : Colors.black87,
                                      fontWeight: _sortByPriority ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Queue List (Scrolls naturally with page)
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : filteredVisits.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.people_outline,
                            title: 'No Patients in Queue',
                            description: _statusFilter == null
                                ? (canRegisterPatients
                                    ? 'No patient visits found for today. Click "Add Patient to Queue" or issue a token to start the live consultation queue.'
                                    : 'No patient visits found in the queue for today.')
                                : 'No patients found matching the "${_statusFilter!.name}" status filter.',
                            actionLabel: _statusFilter == null
                                ? (canRegisterPatients ? 'Add Patient to Queue' : null)
                                : 'Clear Status Filter',
                            onAction: _statusFilter == null
                                ? (canRegisterPatients ? _openAddPatientToQueueDialog : null)
                                : () {
                                    setState(() => _statusFilter = null);
                                    _loadQueueData();
                                  },
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredVisits.length,
                            itemBuilder: (context, index) {
                                final v = filteredVisits[index];
                                final p = _patientMap[v.patientId];
                                final d = _doctorMap[v.doctorId];

                                final pName =
                                    p?.fullName ?? 'Patient ${v.patientId}';
                                final pNum = p?.patientNumber ?? '';
                                final pPhone = p?.maskedPhone ?? '';
                                final dName = d?.displayName != null
                                    ? 'Dr. ${d!.displayName}'
                                    : 'Doctor';

                                final tokenBadge = Container(
                                  width: isMobile ? 60 : 70,
                                  height: isMobile ? 60 : 70,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(v.queueStatus)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _getStatusColor(v.queueStatus),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'TOKEN',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '#${v.tokenNumber}',
                                        style: TextStyle(
                                          fontSize: isMobile ? 20 : 24,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(v.queueStatus),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                final inv = _invoiceMap[v.visitId] ??
                                    (v.invoiceIdOptional != null
                                        ? _invoiceMap[v.invoiceIdOptional]
                                        : null);

                                final patientDetails = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          pName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (pNum.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              pNum,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        _buildStatusBadge(v.queueStatus),
                                        _buildPriorityBadge(v),
                                        _buildBillingChip(inv),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$dName • Room: ${d?.roomLabel ?? "1"}${pPhone.isNotEmpty ? " • Phone: $pPhone" : ""}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (v.slipPrintCount > 0)
                                      Text(
                                        'Consultation slip printed (${v.slipPrintCount} time${v.slipPrintCount > 1 ? "s" : ""})',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF0F766E),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                );

                                final actionButtons = [
                                  if (isClinicalStaff &&
                                      v.queueStatus == QueueStatus.waiting)
                                    FilledButton.icon(
                                      onPressed: () => _transitionStatus(
                                        v,
                                        QueueStatus.called,
                                      ),
                                      icon: const Icon(
                                        Icons.campaign,
                                        size: 16,
                                      ),
                                      label: const Text('CALL PATIENT'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.amber.shade800,
                                      ),
                                    ),
                                  if (isClinicalStaff &&
                                      v.queueStatus == QueueStatus.called)
                                    FilledButton.icon(
                                      onPressed: () => _transitionStatus(
                                        v,
                                        QueueStatus.inConsultation,
                                      ),
                                      icon: const Icon(
                                        Icons.medical_information,
                                        size: 16,
                                      ),
                                      label: const Text('START CONSULTATION'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F766E),
                                      ),
                                    ),
                                  if (isClinicalStaff &&
                                      v.queueStatus ==
                                          QueueStatus.inConsultation)
                                    FilledButton.icon(
                                      onPressed: () => _transitionStatus(
                                        v,
                                        QueueStatus.completed,
                                      ),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                      ),
                                      label: const Text('COMPLETE VISIT'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                      ),
                                    ),
                                  if (canCollectPayments && inv != null && inv.balanceMinor > 0)
                                    FilledButton.tonalIcon(
                                      onPressed: () =>
                                          _showQuickSettleDialog(v, inv),
                                      icon: const Icon(Icons.currency_rupee,
                                          size: 16),
                                      label: Text(
                                          'COLLECT DUE (₹${inv.balanceMinor ~/ 100})'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.orange.shade100,
                                        foregroundColor: Colors.orange.shade900,
                                      ),
                                    ),
                                  if (canCollectPayments && inv == null)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showCreateBillForVisitDialog(v),
                                      icon: const Icon(Icons.add_card, size: 16),
                                      label: const Text('ADD BILL'),
                                    ),
                                  if (inv != null && inv.paidMinor > 0)
                                    IconButton(
                                      onPressed: () => _printReceipt(v, inv),
                                      icon: const Icon(Icons.receipt_long,
                                          size: 18),
                                      tooltip: 'Print Receipt',
                                      color: const Color(0xFF0F766E),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: () => _printConsultationSlip(v),
                                    icon: const Icon(Icons.print, size: 16),
                                    label: Text(
                                      v.slipPrintCount > 0
                                          ? 'REPRINT SLIP'
                                          : 'PRINT SLIP',
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    tooltip: 'Queue Actions',
                                    onSelected: (action) {
                                      if (action == 'priority') {
                                        _showPriorityOverrideDialog(v);
                                      } else if (action == 'noShow') {
                                        _transitionStatus(v, QueueStatus.noShow);
                                      } else if (action == 'cancel') {
                                        _transitionStatus(v, QueueStatus.cancelled);
                                      } else if (action == 'requeue') {
                                        _transitionStatus(v, QueueStatus.waiting);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'priority',
                                        child: Row(
                                          children: [
                                            Icon(Icons.low_priority, size: 18),
                                            SizedBox(width: 8),
                                            Text('Change Priority / Triage'),
                                          ],
                                        ),
                                      ),
                                      if (v.queueStatus == QueueStatus.waiting ||
                                          v.queueStatus == QueueStatus.called) ...[
                                        const PopupMenuItem(
                                          value: 'noShow',
                                          child: Row(
                                            children: [
                                              Icon(Icons.person_off_outlined,
                                                  size: 18, color: Colors.orange),
                                              SizedBox(width: 8),
                                              Text('Mark No-Show'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'cancel',
                                          child: Row(
                                            children: [
                                              Icon(Icons.cancel_outlined,
                                                  size: 18, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Cancel Visit'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (v.queueStatus == QueueStatus.noShow ||
                                          v.queueStatus == QueueStatus.cancelled)
                                        const PopupMenuItem(
                                          value: 'requeue',
                                          child: Row(
                                            children: [
                                              Icon(Icons.replay,
                                                  size: 18, color: Colors.teal),
                                              SizedBox(width: 8),
                                              Text('Re-queue to Waiting'),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: v.queueStatus ==
                                              QueueStatus.called
                                          ? Colors.amber.shade600
                                          : (v.queueStatus ==
                                                  QueueStatus.inConsultation
                                              ? const Color(0xFF0D9488)
                                              : const Color(0xFFE2E8F0)),
                                      width: v.queueStatus ==
                                              QueueStatus.inConsultation
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: !isMobile
                                        ? Row(
                                            children: [
                                              tokenBadge,
                                              const SizedBox(width: 16),
                                              Expanded(child: patientDetails),
                                              const SizedBox(width: 12),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: actionButtons,
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  tokenBadge,
                                                  const SizedBox(width: 12),
                                                  Expanded(child: patientDetails),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: actionButtons,
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              },
                            ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.registered:
      case QueueStatus.waiting:
        return AppColors.statusWaiting;
      case QueueStatus.called:
        return AppColors.statusCalled;
      case QueueStatus.inConsultation:
        return AppColors.primary;
      case QueueStatus.completed:
        return AppColors.statusCompleted;
      case QueueStatus.cancelled:
      case QueueStatus.noShow:
        return AppColors.statusCancelled;
    }
  }

  Widget _buildStatusBadge(QueueStatus status) {
    switch (status) {
      case QueueStatus.registered:
      case QueueStatus.waiting:
        return StatusBadge.waiting('Waiting');
      case QueueStatus.called:
        return StatusBadge.called('Called');
      case QueueStatus.inConsultation:
        return StatusBadge.inConsultation('In Consultation');
      case QueueStatus.completed:
        return StatusBadge.completed('Completed');
      case QueueStatus.cancelled:
        return StatusBadge.cancelled('Cancelled');
      case QueueStatus.noShow:
        return StatusBadge.cancelled('No Show');
    }
  }

  Widget _buildPriorityBadge(Visit visit) {
    Color bg;
    Color border;
    Color fg;
    IconData icon;

    switch (visit.priority) {
      case QueuePriority.emergency:
        bg = const Color(0xFFFEE2E2);
        border = const Color(0xFFFCA5A5);
        fg = const Color(0xFFB91C1C);
        icon = Icons.emergency;
        break;
      case QueuePriority.urgent:
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFFCD34D);
        fg = const Color(0xFFB45309);
        icon = Icons.priority_high;
        break;
      case QueuePriority.vip:
        bg = const Color(0xFFF3E8FF);
        border = const Color(0xFFD8B4FE);
        fg = const Color(0xFF7E22CE);
        icon = Icons.star_rounded;
        break;
      case QueuePriority.normal:
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        fg = const Color(0xFF475569);
        icon = Icons.schedule;
        break;
    }

    return InkWell(
      onTap: () => _showPriorityOverrideDialog(visit),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
            Text(
              visit.priority.displayName.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 12, color: fg),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingChip(Invoice? inv) {
    if (inv == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          'NO BILL',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }

    if (inv.status == InvoiceStatus.paid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 12, color: Color(0xFF166534)),
            const SizedBox(width: 3),
            Text(
              'PAID ₹${inv.paidMinor ~/ 100}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF166534),
              ),
            ),
          ],
        ),
      );
    }

    if (inv.status == InvoiceStatus.partiallyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDD5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timelapse, size: 12, color: Color(0xFF9A3412)),
            const SizedBox(width: 3),
            Text(
              'PARTIAL: PAID ₹${inv.paidMinor ~/ 100} • DUE ₹${inv.balanceMinor ~/ 100}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9A3412),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pending_actions, size: 12, color: Color(0xFF92400E)),
          const SizedBox(width: 3),
          Text(
            'UNPAID: ₹${inv.balanceMinor ~/ 100} DUE',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickSettleDialog(Visit visit, Invoice invoice) {
    final session = ref.read(sessionProvider);
    if (session.role == UserRole.doctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access restricted: Payment collection is handled by reception staff as per PRD.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final patient = _patientMap[visit.patientId];
    final remainingDueRupees = invoice.balanceMinor ~/ 100;
    final collectController =
        TextEditingController(text: '$remainingDueRupees');
    final cashController =
        TextEditingController(text: '${remainingDueRupees ~/ 2}');
    final upiController =
        TextEditingController(text: '${remainingDueRupees - (remainingDueRupees ~/ 2)}');
    String paymentMethod = 'cash'; // 'cash', 'upi', 'card', 'mixed'
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.currency_rupee, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Text('Collect Fee - Token #${visit.tokenNumber}'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: ${patient?.fullName ?? "Valued Patient"} (${patient?.patientNumber ?? ""})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Bill:'),
                              Text('₹${invoice.totalMinor ~/ 100}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Already Paid:'),
                              Text('₹${invoice.paidMinor ~/ 100}',
                                  style:
                                      TextStyle(color: Colors.green.shade700)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Outstanding Due:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text('₹$remainingDueRupees',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: collectController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount to Collect Now *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        helperText:
                            'Enter amount (can be partial or full remaining due)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Payment Tender: *',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Cash'),
                          selected: paymentMethod == 'cash',
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => paymentMethod = 'cash');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('UPI'),
                          selected: paymentMethod == 'upi',
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => paymentMethod = 'upi');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Card'),
                          selected: paymentMethod == 'card',
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => paymentMethod = 'card');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Mixed (Cash + Digital)'),
                          selected: paymentMethod == 'mixed',
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => paymentMethod = 'mixed');
                            }
                          },
                        ),
                      ],
                    ),
                    if (paymentMethod == 'mixed') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cashController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cash Portion (₹) *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: upiController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Digital Portion (₹) *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final parsedAmount =
                              int.tryParse(collectController.text.trim()) ?? 0;
                          if (parsedAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please enter a valid amount greater than 0'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          int cashAmount = 0;
                          int upiAmount = 0;
                          if (paymentMethod == 'mixed') {
                            cashAmount = int.tryParse(cashController.text.trim()) ?? 0;
                            upiAmount = int.tryParse(upiController.text.trim()) ?? 0;
                            if (cashAmount + upiAmount != parsedAmount) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Cash (₹$cashAmount) + Digital (₹$upiAmount) must equal ₹$parsedAmount'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                          }

                          setDialogState(() => isSubmitting = true);
                          final session = ref.read(sessionProvider);
                          final billingRepo =
                              ref.read(billingRepositoryProvider);
                          final now = DateTime.now().toUtc();

                          try {
                            if (paymentMethod == 'mixed') {
                              final p1 = Payment(
                                paymentId: const Uuid().v4(),
                                clinicId: session.clinicId,
                                invoiceId: invoice.invoiceId,
                                amountMinor: cashAmount * 100,
                                method: PaymentMethod.cash,
                                receivedAt: now,
                                receivedByStaffId: session.staffId,
                                status: PaymentStatus.completed,
                                createdAt: now,
                              );
                              final p2 = Payment(
                                paymentId: const Uuid().v4(),
                                clinicId: session.clinicId,
                                invoiceId: invoice.invoiceId,
                                amountMinor: upiAmount * 100,
                                method: PaymentMethod.upi,
                                receivedAt: now,
                                receivedByStaffId: session.staffId,
                                status: PaymentStatus.completed,
                                createdAt: now,
                              );
                              await billingRepo.recordPayments(
                                payments: [p1, p2],
                                idempotencyKey: 'pay_mixed_${p1.paymentId}',
                              );
                            } else {
                              final payment = Payment(
                                paymentId: const Uuid().v4(),
                                clinicId: session.clinicId,
                                invoiceId: invoice.invoiceId,
                                amountMinor: parsedAmount * 100,
                                method: PaymentMethod.fromWire(paymentMethod),
                                receivedAt: now,
                                receivedByStaffId: session.staffId,
                                status: PaymentStatus.completed,
                                createdAt: now,
                              );
                              await billingRepo.recordPayment(
                                payment: payment,
                                idempotencyKey: 'pay_${payment.paymentId}',
                              );
                            }
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            await _loadQueueData();
                            unawaited(
                              ref
                                  .read(masterSheetSyncSchedulerProvider)
                                  .triggerManualSync(clinicId: session.clinicId),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Collected ₹$parsedAmount for Token #${visit.tokenNumber} via ${paymentMethod.toUpperCase()}',
                                  ),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Payment failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E)),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('CONFIRM PAYMENT'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateBillForVisitDialog(Visit visit) {
    final session = ref.read(sessionProvider);
    if (session.role == UserRole.doctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access restricted: Billing is handled by reception staff as per PRD.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final patient = _patientMap[visit.patientId];
    final doctor = _doctorMap[visit.doctorId];
    final baseRupees = doctor != null ? (doctor.defaultFee / 100).round() : 300;
    int additionalRupees = 0;
    String? selectedFeeId;

    if (visit.priority == QueuePriority.emergency) {
      final emergencyFee = _feeCatalog.where((f) =>
        f.active &&
        (f.visitTypeOptional?.toLowerCase() == 'emergency' ||
         f.feeName.toLowerCase().contains('emergency') ||
         f.feeCode.toLowerCase().contains('emergency'))
      ).firstOrNull;
      if (emergencyFee != null) {
        selectedFeeId = emergencyFee.feeId;
        additionalRupees = emergencyFee.defaultAmountMinor ~/ 100;
      }
    }

    int totalRupees = baseRupees + additionalRupees;
    final feeController = TextEditingController(text: '$totalRupees');
    String paymentOption = 'unpaid';
    String paymentMethod = 'cash';
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.add_card, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Text('Create Bill - Token #${visit.tokenNumber}'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: ${patient?.fullName ?? "Valued Patient"} • Dr. ${doctor?.displayName ?? "Consultant"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFF475569)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              additionalRupees > 0
                                  ? 'Base Fee: ₹$baseRupees  +  Additional/Emergency: ₹$additionalRupees  =  Total: ₹$totalRupees'
                                  : 'Base Consultation Fee: ₹$baseRupees',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_feeCatalog.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: selectedFeeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Additional Service / Surcharge (Added to Base Fee)',
                          border: OutlineInputBorder(),
                          helperText: 'Select procedure or surcharge to add to consultation fee',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None (Base Consultation Only)'),
                          ),
                          ..._feeCatalog.where((f) => f.active).map((f) {
                            final scope = f.doctorIdOptional != null
                                ? ' [Doc]'
                                : (f.visitTypeOptional != null ? ' [${f.visitTypeOptional}]' : '');
                            return DropdownMenuItem<String?>(
                              value: f.feeId,
                              child: Text('${f.feeName}$scope (+₹${f.defaultAmountMinor ~/ 100})'),
                            );
                          }),
                        ],
                        onChanged: (catId) {
                          setDialogState(() {
                            selectedFeeId = catId;
                            if (catId != null) {
                              final cat = _feeCatalog.where((f) => f.feeId == catId).firstOrNull;
                              additionalRupees = cat != null ? (cat.defaultAmountMinor ~/ 100) : 0;
                            } else {
                              additionalRupees = 0;
                            }
                            totalRupees = baseRupees + additionalRupees;
                            feeController.text = '$totalRupees';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: feeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Whole Fee *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val) ?? 0;
                        setDialogState(() => totalRupees = parsed);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Payment Status:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Pay Later (Unpaid)'),
                          selected: paymentOption == 'unpaid',
                          selectedColor: const Color(0xFFFEF3C7),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => paymentOption = 'unpaid');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Pay Full Now'),
                          selected: paymentOption == 'full',
                          selectedColor: const Color(0xFFCCFBF1),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => paymentOption = 'full');
                            }
                          },
                        ),
                      ],
                    ),
                    if (paymentOption == 'full') ...[
                      const SizedBox(height: 12),
                      const Text('Tender:',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selected: paymentMethod == 'cash',
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => paymentMethod = 'cash');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('UPI'),
                            selected: paymentMethod == 'upi',
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => paymentMethod = 'upi');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Card'),
                            selected: paymentMethod == 'card',
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => paymentMethod = 'card');
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final feeRupees =
                              int.tryParse(feeController.text.trim()) ?? 0;
                          if (feeRupees <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid fee'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final session = ref.read(sessionProvider);
                          final billingRepo =
                              ref.read(billingRepositoryProvider);

                          final totalMinor = feeRupees * 100;
                          final paidMinor =
                              paymentOption == 'full' ? totalMinor : 0;
                          final balanceMinor = totalMinor - paidMinor;

                          final invoiceId = const Uuid().v4();
                          final currentYear = DateTime.now().year;
                          final financialYear =
                              '$currentYear-${currentYear + 1}';
                          final invoiceNumber =
                              await billingRepo.generateNextInvoiceNumber(
                            session.clinicId,
                            financialYear,
                          );

                          final items = <InvoiceItem>[];
                          final addlCatalogItem = selectedFeeId != null
                              ? _feeCatalog.where((f) => f.feeId == selectedFeeId).firstOrNull
                              : null;

                          if (additionalRupees > 0 && addlCatalogItem != null) {
                            final baseMinor = baseRupees * 100;
                            final addlMinor = totalMinor > baseMinor
                                ? totalMinor - baseMinor
                                : (additionalRupees * 100);
                            final finalBaseMinor = totalMinor - addlMinor;

                            items.add(InvoiceItem(
                              invoiceItemId: const Uuid().v4(),
                              clinicId: session.clinicId,
                              invoiceId: invoiceId,
                              description:
                                  'Consultation - Dr. ${doctor?.displayName ?? "Consultant"}',
                              quantity: 1,
                              unitPriceMinor: finalBaseMinor,
                              discountMinor: 0,
                              taxMinor: 0,
                              lineTotalMinor: finalBaseMinor,
                              createdAt: DateTime.now().toUtc(),
                            ));

                            items.add(InvoiceItem(
                              invoiceItemId: const Uuid().v4(),
                              clinicId: session.clinicId,
                              invoiceId: invoiceId,
                              feeIdOptional: addlCatalogItem.feeId,
                              description: addlCatalogItem.feeName,
                              quantity: 1,
                              unitPriceMinor: addlMinor,
                              discountMinor: 0,
                              taxMinor: 0,
                              lineTotalMinor: addlMinor,
                              createdAt: DateTime.now().toUtc(),
                            ));
                          } else {
                            items.add(InvoiceItem(
                              invoiceItemId: const Uuid().v4(),
                              clinicId: session.clinicId,
                              invoiceId: invoiceId,
                              description: visit.priority == QueuePriority.emergency
                                  ? 'Emergency Consultation - Dr. ${doctor?.displayName ?? "Consultant"}'
                                  : 'Consultation - Dr. ${doctor?.displayName ?? "Consultant"}',
                              quantity: 1,
                              unitPriceMinor: totalMinor,
                              discountMinor: 0,
                              taxMinor: 0,
                              lineTotalMinor: totalMinor,
                              createdAt: DateTime.now().toUtc(),
                            ));
                          }

                          final invoice = Invoice(
                            invoiceId: invoiceId,
                            clinicId: session.clinicId,
                            invoiceNumber: invoiceNumber,
                            financialYear: financialYear,
                            patientId: visit.patientId,
                            visitId: visit.visitId,
                            issueDateLocal: visit.visitDateLocal,
                            subtotalMinor: totalMinor,
                            discountMinor: 0,
                            taxMinor: 0,
                            totalMinor: totalMinor,
                            paidMinor: paidMinor,
                            balanceMinor: balanceMinor,
                            status: balanceMinor <= 0
                                ? InvoiceStatus.paid
                                : InvoiceStatus.issued,
                            createdByStaffId: session.staffId,
                            createdAt: DateTime.now().toUtc(),
                            updatedAt: DateTime.now().toUtc(),
                          );

                          Payment? initialPayment;
                          if (paidMinor > 0) {
                            initialPayment = Payment(
                              paymentId: const Uuid().v4(),
                              clinicId: session.clinicId,
                              invoiceId: invoiceId,
                              amountMinor: paidMinor,
                              method: PaymentMethod.fromWire(paymentMethod),
                              receivedAt: DateTime.now().toUtc(),
                              receivedByStaffId: session.staffId,
                              status: PaymentStatus.completed,
                              createdAt: DateTime.now().toUtc(),
                            );
                          }

                          try {
                            await billingRepo.createInvoiceAtomic(
                              invoice: invoice,
                              items: items,
                              initialPayment: initialPayment,
                              idempotencyKey: 'inv_visit_${visit.visitId}',
                            );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            await _loadQueueData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Bill created for Token #${visit.tokenNumber}!',
                                  ),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create bill: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E)),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('CREATE BILL'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _printReceipt(Visit visit, Invoice invoice) async {
    final session = ref.read(sessionProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);
    final billingRepo = ref.read(billingRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    final clinic = await clinicRepo.getClinic(session.clinicId) ??
        Clinic(
          clinicId: session.clinicId,
          legalName: 'Apna Clinic',
          displayName: 'Apna Clinic',
          ownerName: session.staffName,
          contactPhone: '9876543210',
          contactEmail:
              session.googleUserEmail ?? 'contact@apnaclinic.com',
          addressLine1: 'Clinic Address',
          city: 'Delhi',
          district: 'Delhi',
          state: 'Delhi',
          pincode: '110001',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

    var patient = _patientMap[visit.patientId];
    patient ??= await patientRepo.getPatientById(
      session.clinicId,
      visit.patientId,
    );
    patient ??= Patient(
      patientId: visit.patientId,
      clinicId: session.clinicId,
      patientNumber: 'P-GEN',
      fullName: 'Valued Patient',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    final payments = await billingRepo.getPaymentsForInvoice(
      session.clinicId,
      invoice.invoiceId,
    );

    await ReceiptSlipService.printReceipt(
      clinic: clinic,
      invoice: invoice,
      patient: patient,
      payments: payments,
      paperSize: clinic.defaultPaperSize,
    );
  }
}

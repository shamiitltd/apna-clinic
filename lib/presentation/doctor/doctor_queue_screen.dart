import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/printing/consultation_slip_service.dart';
import '../../application/providers.dart';
import '../../core/permissions/roles.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/dialogs/consultation_slip_preview_dialog.dart';

class DoctorQueueScreen extends ConsumerStatefulWidget {
  const DoctorQueueScreen({super.key});

  @override
  ConsumerState<DoctorQueueScreen> createState() => _DoctorQueueScreenState();
}

class _DoctorQueueScreenState extends ConsumerState<DoctorQueueScreen> {
  List<Visit> _visits = [];
  Map<String, Patient> _patientMap = {};
  List<Doctor> _clinicDoctors = [];
  String? _selectedDoctorId; // Doctor isolation filter (Owner selectable, Doctor locked)
  bool _isLoading = false;
  String _followUpDays = 'None';
  final TextEditingController _clinicalNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void dispose() {
    _clinicalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    final visitRepo = ref.read(visitRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);

    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final doctors = await clinicRepo.getDoctors(session.clinicId);
      _clinicDoctors = doctors;

      // PRD Module 8 Doctor Queue Isolation:
      // If active role is Doctor, identify their doctorId and isolate strictly.
      String? targetDoctorId;
      if (session.role == UserRole.doctor) {
        if (session.assignedDoctorId != null && session.assignedDoctorId!.isNotEmpty) {
          targetDoctorId = session.assignedDoctorId;
        } else {
          final matched = doctors.cast<Doctor?>().firstWhere(
            (d) =>
                d?.doctorId == session.staffId ||
                d?.displayName.trim().toLowerCase() ==
                    session.staffName.trim().toLowerCase(),
            orElse: () => doctors.isNotEmpty ? doctors.first : null,
          );
          targetDoctorId = matched?.doctorId;
        }
        _selectedDoctorId = targetDoctorId;
      } else {
        targetDoctorId = _selectedDoctorId;
      }

      final allVisits = await visitRepo.getVisitsForDate(
        session.clinicId,
        dateStr,
      );

      final visits = (targetDoctorId != null && targetDoctorId.isNotEmpty)
          ? allVisits.where((v) => v.doctorId == targetDoctorId).toList()
          : allVisits;

      final Map<String, Patient> pMap = {};
      for (final v in visits) {
        if (!pMap.containsKey(v.patientId)) {
          final p = await patientRepo.getPatientById(
            session.clinicId,
            v.patientId,
          );
          if (p != null) pMap[v.patientId] = p;
        }
      }

      setState(() {
        _visits = visits;
        _patientMap = pMap;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(Visit visit, QueueStatus newStatus) async {
    final session = ref.read(sessionProvider);
    if (session.role != UserRole.doctor && session.role != UserRole.owner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Access Denied: Only Doctors and Clinic Owners can alter Doctor Desk consultations.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final visitRepo = ref.read(visitRepositoryProvider);
    final db = ref.read(localDatabaseProvider);

    try {
      if (visit.queueStatus == QueueStatus.registered &&
          newStatus == QueueStatus.called) {
        await visitRepo.updateQueueStatus(
          clinicId: session.clinicId,
          visitId: visit.visitId,
          newStatus: QueueStatus.waiting,
          staffId: session.staffId,
          deviceId: session.deviceId,
        );
      }

      await visitRepo.updateQueueStatus(
        clinicId: session.clinicId,
        visitId: visit.visitId,
        newStatus: newStatus,
        staffId: session.staffId,
        deviceId: session.deviceId,
      );

      // Trigger background sync to Google Master Sheet
      unawaited(
        ref
            .read(masterSheetSyncSchedulerProvider)
            .triggerManualSync(clinicId: session.clinicId),
      );

      if (newStatus == QueueStatus.completed) {
        final now = DateTime.now().toUtc();
        final nowIso = now.toIso8601String();
        final notesText = _clinicalNotesController.text.trim();

        // Stage 13_MEDICAL_RECORDS
        final medId = 'MED-${visit.visitId}';
        final medPayload = {
          'record_id': medId,
          'patient_id': visit.patientId,
          'consultation_id': visit.visitId,
          'record_type': 'OPD_CONSULTATION',
          'title': 'Consultation Slip - Token #${visit.tokenNumber}',
          'description': notesText.isNotEmpty ? notesText : 'Physical A5 Consultation Slip issued with clinical findings.',
          'document_url': '',
          'record_date': visit.visitDateLocal,
          'created_by': visit.doctorId,
          'created_at': nowIso,
          'updated_at': nowIso,
        };
        final medOutbox = SyncOutboxEvent(
          outboxEventId: 'outbox_med_${visit.visitId}',
          clinicId: session.clinicId,
          entityType: '13_MEDICAL_RECORDS',
          entityId: medId,
          operation: OutboxOperation.insert,
          payloadJson: jsonEncode(medPayload),
          createdAt: now,
          idempotencyKey: 'med_${visit.visitId}',
        );
        await db.upsert('sync_outbox', medOutbox.outboxEventId, medOutbox.toMap());

        // Stage 14_PRESCRIPTIONS
        final rxId = 'RX-${visit.visitId}';
        final rxPayload = {
          'prescription_id': rxId,
          'consultation_id': visit.visitId,
          'patient_id': visit.patientId,
          'medicine_name': 'Physical Consultation Slip Prescription',
          'dosage': 'As handwritten on physical slip',
          'frequency': 'Daily',
          'duration': 'As advised by doctor',
          'route': 'ORAL',
          'instructions': notesText.isNotEmpty ? notesText : 'Handwritten medicines and dosages detailed on physical slip.',
          'quantity': '1',
          'created_at': nowIso,
        };
        final rxOutbox = SyncOutboxEvent(
          outboxEventId: 'outbox_rx_${visit.visitId}',
          clinicId: session.clinicId,
          entityType: '14_PRESCRIPTIONS',
          entityId: rxId,
          operation: OutboxOperation.insert,
          payloadJson: jsonEncode(rxPayload),
          createdAt: now,
          idempotencyKey: 'rx_${visit.visitId}',
        );
        await db.upsert('sync_outbox', rxOutbox.outboxEventId, rxOutbox.toMap());

        if (_followUpDays != 'None') {
          final daysMatch = RegExp(r'\d+').firstMatch(_followUpDays);
          final days =
              daysMatch != null ? int.tryParse(daysMatch.group(0)!) ?? 0 : 0;
          if (days > 0) {
            final due = DateTime.now().add(Duration(days: days));
            final dueDateStr =
                '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
            final followup = Followup(
              followupId: 'flw_${visit.visitId}',
              clinicId: session.clinicId,
              patientId: visit.patientId,
              sourceVisitIdOptional: visit.visitId,
              doctorId: visit.doctorId,
              dueDate: dueDateStr,
              administrativeNoteOptional:
                  notesText.isNotEmpty
                      ? notesText
                      : 'Follow-up advice in $days days',
              status: 'scheduled',
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            );
            await db.upsert('Followups', followup.followupId, followup.toMap());

            // Stage 15_FOLLOW_UPS
            final flwOutbox = SyncOutboxEvent(
              outboxEventId: 'outbox_followup_${followup.followupId}',
              clinicId: session.clinicId,
              entityType: '15_FOLLOW_UPS',
              entityId: followup.followupId,
              operation: OutboxOperation.insert,
              payloadJson: jsonEncode(followup.toMap()),
              createdAt: now,
              idempotencyKey: 'followup_${followup.followupId}',
            );
            await db.upsert('sync_outbox', flwOutbox.outboxEventId, flwOutbox.toMap());

            // Stage 18_NOTIFICATIONS
            final notifId = 'NOTIF-${followup.followupId}';
            final notifPayload = {
              'notification_id': notifId,
              'patient_id': visit.patientId,
              'notification_type': 'FOLLOWUP_REMINDER',
              'recipient_contact': _patientMap[visit.patientId]?.phoneOptional ?? '',
              'scheduled_at': dueDateStr,
              'sent_at': nowIso,
              'channel': 'WHATSAPP_SMS',
              'template_name': 'FOLLOWUP_SCHEDULED',
              'status': 'SCHEDULED',
              'delivery_status': 'PENDING',
              'remarks': followup.administrativeNoteOptional ?? 'Follow-up scheduled in $days days',
              'created_at': nowIso,
            };
            final notifOutbox = SyncOutboxEvent(
              outboxEventId: 'outbox_notif_$notifId',
              clinicId: session.clinicId,
              entityType: '18_NOTIFICATIONS',
              entityId: notifId,
              operation: OutboxOperation.insert,
              payloadJson: jsonEncode(notifPayload),
              createdAt: now,
              idempotencyKey: 'notif_$notifId',
            );
            await db.upsert('sync_outbox', notifOutbox.outboxEventId, notifOutbox.toMap());
          }
        }

        final patientName = _patientMap[visit.patientId]?.fullName ?? 'Patient';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Consultation completed for Token #${visit.tokenNumber} ($patientName).',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        }

        _clinicalNotesController.clear();
        _followUpDays = 'None';
      }

      await _loadQueue();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating queue status: $e'),
            backgroundColor: Colors.red,
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
                    'Override triage priority for ${_patientMap[visit.patientId]?.fullName ?? "Patient"}. High priority tokens are surfaced first in your cabin queue.',
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
        await _loadQueue();
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
              backgroundColor: AppColors.primary,
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

  Widget _buildPriorityBadge(QueuePriority priority, {VoidCallback? onTap}) {
    Color bg;
    Color border;
    Color fg;
    IconData icon;

    switch (priority) {
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

    final badge = Container(
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
            priority.displayName.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 12, color: fg),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: badge,
      );
    }
    return badge;
  }

  Future<void> _printSlip(Visit visit) async {
    try {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final patientRepo = ref.read(patientRepositoryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opening consultation slip for Token #${visit.tokenNumber}...',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }

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

      final doctor = await clinicRepo.getDoctor(session.clinicId, visit.doctorId) ??
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

      final currentNotes = _clinicalNotesController.text.trim();

      try {
        await ConsultationSlipPreviewDialog.show(
          context: context,
          clinic: clinic,
          doctor: doctor,
          patient: patient,
          visit: visit,
          patientReportedReasonForVisit: visit.reasonForVisitEncryptedRef,
          clinicalNotes: currentNotes.isNotEmpty ? currentNotes : null,
          onPrinted: () {
            _loadQueue();
          },
        );
      } catch (_) {
        // Graceful direct print fallback if preview dialog module was dynamically linked during hot reload
        await ConsultationSlipService.printSlip(
          clinic: clinic,
          doctor: doctor,
          patient: patient,
          visit: visit,
          clinicalNotes: currentNotes.isNotEmpty ? currentNotes : null,
          paperSize: clinic.defaultPaperSize.isNotEmpty ? clinic.defaultPaperSize : 'A5',
        );
        final visitRepo = ref.read(visitRepositoryProvider);
        await visitRepo.incrementSlipPrintCount(
          clinicId: session.clinicId,
          visitId: visit.visitId,
          paperSize: clinic.defaultPaperSize.isNotEmpty ? clinic.defaultPaperSize : 'A5',
          staffId: session.staffId,
          deviceId: session.deviceId,
        );
        await _loadQueue();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating consultation slip: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isAuthorized =
        session.role == UserRole.doctor || session.role == UserRole.owner;

    if (!isAuthorized) {
      return AppScaffold(
        currentRoute: '/doctor',
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gpp_bad_rounded, size: 56, color: Colors.red.shade700),
                  const SizedBox(height: 16),
                  const Text(
                    'Access Denied: Doctor Desk',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Under clinical governance and PRD/TRD RBAC policies, the Doctor Desk is strictly reserved for Doctors and Clinic Owners. Receptionists and front-desk staff must manage waiting patients via the Live Queue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/queue'),
                    icon: const Icon(Icons.format_list_numbered),
                    label: const Text('Open Live Queue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Active consultation: patient currently in consultation or called to cabin
    final currentConsultation = _visits.cast<Visit?>().firstWhere(
          (v) => v?.queueStatus == QueueStatus.inConsultation,
          orElse: () => _visits.cast<Visit?>().firstWhere(
            (v) => v?.queueStatus == QueueStatus.called,
            orElse: () => null,
          ),
        );

    final waitingVisits = _visits
        .where((v) =>
            v.queueStatus == QueueStatus.waiting ||
            v.queueStatus == QueueStatus.registered)
        .toList()
      ..sort((a, b) {
        final pDiff = b.priority.level.compareTo(a.priority.level);
        if (pDiff != 0) return pDiff;
        return a.tokenNumber.compareTo(b.tokenNumber);
      });

    final completedVisits = _visits
        .where((v) => v.queueStatus == QueueStatus.completed)
        .toList();

    return AppScaffold(
      currentRoute: '/doctor',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final horizontalPadding = isDesktop ? 24.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row (Adaptive Wrap on narrow viewports)
                constraints.maxWidth < 500
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Doctor Clinical Workstation',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Assigned Doctor: ${session.staffName} • Room Cabin Active • Live Collaboration',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _loadQueue,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Doctor Clinical Workstation',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Assigned Doctor: ${session.staffName} • Room Cabin Active • Module 13 Live Collaboration',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _loadQueue,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Refresh'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 16),

                // PRD Module 8: Owner Cross-Doctor Inspection Bar
                if (session.role == UserRole.owner && _clinicDoctors.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Admin Doctor Desk Filter: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String?>(
                          value: _selectedDoctorId,
                          underline: const SizedBox(),
                          isDense: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Doctors (Consolidated Queue)'),
                            ),
                            ..._clinicDoctors.map(
                              (d) => DropdownMenuItem<String?>(
                                value: d.doctorId,
                                child: Text('Dr. ${d.displayName} (${d.specialtyLabel})'),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedDoctorId = val);
                            _loadQueue();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Operational Metric Cards
                LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final isDesk = cardConstraints.maxWidth >= 900;
                    final isSingleCol = cardConstraints.maxWidth < 420;
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
                          value: '${waitingVisits.length}',
                          subtitle: 'Next in sequence',
                          icon: Icons.hourglass_top,
                          iconColor: AppColors.statusWaiting,
                        ),
                        MetricCard(
                          title: 'Active Cabin Patient',
                          value: currentConsultation != null ? '#${currentConsultation.tokenNumber}' : 'None',
                          subtitle: currentConsultation != null ? currentConsultation.queueStatus.wireValue.toUpperCase() : 'Ready for next',
                          icon: Icons.medical_services,
                          iconColor: AppColors.primary,
                        ),
                        MetricCard(
                          title: 'Consultations Done',
                          value: '${completedVisits.length}',
                          subtitle: 'Completed today',
                          icon: Icons.check_circle,
                          iconColor: AppColors.statusCompleted,
                        ),
                        MetricCard(
                          title: 'Total Today',
                          value: '${_visits.length}',
                          subtitle: 'Registered visits',
                          icon: Icons.format_list_numbered,
                          iconColor: AppColors.secondary,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Main 2-Column Clinical Layout (Desktop: Side-by-Side; Mobile: Stacked; Fully Scrollable)
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Active Consultation Desk
                              Expanded(
                                flex: 6,
                                child: _buildActiveWorkstation(
                                  currentConsultation,
                                  waitingVisits,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right: Waiting Queue
                              Expanded(
                                flex: 4,
                                child: _buildUpcomingQueue(
                                  waitingVisits,
                                  completedVisits,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildActiveWorkstation(
                                currentConsultation,
                                waitingVisits,
                              ),
                              const SizedBox(height: 16),
                              _buildUpcomingQueue(
                                waitingVisits,
                                completedVisits,
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

  Widget _buildActiveWorkstation(
    Visit? currentVisit,
    List<Visit> waitingVisits,
  ) {
    if (currentVisit == null) {
      return AppCard(
        title: 'Current Consultation Cabin',
        trailing: StatusBadge.waiting('IDLE / READY'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.meeting_room,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Patient in Consultation Cabin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                waitingVisits.isNotEmpty
                    ? '${waitingVisits.length} patient${waitingVisits.length > 1 ? "s" : ""} waiting in the lobby queue.'
                    : 'The lobby queue is currently empty. Next check-ins will appear automatically.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (waitingVisits.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _updateStatus(
                    waitingVisits.first,
                    QueueStatus.called,
                  ),
                  icon: const Icon(Icons.campaign, size: 20),
                  label: Text(
                    'CALL NEXT: Token #${waitingVisits.first.tokenNumber} (${_patientMap[waitingVisits.first.patientId]?.fullName ?? "Patient"})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final patient = _patientMap[currentVisit.patientId];
    final isCalled = currentVisit.queueStatus == QueueStatus.called;

    return AppCard(
      title: 'Active Consultation Cabin',
      trailing: isCalled
          ? StatusBadge.called('CALLED TO CABIN')
          : StatusBadge.inConsultation('IN CONSULTATION'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Demographic Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Token number badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'TOKEN',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '#${currentVisit.tokenNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Patient Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              patient?.fullName ?? 'Patient',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (patient?.patientNumber != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                patient!.patientNumber,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          _buildPriorityBadge(
                            currentVisit.priority,
                            onTap: () => _showPriorityOverrideDialog(currentVisit),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${patient?.displayAge ?? "-"} Years • ${patient?.sexOptional?.toUpperCase() ?? "UNKNOWN"} • Phone: ${patient?.maskedPhone ?? "N/A"}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Address: ${patient?.cityOptional ?? "Local"} • Visit Type: ${currentVisit.visitType.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clinical Note Reminder
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prescriptions and clinical findings are written on the pre-printed physical A5 Consultation Slip.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Clinical Observation Pad
          const Text(
            'Doctor Consultation Summary / Chief Complaint',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _clinicalNotesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter brief clinical notes, primary diagnosis or advice...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),

          // Follow-up Selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Follow-up Advice: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              ...['None', '3 Days', '5 Days', '7 Days', '14 Days'].map((days) {
                final isSelected = _followUpDays == days;
                return ChoiceChip(
                  label: Text(days),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _followUpDays = days);
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Action Toolbar
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isCalled)
                FilledButton.icon(
                  onPressed: () => _updateStatus(
                    currentVisit,
                    QueueStatus.inConsultation,
                  ),
                  icon: const Icon(Icons.meeting_room, size: 18),
                  label: const Text('PATIENT SEATED — START CONSULT'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () => _updateStatus(
                    currentVisit,
                    QueueStatus.completed,
                  ),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('COMPLETE CONSULTATION & CLOSE VISIT'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusCompleted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _printSlip(currentVisit),
                icon: const Icon(Icons.print, size: 16),
                label: const Text('PRINT A5 SLIP'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _updateStatus(
                  currentVisit,
                  QueueStatus.noShow,
                ),
                child: const Text(
                  'Mark No-Show',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingQueue(
    List<Visit> waitingVisits,
    List<Visit> completedVisits,
  ) {
    return AppCard(
      title: 'Upcoming Queue (${waitingVisits.length} Waiting)',
      trailing: Text(
        '${completedVisits.length} Done Today',
        style: const TextStyle(
          color: AppColors.statusCompleted,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      child: waitingVisits.isEmpty
          ? EmptyStateWidget(
              icon: Icons.done_all,
              title: 'No Patients Waiting',
              description: 'The waiting queue for your room is currently empty.',
              actionLabel: 'Refresh Queue',
              onAction: _loadQueue,
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: waitingVisits.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final v = waitingVisits[idx];
                final p = _patientMap[v.patientId];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '#${v.tokenNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p?.fullName ?? 'Patient',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildPriorityBadge(
                                  v.priority,
                                  onTap: () => _showPriorityOverrideDialog(v),
                                ),
                              ],
                            ),
                            Text(
                              '${p?.displayAge ?? "-"} Y • ${p?.sexOptional ?? ""} • Checked in: ${v.checkinAt.hour.toString().padLeft(2, "0")}:${v.checkinAt.minute.toString().padLeft(2, "0")}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _updateStatus(
                          v,
                          QueueStatus.called,
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('CALL'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/permissions/roles.dart';
import '../../core/utils/downloader/file_download_helper.dart';
import '../../core/utils/phone_normalizer.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/services/authorization_service.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/unauthorized_screen.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedDoctorId;
  List<Appointment> _appointments = [];
  List<Followup> _followups = [];
  int _selectedMainTab = 0; // 0: Appointments, 1: Follow-up Reminders (Module 12)
  String _followupFilter = 'all'; // 'all', 'today', 'upcoming', 'overdue', 'completed'
  String? _followupDoctorFilter;
  List<Doctor> _doctors = [];
  Map<String, Patient> _patientMap = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);
    final appRepo = ref.read(appointmentRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final followupRepo = ref.read(followupRepositoryProvider);

    try {
      final docs = await clinicRepo.getDoctors(session.clinicId);
      final apps = await appRepo.getAppointmentsForDate(
        session.clinicId,
        _selectedDate,
        doctorId: _selectedDoctorId,
      );
      final followups = await followupRepo.getAllFollowups(session.clinicId);

      final pMap = <String, Patient>{};
      for (final a in apps) {
        if (!pMap.containsKey(a.patientId)) {
          final p = await patientRepo.getPatientById(session.clinicId, a.patientId);
          if (p != null) pMap[a.patientId] = p;
        }
      }
      for (final f in followups) {
        if (!pMap.containsKey(f.patientId)) {
          final p = await patientRepo.getPatientById(session.clinicId, f.patientId);
          if (p != null) pMap[f.patientId] = p;
        }
      }

      setState(() {
        _doctors = docs;
        if (_doctors.isNotEmpty && _selectedDoctorId == null) {
          _selectedDoctorId = _doctors.first.doctorId;
        }
        _appointments = apps;
        _followups = followups;
        _patientMap = pMap;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateAppointmentDialog({
    Patient? preSelectedPatient,
    String? preSelectedDoctorId,
    String? defaultAppointmentType,
    DateTime? defaultDate,
    String? convertingFollowupId,
  }) async {
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final appRepo = ref.read(appointmentRepositoryProvider);

    final patientSearchController = TextEditingController();
    Patient? selectedPatient = preSelectedPatient;
    List<Patient> searchResults = [];
    String doctorId = preSelectedDoctorId ??
        _selectedDoctorId ??
        (_doctors.isNotEmpty ? _doctors.first.doctorId : '');

    DateTime appointmentDate = defaultDate ?? _selectedDate;
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    Doctor? initialDoc =
        _doctors.where((d) => d.doctorId == doctorId).firstOrNull;
    int durationMinutes = initialDoc?.consultationDurationMinutes ?? 15;
    if (durationMinutes <= 0) durationMinutes = 15;

    String appointmentType = defaultAppointmentType ?? 'new_consultation';
    String bookingSource = 'reception';
    bool reminderConsent = true;
    String? conflictError;

    List<DateTime> availableSlots = [];
    try {
      availableSlots = await appRepo.getAvailableSlots(
        clinicId: session.clinicId,
        doctorId: doctorId,
        date: appointmentDate,
        durationMinutes: durationMinutes,
      );
      if (availableSlots.isNotEmpty) {
        selectedTime = TimeOfDay(
          hour: availableSlots.first.hour,
          minute: availableSlots.first.minute,
        );
      }
    } catch (_) {}

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dateStr =
              '${appointmentDate.day.toString().padLeft(2, '0')}/${appointmentDate.month.toString().padLeft(2, '0')}/${appointmentDate.year}';

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('Schedule New Appointment')),
              ],
            ),
            content: Container(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.of(dialogCtx).size.height * 0.85,
              ),
              width: MediaQuery.of(dialogCtx).size.width >= 560
                  ? 500.0
                  : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Selection
                    const Text(
                      '1. Select Patient',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (selectedPatient != null)
                      ListTile(
                        tileColor: Colors.blue.shade50,
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: Text(selectedPatient!.fullName),
                        subtitle: Text(
                          '${selectedPatient!.patientNumber} • ${selectedPatient!.phoneOptional ?? ""}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setDialogState(() => selectedPatient = null),
                        ),
                      )
                    else ...[
                      TextField(
                        controller: patientSearchController,
                        decoration: const InputDecoration(
                          hintText: 'Search patient by name or phone...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (query) async {
                          if (query.trim().length >= 2) {
                            final results = await patientRepo.searchPatients(
                              session.clinicId,
                              query,
                            );
                            setDialogState(() => searchResults = results);
                          } else {
                            setDialogState(() => searchResults = []);
                          }
                        },
                      ),
                      if (searchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            itemBuilder: (c, idx) {
                              final p = searchResults[idx];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '${p.fullName} (${p.patientNumber})',
                                ),
                                subtitle: Text(p.phoneOptional ?? 'No phone'),
                                onTap: () {
                                  setDialogState(() {
                                    selectedPatient = p;
                                    searchResults = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      if (searchResults.isEmpty &&
                          patientSearchController.text.trim().length >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.person_add, size: 16),
                            label: Text(
                              'Quick Register "${patientSearchController.text.trim()}"',
                            ),
                            onPressed: () async {
                              final name = patientSearchController.text.trim();
                              final pNum = await patientRepo
                                  .generateNextPatientNumber(session.clinicId);
                              final p = Patient(
                                patientId:
                                    'pat_${DateTime.now().millisecondsSinceEpoch}',
                                clinicId: session.clinicId,
                                patientNumber: pNum,
                                fullName: name,
                                createdAt: DateTime.now().toUtc(),
                                updatedAt: DateTime.now().toUtc(),
                              );
                              await patientRepo.savePatient(p);
                              setDialogState(() {
                                selectedPatient = p;
                                searchResults = [];
                                patientSearchController.clear();
                              });
                            },
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Doctor Selection
                    const Text(
                      '2. Assigned Doctor & Schedule',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: doctorId.isNotEmpty ? doctorId : null,
                      decoration: const InputDecoration(
                        labelText: 'Doctor',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _doctors
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.doctorId,
                              child: Text(
                                '${d.displayName} (${d.consultationDurationMinutes} min)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          final selectedDoc = _doctors
                              .where((d) => d.doctorId == val)
                              .firstOrNull;
                          final newDuration =
                              selectedDoc?.consultationDurationMinutes ?? 15;
                          setDialogState(() {
                            doctorId = val;
                            durationMinutes =
                                newDuration > 0 ? newDuration : 15;
                            conflictError = null;
                          });
                          final slots = await appRepo.getAvailableSlots(
                            clinicId: session.clinicId,
                            doctorId: val,
                            date: appointmentDate,
                            durationMinutes: durationMinutes,
                          );
                          setDialogState(() => availableSlots = slots);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Appointment Date
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text('Date: $dateStr'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: appointmentDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  appointmentDate = picked;
                                  conflictError = null;
                                });
                                final slots = await appRepo.getAvailableSlots(
                                  clinicId: session.clinicId,
                                  doctorId: doctorId,
                                  date: picked,
                                  durationMinutes: durationMinutes,
                                );
                                setDialogState(() => availableSlots = slots);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Available slot suggestion chips
                    if (availableSlots.isNotEmpty) ...[
                      const Text(
                        'Available Slots for this Day:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: availableSlots.take(8).map((slot) {
                          final sTime = TimeOfDay(
                            hour: slot.hour,
                            minute: slot.minute,
                          );
                          final isSelected = selectedTime.hour == slot.hour &&
                              selectedTime.minute == slot.minute;
                          return ChoiceChip(
                            label: Text(
                              sTime.format(context),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setDialogState(() {
                                selectedTime = sTime;
                                conflictError = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Time and Duration
                    // Time and Duration
                    LayoutBuilder(
                      builder: (ctx, slotConstraints) {
                        if (slotConstraints.maxWidth < 360) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.access_time),
                                label: Text(
                                  'Time: ${selectedTime.format(context)}',
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime,
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedTime = picked;
                                      conflictError = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int>(
                                initialValue: durationMinutes,
                                decoration: const InputDecoration(
                                  labelText: 'Slot Duration',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 10,
                                    child: Text('10 mins'),
                                  ),
                                  DropdownMenuItem(
                                    value: 15,
                                    child: Text('15 mins'),
                                  ),
                                  DropdownMenuItem(
                                    value: 20,
                                    child: Text('20 mins'),
                                  ),
                                  DropdownMenuItem(
                                    value: 30,
                                    child: Text('30 mins'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => durationMinutes = v);
                                  }
                                },
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.access_time),
                                label: Text(
                                  'Time: ${selectedTime.format(context)}',
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime,
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedTime = picked;
                                      conflictError = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: durationMinutes,
                                decoration: const InputDecoration(
                                  labelText: 'Slot Duration',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 10,
                                    child: Text('10 mins'),
                                  ),
                                  DropdownMenuItem(
                                    value: 15,
                                    child: Text('15 mins'),
                                  ),
                                  DropdownMenuItem(
                                    value: 20,
                                    child: Text('20 mins'),
                                  ),
                                  DropdownMenuItem(
                                    value: 30,
                                    child: Text('30 mins'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => durationMinutes = v);
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Type & Source
                    LayoutBuilder(
                      builder: (ctx, typeConstraints) {
                        if (typeConstraints.maxWidth < 360) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: appointmentType,
                                decoration: const InputDecoration(
                                  labelText: 'Consultation Type',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'new_consultation',
                                    child: Text('New Consultation'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'followup',
                                    child: Text('Follow-up'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => appointmentType = v);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: bookingSource,
                                decoration: const InputDecoration(
                                  labelText: 'Booking Source',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'reception',
                                    child: Text('Reception Desk'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'phone',
                                    child: Text('Phone Call'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'walkin',
                                    child: Text('Walk-in Advance'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => bookingSource = v);
                                  }
                                },
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: appointmentType,
                                decoration: const InputDecoration(
                                  labelText: 'Consultation Type',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'new_consultation',
                                    child: Text('New Consultation'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'followup',
                                    child: Text('Follow-up'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => appointmentType = v);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: bookingSource,
                                decoration: const InputDecoration(
                                  labelText: 'Booking Source',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'reception',
                                    child: Text('Reception Desk'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'phone',
                                    child: Text('Phone Call'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'walkin',
                                    child: Text('Walk-in Advance'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => bookingSource = v);
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: reminderConsent,
                      title: const Text(
                        'Patient consented to administrative SMS reminder',
                        style: TextStyle(fontSize: 13),
                      ),
                      onChanged: (v) =>
                          setDialogState(() => reminderConsent = v ?? false),
                    ),

                    if (conflictError != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                conflictError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (selectedPatient == null) {
                    setDialogState(
                      () => conflictError = 'Please select a patient.',
                    );
                    return;
                  }
                  if (doctorId.isEmpty) {
                    setDialogState(
                      () => conflictError = 'Please assign a doctor.',
                    );
                    return;
                  }

                  final start = DateTime(
                    appointmentDate.year,
                    appointmentDate.month,
                    appointmentDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  final end = start.add(Duration(minutes: durationMinutes));

                  // Double booking prevention check
                  final hasConflict = await appRepo.hasSlotConflict(
                    clinicId: session.clinicId,
                    doctorId: doctorId,
                    start: start,
                    end: end,
                  );

                  if (hasConflict) {
                    final conflict = CollaborationConflict(
                      conflictId: 'conflict_booking_${DateTime.now().millisecondsSinceEpoch}',
                      clinicId: session.clinicId,
                      entityType: 'appointment',
                      entityId: 'slot_${doctorId}_${start.millisecondsSinceEpoch}',
                      localDeviceId: 'workstation',
                      remoteDeviceId: 'concurrent_terminal',
                      conflictType: 'overlapping_slot',
                      detectedAt: DateTime.now().toUtc(),
                      localSummary: 'Doctor $doctorId slot for ${selectedPatient!.fullName} at ${start.toLocal()}',
                      remoteSummary: 'Overlapping slot detected in same doctor window',
                    );
                    await ref.read(deviceCollaborationRepositoryProvider).recordConflict(conflict);

                    setDialogState(
                      () => conflictError =
                          'Slot conflict detected! Doctor already has an appointment during this time window.',
                    );
                    return;
                  }

                  final newAppointment = Appointment(
                    appointmentId:
                        'app_${DateTime.now().millisecondsSinceEpoch}',
                    clinicId: session.clinicId,
                    patientId: selectedPatient!.patientId,
                    doctorId: doctorId,
                    scheduledStartAt: start,
                    scheduledEndAt: end,
                    appointmentType: appointmentType,
                    bookingSource: bookingSource,
                    status: AppointmentStatus.scheduled,
                    createdByStaffId: session.staffId,
                    reminderConsent: reminderConsent,
                    createdAt: DateTime.now().toUtc(),
                    updatedAt: DateTime.now().toUtc(),
                  );

                  if (convertingFollowupId != null) {
                    final followupRepo = ref.read(followupRepositoryProvider);
                    await followupRepo.convertToAppointment(
                      clinicId: session.clinicId,
                      followupId: convertingFollowupId,
                      appointment: newAppointment,
                      actorId: session.staffId,
                    );
                  } else {
                    await appRepo.saveAppointment(newAppointment);
                  }
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (mounted) {
                    setState(() {
                      _selectedDate = appointmentDate;
                      _selectedDoctorId = doctorId;
                    });
                    await _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.teal.shade700,
                        content: Text(
                          'Appointment confirmed for ${selectedPatient!.fullName} on ${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year} at ${selectedTime.format(context)}',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Confirm Appointment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkInToVisit(Appointment appointment) async {
    final session = ref.read(sessionProvider);
    final visitRepo = ref.read(visitRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final appRepo = ref.read(appointmentRepositoryProvider);

    final patient = await patientRepo.getPatientById(
      session.clinicId,
      appointment.patientId,
    );
    if (patient == null) return;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-In Patient'),
        content: Text(
          'Generate visit & queue token for ${patient.fullName} (${patient.patientNumber})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate Token & Visit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final visit = Visit(
        visitId: 'visit_${now.millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        patientId: appointment.patientId,
        doctorId: appointment.doctorId,
        appointmentIdOptional: appointment.appointmentId,
        visitDateLocal: dateStr,
        checkinAt: now,
        tokenNumber: 0,
        tokenScopeKey: '${session.clinicId}:${appointment.doctorId}:$dateStr',
        queueStatus: QueueStatus.waiting,
        visitType: appointment.appointmentType,
        createdByStaffId: session.staffId,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      );

      final createdVisit = await visitRepo.createVisitAtomic(
        visit: visit,
        idempotencyKey: 'checkin_${appointment.appointmentId}',
        deviceId: session.deviceId,
        staffId: session.staffId,
      );

      // Mark appointment completed
      await appRepo.updateAppointmentStatus(
        session.clinicId,
        appointment.appointmentId,
        AppointmentStatus.completed,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Checked-In! Issued Token #${createdVisit.tokenNumber} for ${patient.fullName}',
            ),
            action: SnackBarAction(
              label: 'View Queue',
              textColor: Colors.white,
              onPressed: () => context.go('/queue'),
            ),
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to check-in: $e'),
          ),
        );
      }
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this appointment?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final session = ref.read(sessionProvider);
      final appRepo = ref.read(appointmentRepositoryProvider);
      await appRepo.updateAppointmentStatus(
        session.clinicId,
        appointment.appointmentId,
        AppointmentStatus.cancelled,
        cancelReason: reasonController.text.trim(),
      );
      await _loadData();
    }
  }

  Future<void> _showRescheduleDialog(Appointment appointment) async {
    final session = ref.read(sessionProvider);
    final appRepo = ref.read(appointmentRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    final patient = _patientMap[appointment.patientId] ??
        await patientRepo.getPatientById(
          session.clinicId,
          appointment.patientId,
        );

    DateTime newDate = appointment.scheduledStartAt;
    TimeOfDay newTime = TimeOfDay(
      hour: appointment.scheduledStartAt.hour,
      minute: appointment.scheduledStartAt.minute,
    );
    String targetDoctorId = appointment.doctorId;
    final durationMinutes = appointment.scheduledEndAt
        .difference(appointment.scheduledStartAt)
        .inMinutes
        .clamp(5, 120);

    String? rescheduleConflictError;
    List<DateTime> availableSlots = [];
    bool isLoadingSlots = false;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void fetchSlots() {
            setDialogState(() => isLoadingSlots = true);
            appRepo
                .getAvailableSlots(
                  clinicId: session.clinicId,
                  doctorId: targetDoctorId,
                  date: newDate,
                  durationMinutes: durationMinutes,
                )
                .then((slots) {
                  if (dialogCtx.mounted) {
                    setDialogState(() {
                      availableSlots = slots;
                      isLoadingSlots = false;
                    });
                  }
                })
                .catchError((_) {
                  if (dialogCtx.mounted) {
                    setDialogState(() => isLoadingSlots = false);
                  }
                });
          }

          if (availableSlots.isEmpty && !isLoadingSlots) {
            fetchSlots();
          }

          final newDateFormatted =
              '${newDate.day.toString().padLeft(2, '0')}/${newDate.month.toString().padLeft(2, '0')}/${newDate.year}';

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit_calendar, color: Color(0xFF0F766E)),
                SizedBox(width: 8),
                Expanded(child: Text('Reschedule Appointment')),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFE0F2FE),
                            child: Icon(
                              Icons.person,
                              color: Color(0xFF0284C7),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patient?.fullName ?? 'Patient',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Current: ${appointment.scheduledStartAt.day}/${appointment.scheduledStartAt.month}/${appointment.scheduledStartAt.year} at ${appointment.scheduledStartAt.hour.toString().padLeft(2, '0')}:${appointment.scheduledStartAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Doctor Selector
                    if (_doctors.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: targetDoctorId.isNotEmpty &&
                                _doctors.any((d) => d.doctorId == targetDoctorId)
                            ? targetDoctorId
                            : _doctors.first.doctorId,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Doctor',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _doctors
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.doctorId,
                                child: Text(d.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              targetDoctorId = val;
                              availableSlots.clear();
                              rescheduleConflictError = null;
                            });
                            fetchSlots();
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Date & Time Picker Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: newDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 7),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 180),
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  newDate = picked;
                                  availableSlots.clear();
                                  rescheduleConflictError = null;
                                });
                                fetchSlots();
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'New Date',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    newDateFormatted,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: newTime,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  newTime = picked;
                                  rescheduleConflictError = null;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'New Time',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    newTime.format(context),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Icon(Icons.access_time, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Available Slots Suggestion Chips
                    Text(
                      'Suggested Available Slots ($durationMinutes min):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isLoadingSlots)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (availableSlots.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'No open scheduled slots found in doctor working hours for this date. You can still set a custom time above.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: availableSlots.take(8).map((slot) {
                          final slotTime = TimeOfDay(
                            hour: slot.hour,
                            minute: slot.minute,
                          );
                          final isSelected = newTime.hour == slot.hour &&
                              newTime.minute == slot.minute;
                          return ChoiceChip(
                            label: Text(
                              slotTime.format(context),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFFCCFBF1),
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  newTime = slotTime;
                                  rescheduleConflictError = null;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),

                    if (rescheduleConflictError != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rescheduleConflictError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final newStart = DateTime(
                    newDate.year,
                    newDate.month,
                    newDate.day,
                    newTime.hour,
                    newTime.minute,
                  );
                  final newEnd =
                      newStart.add(Duration(minutes: durationMinutes));

                  // Double booking check (excluding the current appointment being rescheduled)
                  final hasConflict = await appRepo.hasSlotConflict(
                    clinicId: session.clinicId,
                    doctorId: targetDoctorId,
                    start: newStart,
                    end: newEnd,
                    excludeAppointmentId: appointment.appointmentId,
                  );

                  if (hasConflict) {
                    final conflict = CollaborationConflict(
                      conflictId: 'conflict_reschedule_${DateTime.now().millisecondsSinceEpoch}',
                      clinicId: session.clinicId,
                      entityType: 'appointment',
                      entityId: appointment.appointmentId,
                      localDeviceId: 'workstation',
                      remoteDeviceId: 'concurrent_terminal',
                      conflictType: 'overlapping_slot',
                      detectedAt: DateTime.now().toUtc(),
                      localSummary: 'Reschedule request for ${appointment.appointmentId} to ${newStart.toLocal()}',
                      remoteSummary: 'Destination slot conflicts with existing appointment',
                    );
                    await ref.read(deviceCollaborationRepositoryProvider).recordConflict(conflict);

                    setDialogState(
                      () => rescheduleConflictError =
                          'Slot conflict detected! The doctor already has another appointment during this time.',
                    );
                    return;
                  }

                  try {
                    await appRepo.rescheduleAppointment(
                      clinicId: session.clinicId,
                      appointmentId: appointment.appointmentId,
                      newStart: newStart,
                      newEnd: newEnd,
                      newDoctorId: targetDoctorId,
                    );
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    if (mounted) {
                      setState(() {
                        _selectedDate = newDate;
                        _selectedDoctorId = targetDoctorId;
                      });
                      await _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.teal.shade700,
                          content: Text(
                            'Appointment successfully rescheduled to $newDateFormatted at ${newTime.format(context)}',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(
                      () => rescheduleConflictError =
                          'Failed to reschedule: $e',
                    );
                  }
                },
                child: const Text('Confirm Reschedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _markNoShow(Appointment appointment) async {
    final patient = _patientMap[appointment.patientId];
    final patientName = patient?.fullName ?? 'Patient';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as No-Show'),
        content: Text(
          'Mark appointment for $patientName as No-Show?\n\nThis will release the reserved time slot for other patients and record the attendance status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark No-Show'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final session = ref.read(sessionProvider);
      final appRepo = ref.read(appointmentRepositoryProvider);
      await appRepo.updateAppointmentStatus(
        session.clinicId,
        appointment.appointmentId,
        AppointmentStatus.noShow,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.amber.shade900,
            content: const Text(
              'Marked appointment as No-Show. Slot is now free.',
            ),
          ),
        );
      }
      await _loadData();
    }
  }

  Future<void> _bookFollowUp(Appointment appointment) async {
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final patient = _patientMap[appointment.patientId] ??
        await patientRepo.getPatientById(
          session.clinicId,
          appointment.patientId,
        );

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event_repeat, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Schedule Patient Follow-up'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose how to schedule follow-up for ${patient?.fullName ?? "patient"}:'),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(Icons.notifications_active, color: Color(0xFF0284C7)),
              ),
              title: const Text('Follow-up Reminder (PRD M12)'),
              subtitle: const Text('Add to staff reminder ledger with due date & DPDP consent'),
              onTap: () => Navigator.pop(ctx, 'reminder'),
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(Icons.calendar_month, color: Color(0xFF15803D)),
              ),
              title: const Text('Direct Calendar Appointment'),
              subtitle: const Text('Book an immediate scheduled slot on the doctor schedule'),
              onTap: () => Navigator.pop(ctx, 'slot'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (mode == 'reminder') {
      await _showScheduleFollowupDialog(
        preSelectedPatient: patient,
        preSelectedDoctorId: appointment.doctorId,
        defaultDueDate: DateTime.now().add(const Duration(days: 7)),
      );
    } else if (mode == 'slot') {
      final nextWeek = DateTime.now().add(const Duration(days: 7));
      await _showCreateAppointmentDialog(
        preSelectedPatient: patient,
        preSelectedDoctorId: appointment.doctorId,
        defaultAppointmentType: 'followup',
        defaultDate: nextWeek,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);

    // Layer 2 RBAC Guard: Accountant is restricted from Appointments & Clinical Schedules (PRD Section 2)
    if (session.role == UserRole.accountant) {
      return const UnauthorizedScreen(
        customMessage:
            'Accountant role is restricted from accessing Appointments and Patient Schedules as per PRD Section 2.',
      );
    }

    final canManageFollowups = AuthorizationService.hasPermission(
      role: session.role,
      permission: AppPermission.manageFollowups,
    );

    final dateFormatted =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    return AppScaffold(
      currentRoute: '/appointments',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedMainTab == 0
            ? _showCreateAppointmentDialog
            : _showScheduleFollowupDialog,
        icon: Icon(_selectedMainTab == 0 ? Icons.add : Icons.notification_add),
        label: Text(_selectedMainTab == 0 ? 'Book Appointment' : 'Schedule Follow-up'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final isMobile = constraints.maxWidth < 768;
          final horizontalPadding = isDesktop ? 24.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row (Responsive Wrap)
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
                          l10n.translate('nav_appointments'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 24 : 20,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedMainTab == 0
                              ? 'Doctor Schedules & Advance Slot Booking'
                              : 'PRD M12: Administrative Follow-up Reminders & DPDP Consent',
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
                        if (canManageFollowups)
                          FilledButton.icon(
                            onPressed: _showScheduleFollowupDialog,
                            icon: const Icon(Icons.notification_add, size: 16),
                            label: Text(
                              isMobile ? 'Follow-up' : 'SCHEDULE FOLLOW-UP',
                              style: TextStyle(fontSize: isMobile ? 13 : 14),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: _showCreateAppointmentDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            isMobile ? 'New Slot' : 'BOOK APPOINTMENT',
                            style: TextStyle(fontSize: isMobile ? 13 : 14),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tab Switcher: Appointments vs Follow-up Reminders (PRD M12)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          selected: _selectedMainTab == 0,
                          label: Text(
                            isMobile
                                ? 'Appointments (${_appointments.length})'
                                : 'Scheduled Appointments (${_appointments.length})',
                          ),
                          selectedColor: const Color(0xFF0F766E),
                          labelStyle: TextStyle(
                            color: _selectedMainTab == 0 ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 13,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedMainTab = 0);
                          },
                        ),
                        ChoiceChip(
                          selected: _selectedMainTab == 1,
                          label: Text(
                            isMobile
                                ? 'Follow-ups (${_followups.length})'
                                : 'Follow-up Reminders (${_followups.length})',
                          ),
                          selectedColor: const Color(0xFF0284C7),
                          labelStyle: TextStyle(
                            color: _selectedMainTab == 1 ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 13,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedMainTab = 1);
                          },
                        ),
                      ],
                    ),
                    if (_selectedMainTab == 1 && _followups.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _exportFollowupsCsv,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export Follow-ups (CSV)'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_selectedMainTab == 0) ...[

                // Operational Summary Metrics
                LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final isWideDesktop = cardConstraints.maxWidth >= 1100;
                    final isTablet = cardConstraints.maxWidth >= 640 &&
                        cardConstraints.maxWidth < 1100;
                    final isSingleCol = cardConstraints.maxWidth < 420;
                    final scheduledCount = _appointments
                        .where((a) => a.status == AppointmentStatus.scheduled)
                        .length;
                    final checkedInCount = _appointments
                        .where((a) => a.status == AppointmentStatus.completed)
                        .length;
                    final noShowCount = _appointments
                        .where((a) => a.status == AppointmentStatus.noShow)
                        .length;
                    final cancelledCount = _appointments
                        .where((a) => a.status == AppointmentStatus.cancelled)
                        .length;
                    final totalCount = _appointments.length;

                    return GridView.count(
                      crossAxisCount: isWideDesktop
                          ? 5
                          : (isTablet ? 3 : (isSingleCol ? 1 : 2)),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isWideDesktop
                          ? 2.2
                          : (isSingleCol ? 2.8 : 1.4),
                      children: [
                        MetricCard(
                          title: 'Total Booked',
                          value: '$totalCount',
                          subtitle: 'For $dateFormatted',
                          icon: Icons.event_note,
                          iconColor: AppColors.primary,
                        ),
                        MetricCard(
                          title: 'Scheduled',
                          value: '$scheduledCount',
                          subtitle: 'Awaiting patient arrival',
                          icon: Icons.access_time_filled,
                          iconColor: AppColors.info,
                        ),
                        MetricCard(
                          title: 'Checked-In',
                          value: '$checkedInCount',
                          subtitle: 'Transferred to live queue',
                          icon: Icons.check_circle,
                          iconColor: AppColors.success,
                        ),
                        MetricCard(
                          title: 'No-Show',
                          value: '$noShowCount',
                          subtitle: 'Slots released',
                          icon: Icons.person_off_outlined,
                          iconColor: Colors.amber.shade800,
                        ),
                        MetricCard(
                          title: 'Cancelled',
                          value: '$cancelledCount',
                          subtitle: 'Slots freed',
                          icon: Icons.cancel,
                          iconColor: AppColors.error,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Filter Bar: Date & Doctor (Responsive)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    child: constraints.maxWidth >= 640
                        ? Row(
                            children: [
                              // Date Navigation
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                tooltip: 'Previous Day',
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = _selectedDate.subtract(
                                      const Duration(days: 1),
                                    );
                                  });
                                  _loadData();
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
                                    await _loadData();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 6.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        dateFormatted,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                tooltip: 'Next Day',
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = _selectedDate.add(
                                      const Duration(days: 1),
                                    );
                                  });
                                  _loadData();
                                },
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() => _selectedDate = DateTime.now());
                                  _loadData();
                                },
                                child: const Text('Today'),
                              ),

                              const Spacer(),

                              // Doctor Dropdown Filter
                              if (_doctors.isNotEmpty) ...[
                                const Text(
                                  'Doctor: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: _selectedDoctorId,
                                  underline: const SizedBox(),
                                  items: _doctors
                                      .map(
                                        (d) => DropdownMenuItem(
                                          value: d.doctorId,
                                          child: Text(d.displayName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedDoctorId = val);
                                    _loadData();
                                  },
                                ),
                              ],
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.chevron_left, size: 20),
                                    tooltip: 'Previous Day',
                                    onPressed: () {
                                      setState(() {
                                        _selectedDate = _selectedDate.subtract(
                                          const Duration(days: 1),
                                        );
                                      });
                                      _loadData();
                                    },
                                  ),
                                  Expanded(
                                    child: InkWell(
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
                                          await _loadData();
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              dateFormatted,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.chevron_right, size: 20),
                                    tooltip: 'Next Day',
                                    onPressed: () {
                                      setState(() {
                                        _selectedDate = _selectedDate.add(
                                          const Duration(days: 1),
                                        );
                                      });
                                      _loadData();
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: const Size(48, 32),
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _selectedDate = DateTime.now(),
                                      );
                                      _loadData();
                                    },
                                    child: const Text(
                                      'Today',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              if (_doctors.isNotEmpty) ...[
                                const Divider(color: Color(0xFFF1F5F9)),
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
                                      child: DropdownButton<String>(
                                        value: _selectedDoctorId,
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        items: _doctors
                                            .map(
                                              (d) => DropdownMenuItem(
                                                value: d.doctorId,
                                                child: Text(d.displayName),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          setState(() => _selectedDoctorId = val);
                                          _loadData();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

            // Appointments List (Scrolls naturally with page)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _appointments.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.event_available,
                        title: 'No Appointments for $dateFormatted',
                        description:
                            'There are no patient appointments scheduled on this date for the selected doctor.',
                        actionLabel: 'Schedule Advance Appointment',
                        onAction: _showCreateAppointmentDialog,
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _appointments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                        final app = _appointments[index];
                        final startFormatted =
                            '${app.scheduledStartAt.hour.toString().padLeft(2, '0')}:${app.scheduledStartAt.minute.toString().padLeft(2, '0')}';
                        final endFormatted =
                            '${app.scheduledEndAt.hour.toString().padLeft(2, '0')}:${app.scheduledEndAt.minute.toString().padLeft(2, '0')}';

                        final patient = _patientMap[app.patientId];
                        final patientName =
                            patient?.fullName ?? 'Patient (${app.patientId})';
                        final patientNumber = patient?.patientNumber ?? '';
                        final patientPhone = patient?.phoneOptional ?? '';

                        Widget statusWidget;
                        if (app.status == AppointmentStatus.scheduled) {
                          statusWidget = StatusBadge.waiting('Scheduled');
                        } else if (app.status == AppointmentStatus.completed) {
                          statusWidget = StatusBadge.completed('Checked In');
                        } else if (app.status == AppointmentStatus.cancelled) {
                          statusWidget = StatusBadge.cancelled('Cancelled');
                        } else if (app.status == AppointmentStatus.noShow) {
                          statusWidget = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              'No-Show',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          );
                        } else {
                          statusWidget =
                              StatusBadge.waiting(app.status.wireValue);
                        }

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: app.status == AppointmentStatus.completed
                                  ? const Color(0xFFBBF7D0)
                                  : app.status == AppointmentStatus.cancelled
                                      ? const Color(0xFFFECACA)
                                      : app.status == AppointmentStatus.noShow
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFE2E8F0),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: constraints.maxWidth >= 640
                                ? Row(
                                    children: [
                                      // Time Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              startFormatted,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            Text(
                                              endFormatted,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Patient & Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    patientName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                if (patientNumber
                                                    .isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey.shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      patientNumber,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(width: 10),
                                                statusWidget,
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                if (patientPhone.isNotEmpty)
                                                  Text(
                                                    'Phone: $patientPhone',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                Text(
                                                  '• Type: ${app.appointmentType == "followup" ? "Follow-up" : "New Consult"}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                                Text(
                                                  '• Via ${app.bookingSource}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                                if (app.cancelReason != null)
                                                  Text(
                                                    '• Reason: ${app.cancelReason}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.error,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Action Buttons
                                      if (app.status ==
                                          AppointmentStatus.scheduled) ...[
                                        FilledButton.icon(
                                          onPressed: () => _checkInToVisit(app),
                                          icon: const Icon(
                                            Icons.how_to_reg,
                                            size: 16,
                                          ),
                                          label:
                                              const Text('Check-In (Token)'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _showRescheduleDialog(app),
                                          icon: const Icon(
                                            Icons.edit_calendar,
                                            size: 15,
                                          ),
                                          label: const Text('Reschedule'),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: () => _markNoShow(app),
                                          icon: Icon(
                                            Icons.person_off_outlined,
                                            size: 15,
                                            color: Colors.amber.shade800,
                                          ),
                                          label: Text(
                                            'No-Show',
                                            style: TextStyle(
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: Colors.amber.shade400,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: () =>
                                              _cancelAppointment(app),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.red.shade700,
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                      ] else if (app.status ==
                                          AppointmentStatus.completed) ...[
                                        const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 18,
                                              color: AppColors.success,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Token Issued',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton.icon(
                                          onPressed: () => _bookFollowUp(app),
                                          icon: const Icon(
                                            Icons.add_task,
                                            size: 15,
                                          ),
                                          label:
                                              const Text('Book Follow-up'),
                                        ),
                                      ] else if (app.status ==
                                              AppointmentStatus.cancelled ||
                                          app.status ==
                                              AppointmentStatus.noShow) ...[
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _showRescheduleDialog(app),
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Re-book / Reschedule',
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  startFormatted,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Colors.blue.shade900,
                                                  ),
                                                ),
                                                Text(
                                                  endFormatted,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  patientName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Wrap(
                                                  spacing: 4,
                                                  runSpacing: 2,
                                                  children: [
                                                    Text(
                                                      app.appointmentType == 'followup'
                                                          ? 'Follow-up'
                                                          : 'New Consult',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                    Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                                    Text(
                                                      app.bookingSource,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Status: ${app.status.wireValue.toUpperCase()}${app.cancelReason != null ? " • ${app.cancelReason}" : ""}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: app.status ==
                                                  AppointmentStatus.completed
                                              ? Colors.green.shade800
                                              : app.status ==
                                                      AppointmentStatus.cancelled
                                                  ? Colors.red.shade800
                                                  : app.status ==
                                                          AppointmentStatus.noShow
                                                      ? Colors.amber.shade900
                                                      : Colors.grey.shade700,
                                        ),
                                      ),
                                      if (app.status ==
                                          AppointmentStatus.scheduled) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton.icon(
                                                onPressed: () =>
                                                    _checkInToVisit(app),
                                                icon: const Icon(
                                                  Icons.login,
                                                  size: 15,
                                                ),
                                                label: const Text(
                                                  'Check-In',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green.shade700,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _showRescheduleDialog(app),
                                                icon: const Icon(
                                                  Icons.edit_calendar,
                                                  size: 14,
                                                ),
                                                label: const Text(
                                                  'Reschedule',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                                style:
                                                    OutlinedButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _markNoShow(app),
                                                icon: Icon(
                                                  Icons.person_off_outlined,
                                                  size: 14,
                                                  color:
                                                      Colors.amber.shade800,
                                                ),
                                                label: Text(
                                                  'No-Show',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.amber.shade900,
                                                  ),
                                                ),
                                                style:
                                                    OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color:
                                                        Colors.amber.shade400,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () =>
                                                    _cancelAppointment(app),
                                                style:
                                                    OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.red.shade700,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Cancel',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else if (app.status ==
                                          AppointmentStatus.completed) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: AppColors.success,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Token Issued',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Spacer(),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _bookFollowUp(app),
                                              icon: const Icon(
                                                Icons.add_task,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'Follow-up',
                                                style:
                                                    TextStyle(fontSize: 12),
                                              ),
                                              style:
                                                  OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else if (app.status ==
                                              AppointmentStatus.cancelled ||
                                          app.status ==
                                              AppointmentStatus.noShow) ...[
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _showRescheduleDialog(app),
                                            icon: const Icon(
                                              Icons.refresh,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'Re-book / Reschedule',
                                              style:
                                                  TextStyle(fontSize: 12),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                ] else ...[
                  _buildFollowupsView(constraints, isDesktop, isMobile),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowupsView(
    BoxConstraints constraints,
    bool isDesktop,
    bool isMobile,
  ) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final in7Days = now.add(const Duration(days: 7));
    final in7DaysStr =
        '${in7Days.year}-${in7Days.month.toString().padLeft(2, '0')}-${in7Days.day.toString().padLeft(2, '0')}';

    final totalCount = _followups.length;
    final dueTodayCount =
        _followups.where((f) => f.isDueToday(todayStr)).length;
    final overdueCount =
        _followups.where((f) => f.isOverdue(todayStr)).length;
    final upcomingCount = _followups
        .where((f) =>
            f.status == 'scheduled' &&
            f.dueDate.compareTo(todayStr) > 0 &&
            f.dueDate.compareTo(in7DaysStr) <= 0)
        .length;
    final completedCount =
        _followups.where((f) => f.status == 'completed').length;

    // Filter followups list
    final filtered = _followups.where((f) {
      if (_followupDoctorFilter != null &&
          _followupDoctorFilter!.isNotEmpty &&
          f.doctorId != _followupDoctorFilter) {
        return false;
      }
      switch (_followupFilter) {
        case 'today':
          return f.isDueToday(todayStr);
        case 'upcoming':
          return f.status == 'scheduled' &&
              f.dueDate.compareTo(todayStr) > 0 &&
              f.dueDate.compareTo(in7DaysStr) <= 0;
        case 'overdue':
          return f.isOverdue(todayStr);
        case 'completed':
          return f.status == 'completed';
        default:
          return true;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Follow-ups Summary Metrics
        LayoutBuilder(
          builder: (context, cardConstraints) {
            final isWide = cardConstraints.maxWidth >= 1100;
            final isTab = cardConstraints.maxWidth >= 640 &&
                cardConstraints.maxWidth < 1100;
            final isSingle = cardConstraints.maxWidth < 420;

            return GridView.count(
              crossAxisCount: isWide ? 5 : (isTab ? 3 : (isSingle ? 1 : 2)),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWide ? 2.2 : (isSingle ? 2.8 : 1.4),
              children: [
                MetricCard(
                  title: 'Total Reminders',
                  value: '$totalCount',
                  subtitle: 'Scheduled follow-ups',
                  icon: Icons.event_repeat,
                  iconColor: AppColors.primary,
                ),
                MetricCard(
                  title: 'Due Today',
                  value: '$dueTodayCount',
                  subtitle: 'Awaiting reception contact',
                  icon: Icons.today,
                  iconColor: Colors.amber.shade800,
                ),
                MetricCard(
                  title: 'Upcoming (7d)',
                  value: '$upcomingCount',
                  subtitle: 'Due within next 7 days',
                  icon: Icons.upcoming,
                  iconColor: const Color(0xFF0284C7),
                ),
                MetricCard(
                  title: 'Overdue',
                  value: '$overdueCount',
                  subtitle: 'Past due date',
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.error,
                ),
                MetricCard(
                  title: 'Converted',
                  value: '$completedCount',
                  subtitle: 'Booked to appointment',
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.success,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Filter Bar: Status & Doctor
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 10.0,
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: _followupFilter == 'all',
                      label: Text('All ($totalCount)'),
                      onSelected: (_) =>
                          setState(() => _followupFilter = 'all'),
                    ),
                    FilterChip(
                      selected: _followupFilter == 'today',
                      label: Text('Due Today ($dueTodayCount)'),
                      selectedColor: Colors.amber.shade100,
                      onSelected: (_) =>
                          setState(() => _followupFilter = 'today'),
                    ),
                    FilterChip(
                      selected: _followupFilter == 'upcoming',
                      label: Text('Upcoming ($upcomingCount)'),
                      selectedColor: Colors.blue.shade100,
                      onSelected: (_) =>
                          setState(() => _followupFilter = 'upcoming'),
                    ),
                    FilterChip(
                      selected: _followupFilter == 'overdue',
                      label: Text('Overdue ($overdueCount)'),
                      selectedColor: Colors.red.shade100,
                      onSelected: (_) =>
                          setState(() => _followupFilter = 'overdue'),
                    ),
                    FilterChip(
                      selected: _followupFilter == 'completed',
                      label: Text('Converted ($completedCount)'),
                      selectedColor: Colors.green.shade100,
                      onSelected: (_) =>
                          setState(() => _followupFilter = 'completed'),
                    ),
                  ],
                ),
                if (_doctors.isNotEmpty)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      value: _followupDoctorFilter,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Filter Doctor',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Doctors'),
                        ),
                        ..._doctors.map((d) {
                          return DropdownMenuItem(
                            value: d.doctorId,
                            child: Text(d.displayName),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _followupDoctorFilter = val);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Follow-ups List
        filtered.isEmpty
            ? EmptyStateWidget(
                icon: Icons.notifications_none,
                title: 'No Follow-up Reminders Found',
                description:
                    'PRD M12: Patients due for routine checkups, dressing changes, or report reviews are tracked here.',
                actionLabel: 'Schedule First Follow-up Reminder',
                onAction: _showScheduleFollowupDialog,
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final f = filtered[index];
                  final patient = _patientMap[f.patientId];
                  final doctor = _doctors
                      .where((d) => d.doctorId == f.doctorId)
                      .firstOrNull;

                  final pName = patient?.fullName ?? 'Patient';
                  final pNum = patient?.patientNumber ?? '';
                  final pPhone = patient?.phoneOptional != null
                      ? PhoneNormalizer.mask(patient!.phoneOptional)
                      : 'No phone';
                  final docName = doctor?.displayName ?? 'Assigned Doctor';

                  Color cardBg = Colors.white;
                  Color borderColor = const Color(0xFFE2E8F0);
                  String dueBadgeText = 'DUE: ${f.dueDate}';
                  Color dueBadgeBg = Colors.blue.shade50;
                  Color dueBadgeFg = Colors.blue.shade800;

                  if (f.status == 'completed') {
                    dueBadgeText = 'COMPLETED';
                    dueBadgeBg = Colors.green.shade50;
                    dueBadgeFg = Colors.green.shade800;
                  } else if (f.isDueToday(todayStr)) {
                    dueBadgeText = 'DUE TODAY';
                    dueBadgeBg = Colors.amber.shade100;
                    dueBadgeFg = Colors.amber.shade900;
                    borderColor = Colors.amber.shade300;
                  } else if (f.isOverdue(todayStr)) {
                    dueBadgeText = 'OVERDUE';
                    dueBadgeBg = Colors.red.shade100;
                    dueBadgeFg = Colors.red.shade900;
                    borderColor = Colors.red.shade300;
                  }

                  return Card(
                    elevation: 0,
                    color: cardBg,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Name, ID, Badges
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        dueBadgeBg.withValues(alpha: 0.7),
                                    child: Icon(
                                      f.status == 'completed'
                                          ? Icons.check
                                          : Icons.event_repeat,
                                      color: dueBadgeFg,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '$pNum • $pPhone',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dueBadgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      dueBadgeText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: dueBadgeFg,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: f.reminderConsent
                                          ? Colors.green.shade50
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: f.reminderConsent
                                            ? Colors.green.shade200
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      f.reminderConsent
                                          ? 'Consent: ${f.channelPreference.toUpperCase()}'
                                          : 'No Consent',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: f.reminderConsent
                                            ? Colors.green.shade800
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: f.reminderStatus == 'sent'
                                          ? const Color(0xFFF0FDF4)
                                          : (f.reminderStatus == 'failed'
                                              ? const Color(0xFFFEF2F2)
                                              : const Color(0xFFFFFBEB)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: f.reminderStatus == 'sent'
                                            ? const Color(0xFF86EFAC)
                                            : (f.reminderStatus == 'failed'
                                                ? const Color(0xFFFECACA)
                                                : const Color(0xFFFDE68A)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          f.reminderStatus == 'sent'
                                              ? Icons.check_circle
                                              : (f.reminderStatus == 'failed'
                                                  ? Icons.error_outline
                                                  : Icons.schedule),
                                          size: 13,
                                          color: f.reminderStatus == 'sent'
                                              ? const Color(0xFF16A34A)
                                              : (f.reminderStatus == 'failed'
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFFD97706)),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          f.reminderStatus == 'sent'
                                              ? (f.reminderSentAt != null
                                                  ? 'Sent on ${DateFormat('dd MMM, hh:mm a').format(f.reminderSentAt!.toLocal())} (${f.channelPreference.toUpperCase()})'
                                                  : 'Reminder: SENT (${f.channelPreference.toUpperCase()})')
                                              : (f.reminderStatus == 'failed'
                                                  ? 'Delivery Failed (${f.channelPreference.toUpperCase()})'
                                                  : 'Reminder: PENDING (${f.channelPreference.toUpperCase()})'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: f.reminderStatus == 'sent'
                                                ? const Color(0xFF15803D)
                                                : (f.reminderStatus == 'failed'
                                                    ? const Color(0xFFB91C1C)
                                                    : const Color(0xFFB45309)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 18),

                          // Doctor & Administrative Note
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.medical_services_outlined,
                                    size: 15,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    docName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
                                    size: 15,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Due Date: ${f.dueDate}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              if (f.administrativeNoteOptional != null &&
                                  f.administrativeNoteOptional!.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.notes,
                                      size: 15,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Note: ${f.administrativeNoteOptional}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Actions Row
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (f.status == 'scheduled') ...[
                                FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _showRecordReminderDialog(f),
                                  icon: const Icon(Icons.send_rounded, size: 14),
                                  label: Text(
                                    f.reminderStatus == 'sent'
                                        ? 'Send / Log Reminder Again'
                                        : 'Send Reminder (${f.channelPreference.toUpperCase()})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () =>
                                      _convertFollowupToAppointment(f),
                                  icon: const Icon(Icons.calendar_month, size: 14),
                                  label: const Text(
                                    'Book Slot (Convert)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F766E),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                              PopupMenuButton<String>(
                                tooltip: 'Follow-up Actions',
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (val) {
                                  if (val == 'complete') {
                                    _confirmUpdateFollowupStatus(f, 'completed');
                                  } else if (val == 'cancel') {
                                    _confirmUpdateFollowupStatus(f, 'cancelled');
                                  } else if (val == 'missed') {
                                    _confirmUpdateFollowupStatus(f, 'missed');
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  if (f.status != 'completed')
                                    const PopupMenuItem(
                                      value: 'complete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              size: 16, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text('Mark Completed'),
                                        ],
                                      ),
                                    ),
                                  if (f.status != 'cancelled')
                                    const PopupMenuItem(
                                      value: 'cancel',
                                      child: Row(
                                        children: [
                                          Icon(Icons.cancel,
                                              size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Cancel Reminder'),
                                        ],
                                      ),
                                    ),
                                  if (f.status != 'missed')
                                    const PopupMenuItem(
                                      value: 'missed',
                                      child: Row(
                                        children: [
                                          Icon(Icons.close,
                                              size: 16, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Mark as Missed'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Future<void> _showScheduleFollowupDialog({
    Patient? preSelectedPatient,
    String? preSelectedDoctorId,
    DateTime? defaultDueDate,
    String? sourceVisitId,
  }) async {
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final followupRepo = ref.read(followupRepositoryProvider);

    final patientSearchController = TextEditingController();
    Patient? selectedPatient = preSelectedPatient;
    List<Patient> searchResults = [];

    String doctorId = preSelectedDoctorId ??
        _selectedDoctorId ??
        (_doctors.isNotEmpty ? _doctors.first.doctorId : '');

    DateTime dueDate = defaultDueDate ?? DateTime.now().add(const Duration(days: 7));
    bool reminderConsent = true;
    String channelPreference = 'sms';
    final noteController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dueDateStr =
              '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
          final dueDateFormatted =
              '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}';

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.notification_add, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Expanded(child: Text('Schedule Follow-up Reminder')),
              ],
            ),
            content: Container(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.of(dialogCtx).size.height * 0.85,
              ),
              width: MediaQuery.of(dialogCtx).size.width >= 560
                  ? 520.0
                  : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Selection
                    const Text(
                      '1. Select Patient',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (selectedPatient != null)
                      ListTile(
                        tileColor: Colors.blue.shade50,
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: Text(selectedPatient!.fullName),
                        subtitle: Text(
                          '${selectedPatient!.patientNumber} • ${selectedPatient!.phoneOptional != null ? PhoneNormalizer.mask(selectedPatient!.phoneOptional) : "No phone"}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setDialogState(() => selectedPatient = null),
                        ),
                      )
                    else ...[
                      TextField(
                        controller: patientSearchController,
                        decoration: const InputDecoration(
                          hintText: 'Search patient by name or phone...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (query) async {
                          if (query.trim().length >= 2) {
                            final results = await patientRepo.searchPatients(
                              session.clinicId,
                              query,
                            );
                            setDialogState(() => searchResults = results);
                          } else {
                            setDialogState(() => searchResults = []);
                          }
                        },
                      ),
                      if (searchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            itemBuilder: (c, idx) {
                              final p = searchResults[idx];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '${p.fullName} (${p.patientNumber})',
                                ),
                                subtitle: Text(p.phoneOptional != null ? PhoneNormalizer.mask(p.phoneOptional) : 'No phone'),
                                onTap: () {
                                  setDialogState(() {
                                    selectedPatient = p;
                                    searchResults = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),

                    // Doctor Selection
                    const Text(
                      '2. Assigned Doctor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: doctorId.isNotEmpty ? doctorId : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _doctors.map((d) {
                        return DropdownMenuItem(
                          value: d.doctorId,
                          child: Text('${d.displayName} (${d.specialtyLabel})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => doctorId = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Due Date Picker & Quick Presets
                    const Text(
                      '3. Follow-up Due Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('+3 Days'),
                          onPressed: () => setDialogState(
                            () => dueDate = DateTime.now().add(const Duration(days: 3)),
                          ),
                        ),
                        ActionChip(
                          label: const Text('+1 Week'),
                          onPressed: () => setDialogState(
                            () => dueDate = DateTime.now().add(const Duration(days: 7)),
                          ),
                        ),
                        ActionChip(
                          label: const Text('+2 Weeks'),
                          onPressed: () => setDialogState(
                            () => dueDate = DateTime.now().add(const Duration(days: 14)),
                          ),
                        ),
                        ActionChip(
                          label: const Text('+1 Month'),
                          onPressed: () => setDialogState(
                            () => dueDate = DateTime.now().add(const Duration(days: 30)),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text(dueDateFormatted),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: dueDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => dueDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // DPDP Reminder Consent & Channel
                    const Text(
                      '4. DPDP Reminder Consent & Channel Preference',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: reminderConsent,
                      title: const Text(
                        'Patient explicitly consented to appointment reminders',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'DPDP requirement: Retain consent state for administrative follow-ups',
                        style: TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) => setDialogState(() => reminderConsent = val ?? false),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: channelPreference,
                      decoration: const InputDecoration(
                        labelText: 'Notification Channel',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'sms', child: Text('SMS Notification')),
                        DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp Message')),
                        DropdownMenuItem(value: 'call', child: Text('Phone Call from Reception')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => channelPreference = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Administrative Note (Strictly non-clinical)
                    const Text(
                      '5. Administrative Note (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PRD M12 Boundary: Strictly administrative note (e.g. suture removal, report review). Do not enter medical prescriptions or diagnosis here.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Dressing change and post-op wound review',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (selectedPatient == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text('Please select a patient.'),
                      ),
                    );
                    return;
                  }
                  if (doctorId.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text('Please assign a doctor.'),
                      ),
                    );
                    return;
                  }

                  final now = DateTime.now().toUtc();
                  final flw = Followup(
                    followupId: 'flw_${DateTime.now().millisecondsSinceEpoch}',
                    clinicId: session.clinicId,
                    patientId: selectedPatient!.patientId,
                    sourceVisitIdOptional: sourceVisitId,
                    doctorId: doctorId,
                    dueDate: dueDateStr,
                    administrativeNoteOptional: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                    status: 'scheduled',
                    reminderConsent: reminderConsent,
                    channelPreference: channelPreference,
                    reminderStatus: 'scheduled',
                    createdAt: now,
                    updatedAt: now,
                  );

                  await followupRepo.scheduleFollowup(flw);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (mounted) {
                    await _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF0284C7),
                        content: Text(
                          'Follow-up reminder scheduled for ${selectedPatient!.fullName} on $dueDateFormatted',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Schedule Follow-up'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRecordReminderDialog(Followup f) async {
    final session = ref.read(sessionProvider);
    final followupRepo = ref.read(followupRepositoryProvider);
    final patient = _patientMap[f.patientId];
    final doctor = _doctors.firstWhere(
      (d) => d.doctorId == f.doctorId,
      orElse: () => Doctor(
        doctorId: f.doctorId,
        clinicId: f.clinicId,
        displayName: 'Attending Doctor',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    String channel = f.channelPreference;
    final rawPhone = patient?.phoneOptional ?? '';
    final cleanDigits = PhoneNormalizer.normalize(rawPhone) ?? '';
    final hasPhone = cleanDigits.isNotEmpty;

    final clinicRecords =
        ref.read(localDatabaseProvider).query('Clinic_Config');
    final clinicConfig =
        clinicRecords.isNotEmpty ? clinicRecords.first : null;
    final clinicName =
        (clinicConfig?['clinic_name'] as String?)?.trim().isNotEmpty == true
            ? (clinicConfig!['clinic_name'] as String).trim()
            : 'Apna Clinic';
    final clinicPhone =
        (clinicConfig?['contact_phone'] as String?)?.trim().isNotEmpty == true
            ? (clinicConfig!['contact_phone'] as String).trim()
            : '';

    final defaultMessage =
        'Hello ${patient?.fullName ?? "Valued Patient"},\n\n'
        'This is a friendly reminder from $clinicName regarding your upcoming follow-up appointment with Dr. ${doctor.displayName} scheduled for ${f.dueDate}.\n\n'
        'Please reply to confirm or contact ${clinicPhone.isNotEmpty ? "us at $clinicPhone" : "the clinic"} if you need to choose another slot.\n\n'
        'Thank you,\n$clinicName';

    final messageController = TextEditingController(text: defaultMessage);

    Future<void> launchAndRecord(String targetChannel) async {
      String status = 'sent';
      try {
        if (targetChannel == 'whatsapp') {
          final phoneParam =
              cleanDigits.length == 10 ? '91$cleanDigits' : cleanDigits;
          final encodedText =
              Uri.encodeComponent(messageController.text.trim());
          final waUrl = Uri.parse('https://wa.me/$phoneParam?text=$encodedText');
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
        } else if (targetChannel == 'sms') {
          final encodedBody =
              Uri.encodeComponent(messageController.text.trim());
          final smsUrl = Uri.parse('sms:$cleanDigits?body=$encodedBody');
          await launchUrl(smsUrl);
        } else if (targetChannel == 'call') {
          final telUrl = Uri.parse('tel:$cleanDigits');
          await launchUrl(telUrl);
        }
      } catch (_) {
        status = 'failed';
      }

      await followupRepo.recordReminderNotification(
        clinicId: session.clinicId,
        followupId: f.followupId,
        status: status,
        channel: targetChannel,
        actorId: session.staffId,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor:
                status == 'sent' ? AppColors.success : Colors.amber.shade900,
            content: Text(
              status == 'sent'
                  ? 'Message opened & reminder logged as SENT via ${targetChannel.toUpperCase()}!'
                  : 'Failed to open $targetChannel. Marked as failed.',
            ),
          ),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Follow-up Reminder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Compose & dispatch patient notification',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient & Due Info Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Color(0xFF0F766E),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                patient?.fullName ?? 'Unknown Patient',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: hasPhone
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: hasPhone
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasPhone
                                        ? Icons.phone
                                        : Icons.phone_disabled,
                                    size: 11,
                                    color: hasPhone
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasPhone ? rawPhone : 'No Phone Number',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: hasPhone
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.event,
                              size: 15,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Due: ${f.dueDate}  •  Dr. ${doctor.displayName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notification Channel Selector
                  const Text(
                    'Select Notification Channel:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: channel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'whatsapp',
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFF25D366),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('WhatsApp Message (Recommended)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'sms',
                        child: Row(
                          children: [
                            Icon(
                              Icons.sms_outlined,
                              color: Colors.blue,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('SMS Message (Text)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'call',
                        child: Row(
                          children: [
                            Icon(
                              Icons.call_outlined,
                              color: Colors.teal,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('Phone Call (Direct Dial)'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => channel = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Message Content Preview & Customizer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Message Text (Editable Preview):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: messageController.text),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Message copied to clipboard!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.copy,
                              size: 13,
                              color: Color(0xFF0F766E),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Copy Text',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: messageController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(10),
                      hintText: 'Enter reminder message...',
                      fillColor: Colors.grey.shade50,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons: Send WhatsApp / SMS / Call
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasPhone) ...[
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            launchAndRecord('whatsapp');
                          },
                          icon: const Icon(Icons.chat, size: 15),
                          label: const Text('Open WhatsApp'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            launchAndRecord('sms');
                          },
                          icon: const Icon(Icons.sms, size: 15),
                          label: const Text('Open SMS'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            launchAndRecord('call');
                          },
                          icon: const Icon(Icons.call, size: 15),
                          label: const Text('Call Patient'),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: const Text(
                            'Notice: Patient has no contact phone registered. Please update patient details to send automated messages.',
                            style: TextStyle(fontSize: 11, color: Colors.brown),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                Navigator.pop(ctx);
                await followupRepo.recordReminderNotification(
                  clinicId: session.clinicId,
                  followupId: f.followupId,
                  status: 'sent',
                  channel: channel,
                  actorId: session.staffId,
                );
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.success,
                      content:
                          Text('Marked as SENT via ${channel.toUpperCase()}'),
                    ),
                  );
                }
              },
              child: const Text('Mark Sent (Manual)'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await followupRepo.recordReminderNotification(
                  clinicId: session.clinicId,
                  followupId: f.followupId,
                  status: 'failed',
                  channel: channel,
                  actorId: session.staffId,
                );
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.amber.shade900,
                      content:
                          Text('Marked as FAILED via ${channel.toUpperCase()}'),
                    ),
                  );
                }
              },
              child: const Text(
                'Mark Failed',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertFollowupToAppointment(Followup f) async {
    final patient = _patientMap[f.patientId];
    DateTime dueDate = DateTime.tryParse(f.dueDate) ?? DateTime.now();
    await _showCreateAppointmentDialog(
      preSelectedPatient: patient,
      preSelectedDoctorId: f.doctorId,
      defaultAppointmentType: 'followup',
      defaultDate: dueDate,
      convertingFollowupId: f.followupId,
    );
  }

  Future<void> _confirmUpdateFollowupStatus(Followup f, String newStatus) async {
    final session = ref.read(sessionProvider);
    final followupRepo = ref.read(followupRepositoryProvider);
    await followupRepo.updateFollowupStatus(
      clinicId: session.clinicId,
      followupId: f.followupId,
      status: newStatus,
      actorId: session.staffId,
    );
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow-up status updated to $newStatus')),
      );
    }
  }

  Future<void> _exportFollowupsCsv() async {
    try {
      final session = ref.read(sessionProvider);
      final followupRepo = ref.read(followupRepositoryProvider);
      final docMap = {for (final d in _doctors) d.doctorId: d};
      final csv = followupRepo.exportFollowupsToCsv(_followups, _patientMap, docMap);
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName = 'apna_clinic_followups_${session.clinicId}_$dateStr.csv';
      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        content: csv,
        mimeType: 'text/csv;charset=utf-8',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Follow-ups exported successfully (${_followups.length} records, 0 clinical data).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Export failed: $e')),
        );
      }
    }
  }
}


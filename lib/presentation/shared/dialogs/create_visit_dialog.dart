// Apna Clinic - Shared Visit Creation & Billing Dialog
// Primary source of truth: PRD Section 1.1 Goal 1, Section 28-31, TRD Section 8-9
// Atomic Visit & Token Generation with integrated Billing Ledger

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/entities.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../application/providers.dart';
import '../../../application/printing/consultation_slip_service.dart';
import '../../../application/printing/receipt_slip_service.dart';
import 'consultation_slip_preview_dialog.dart';
import '../theme/app_theme.dart';

class CreateVisitDialog extends ConsumerStatefulWidget {
  final Patient patient;
  final VoidCallback? onVisitCreated;

  const CreateVisitDialog({
    super.key,
    required this.patient,
    this.onVisitCreated,
  });

  @override
  ConsumerState<CreateVisitDialog> createState() => _CreateVisitDialogState();
}

class _CreateVisitDialogState extends ConsumerState<CreateVisitDialog> {
  String? _selectedDoctorId;
  String? _selectedFeeCatalogId;
  final _reasonController = TextEditingController();
  final _feeController = TextEditingController(text: '500');
  final _partialPaidController = TextEditingController(text: '250');
  int _baseFeeRupees = 500;
  int _additionalFeeRupees = 0;
  int _consultationFeeRupees = 500; // Whole fee = _baseFeeRupees + _additionalFeeRupees
  int _partialPaidRupees = 250;
  String _paymentOption = 'unpaid'; // 'unpaid', 'full', 'partial', 'free' - Default to Pay Later / Checkout as per PRD
  String _paymentMethod = 'cash'; // 'cash', 'upi', 'card'
  QueuePriority _selectedPriority = QueuePriority.normal;

  List<Doctor> _doctors = [];
  List<FeeCatalog> _feeCatalog = [];
  Visit? _activeVisit;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDialogData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _feeController.dispose();
    _partialPaidController.dispose();
    super.dispose();
  }

  int _resolveBaseConsultationFee(Doctor doc, List<FeeCatalog> fees) {
    // 1. Doctor-scoped general consultation fee in catalog
    final docFee = fees.where((f) =>
      f.doctorIdOptional == doc.doctorId &&
      f.active &&
      (f.visitTypeOptional == null || f.visitTypeOptional == 'walkin')
    ).firstOrNull;
    if (docFee != null) {
      return (docFee.defaultAmountMinor / 100).round();
    }

    // 2. General walkin consultation fee in catalog
    final walkinFee = fees.where((f) =>
      f.doctorIdOptional == null &&
      f.visitTypeOptional == 'walkin' &&
      f.active
    ).firstOrNull;
    if (walkinFee != null) {
      return (walkinFee.defaultAmountMinor / 100).round();
    }

    // 3. Fallback to Doctor default fee
    return (doc.defaultFee / 100).round();
  }

  FeeCatalog? _resolvePriorityFeeItem(QueuePriority priority, List<FeeCatalog> fees, [Doctor? doc]) {
    if (priority == QueuePriority.normal) return null;
    final priorityKey = priority.name.toLowerCase(); // 'emergency', 'urgent', 'vip'

    // Doctor-scoped priority fee
    final docPriority = fees.where((f) =>
      f.doctorIdOptional == doc?.doctorId &&
      f.active &&
      (f.visitTypeOptional?.toLowerCase() == priorityKey ||
       f.feeName.toLowerCase().contains(priorityKey) ||
       f.feeCode.toLowerCase().contains(priorityKey))
    ).firstOrNull;
    if (docPriority != null) return docPriority;

    // Global priority fee (e.g. Emergency Care catalog item)
    return fees.where((f) =>
      f.active &&
      (f.visitTypeOptional?.toLowerCase() == priorityKey ||
       f.feeName.toLowerCase().contains(priorityKey) ||
       f.feeCode.toLowerCase().contains(priorityKey))
    ).firstOrNull;
  }

  void _updateFees({
    Doctor? doc,
    QueuePriority? priority,
    String? additionalFeeId,
    bool autoSelectPriorityFee = true,
  }) {
    final activeDoc = doc ?? (_doctors.isNotEmpty
        ? _doctors.firstWhere(
            (d) => d.doctorId == _selectedDoctorId,
            orElse: () => _doctors.first,
          )
        : null);

    if (activeDoc != null) {
      _baseFeeRupees = _resolveBaseConsultationFee(activeDoc, _feeCatalog);
    }

    final p = priority ?? _selectedPriority;
    if (autoSelectPriorityFee) {
      final prioFee = _resolvePriorityFeeItem(p, _feeCatalog, activeDoc);
      if (prioFee != null) {
        _selectedFeeCatalogId = prioFee.feeId;
        _additionalFeeRupees = prioFee.defaultAmountMinor ~/ 100;
      } else {
        if (p == QueuePriority.normal && _selectedFeeCatalogId != null) {
          final isPrioFee = _feeCatalog.any((f) => f.feeId == _selectedFeeCatalogId &&
            (f.visitTypeOptional?.toLowerCase() == 'emergency' || f.feeName.toLowerCase().contains('emergency')));
          if (isPrioFee) {
            _selectedFeeCatalogId = null;
            _additionalFeeRupees = 0;
          }
        }
      }
    } else if (additionalFeeId != null) {
      _selectedFeeCatalogId = additionalFeeId;
      final feeItem = _feeCatalog.where((f) => f.feeId == additionalFeeId).firstOrNull;
      _additionalFeeRupees = feeItem != null ? feeItem.defaultAmountMinor ~/ 100 : 0;
    } else {
      _selectedFeeCatalogId = null;
      _additionalFeeRupees = 0;
    }

    _consultationFeeRupees = _baseFeeRupees + _additionalFeeRupees;
    _feeController.text = '$_consultationFeeRupees';
    _partialPaidRupees = (_consultationFeeRupees / 2).round();
    _partialPaidController.text = '$_partialPaidRupees';
  }

  Future<void> _loadDialogData() async {
    final session = ref.read(sessionProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);
    final visitRepo = ref.read(visitRepositoryProvider);
    final billingRepo = ref.read(billingRepositoryProvider);
    final today = DateTime.now().toIso8601String().split('T').first;

    final docs = await clinicRepo.getDoctors(
      session.clinicId,
      activeOnly: true,
    );
    final fees = await billingRepo.getFeeCatalog(session.clinicId);
    final todayVisits =
        await visitRepo.getVisitsForDate(session.clinicId, today);
    Visit? active;
    for (final v in todayVisits) {
      if (v.patientId == widget.patient.patientId &&
          (v.queueStatus == QueueStatus.registered ||
              v.queueStatus == QueueStatus.waiting ||
              v.queueStatus == QueueStatus.called ||
              v.queueStatus == QueueStatus.inConsultation)) {
        active = v;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _doctors = docs;
        _feeCatalog = fees;
        if (docs.isNotEmpty) {
          _selectedDoctorId = docs.first.doctorId;
          _updateFees(doc: docs.first);
        }
        _activeVisit = active;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitVisit() async {
    if (_selectedDoctorId == null || _isSubmitting || _activeVisit != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    final session = ref.read(sessionProvider);
    final visitRepo = ref.read(visitRepositoryProvider);
    final billingRepo = ref.read(billingRepositoryProvider);

    final visitId = const Uuid().v4();
    final today = DateTime.now().toIso8601String().split('T').first;
    final now = DateTime.now().toUtc();

    final selectedDoc = _doctors.firstWhere(
      (d) => d.doctorId == _selectedDoctorId,
      orElse: () => _doctors.first,
    );

    final feeMinor =
        _paymentOption == 'free' ? 0 : (_consultationFeeRupees * 100);
    int paidMinor = 0;
    if (_paymentOption == 'full') {
      paidMinor = feeMinor;
    } else if (_paymentOption == 'partial') {
      paidMinor = (_partialPaidRupees * 100).clamp(0, feeMinor);
    } else if (_paymentOption == 'unpaid' || _paymentOption == 'free') {
      paidMinor = 0;
    }
    final balanceMinor = feeMinor - paidMinor;

    String? invoiceId;
    Invoice? createdInvoice;

    try {
      if (feeMinor > 0) {
        invoiceId = const Uuid().v4();
        final currentYear = DateTime.now().year;
        final financialYear = '$currentYear-${currentYear + 1}';
        final invoiceNumber = await billingRepo.generateNextInvoiceNumber(
          session.clinicId,
          financialYear,
        );

        final items = <InvoiceItem>[];
        final addlCatalogItem = _selectedFeeCatalogId != null
            ? _feeCatalog.where((f) => f.feeId == _selectedFeeCatalogId).firstOrNull
            : null;

        if (_additionalFeeRupees > 0 && addlCatalogItem != null) {
          final baseMinor = _baseFeeRupees * 100;
          final addlMinor = feeMinor > baseMinor
              ? feeMinor - baseMinor
              : (_additionalFeeRupees * 100);
          final finalBaseMinor = feeMinor - addlMinor;

          items.add(InvoiceItem(
            invoiceItemId: const Uuid().v4(),
            clinicId: session.clinicId,
            invoiceId: invoiceId,
            description: 'Consultation - Dr. ${selectedDoc.displayName}',
            quantity: 1,
            unitPriceMinor: finalBaseMinor,
            discountMinor: 0,
            taxMinor: 0,
            lineTotalMinor: finalBaseMinor,
            createdAt: now,
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
            createdAt: now,
          ));
        } else {
          items.add(InvoiceItem(
            invoiceItemId: const Uuid().v4(),
            clinicId: session.clinicId,
            invoiceId: invoiceId,
            description: _selectedPriority == QueuePriority.emergency
                ? 'Emergency Consultation - Dr. ${selectedDoc.displayName}'
                : 'Consultation - Dr. ${selectedDoc.displayName}',
            quantity: 1,
            unitPriceMinor: feeMinor,
            discountMinor: 0,
            taxMinor: 0,
            lineTotalMinor: feeMinor,
            createdAt: now,
          ));
        }

        final invoice = Invoice(
          invoiceId: invoiceId,
          clinicId: session.clinicId,
          invoiceNumber: invoiceNumber,
          financialYear: financialYear,
          patientId: widget.patient.patientId,
          visitId: visitId,
          issueDateLocal: today,
          subtotalMinor: feeMinor,
          discountMinor: 0,
          taxMinor: 0,
          totalMinor: feeMinor,
          paidMinor: paidMinor,
          balanceMinor: balanceMinor,
          status: balanceMinor <= 0
              ? InvoiceStatus.paid
              : (paidMinor > 0
                  ? InvoiceStatus.partiallyPaid
                  : InvoiceStatus.issued),
          createdByStaffId: session.staffId,
          createdAt: now,
          updatedAt: now,
        );

        Payment? initialPayment;
        if (paidMinor > 0) {
          initialPayment = Payment(
            paymentId: const Uuid().v4(),
            clinicId: session.clinicId,
            invoiceId: invoiceId,
            amountMinor: paidMinor,
            method: PaymentMethod.fromWire(_paymentMethod),
            receivedAt: now,
            receivedByStaffId: session.staffId,
            status: PaymentStatus.completed,
            createdAt: now,
          );
        }

        createdInvoice = await billingRepo.createInvoiceAtomic(
          invoice: invoice,
          items: items,
          initialPayment: initialPayment,
          idempotencyKey: 'inv_visit_$visitId',
        );
      }

      final visit = Visit(
        visitId: visitId,
        clinicId: session.clinicId,
        patientId: widget.patient.patientId,
        doctorId: _selectedDoctorId!,
        visitDateLocal: today,
        checkinAt: now,
        tokenNumber: 0, // Assigned transactionally by atomic visit creation
        tokenScopeKey: '',
        visitType: _selectedPriority == QueuePriority.emergency
            ? 'emergency'
            : 'walkin',
        priority: _selectedPriority,
        reasonForVisitEncryptedRef: _reasonController.text.trim().isNotEmpty
            ? 'ref_$visitId'
            : null,
        queueStatus: QueueStatus.waiting,
        invoiceIdOptional: invoiceId,
        createdByStaffId: session.staffId,
        createdAt: now,
        updatedAt: now,
      );

      final createdVisit = await visitRepo.createVisitAtomic(
        visit: visit,
        idempotencyKey: 'create_visit_$visitId',
        deviceId: session.deviceId,
        staffId: session.staffId,
      );

      if (mounted) {
        final parentNavigator = Navigator.of(context, rootNavigator: true);
        Navigator.of(context).pop();
        widget.onVisitCreated?.call();

        // Trigger immediate background synchronization to Google Master Sheet
        unawaited(
          ref
              .read(masterSheetSyncSchedulerProvider)
              .triggerManualSync(clinicId: session.clinicId),
        );

        unawaited(
          showDialog<void>(
            context: parentNavigator.context,
            barrierDismissible: false,
            builder: (ctx) => PostVisitConfirmationDialog(
              visit: createdVisit,
              invoice: createdInvoice,
              doctor: selectedDoc,
              patient: widget.patient,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create visit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 560 ? 520.0 : double.maxFinite;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Visit for ${widget.patient.fullName}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Patient ID: ${widget.patient.patientNumber} • Phone: ${widget.patient.maskedPhone}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              if (_activeVisit != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.amber.shade700, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber.shade900, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patient Already in Queue',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.patient.fullName} already has active Token #${_activeVisit!.tokenNumber} (${_activeVisit!.queueStatus.name.toUpperCase()}) in the queue today. Additional tokens cannot be created until the active consultation is completed.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_doctors.isEmpty)
                const Text(
                  'No active doctors configured. Please configure a doctor in Settings first.',
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedDoctorId,
                  decoration: const InputDecoration(
                    labelText: 'Select Consulting Doctor *',
                    border: OutlineInputBorder(),
                  ),
                  items: _doctors.map((d) {
                    return DropdownMenuItem(
                      value: d.doctorId,
                      child: Text('Dr. ${d.displayName} (${d.specialtyLabel})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDoctorId = val;
                      if (val != null) {
                        final doc = _doctors.firstWhere(
                          (d) => d.doctorId == val,
                          orElse: () => _doctors.first,
                        );
                        _updateFees(doc: doc);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Patient-reported reason for visit (Optional)',
                    hintText: 'e.g. Mild fever since 2 days',
                    border: OutlineInputBorder(),
                    helperText:
                        'Isolated from ordinary financial exports and logs.',
                  ),
                ),
                const SizedBox(height: 14),

                // Triage & Queue Priority
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Triage & Queue Priority',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<QueuePriority>(
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: const [
                          ButtonSegment(
                            value: QueuePriority.normal,
                            label: Text('Normal (FIFO)'),
                            icon: Icon(Icons.person_outline, size: 16),
                          ),
                          ButtonSegment(
                            value: QueuePriority.urgent,
                            label: Text('Urgent'),
                            icon: Icon(Icons.warning_amber_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: QueuePriority.vip,
                            label: Text('Priority (Senior/Child)'),
                            icon: Icon(Icons.family_restroom, size: 16),
                          ),
                          ButtonSegment(
                            value: QueuePriority.emergency,
                            label: Text('Emergency'),
                            icon: Icon(Icons.emergency, size: 16),
                          ),
                        ],
                        selected: {_selectedPriority},
                        onSelectionChanged: (val) {
                          setState(() {
                            _selectedPriority = val.first;
                            _updateFees(priority: val.first);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // CONSULTATION FEE & BILLING SECTION
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.receipt_long,
                                  size: 18, color: Color(0xFF0F766E)),
                              SizedBox(width: 6),
                              Text(
                                'Consultation Fee & Billing',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              controller: _feeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                prefixText: 'Total: ₹ ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) {
                                final parsed = int.tryParse(val) ?? 0;
                                setState(() {
                                  _consultationFeeRupees = parsed;
                                  if (_partialPaidRupees > parsed) {
                                    _partialPaidRupees = parsed;
                                    _partialPaidController.text = '$parsed';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Live Fee Breakdown: Base Fee + Additional Surcharge = Total Fee
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: Color(0xFF475569)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _additionalFeeRupees > 0
                                    ? 'Base Fee: ₹$_baseFeeRupees  +  Additional/Emergency: ₹$_additionalFeeRupees  =  Total: ₹$_consultationFeeRupees'
                                    : 'Base Doctor Consultation Fee: ₹$_baseFeeRupees',
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
                      if (_feeCatalog.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedFeeCatalogId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText:
                                'Additional Service / Surcharge (Added to Base Fee)',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(),
                            helperText:
                                'Emergency charge or procedure added to consultation fee',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None (Base Consultation Only)'),
                            ),
                            ..._feeCatalog.where((f) => f.active).map((f) {
                              final scope = f.doctorIdOptional != null
                                  ? ' [Doc]'
                                  : (f.visitTypeOptional != null
                                      ? ' [${f.visitTypeOptional}]'
                                      : '');
                              return DropdownMenuItem<String?>(
                                value: f.feeId,
                                child: Text(
                                  '${f.feeName}$scope (+₹${f.defaultAmountMinor ~/ 100})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (catId) {
                            setState(() {
                              _updateFees(
                                additionalFeeId: catId,
                                autoSelectPriorityFee: false,
                              );
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Text(
                        'Payment Timing & Status:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Pay Later (At Checkout)'),
                            selected: _paymentOption == 'unpaid',
                            selectedColor: const Color(0xFFFEF3C7),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _paymentOption = 'unpaid');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: Text('Full Advance (₹$_consultationFeeRupees)'),
                            selected: _paymentOption == 'full',
                            selectedColor: const Color(0xFFCCFBF1),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _paymentOption = 'full');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Partial Advance'),
                            selected: _paymentOption == 'partial',
                            selectedColor: const Color(0xFFFFEDD5),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _paymentOption = 'partial';
                                  if (_partialPaidRupees == 0) {
                                    _partialPaidRupees =
                                        (_consultationFeeRupees / 2).round();
                                    _partialPaidController.text =
                                        '$_partialPaidRupees';
                                  }
                                });
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Free / Exempt'),
                            selected: _paymentOption == 'free',
                            selectedColor: const Color(0xFFE2E8F0),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _paymentOption = 'free');
                              }
                            },
                          ),
                        ],
                      ),
                      if (_paymentOption == 'partial') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _partialPaidController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Amount Paid Now',
                                  prefixText: '₹ ',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  final parsed = int.tryParse(val) ?? 0;
                                  setState(() => _partialPaidRupees = parsed);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.orange.shade300),
                              ),
                              child: Text(
                                'Due: ₹${(_consultationFeeRupees - _partialPaidRupees).clamp(0, _consultationFeeRupees)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_paymentOption == 'full' ||
                          _paymentOption == 'partial') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'Payment Tender: ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                ChoiceChip(
                                  label: const Text('Cash'),
                                  selected: _paymentMethod == 'cash',
                                  onSelected: (sel) {
                                    if (sel) {
                                      setState(() => _paymentMethod = 'cash');
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('UPI'),
                                  selected: _paymentMethod == 'upi',
                                  onSelected: (sel) {
                                    if (sel) {
                                      setState(() => _paymentMethod = 'upi');
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Card'),
                                  selected: _paymentMethod == 'card',
                                  onSelected: (sel) {
                                    if (sel) {
                                      setState(() => _paymentMethod = 'card');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      if (_paymentOption == 'unpaid') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text(
                            '₹$_consultationFeeRupees will remain pending as Unpaid in queue and financial ledger.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('CANCEL'),
                    ),
                    FilledButton.icon(
                      onPressed: (_isSubmitting || _activeVisit != null)
                          ? null
                          : _submitVisit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.confirmation_number),
                      label: Text(
                        _isSubmitting
                            ? 'ALLOCATING...'
                            : (_activeVisit != null
                                ? 'ALREADY IN QUEUE'
                                : (screenWidth < 400
                                    ? 'ISSUE TOKEN'
                                    : 'ISSUE TOKEN & QUEUE')),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _activeVisit != null
                            ? Colors.grey
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// POST-VISIT ALLOCATION CONFIRMATION DIALOG WITH PRINT SLIP & RECEIPT
class PostVisitConfirmationDialog extends ConsumerStatefulWidget {
  final Visit visit;
  final Invoice? invoice;
  final Doctor doctor;
  final Patient patient;
  final VoidCallback? onDone;

  const PostVisitConfirmationDialog({
    super.key,
    required this.visit,
    this.invoice,
    required this.doctor,
    required this.patient,
    this.onDone,
  });

  @override
  ConsumerState<PostVisitConfirmationDialog> createState() =>
      _PostVisitConfirmationDialogState();
}

class _PostVisitConfirmationDialogState
    extends ConsumerState<PostVisitConfirmationDialog> {
  bool _isPrintingSlip = false;
  bool _isPrintingReceipt = false;

  Future<void> _printSlip() async {
    if (_isPrintingSlip) return;
    setState(() => _isPrintingSlip = true);

    try {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);

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

      if (mounted) {
        try {
          await ConsultationSlipPreviewDialog.show(
            context: context,
            clinic: clinic,
            doctor: widget.doctor,
            patient: widget.patient,
            visit: widget.visit,
            patientReportedReasonForVisit: widget.visit.reasonForVisitEncryptedRef,
          );
        } catch (_) {
          // Direct print fallback if preview dialog module was dynamically added
          await ConsultationSlipService.printSlip(
            clinic: clinic,
            doctor: widget.doctor,
            patient: widget.patient,
            visit: widget.visit,
            paperSize: clinic.defaultPaperSize.isNotEmpty ? clinic.defaultPaperSize : 'A5',
          );
          final visitRepo = ref.read(visitRepositoryProvider);
          await visitRepo.incrementSlipPrintCount(
            clinicId: session.clinicId,
            visitId: widget.visit.visitId,
            paperSize: clinic.defaultPaperSize.isNotEmpty ? clinic.defaultPaperSize : 'A5',
            staffId: session.staffId,
            deviceId: session.deviceId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Consultation slip for Token #${widget.visit.tokenNumber} sent to printer.',
                ),
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open consultation slip: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrintingSlip = false);
      }
    }
  }

  Future<void> _printReceipt() async {
    if (_isPrintingReceipt || widget.invoice == null) return;
    setState(() => _isPrintingReceipt = true);

    try {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final billingRepo = ref.read(billingRepositoryProvider);

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

      final payments = await billingRepo.getPaymentsForInvoice(
        session.clinicId,
        widget.invoice!.invoiceId,
      );

      await ReceiptSlipService.printReceipt(
        clinic: clinic,
        invoice: widget.invoice!,
        patient: widget.patient,
        payments: payments,
        paperSize: clinic.defaultPaperSize,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receipt for ${widget.invoice!.invoiceNumber} sent to printer.',
            ),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print receipt: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrintingReceipt = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdInvoice = widget.invoice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFCCFBF1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.check, size: 36, color: Color(0xFF0F766E)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Token #${widget.visit.tokenNumber} Allocated!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.patient.fullName} added to waiting queue for Dr. ${widget.doctor.displayName}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Billing Status:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (createdInvoice == null)
                        const Text(
                          'Free / No Charge',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        )
                      else if (createdInvoice.status == InvoiceStatus.paid)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            'PAID (₹${createdInvoice.paidMinor ~/ 100})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        )
                      else if (createdInvoice.status ==
                          InvoiceStatus.partiallyPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Text(
                            'PARTIAL (Paid ₹${createdInvoice.paidMinor ~/ 100} • Due ₹${createdInvoice.balanceMinor ~/ 100})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            'UNPAID (Due ₹${createdInvoice.balanceMinor ~/ 100})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (createdInvoice != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Invoice Number:',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        Text(
                          createdInvoice.invoiceNumber,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isPrintingSlip ? null : _printSlip,
                    icon: _isPrintingSlip
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print, size: 16),
                    label: Text(
                      _isPrintingSlip ? 'PRINTING...' : 'PRINT SLIP',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  ),
                ),
                if (createdInvoice != null &&
                    createdInvoice.paidMinor > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPrintingReceipt ? null : _printReceipt,
                      icon: _isPrintingReceipt
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F766E),
                              ),
                            )
                          : const Icon(Icons.receipt, size: 16),
                      label: Text(
                        _isPrintingReceipt ? 'PRINTING...' : 'RECEIPT',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDone?.call();
              },
              child: const Text('DONE'),
            ),
          ],
        ),
      ),
    );
  }
}

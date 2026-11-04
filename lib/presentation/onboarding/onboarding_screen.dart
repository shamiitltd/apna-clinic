// Apna Clinic - Guided Clinic Onboarding & Setup Wizard
// Configures initial clinic profile, primary consulting doctor, default fees,
// slip paper format, and real test alignment printing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/printing/consultation_slip_service.dart';
import '../../application/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  bool _isSaving = false;
  bool _isPrinting = false;

  // Clinic profile controllers
  final _clinicNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Primary doctor controllers
  final _doctorNameController = TextEditingController();
  final _doctorQualificationController = TextEditingController();
  final _doctorRegNumberController = TextEditingController();
  final _doctorSpecialtyController = TextEditingController(text: 'General Physician');
  final _doctorPhoneController = TextEditingController();

  // Fee & slip configuration
  final _feeController = TextEditingController(text: '300');
  String _paperSize = AppConstants.paperSizeA5;

  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  @override
  void dispose() {
    _clinicNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _doctorNameController.dispose();
    _doctorQualificationController.dispose();
    _doctorRegNumberController.dispose();
    _doctorSpecialtyController.dispose();
    _doctorPhoneController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (!_formKeyStep0.currentState!.validate()) return;
      // Auto-populate doctor name from owner name if blank
      if (_doctorNameController.text.trim().isEmpty && _ownerNameController.text.trim().isNotEmpty) {
        _doctorNameController.text = _ownerNameController.text.trim();
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_formKeyStep1.currentState!.validate()) return;
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (!_formKeyStep2.currentState!.validate()) return;
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      _saveConfiguration();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _testPrintSampleSlip() async {
    setState(() => _isPrinting = true);

    final clinicName = _clinicNameController.text.trim().isNotEmpty
        ? _clinicNameController.text.trim()
        : 'APNA CLINIC';
    final doctorName = _doctorNameController.text.trim().isNotEmpty
        ? _doctorNameController.text.trim()
        : 'Consulting Doctor';
    final feeRupees = int.tryParse(_feeController.text.trim()) ?? 300;

    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final tempClinic = Clinic(
      clinicId: 'temp_sample_clinic',
      legalName: clinicName,
      displayName: clinicName,
      ownerName: _ownerNameController.text.trim().isNotEmpty
          ? _ownerNameController.text.trim()
          : doctorName,
      contactPhone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : '+919876543210',
      contactEmail: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : 'reception@apnaclinic.in',
      addressLine1: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : 'Main Road',
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : 'New Delhi',
      district: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : 'Central',
      state: _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : 'Delhi',
      pincode: _pincodeController.text.trim().isNotEmpty ? _pincodeController.text.trim() : '110001',
      defaultPaperSize: _paperSize,
      defaultConsultationFee: feeRupees * 100,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );

    final tempDoctor = Doctor(
      doctorId: 'temp_sample_doctor',
      clinicId: 'temp_sample_clinic',
      displayName: doctorName,
      qualificationText: _doctorQualificationController.text.trim().isNotEmpty
          ? _doctorQualificationController.text.trim()
          : 'MBBS, MD',
      registrationNumber: _doctorRegNumberController.text.trim().isNotEmpty
          ? _doctorRegNumberController.text.trim()
          : 'REG-12345',
      specialtyLabel: _doctorSpecialtyController.text.trim().isNotEmpty
          ? _doctorSpecialtyController.text.trim()
          : 'General Physician',
      contactPhone: _phoneController.text.trim(),
      active: true,
      defaultFee: feeRupees * 100,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );

    final samplePatient = Patient(
      patientId: 'sample_patient_test',
      clinicId: 'temp_sample_clinic',
      patientNumber: 'TEST-001',
      fullName: 'SAMPLE PATIENT (ALIGNMENT TEST)',
      phoneOptional: '+919999999999',
      ageIfDobUnknown: 32,
      sexOptional: 'Female',
      consentStatus: 'granted',
      consentVersion: 'v1.0',
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );

    final sampleVisit = Visit(
      visitId: 'sample_visit_test',
      clinicId: 'temp_sample_clinic',
      patientId: 'sample_patient_test',
      doctorId: 'temp_sample_doctor',
      visitDateLocal: todayStr,
      checkinAt: now.toUtc(),
      tokenNumber: 1,
      tokenScopeKey: 'test:1',
      visitType: 'walkin',
      queueStatus: QueueStatus.waiting,
      createdByStaffId: 'setup',
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );

    try {
      await ConsultationSlipService.printSlip(
        clinic: tempClinic,
        doctor: tempDoctor,
        patient: samplePatient,
        visit: sampleVisit,
        patientReportedReasonForVisit: 'Test alignment & print margins verification',
        paperSize: _paperSize,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Print preview error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _saveConfiguration() async {
    setState(() => _isSaving = true);

    try {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final billingRepo = ref.read(billingRepositoryProvider);

      final clinicName = _clinicNameController.text.trim();
      final ownerName = _ownerNameController.text.trim().isNotEmpty
          ? _ownerNameController.text.trim()
          : _doctorNameController.text.trim();
      final doctorName = _doctorNameController.text.trim();
      final feeRupees = int.tryParse(_feeController.text.trim()) ?? 300;
      final feePaise = feeRupees * 100;
      final now = DateTime.now().toUtc();

      final accessState = ref.read(appAccessProvider);
      final clinicId = accessState.firebaseUid != null && accessState.firebaseUid!.isNotEmpty
          ? 'clinic_${accessState.firebaseUid}'
          : (session.clinicId == 'clinic_primary_demo'
              ? 'clinic_${DateTime.now().millisecondsSinceEpoch}'
              : session.clinicId);
      final doctorId = 'doc_${clinicId}_01';

      final clinic = Clinic(
        clinicId: clinicId,
        legalName: clinicName,
        displayName: clinicName,
        ownerName: ownerName,
        contactPhone: _phoneController.text.trim(),
        contactEmail: _emailController.text.trim(),
        addressLine1: _addressController.text.trim(),
        city: _cityController.text.trim(),
        district: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        defaultPaperSize: _paperSize,
        defaultConsultationFee: feePaise,
        createdAt: now,
        updatedAt: now,
      );

      final doctor = Doctor(
        doctorId: doctorId,
        clinicId: clinicId,
        displayName: doctorName,
        qualificationText: _doctorQualificationController.text.trim(),
        registrationNumber: _doctorRegNumberController.text.trim(),
        specialtyLabel: _doctorSpecialtyController.text.trim().isNotEmpty
            ? _doctorSpecialtyController.text.trim()
            : 'General Physician',
        contactPhone: _doctorPhoneController.text.trim().isNotEmpty
            ? _doctorPhoneController.text.trim()
            : _phoneController.text.trim(),
        active: true,
        defaultFee: feePaise,
        createdAt: now,
        updatedAt: now,
      );

      final defaultFeeItem = FeeCatalog(
        feeId: 'fee_gen_consult_$clinicId',
        clinicId: clinicId,
        feeCode: 'CONSULT-GEN',
        feeName: 'General Consultation',
        defaultAmountMinor: feePaise,
        createdAt: now,
        updatedAt: now,
      );

      // Persist configuration
      await clinicRepo.saveClinic(clinic);
      await clinicRepo.saveDoctor(doctor);
      await billingRepo.saveFeeCatalogItem(defaultFeeItem);

      // Update active session
      ref.read(sessionProvider.notifier).setClinic(
        clinicId,
        'staff_admin',
        ownerName,
      );

      if (mounted) {
        ref.read(appAccessProvider.notifier).markClinicSetupCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade700,
            content: Text('Clinic "$clinicName" setup completed successfully!'),
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Failed to save configuration: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentRoute: '/onboarding',
      title: 'Clinic Setup Wizard',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12.0 : 24.0,
                vertical: 20.0,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 820),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isNarrow ? 16.0 : 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to Apna Clinic',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Initial setup wizard: configure your clinic, primary doctor, and print preferences.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 12),
                    Stepper(
                      physics: const NeverScrollableScrollPhysics(),
                      currentStep: _currentStep,
                      onStepContinue: _isSaving ? null : _onStepContinue,
                      onStepCancel: _isSaving ? null : _onStepCancel,
                      controlsBuilder: (context, details) {
                        final isLastStep = _currentStep == 3;
                        return Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Row(
                            children: [
                              FilledButton.icon(
                                onPressed: details.onStepContinue,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        isLastStep ? Icons.check_circle : Icons.arrow_forward,
                                        size: 18,
                                      ),
                                label: Text(
                                  _isSaving
                                      ? 'SAVING SETUP...'
                                      : (isLastStep
                                          ? 'COMPLETE CLINIC SETUP'
                                          : 'CONTINUE TO NEXT STEP'),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              if (_currentStep > 0) ...[
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: _isSaving ? null : details.onStepCancel,
                                  child: const Text('BACK'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      steps: [
                        // STEP 1: CLINIC PROFILE
                        Step(
                          title: const Text(
                            'Clinic Profile',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Name, address & contact information'),
                          isActive: _currentStep >= 0,
                          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                          content: Form(
                            key: _formKeyStep0,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _clinicNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Clinic Legal & Display Name *',
                                    hintText: 'e.g. LifeCare Clinic',
                                    prefixIcon: Icon(Icons.local_hospital_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter the clinic name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _ownerNameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Owner / Lead Doctor Name',
                                          hintText: 'e.g. Dr. Rajesh Sharma',
                                          prefixIcon: Icon(Icons.person_outline),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneController,
                                        decoration: const InputDecoration(
                                          labelText: 'Clinic Contact Phone *',
                                          hintText: 'e.g. +91 9876543210',
                                          prefixIcon: Icon(Icons.phone_outlined),
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.phone,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Please enter clinic contact phone';
                                          }
                                          if (val.trim().length < 8) {
                                            return 'Phone number too short';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Clinic Street Address *',
                                    hintText: 'e.g. 14, Main Road, Near Bus Stand',
                                    prefixIcon: Icon(Icons.location_on_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter the clinic address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _cityController,
                                        decoration: const InputDecoration(
                                          labelText: 'City *',
                                          hintText: 'e.g. New Delhi',
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _stateController,
                                        decoration: const InputDecoration(
                                          labelText: 'State *',
                                          hintText: 'e.g. Delhi',
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _pincodeController,
                                        decoration: const InputDecoration(
                                          labelText: 'Pincode *',
                                          hintText: 'e.g. 110001',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Clinic Email (Optional)',
                                    hintText: 'e.g. contact@lifecareclinic.in',
                                    prefixIcon: Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // STEP 2: PRIMARY DOCTOR
                        Step(
                          title: const Text(
                            'Primary Consulting Doctor',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Doctor details appearing on slips & receipts'),
                          isActive: _currentStep >= 1,
                          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                          content: Form(
                            key: _formKeyStep1,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _doctorNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Primary Doctor Name *',
                                    hintText: 'e.g. Dr. Rajesh Sharma',
                                    prefixIcon: Icon(Icons.medical_services_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter doctor name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _doctorQualificationController,
                                        decoration: const InputDecoration(
                                          labelText: 'Qualifications',
                                          hintText: 'e.g. MBBS, MD (General Medicine)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _doctorRegNumberController,
                                        decoration: const InputDecoration(
                                          labelText: 'Medical Registration No.',
                                          hintText: 'e.g. DMC-48291',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _doctorSpecialtyController,
                                        decoration: const InputDecoration(
                                          labelText: 'Department / Specialty',
                                          hintText: 'e.g. General Physician',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _doctorPhoneController,
                                        decoration: const InputDecoration(
                                          labelText: 'Doctor Phone (Optional)',
                                          hintText: 'e.g. +91 9876543220',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // STEP 3: FEES & SLIP FORMAT
                        Step(
                          title: const Text(
                            'Consultation & Print Format',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Default fee catalog and slip dimensions'),
                          isActive: _currentStep >= 2,
                          state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                          content: Form(
                            key: _formKeyStep2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _feeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Standard Consultation Fee (₹) *',
                                    hintText: 'e.g. 300',
                                    prefixText: '₹ ',
                                    prefixIcon: Icon(Icons.currency_rupee),
                                    helperText: 'Saved in integer paise (e.g. ₹300 = 30000 paise). Zero floating-point drift.',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter a consultation fee';
                                    }
                                    final n = int.tryParse(val.trim());
                                    if (n == null || n < 0) {
                                      return 'Fee must be a non-negative number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Default Consultation Slip & Receipt Paper Size:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(
                                        value: AppConstants.paperSizeA5,
                                        label: Text('A5 Portrait (Recommended for Clinic Slips)'),
                                        icon: Icon(Icons.receipt_outlined),
                                      ),
                                      ButtonSegment(
                                        value: AppConstants.paperSizeA4,
                                        label: Text('A4 Standard Letter Sheet'),
                                        icon: Icon(Icons.description_outlined),
                                      ),
                                    ],
                                    selected: {_paperSize},
                                    onSelectionChanged: (newSelection) {
                                      setState(() => _paperSize = newSelection.first);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // STEP 4: VERIFICATION & TEST PRINT
                        Step(
                          title: const Text(
                            'Alignment Verification & Launch',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Review setup and test print before opening'),
                          isActive: _currentStep >= 3,
                          state: StepState.indexed,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                elevation: 0,
                                color: const Color(0xFFF8FAFC),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.check_circle_outline, color: AppColors.primary, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Configuration Summary',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                                      Text(
                                        'Clinic: ${_clinicNameController.text.trim().isNotEmpty ? _clinicNameController.text.trim() : "Not specified"}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Address: ${_addressController.text.trim()}, ${_cityController.text.trim()} - ${_pincodeController.text.trim()}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Doctor: ${_doctorNameController.text.trim().isNotEmpty ? _doctorNameController.text.trim() : "Not specified"} (${_doctorQualificationController.text.trim().isNotEmpty ? _doctorQualificationController.text.trim() : "Consultant"})',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Default Fee: ₹${_feeController.text.trim()} • Slip Size: $_paperSize',
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _isPrinting ? null : _testPrintSampleSlip,
                                icon: _isPrinting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.print_outlined),
                                label: Text(
                                  _isPrinting
                                      ? 'GENERATING PREVIEW...'
                                      : 'Print Sample Consultation Slip (Test Alignment)',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Note: The test print renders a client-side vector PDF using your clinic header and doctor details. No patient records are stored.',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

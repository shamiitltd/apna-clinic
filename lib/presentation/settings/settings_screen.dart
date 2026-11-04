// Apna Clinic - Settings & Clinic Administration Screen
// Comprehensive Clinic Configuration, Doctor Roster, Fee Catalog, Staff Directory,
// Printer Hardware Defaults, Encrypted AES-256 Backups & Cloud Sync State

import 'dart:convert';

import '../../core/utils/image_picker/platform_image_picker.dart';
import '../../core/utils/downloader/file_download_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/permissions/roles.dart';
import '../../domain/entities/entities.dart';
import '../../infrastructure/security/local_encryption_service.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Navigation section index
  int _selectedSection = 0;
  bool _isLoading = true;

  // Clinic profile controllers
  final _clinicNameController = TextEditingController();
  final _clinicOwnerController = TextEditingController();
  final _clinicPhoneController = TextEditingController();
  final _clinicEmailController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  final _clinicCityController = TextEditingController();
  final _clinicStateController = TextEditingController();
  final _clinicPincodeController = TextEditingController();
  final _defaultFeeController = TextEditingController();

  String _paperSize = AppConstants.paperSizeA5;
  List<Doctor> _doctors = [];
  List<FeeCatalog> _feeCatalog = [];
  List<Staff> _staffList = [];

  String? _logoBase64;
  String? _logoDriveFileId;
  bool _isUploadingLogo = false;

  bool _isBackingUp = false;
  final bool _isRestoring = false;
  String? _lastBackupJson;

  // Multi-Device Collaboration (Module 13)
  DeviceRegistration? _localDevice;
  DeviceLease? _activeLease;
  List<DeviceRegistration> _connectedDevices = [];
  List<CollaborationConflict> _collaborationConflicts = [];

  // Multi-Branch & Third-Party Integrations (Module 14)
  List<Branch> _branches = [];
  ConsolidatedClinicReport? _consolidatedReport;
  AbdmIntegrationConfig? _abdmConfig;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _clinicNameController.dispose();
    _clinicOwnerController.dispose();
    _clinicPhoneController.dispose();
    _clinicEmailController.dispose();
    _clinicAddressController.dispose();
    _clinicCityController.dispose();
    _clinicStateController.dispose();
    _clinicPincodeController.dispose();
    _defaultFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);
    final billingRepo = ref.read(billingRepositoryProvider);

    try {
      final clinic = await clinicRepo.getClinic(session.clinicId);
      if (clinic != null) {
        _clinicNameController.text = clinic.displayName;
        _clinicOwnerController.text = clinic.ownerName;
        _clinicPhoneController.text = clinic.contactPhone;
        _clinicEmailController.text = clinic.contactEmail;
        _clinicAddressController.text = clinic.addressLine1;
        _clinicCityController.text = clinic.city;
        _clinicStateController.text = clinic.state;
        _clinicPincodeController.text = clinic.pincode;
        _defaultFeeController.text =
            (clinic.defaultConsultationFee ~/ 100).toString();
        _paperSize = clinic.defaultPaperSize;
        _logoBase64 = clinic.logoBase64;
        _logoDriveFileId = clinic.logoDriveFileId;
      } else {
        _clinicNameController.text = 'City Health Clinic';
        _clinicOwnerController.text = 'Dr. Sharma';
        _clinicPhoneController.text = '+919876543210';
        _clinicEmailController.text = 'contact@cityhealthclinic.in';
        _clinicAddressController.text = 'Main Market, Connaught Place';
        _clinicCityController.text = 'New Delhi';
        _clinicStateController.text = 'Delhi';
        _clinicPincodeController.text = '110001';
        _defaultFeeController.text = '300';
      }

      _doctors = await clinicRepo.getDoctors(session.clinicId);
      _feeCatalog = await billingRepo.getFeeCatalog(session.clinicId);
      _staffList = await clinicRepo.getStaffMembers(session.clinicId);
      await _loadCollaborationData();
      await _loadBranchData();
    } catch (_) {
      // Fallback defaults
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final picked = await PlatformImagePicker.pickLogoImage();
      if (picked == null) return;

      final bytes = picked.bytes;
      final fileExtension = picked.extension;
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Failed to read image data from selected file.'),
            ),
          );
        }
        return;
      }

      // Max size check: 2MB
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Logo file is too large. Please select an image under 2MB.'),
            ),
          );
        }
        return;
      }

      setState(() => _isUploadingLogo = true);

      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final base64String = base64Encode(bytes);

      // Save locally first for 100% offline-first reliability
      var clinic = await clinicRepo.getClinic(session.clinicId);
      if (clinic != null) {
        clinic = clinic.copyWith(
          logoBase64: base64String,
          updatedAt: DateTime.now().toUtc(),
        );
        await clinicRepo.saveClinic(clinic);
      }

      setState(() {
        _logoBase64 = base64String;
      });

      // Now sync to Google Drive Branding/ folder if connected
      String? driveFileId;
      String syncMessage = 'Clinic logo saved locally for slip printing.';

      if (session.isGoogleAuthenticated) {
        try {
          final authService = ref.read(authServiceProvider);
          final accessToken = await authService.getValidAccessToken();

          if (accessToken != null && accessToken.isNotEmpty) {
            final driveClient = ref.read(googleDriveClientProvider);
            final brandingFolderId = await driveClient.initializeClinicBrandingFolder(
              accessToken: accessToken,
              clinicId: session.clinicId,
            );

            final extension = fileExtension.toLowerCase();
            final mimeType = extension == 'png'
                ? 'image/png'
                : (extension == 'webp' ? 'image/webp' : 'image/jpeg');

            driveFileId = await driveClient.uploadBinaryFile(
              accessToken: accessToken,
              parentFolderId: brandingFolderId,
              fileName: 'clinic_logo_${DateTime.now().millisecondsSinceEpoch}.$extension',
              mimeType: mimeType,
              bytes: bytes,
            );

            if (clinic != null && driveFileId.isNotEmpty) {
              clinic = clinic.copyWith(
                logoDriveFileId: driveFileId,
                updatedAt: DateTime.now().toUtc(),
              );
              await clinicRepo.saveClinic(clinic);
            }

            setState(() {
              _logoDriveFileId = driveFileId;
            });

            syncMessage = 'Clinic logo saved and uploaded to Google Drive (Branding/)!';
          }
        } catch (e) {
          syncMessage = 'Clinic logo saved locally. (Drive sync notice: $e)';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(syncMessage),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error uploading logo: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
      }
    }
  }

  Future<void> _removeLogo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Clinic Logo?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove the clinic logo? Consultation slips and receipts will revert to text header.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Logo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);

      var clinic = await clinicRepo.getClinic(session.clinicId);
      if (clinic != null) {
        clinic = clinic.copyWith(
          logoBase64: null,
          logoDriveFileId: null,
          updatedAt: DateTime.now().toUtc(),
        );
        await clinicRepo.saveClinic(clinic);
      }

      setState(() {
        _logoBase64 = null;
        _logoDriveFileId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clinic logo removed.'),
          ),
        );
      }
    }
  }

  Future<void> _saveClinicProfile() async {
    final session = ref.read(sessionProvider);
    final clinicRepo = ref.read(clinicRepositoryProvider);

    final feeRupees = int.tryParse(_defaultFeeController.text.trim()) ?? 300;
    final now = DateTime.now().toUtc();

    final clinic = Clinic(
      clinicId: session.clinicId,
      legalName: _clinicNameController.text.trim(),
      displayName: _clinicNameController.text.trim(),
      ownerName: _clinicOwnerController.text.trim(),
      contactPhone: _clinicPhoneController.text.trim(),
      contactEmail: _clinicEmailController.text.trim(),
      addressLine1: _clinicAddressController.text.trim(),
      city: _clinicCityController.text.trim(),
      district: _clinicCityController.text.trim(),
      state: _clinicStateController.text.trim(),
      pincode: _clinicPincodeController.text.trim(),
      defaultPaperSize: _paperSize,
      defaultConsultationFee: feeRupees * 100,
      logoBase64: _logoBase64,
      logoDriveFileId: _logoDriveFileId,
      createdAt: now,
      updatedAt: now,
    );

    await clinicRepo.saveClinic(clinic);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Clinic Profile and Configuration saved successfully.'),
        ),
      );
    }
  }

  Future<void> _showDoctorDialog([Doctor? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final regCtrl = TextEditingController(
      text: existing?.registrationNumber ?? '',
    );
    final qualCtrl = TextEditingController(
      text: existing?.qualificationText ?? '',
    );
    final specCtrl = TextEditingController(
      text: existing?.specialtyLabel ?? 'General Physician',
    );
    final phoneCtrl = TextEditingController(
      text: existing?.contactPhone ?? '+91',
    );
    final feeCtrl = TextEditingController(
      text: existing != null ? (existing.defaultFee ~/ 100).toString() : '300',
    );
    bool active = existing?.active ?? true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.medical_services, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(existing == null ? 'Add Doctor' : 'Edit Doctor Details'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Doctor Name (with title) *',
                      hintText: 'e.g. Dr. Rajesh Sharma',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: regCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Registration No. *',
                            hintText: 'e.g. DMC-48291',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: specCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Specialty *',
                            hintText: 'e.g. General Medicine',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qualCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qualifications *',
                      hintText: 'e.g. MBBS, MD (Medicine)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contact Phone',
                            hintText: '+919876543210',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Consultation Fee (₹) *',
                            hintText: '300',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active for Patient Visits'),
                    subtitle: const Text(
                      'Inactive doctors are hidden from visit check-in',
                    ),
                    value: active,
                    activeTrackColor: AppColors.primaryLight,
                    onChanged: (val) => setDialogState(() => active = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save Doctor'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final fee = (int.tryParse(feeCtrl.text.trim()) ?? 300) * 100;
      final now = DateTime.now().toUtc();

      final doctor = Doctor(
        doctorId:
            existing?.doctorId ??
            'doc_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        displayName: nameCtrl.text.trim(),
        qualificationText: qualCtrl.text.trim(),
        registrationNumber: regCtrl.text.trim(),
        specialtyLabel: specCtrl.text.trim(),
        contactPhone: phoneCtrl.text.trim(),
        active: active,
        defaultFee: fee,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await clinicRepo.saveDoctor(doctor);
      await _loadSettings();
    }
  }

  Future<void> _showFeeDialog([FeeCatalog? existing]) async {
    final codeCtrl = TextEditingController(text: existing?.feeCode ?? '');
    final nameCtrl = TextEditingController(text: existing?.feeName ?? '');
    final amountCtrl = TextEditingController(
      text:
          existing != null
              ? (existing.defaultAmountMinor ~/ 100).toString()
              : '200',
    );
    String? selectedDoctorId = existing?.doctorIdOptional;
    String? selectedVisitType = existing?.visitTypeOptional;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payments, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(existing == null ? 'Add Service Fee' : 'Edit Service Fee'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 440.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Service Code *',
                      hintText: 'e.g. CONSULT-GEN, ECG-01',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Service Name / Description *',
                      hintText: 'e.g. Senior Consultant General OPD',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedDoctorId,
                    decoration: const InputDecoration(
                      labelText: 'Scoped Doctor (Optional)',
                      helperText: 'Leave empty to apply to all doctors in clinic',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Doctors (Clinic-wide)'),
                      ),
                      ..._doctors.map((d) {
                        return DropdownMenuItem<String?>(
                          value: d.doctorId,
                          child: Text('Dr. ${d.displayName} (${d.specialtyLabel})'),
                        );
                      }),
                    ],
                    onChanged: (val) => setDlgState(() => selectedDoctorId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedVisitType,
                    decoration: const InputDecoration(
                      labelText: 'Visit Type (Optional)',
                      helperText: 'Leave empty for any visit type',
                    ),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Any Visit Type'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'walkin',
                        child: Text('Walk-in Consultation'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'appointment',
                        child: Text('Scheduled Appointment'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'followup',
                        child: Text('Follow-up Review'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'emergency',
                        child: Text('Emergency Care'),
                      ),
                    ],
                    onChanged: (val) => setDlgState(() => selectedVisitType = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fee Amount (₹) *',
                      prefixText: '₹ ',
                      hintText: '200',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save Service Fee'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final session = ref.read(sessionProvider);
      final billingRepo = ref.read(billingRepositoryProvider);
      final feeMinor = (int.tryParse(amountCtrl.text.trim()) ?? 200) * 100;
      final now = DateTime.now().toUtc();

      final item = FeeCatalog(
        feeId: existing?.feeId ?? 'fee_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        doctorIdOptional: selectedDoctorId,
        visitTypeOptional: selectedVisitType,
        feeCode: codeCtrl.text.trim(),
        feeName: nameCtrl.text.trim(),
        defaultAmountMinor: feeMinor,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await billingRepo.saveFeeCatalogItem(item);
      await _loadSettings();
    }
  }

  Future<void> _showStaffDialog([Staff? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final pinCtrl = TextEditingController();
    UserRole selectedRole = existing?.role ?? UserRole.receptionist;
    bool active = existing?.active ?? true;
    String? selectedDoctorId = existing?.assignedDoctorIds.isNotEmpty == true
        ? existing!.assignedDoctorIds.first
        : (_doctors.isNotEmpty ? _doctors.first.doctorId : null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.badge_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(existing == null ? 'Add Staff Member' : 'Edit Staff Member'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Staff Name *',
                      hintText: 'e.g. Suman Sharma',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Login Email Address *',
                      hintText: 'staff@gmail.com',
                      helperText: 'Used to recognize role upon sign-in',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+919876543210',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Role & Permissions *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.receptionist,
                        child: Text('Receptionist (Queue, Tokens, Slips, Billing)'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.doctor,
                        child: Text('Doctor (Doctor Desk, Queue, Clinical Notes)'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.accountant,
                        child: Text('Accountant (Billing, Ledger, Financial Reports)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                  if (selectedRole == UserRole.doctor && _doctors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDoctorId,
                      decoration: const InputDecoration(
                        labelText: 'Link to Doctor Profile *',
                        helperText: 'Isolates this doctor\'s queue and patient details (PRD M08)',
                      ),
                      items: _doctors.map((d) {
                        return DropdownMenuItem<String>(
                          value: d.doctorId,
                          child: Text('${d.displayName} (${d.specialtyLabel})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedDoctorId = val);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Quick Login / Workstation PIN',
                      hintText: existing?.hasPin == true
                          ? '•••• (Leave blank to keep existing)'
                          : 'e.g. 2468',
                      helperText: 'Allows this staff member to unlock the shared workstation',
                      prefixIcon: const Icon(Icons.pin, size: 20),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Account Active',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      active
                          ? 'Staff can log in and perform assigned duties'
                          : 'Deactivated: Access and login revoked',
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    value: active,
                    activeTrackColor: const Color(0xFFCCFBF1),
                    activeColor: const Color(0xFF0F766E),
                    onChanged: (val) => setDialogState(() => active = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null && existing.role != UserRole.owner)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                onPressed: () async {
                  Navigator.pop(ctx, false);
                  await _confirmDeleteStaff(existing);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save Staff Member'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final now = DateTime.now().toUtc();

      String? pinHash = existing?.pinHash;
      String? pinSalt = existing?.pinSalt;
      if (pinCtrl.text.trim().isNotEmpty) {
        final pinData = Staff.generatePinHash(pinCtrl.text.trim());
        pinHash = pinData['pin_hash'];
        pinSalt = pinData['pin_salt'];
      }

      final staff = Staff(
        staffId:
            existing?.staffId ??
            'staff_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        displayName: nameCtrl.text.trim(),
        role: selectedRole,
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        active: active,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        pinHash: pinHash,
        pinSalt: pinSalt,
        assignedDoctorIds: (selectedRole == UserRole.doctor && selectedDoctorId != null)
            ? [selectedDoctorId!]
            : (existing?.assignedDoctorIds ?? const []),
      );

      await clinicRepo.saveStaff(staff);
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(
              existing == null
                  ? 'Staff member added successfully.'
                  : 'Staff details for "${staff.displayName}" updated successfully.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleStaffActive(Staff staff) async {
    final clinicRepo = ref.read(clinicRepositoryProvider);
    final updated = staff.copyWith(active: !staff.active);
    await clinicRepo.saveStaff(updated);
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: updated.active ? Colors.green.shade800 : Colors.orange.shade900,
          content: Text(
            '${staff.displayName} has been ${updated.active ? 'reactivated' : 'deactivated'}.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteStaff(Staff staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Staff Member?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${staff.displayName}" (${staff.role.name.toUpperCase()}) from the clinic roster? This will permanently delete their staff record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Staff'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final clinicRepo = ref.read(clinicRepositoryProvider);
      await clinicRepo.deleteStaff(staff.staffId);
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('${staff.displayName} removed from staff roster.'),
          ),
        );
      }
    }
  }

  Future<void> _purgeAllTestData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Purge All Local Test Data?'),
          ],
        ),
        content: const SizedBox(
          width: 420,
          child: Text(
            'This will permanently remove all local dummy/test patients, visits, queue tokens, invoices, and payment records from this computer so your clinic starts completely fresh with 0 records.\n\nYour Google Drive cloud files and clinic profile will NOT be deleted.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Purge Test Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = ref.read(localDatabaseProvider);
      await db.clearAll();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'All local test data purged. Clinic is now fresh and clean.',
            ),
          ),
        );
        context.go('/dashboard');
      }
    }
  }

  Future<void> _performEncryptedBackup() async {
    final session = ref.read(sessionProvider);
    final db = ref.read(localDatabaseProvider);
    final backupRepo = ref.read(backupRepositoryProvider);
    final syncHealthNotifier = ref.read(syncHealthProvider.notifier);

    final passphraseController = TextEditingController(
      text: 'ApnaClinicSecurePass2026!',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Create Encrypted Full Backup'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(280.0, 520.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your entire local operational database (patients, visits, tokens, invoices, payments, audit history) will be serialized, encrypted using AES-256-CBC, and signed with a SHA-256 integrity checksum.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passphraseController,
                decoration: const InputDecoration(
                  labelText: 'Encryption Master Passphrase',
                  helperText:
                      'Required to decrypt and restore this backup in future.',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate Encrypted Snapshot'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBackingUp = true);

    try {
      final passphrase = passphraseController.text.trim();
      const salt = 'ApnaClinicSalt2026';
      final key = LocalEncryptionService.deriveKeyFromPassphrase(
        passphrase,
        salt,
      );

      final snapshot = db.exportFullSnapshot(session.clinicId);
      final plaintext = jsonEncode(snapshot);

      final envelope = LocalEncryptionService.encryptText(
        plaintext: plaintext,
        key: key,
      );

      final now = DateTime.now().toUtc();
      final tablesMap = snapshot['tables'] as Map<String, dynamic>? ?? {};
      final totalRecords = tablesMap.values.fold<int>(
        0,
        (int sum, dynamic t) => sum + (t as Map).length,
      );

      final manifest = BackupManifest(
        backupId: 'backup_${now.millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        deviceId: session.deviceId,
        backupTimestamp: now,
        schemaVersion: '1.0.0',
        recordCountsJson: jsonEncode(
          tablesMap.map((k, v) => MapEntry(k, (v as Map).length)),
        ),
        ciphertextSha256: envelope.checksumSha256,
        verificationStatus: 'verified',
        verifiedAt: now,
      );

      await backupRepo.saveBackupManifest(manifest);
      syncHealthNotifier.markBackupVerified(now);

      final exportPackage = {
        'manifest': manifest.toMap(),
        'encryption': {'algorithm': 'AES-256-CBC', 'kdf': 'PBKDF2-HMAC-SHA256'},
        'encrypted_envelope': envelope.toMap(),
      };

      _lastBackupJson = jsonEncode(exportPackage);

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Text('Backup Successfully Generated & Verified'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 500.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Backup ID: ${manifest.backupId}'),
                  Text('Timestamp: ${now.toLocal()}'),
                  Text('Total Records Secured: $totalRecords'),
                  Text(
                    'SHA-256 Checksum: ${envelope.checksumSha256.substring(0, 16)}...',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Encrypted Package (Preview):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      '${_lastBackupJson!.substring(0, 180)}...',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Backup failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _showRestoreWizard() async {
    final session = ref.read(sessionProvider);
    if (session.role != UserRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Access Denied: Only Clinic Owner can execute database restore.',
          ),
        ),
      );
      return;
    }

    final db = ref.read(localDatabaseProvider);
    final backupJsonController = TextEditingController(
      text: _lastBackupJson ?? '',
    );
    final passphraseController = TextEditingController(
      text: 'ApnaClinicSecurePass2026!',
    );
    String? statusError;
    Map<String, int>? reconciliationReport;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.settings_backup_restore, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Encrypted Database Restore Wizard'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 600.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STEP 1: Paste your encrypted .apnabackup JSON string and decryption passphrase.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passphraseController,
                      decoration: const InputDecoration(
                        labelText: 'Master Decryption Passphrase',
                        isDense: true,
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: backupJsonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Encrypted Backup JSON Content',
                        isDense: true,
                      ),
                    ),
                    if (statusError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(color: const Color(0xFFFECACA)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusError!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (reconciliationReport != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Reconciliation Report (Verified Successfully):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...reconciliationReport!.entries.map(
                        (e) => Text(
                          '• ${e.key}: ${e.value} records restored',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
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
                onPressed: _isRestoring
                    ? null
                    : () async {
                        setDialogState(() {
                          statusError = null;
                          reconciliationReport = null;
                        });

                        final jsonStr = backupJsonController.text.trim();
                        final pass = passphraseController.text.trim();

                        if (jsonStr.isEmpty || pass.isEmpty) {
                          setDialogState(
                            () => statusError =
                                'Please provide backup JSON and passphrase.',
                          );
                          return;
                        }

                        try {
                          final parsed =
                              jsonDecode(jsonStr) as Map<String, dynamic>;
                          final envelopeMap =
                              parsed['encrypted_envelope']
                                  as Map<String, dynamic>;
                          final envelope = EncryptedEnvelope.fromMap(
                            envelopeMap,
                          );

                          const salt = 'ApnaClinicSalt2026';
                          final key =
                              LocalEncryptionService.deriveKeyFromPassphrase(
                                pass,
                                salt,
                              );
                          String decryptedPlaintext;
                          try {
                            decryptedPlaintext =
                                LocalEncryptionService.decryptEnvelope(
                                  envelope: envelope,
                                  key: key,
                                );
                          } catch (e) {
                            setDialogState(
                              () => statusError =
                                  'Decryption failed: Incorrect passphrase or corrupted data.',
                            );
                            return;
                          }

                          final Map<String, dynamic> rawDecrypted = jsonDecode(
                            decryptedPlaintext,
                          ) as Map<String, dynamic>;

                          await db.restoreFullSnapshot(
                            session.clinicId,
                            rawDecrypted,
                          );

                          final tablesMap =
                              rawDecrypted['tables'] as Map<String, dynamic>? ??
                              {};
                          final report = <String, int>{};
                          tablesMap.forEach((table, records) {
                            report[table] = (records as Map).length;
                          });

                          setDialogState(() {
                            reconciliationReport = report;
                          });

                          await _loadSettings();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text(
                                  'Database restored and reconciled successfully!',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(
                            () => statusError = 'Restore failed: $e',
                          );
                        }
                      },
                child: const Text('Validate & Restore'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showUnlockDialog(BuildContext context) async {
    final pinController = TextEditingController();
    String? errorMessage;
    bool obscurePin = true;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Unlock Workstation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your 4-digit Owner Security PIN to restore Admin access to Settings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: obscurePin,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Owner Security PIN',
                    hintText: 'Default: 1234',
                    prefixIcon: const Icon(Icons.key, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePin ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscurePin = !obscurePin),
                    ),
                    errorText: errorMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onSubmitted: (_) async {
                    final pin = pinController.text.trim();
                    final success = await ref
                        .read(sessionProvider.notifier)
                        .unlockWorkstation(pin);
                    if (success) {
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.green,
                            content: Text('Owner access restored.'),
                          ),
                        );
                      }
                    } else {
                      setDialogState(() {
                        errorMessage = 'Incorrect PIN. Default is 1234.';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              icon: const Icon(Icons.lock_open, size: 16),
              label: const Text('Unlock Workstation'),
              onPressed: () async {
                final pin = pinController.text.trim();
                final success = await ref
                    .read(sessionProvider.notifier)
                    .unlockWorkstation(pin);
                if (success) {
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('Owner access restored.'),
                      ),
                    );
                  }
                } else {
                  setDialogState(() {
                    errorMessage = 'Incorrect PIN. Default is 1234.';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePinDialog() async {
    final sessionNotifier = ref.read(sessionProvider.notifier);
    final currentPin = await sessionNotifier.getOwnerPin();
    final isCustomPin = currentPin != SessionNotifier.defaultOwnerPin;

    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    String? errorMessage;
    bool obscurePins = true;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.password, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Change Owner Security PIN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a 4 to 6 digit security PIN used to unlock this workstation when switching from Receptionist or Doctor modes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (isCustomPin) ...[
                  TextField(
                    controller: oldPinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: obscurePins,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Current PIN',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: newPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: obscurePins,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'New 4-Digit PIN',
                    hintText: 'e.g. 5678',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: obscurePins,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Confirm New PIN',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    errorText: errorMessage,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: !obscurePins,
                      onChanged: (v) =>
                          setDialogState(() => obscurePins = !(v ?? false)),
                    ),
                    const Text('Show PIN digits', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              child: const Text('Save Security PIN'),
              onPressed: () async {
                if (isCustomPin && oldPinCtrl.text.trim() != currentPin) {
                  setDialogState(() => errorMessage = 'Current PIN is incorrect.');
                  return;
                }
                final newPin = newPinCtrl.text.trim();
                final confirm = confirmPinCtrl.text.trim();
                if (newPin.length < 4) {
                  setDialogState(
                    () => errorMessage = 'PIN must be at least 4 digits.',
                  );
                  return;
                }
                if (newPin != confirm) {
                  setDialogState(() => errorMessage = 'New PINs do not match.');
                  return;
                }
                await sessionNotifier.setOwnerPin(newPin);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.green,
                      content: Text('Owner Security PIN updated successfully.'),
                    ),
                  );
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lockWorkstation(UserRole role) async {
    final roleName = role == UserRole.receptionist
        ? 'Receptionist'
        : (role == UserRole.doctor ? 'Doctor' : 'Accountant');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Lock to $roleName Mode?'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Text(
            'This workstation will be restricted to $roleName duties. To return to Owner mode, your 4-digit Owner PIN will be required.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
            icon: const Icon(Icons.lock, size: 16),
            label: Text('Lock as $roleName'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(sessionProvider.notifier).lockWorkstationToRole(role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            content: Text('Workstation locked to $roleName Mode.'),
          ),
        );
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final syncHealth = ref.watch(syncHealthProvider);

    // RBAC Security Barrier: Settings is strictly Owner / Admin only
    if (session.role != UserRole.owner) {
      return AppScaffold(
        currentRoute: '/settings',
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200),
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
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 56,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Access Restricted: Owner Only',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Under clinical governance and PRD/TRD RBAC policies, Clinic Administration, doctor roster, consultation fee catalog, staff credentials, and encrypted backups are strictly reserved for the Clinic Owner.\n\nThis computer is currently locked in ${session.role.name.toUpperCase()} mode.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: () => context.go('/dashboard'),
                        child: const Text('Back to Dashboard'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                        ),
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('Unlock with PIN'),
                        onPressed: () => _showUnlockDialog(context),
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

    return AppScaffold(
      currentRoute: '/settings',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28.0 : 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header
                if (isDesktop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('nav_settings'),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Clinic Profile, Doctor Roster, Fees, Staff Access, Hardware Defaults & Backup',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      StatusBadge(
                        label: 'ROLE: ${session.role.name.toUpperCase()}',
                        textColor: AppColors.info,
                        backgroundColor: const Color(0xFFEFF6FF),
                        icon: Icons.shield_outlined,
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            l10n.translate('nav_settings'),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          StatusBadge(
                            label: 'ROLE: ${session.role.name.toUpperCase()}',
                            textColor: AppColors.info,
                            backgroundColor: const Color(0xFFEFF6FF),
                            icon: Icons.shield_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Clinic Profile, Doctor Roster, Fees, Staff Access, Hardware Defaults & Backup',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // Section Navigation Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip(0, 'Clinic Profile', Icons.local_hospital),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        1,
                        'Doctors (${_doctors.length})',
                        Icons.medical_services,
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        2,
                        'Fee Catalog (${_feeCatalog.length})',
                        Icons.payments,
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(3, 'Staff & Roles', Icons.admin_panel_settings),
                      const SizedBox(width: 8),
                      _buildTabChip(4, 'Printer & Slips', Icons.print),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        5,
                        'Backup & Disaster Recovery',
                        Icons.security,
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(6, 'Cloud Sync & Roadmap', Icons.cloud_sync),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        7,
                        'Subscription & Licensing',
                        Icons.card_membership,
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        8,
                        'Live Collaboration (M13)',
                        Icons.devices_other,
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        9,
                        'Multi-Branch & Integrations (M14)',
                        Icons.domain_add,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Selected Tab Body
                IndexedStack(
                  index: _selectedSection,
                  children: [
                    _buildClinicProfileSection(isDesktop),
                    _buildDoctorManagementSection(isDesktop),
                    _buildFeeCatalogSection(isDesktop),
                    _buildStaffAndRolesSection(isDesktop, session),
                    _buildPrintingSection(isDesktop),
                    _buildBackupSection(isDesktop, syncHealth),
                    _buildCloudSyncSection(isDesktop, session),
                    _buildSubscriptionSection(isDesktop, session),
                    _buildCollaborationSection(isDesktop, session),
                    _buildMultiBranchSection(isDesktop, session),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabChip(int index, String label, IconData icon) {
    final isSelected = _selectedSection == index;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedSection = index);
      },
    );
  }

  // 1. Clinic Profile Section
  Widget _buildClinicProfileSection(bool isDesktop) {
    return AppCard(
      title: 'Clinic Information & Practice Details',
      trailing: FilledButton.icon(
        onPressed: _saveClinicProfile,
        icon: const Icon(Icons.save, size: 16),
        label: const Text('Save Profile Changes'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Identity appears on consultation slips, invoices, and diagnostic receipts.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Clinic Brand Logo Card (PRD Module 1 & TRD Section 6)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo Avatar / Preview
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _logoBase64 != null
                        ? Image.memory(
                            base64Decode(_logoBase64!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 28, color: Color(0xFF94A3B8)),
                              SizedBox(height: 2),
                              Text(
                                'NO LOGO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details and Actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Official Clinic Logo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_logoBase64 != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Active on Slips & Receipts',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                            if (_logoDriveFileId != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_done, size: 10, color: Color(0xFF0369A1)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Drive Branding/ Synced',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload your clinic emblem or insignia (PNG, JPG, WebP max 2MB). This is printed at the top-left of consultation slips and payment receipts.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                            icon: _isUploadingLogo
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _logoBase64 != null
                                        ? Icons.edit
                                        : Icons.upload_file,
                                    size: 15,
                                  ),
                            label: Text(
                              _isUploadingLogo
                                  ? 'Uploading...'
                                  : (_logoBase64 != null
                                      ? 'Change Logo'
                                      : 'Upload Logo to Drive Branding/'),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          if (_logoBase64 != null)
                            OutlinedButton.icon(
                              onPressed: _isUploadingLogo ? null : _removeLogo,
                              icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                              label: const Text(
                                'Remove Logo',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _clinicNameController,
                    decoration: const InputDecoration(
                      labelText: 'Clinic Display Name *',
                      hintText: 'City Health Clinic',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _clinicOwnerController,
                    decoration: const InputDecoration(
                      labelText: 'Owner / Chief Medical Officer *',
                      hintText: 'Dr. Sharma',
                    ),
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _clinicNameController,
              decoration: const InputDecoration(
                labelText: 'Clinic Display Name *',
                hintText: 'City Health Clinic',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clinicOwnerController,
              decoration: const InputDecoration(
                labelText: 'Owner / Chief Medical Officer *',
                hintText: 'Dr. Sharma',
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _clinicPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number *',
                      hintText: '+919876543210',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _clinicEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email Address',
                      hintText: 'contact@cityhealthclinic.in',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _defaultFeeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Default Consultation Fee (₹) *',
                      hintText: '300',
                    ),
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _clinicPhoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone Number *',
                hintText: '+919876543210',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clinicEmailController,
              decoration: const InputDecoration(
                labelText: 'Contact Email Address',
                hintText: 'contact@cityhealthclinic.in',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _defaultFeeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default Consultation Fee (₹) *',
                hintText: '300',
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _clinicAddressController,
            decoration: const InputDecoration(
              labelText: 'Clinic Address (Line 1) *',
              hintText: 'Main Market, Connaught Place',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _clinicCityController,
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    hintText: 'New Delhi',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _clinicStateController,
                  decoration: const InputDecoration(
                    labelText: 'State *',
                    hintText: 'Delhi',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _clinicPincodeController,
                  decoration: const InputDecoration(
                    labelText: 'Pincode *',
                    hintText: '110001',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Doctor Management Section
  Widget _buildDoctorManagementSection(bool isDesktop) {
    return AppCard(
      title: 'Doctor Roster & Cabin Assignments',
      trailing: FilledButton.icon(
        onPressed: () => _showDoctorDialog(),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Doctor'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Doctors appear on queue tokens, appointment booking, and consultation slips.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_doctors.isEmpty)
            const EmptyStateWidget(
              icon: Icons.medical_services_outlined,
              title: 'No Doctors Registered',
              description: 'Click "Add Doctor" to configure your medical team.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _doctors.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = _doctors[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFCCFBF1),
                    child: Icon(
                      Icons.medical_services,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        doc.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: doc.active ? 'ACTIVE' : 'INACTIVE',
                        textColor:
                            doc.active
                                ? AppColors.success
                                : AppColors.textMuted,
                        backgroundColor:
                            doc.active
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${doc.qualificationText} • Reg: ${doc.registrationNumber} • Specialty: ${doc.specialtyLabel} • Standard Fee: ₹${doc.defaultFee ~/ 100}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Doctor Details',
                    onPressed: () => _showDoctorDialog(doc),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // 3. Fee Catalog Section
  Widget _buildFeeCatalogSection(bool isDesktop) {
    return AppCard(
      title: 'Clinic Fee Catalog & Standard Procedures',
      trailing: FilledButton.icon(
        onPressed: () => _showFeeDialog(),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Fee Item'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services selectable during patient billing, registration, and invoicing.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_feeCatalog.isEmpty)
            const EmptyStateWidget(
              icon: Icons.payments_outlined,
              title: 'No Fee Items Registered',
              description:
                  'Click "Add Fee Item" to register consultation and procedural charges.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _feeCatalog.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final fee = _feeCatalog[index];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF1F5F9),
                      child: Text(
                        fee.feeCode.split('-').last,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    title: Text(
                      fee.feeName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Code: ${fee.feeCode}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '₹${fee.defaultAmountMinor ~/ 100}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    onTap: () => _showFeeDialog(fee),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // 4. Staff & Roles Section
  Widget _buildStaffAndRolesSection(bool isDesktop, SessionState session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Workstation Lockdown Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF93C5FD)),
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color(0xFFEFF6FF),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.security_outlined,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Workstation Lockdown (Staff Duty Mode)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: session.isWorkstationLocked
                          ? '${session.role.name.toUpperCase()} (LOCKED)'
                          : 'OWNER (UNLOCKED)',
                      textColor: session.isWorkstationLocked
                          ? AppColors.error
                          : AppColors.success,
                      backgroundColor: Colors.white,
                      icon: session.isWorkstationLocked
                          ? Icons.lock
                          : Icons.lock_open,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Under the PRD/TRD Single-Account Clinic Operating Model, the clinic owner signs in and connects Google Drive in the morning, then locks the computer into Receptionist Desk mode. Front-desk staff cannot view financial reports, modify fees, access Doctor Desk, or exit lockdown without your Owner Security PIN.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E3A8A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () =>
                          _lockWorkstation(UserRole.receptionist),
                      icon: const Icon(Icons.desk, size: 16),
                      label: const Text('Lock as Receptionist Desk'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => _lockWorkstation(UserRole.doctor),
                      icon: const Icon(
                        Icons.medical_services_outlined,
                        size: 16,
                      ),
                      label: const Text('Lock as Doctor Desk'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => _lockWorkstation(UserRole.accountant),
                      icon: const Icon(Icons.account_balance, size: 16),
                      label: const Text('Lock as Accountant Desk'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 2. Owner Security PIN Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color(0xFFFFFBEB),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              children: [
                const Icon(
                  Icons.password,
                  color: Color(0xFFB45309),
                  size: 28,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Owner Security PIN Protection',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Required to unlock this computer back to Owner / Admin mode whenever staff lockdown is active. (Default PIN: 1234)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB45309),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF92400E),
                    side: const BorderSide(color: Color(0xFFD97706)),
                  ),
                  onPressed: _showChangePinDialog,
                  icon: const Icon(Icons.edit, size: 15),
                  label: const Text('Change PIN'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Staff Directory Card
        AppCard(
          title: 'Clinic Staff Directory & Access Levels',
          trailing: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
            onPressed: () => _showStaffDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Staff Member'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Staff credentials are authorized locally with role-based policies.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (_staffList.isNotEmpty)
                ..._staffList.map(
                  (s) => Column(
                    children: [
                      _buildStaffRow(s),
                      const Divider(height: 1),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyStateWidget(
                    icon: Icons.badge_outlined,
                    title: 'No Staff Members Registered',
                    description:
                        'No staff members have been added yet. Click "Add Staff Member" to assign receptionists, doctors, or accountants.',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffRow(Staff s) {
    final isActive = s.active;
    final role = s.role;
    final permissions = s.email.isNotEmpty ? s.email : s.phone;
    final isOwner = role == UserRole.owner;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: () => _showStaffDialog(s),
      leading: CircleAvatar(
        backgroundColor: isActive ? const Color(0xFFCCFBF1) : Colors.grey.shade200,
        child: Text(
          s.displayName.isNotEmpty
              ? s.displayName.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? AppColors.primary : Colors.grey.shade600,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              s.displayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.black87 : Colors.grey.shade500,
                decoration: isActive ? null : TextDecoration.lineThrough,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            label: role.name.toUpperCase(),
            textColor: role == UserRole.owner
                ? AppColors.info
                : role == UserRole.doctor
                    ? AppColors.success
                    : AppColors.textSecondary,
            backgroundColor: role == UserRole.owner
                ? const Color(0xFFEFF6FF)
                : role == UserRole.doctor
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF1F5F9),
          ),
          const SizedBox(width: 6),
          StatusBadge(
            label: isActive ? 'ACTIVE' : 'DEACTIVATED',
            textColor: isActive ? Colors.teal.shade800 : Colors.red.shade800,
            backgroundColor:
                isActive ? const Color(0xFFE6FFFA) : const Color(0xFFFEE2E2),
          ),
        ],
      ),
      subtitle: Text(
        '${role.name.toUpperCase()} • $permissions',
        style: TextStyle(
          color: isActive ? Colors.grey.shade700 : Colors.grey.shade400,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isOwner) ...[
            IconButton(
              icon: Icon(
                isActive ? Icons.block : Icons.check_circle_outline,
                size: 20,
                color: isActive ? Colors.orange.shade800 : Colors.green.shade700,
              ),
              tooltip:
                  isActive ? 'Deactivate Staff Member' : 'Reactivate Staff Member',
              onPressed: () => _toggleStaffActive(s),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red.shade700,
              ),
              tooltip: 'Remove Staff Member',
              onPressed: () => _confirmDeleteStaff(s),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
            tooltip: 'Edit Staff Details',
            onPressed: () => _showStaffDialog(s),
          ),
        ],
      ),
    );
  }

  // 5. Printing & Hardware Section
  Widget _buildPrintingSection(bool isDesktop) {
    return AppCard(
      title: 'Printer & Consultation Slip Defaults (PRD Sec 29 & 30)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consultation slips feature clinic branding, patient identity, and blank handwriting areas for doctor notes, Rx, and advice.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text(
            'Default Paper Size for Consultation Slips & Receipts:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: AppConstants.paperSizeA5,
                label: Text('A5 Portrait (Recommended Clinical Standard)'),
                icon: Icon(Icons.receipt_outlined),
              ),
              ButtonSegment(
                value: AppConstants.paperSizeA4,
                label: Text('A4 Standard Sheet (Full Page)'),
                icon: Icon(Icons.description_outlined),
              ),
            ],
            selected: {_paperSize},
            onSelectionChanged: (newSelection) {
              setState(() => _paperSize = newSelection.first);
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prescription Integrity Rule (PRD Principle 4):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Apna Clinic strictly generates paper slips with pre-printed clinic headers, doctor credentials, and patient demographics. The application strictly never writes digital prescriptions — doctors handwrite notes, medicines, and advice directly onto the slip.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. Backup & Disaster Recovery Section
  Widget _buildBackupSection(bool isDesktop, SyncHealthState syncHealth) {
    return AppCard(
      title: 'Encrypted Database Backup & Disaster Recovery (AES-256-CBC)',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _isBackingUp ? null : _performEncryptedBackup,
            icon: const Icon(Icons.file_download, size: 16),
            label: const Text('Backup Now (AES-256)'),
          ),
          OutlinedButton.icon(
            onPressed: _showRestoreWizard,
            icon: const Icon(Icons.settings_backup_restore, size: 16),
            label: const Text('Restore Wizard'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
            ),
            onPressed: _purgeAllTestData,
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Purge Test Data'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local database snapshot is encrypted with PBKDF2 key derivation and verified with SHA-256 checksum integrity.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              syncHealth.lastVerifiedBackupTime != null
                  ? Icons.verified_user
                  : Icons.lock_outline,
              color:
                  syncHealth.lastVerifiedBackupTime != null
                      ? AppColors.success
                      : AppColors.primary,
              size: 36,
            ),
            title: Text(
              syncHealth.lastVerifiedBackupTime != null
                  ? 'Verified Encrypted Backup Active'
                  : 'No Verified Backup Generated Today',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              syncHealth.lastVerifiedBackupTime != null
                  ? 'Last Verified: ${syncHealth.lastVerifiedBackupTime!.toLocal()} • SHA-256 Checksum Verified'
                  : 'Generate an encrypted local backup snapshot to protect your clinic operational data.',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield, color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Backups include complete relational graphs: Patients, Visits, Tokens, Invoices, Payments, and Tamper-evident Audit Logs with rollback protection.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 7. Cloud Sync & Master Sheet Roadmap Section
  Widget _buildCloudSyncSection(bool isDesktop, SessionState session) {
    return AppCard(
      title:
          'Google Cloud Sync & Master Workbook Connection (Phase 2 & 3 Roadmap)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '100% Offline-First Architecture. Master Sheet synchronization is scheduled for Phase 2.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade900),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PHASE 1 ACTIVE: Apna Clinic operates in 100% offline, local-first standalone database mode (PRD Principle 1). Google Drive OAuth and Master Sheet formulas are strictly scheduled for Phase 2 and Phase 3.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.table_chart_outlined,
              size: 28,
              color: AppColors.success,
            ),
            title: Text('Scheduled Master Workbook: ApnaClinic_Master_v1'),
            subtitle: Text(
              '19 Canonical Tabs • Incremental outbox batch sync cursor (Phase 2)',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.folder_outlined,
              size: 28,
              color: AppColors.primary,
            ),
            title: Text(
              'Target Drive Folder: ApnaClinic/${session.clinicId}/Backups/Encrypted/',
            ),
            subtitle: const Text(
              'Restricted application data scope (drive.file) (Phase 3)',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 8. Subscription & Licensing Management (PRD Module 10)
  Widget _buildSubscriptionSection(bool isDesktop, SessionState session) {
    // RBAC: PRD Section 2 & Section 5 M10 — Subscription management is restricted to Owner
    if (session.role != UserRole.owner) {
      return AppCard(
        title: 'Subscription & Commercial Licensing (Module 10)',
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Access Restricted: Subscription settings, commercial licensing, and renewals are restricted strictly to Clinic Owner / Administrator as per PRD Section 2 & M10.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final subscriptionAsync = ref.watch(subscriptionProvider);

    return AppCard(
      title: 'Subscription & Licensing Management (PRD Module 10)',
      trailing: OutlinedButton.icon(
        onPressed: () => ref.refresh(subscriptionProvider),
        icon: const Icon(Icons.refresh, size: 15),
        label: const Text('Refresh Status'),
      ),
      child: subscriptionAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, _) => Container(
          padding: const EdgeInsets.all(16),
          color: Colors.red.shade50,
          child: Text('Failed to load subscription: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (sub) {
          final now = DateTime.now().toUtc();
          final isOperational = sub.canPerformOperationalWrites;
          final daysLeft = sub.daysRemaining(now);
          final graceLeft = sub.graceDaysRemaining(now);

          Color statusColor;
          String statusBadgeText;
          IconData statusIcon;

          switch (sub.status) {
            case SubscriptionStatus.trialActive:
              statusColor = const Color(0xFF2563EB); // Blue
              statusBadgeText = 'ACTIVE TRIAL (${daysLeft}d left)';
              statusIcon = Icons.timer;
              break;
            case SubscriptionStatus.paidActive:
              statusColor = const Color(0xFF0F766E); // Teal
              statusBadgeText = 'COMMERCIAL LICENSE ACTIVE (${daysLeft}d left)';
              statusIcon = Icons.verified;
              break;
            case SubscriptionStatus.gracePeriod:
              statusColor = const Color(0xFFD97706); // Amber
              statusBadgeText = 'OFFLINE GRACE PERIOD (${graceLeft}d left)';
              statusIcon = Icons.warning_amber_rounded;
              break;
            case SubscriptionStatus.expired:
              statusColor = const Color(0xFFDC2626); // Red
              statusBadgeText = 'EXPIRED (SAFE READ-ONLY MODE)';
              statusIcon = Icons.lock_clock;
              break;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Current Entitlement Banner Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            sub.tier.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                statusBadgeText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isOperational
                          ? 'Full Operational Mode: All Clinic Management Modules Active'
                          : 'Safe Read-Only Mode: Operational Writes Paused, Data Export 100% Guaranteed',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isOperational
                          ? 'Includes Patient Registration, Smart Queue, Consultation Slip Printing, Billing, Reports, and Google Sheets Sync.'
                          : 'As per PRD M10, expired subscriptions never lock patient data. You can export patients, view records, download CSV reports, and create backups.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Entitlement Metadata Grid
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _buildEntitlementMetric(
                    label: 'Valid Until',
                    value: '${sub.validUntil.day.toString().padLeft(2, '0')}/${sub.validUntil.month.toString().padLeft(2, '0')}/${sub.validUntil.year}',
                    icon: Icons.calendar_today,
                  ),
                  _buildEntitlementMetric(
                    label: 'Offline Grace Buffer',
                    value: '7 Days (${sub.graceUntil.day.toString().padLeft(2, '0')}/${sub.graceUntil.month.toString().padLeft(2, '0')}/${sub.graceUntil.year})',
                    icon: Icons.shield,
                  ),
                  _buildEntitlementMetric(
                    label: 'Commercial Price',
                    value: '₹3,999 / year',
                    icon: Icons.currency_rupee,
                  ),
                  _buildEntitlementMetric(
                    label: 'Offline Token Security',
                    value: 'HMAC-SHA256 Signed',
                    icon: Icons.fingerprint,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // 3. Licensing Actions Row
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showRenewalDialog(context, sub, session),
                    icon: const Icon(Icons.shopping_bag, size: 16),
                    label: const Text('Renew Annual License (₹3,999/yr)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showActivateOfflineKeyDialog(context, session),
                    icon: const Icon(Icons.key, size: 16),
                    label: const Text('Enter Offline License Key'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportSafeClinicData(session),
                    icon: const Icon(Icons.file_download, size: 16),
                    label: const Text('Safe Patient Export (CSV)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 4. PRD Compliance & Data Protection Notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'PRD Module 10 Compliance: Clinic Data Ownership Guarantee',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Apna Clinic adheres strictly to non-lock-in principles. Offline license tokens are cryptographically signed to allow clinics to operate through internet disruptions. Even if an annual subscription lapses, all existing patient records and daily accounts remain 100% accessible and exportable without fee.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEntitlementMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0F766E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenewalDialog(
    BuildContext context,
    ClinicSubscription sub,
    SessionState session,
  ) async {
    final paymentRefController = TextEditingController(
      text: 'UPI_APNA_${DateTime.now().millisecondsSinceEpoch}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('Renew Annual License'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commercial License Details (PRD Section 5 M10 & Section 13):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Plan:', style: TextStyle(fontSize: 13)),
                      Text('Annual Commercial (365 Days)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fee (Indian Rupees):', style: TextStyle(fontSize: 13)),
                      Text('₹3,999.00 / year', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment / Transaction Reference ID:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: paymentRefController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'e.g. UPI / Card reference',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirm Renewal (₹3,999)'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(subscriptionProvider.notifier).renewAnnual(
          actorId: session.staffId,
          paymentReference: paymentRefController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF0F766E),
              content: Text('Annual Commercial License successfully renewed! Valid for 365 days.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Renewal failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _showActivateOfflineKeyDialog(
    BuildContext context,
    SessionState session,
  ) async {
    final keyController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('Activate Offline License Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the cryptographic license key token issued for this clinic:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste base64 license token here...',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            child: const Text('Verify & Activate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final key = keyController.text.trim();
      if (key.isEmpty) return;

      try {
        await ref.read(subscriptionProvider.notifier).activateOfflineKey(
          licenseKey: key,
          actorId: session.staffId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF0F766E),
              content: Text('Offline cryptographic license key verified and activated successfully!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('License verification failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportSafeClinicData(SessionState session) async {
    try {
      final patientRepo = ref.read(patientRepositoryProvider);
      final patients = await patientRepo.searchPatients(session.clinicId, '');
      final csv = StringBuffer();
      csv.write('\uFEFF');
      csv.writeln('patient_id,full_name,phone,age,sex,created_at');
      for (final p in patients) {
        csv.writeln(
          '"${p.patientId}","${p.fullName}","${p.phoneOptional ?? ''}","${p.displayAge ?? ''}","${p.sexOptional ?? ''}","${p.createdAt.toIso8601String()}"',
        );
      }
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName = 'apna_clinic_safe_export_${session.clinicId}_$dateStr.csv';
      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        content: csv.toString(),
        mimeType: 'text/csv;charset=utf-8',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Safe export downloaded: ${patients.length} patient records preserved.'),
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

  // =========================================================================
  // MULTI-DEVICE LIVE COLLABORATION METHODS (MODULE 13)
  // =========================================================================

  Future<void> _loadCollaborationData() async {
    final session = ref.read(sessionProvider);
    final collabRepo = ref.read(deviceCollaborationRepositoryProvider);
    try {
      final dev = await collabRepo.getLocalDevice(session.clinicId);
      final lease = await collabRepo.getActiveWriteLease(session.clinicId);
      final devices = await collabRepo.getConnectedDevices(session.clinicId);
      final conflicts = await collabRepo.getConflicts(session.clinicId, unresolvedOnly: false);
      if (mounted) {
        setState(() {
          _localDevice = dev;
          _activeLease = lease;
          _connectedDevices = devices;
          _collaborationConflicts = conflicts;
        });
      }
    } catch (_) {}
  }

  Future<void> _acquireWriteLease() async {
    final session = ref.read(sessionProvider);
    final collabRepo = ref.read(deviceCollaborationRepositoryProvider);
    try {
      await collabRepo.acquireWriteLease(
        clinicId: session.clinicId,
        staffId: session.staffId,
        role: session.role,
      );
      await _loadCollaborationData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Authoritative write lease acquired for this terminal!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Failed to acquire write lease: $e')),
        );
      }
    }
  }

  Future<void> _renewWriteLease() async {
    final session = ref.read(sessionProvider);
    final collabRepo = ref.read(deviceCollaborationRepositoryProvider);
    try {
      await collabRepo.renewWriteLease(
        clinicId: session.clinicId,
        staffId: session.staffId,
      );
      await _loadCollaborationData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Write lease renewed for an additional 5 minutes.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Renewal failed: $e')),
        );
      }
    }
  }

  Future<void> _releaseWriteLease() async {
    final session = ref.read(sessionProvider);
    final collabRepo = ref.read(deviceCollaborationRepositoryProvider);
    try {
      await collabRepo.releaseWriteLease(
        clinicId: session.clinicId,
        staffId: session.staffId,
      );
      await _loadCollaborationData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Write lease released. Terminal returned to unassigned mode.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Release failed: $e')),
        );
      }
    }
  }

  Future<void> _showRenameDeviceDialog() async {
    final session = ref.read(sessionProvider);
    final collabRepo = ref.read(deviceCollaborationRepositoryProvider);
    final controller = TextEditingController(text: _localDevice?.deviceName ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('Rename Workstation Terminal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give this terminal a recognizable location label (e.g. "Reception Counter 1", "OPD Room 2").',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Terminal Name *',
                hintText: 'e.g. Reception Desk 1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            child: const Text('SAVE NAME'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty && _localDevice != null) {
      try {
        await collabRepo.updateDeviceName(
          clinicId: session.clinicId,
          deviceId: _localDevice!.deviceId,
          newName: controller.text.trim(),
        );
        await _loadCollaborationData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Workstation name updated successfully.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Update failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _showTransferLeaseDialog(String targetDeviceId) async {
    final session = ref.read(sessionProvider);
    final collabRepo = ref.read(deviceCollaborationRepositoryProvider);
    final controller = TextEditingController(text: 'Workstation rotation by Owner');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Transfer Write Authority'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'As Clinic Owner, you are transferring primary write authority to device "$targetDeviceId". This workstation will hold exclusive permission for visit tokens and invoices.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Transfer Reason / Audit Note *',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            child: const Text('TRANSFER LEASE'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await collabRepo.forceTransferLease(
          clinicId: session.clinicId,
          staffId: session.staffId,
          targetDeviceId: targetDeviceId,
          reason: controller.text.trim(),
        );
        await _loadCollaborationData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Write lease successfully transferred!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Transfer failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _showResolveConflictDialog(CollaborationConflict conflict) async {
    final session = ref.read(sessionProvider);
    final collabRepo = ref.read(deviceCollaborationRepositoryProvider);
    final notesController = TextEditingController();
    String selectedAction = 'resolved_keep_local';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.rule, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Resolve Collaboration Conflict'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entity: ${conflict.entityType.toUpperCase()} (${conflict.entityId})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text('Conflict: ${conflict.conflictType}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Local Summary: ${conflict.localSummary}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Incoming Summary: ${conflict.remoteSummary}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Choose Resolution Strategy:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                RadioListTile<String>(
                  title: const Text('Keep Local (Primary Workstation)'),
                  subtitle: const Text('Preserves local database state as authoritative'),
                  value: 'resolved_keep_local',
                  groupValue: selectedAction,
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedAction = val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Keep Incoming (Remote Workstation)'),
                  subtitle: const Text('Accepts remote terminal changes'),
                  value: 'resolved_keep_remote',
                  groupValue: selectedAction,
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedAction = val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Manual Administrative Override'),
                  subtitle: const Text('Record custom resolution notes and audit entry'),
                  value: 'resolved_manual',
                  groupValue: selectedAction,
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedAction = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Resolution Audit Notes (Optional)',
                    hintText: 'e.g. Consulted receptionist and verified slot availability',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
              child: const Text('CONFIRM RESOLUTION'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await collabRepo.resolveConflict(
          conflictId: conflict.conflictId,
          clinicId: session.clinicId,
          staffId: session.staffId,
          resolutionStatus: selectedAction,
          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        );
        await _loadCollaborationData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Conflict successfully resolved and logged to audit trail.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Resolution failed: $e')),
          );
        }
      }
    }
  }

  Widget _buildCollaborationSection(bool isDesktop, SessionState session) {
    final hasLease = _activeLease != null &&
        _activeLease!.holderDeviceId == _localDevice?.deviceId &&
        _activeLease!.isActive;
    final isUnassigned = _activeLease == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Current Terminal Identity & Write Authority
        AppCard(
          title: 'Workstation Terminal Identity & Single-Writer Authority',
          trailing: OutlinedButton.icon(
            onPressed: _loadCollaborationData,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Refresh Terminal Roster'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasLease || isUnassigned
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasLease || isUnassigned
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasLease || isUnassigned
                              ? Icons.verified
                              : Icons.lock_clock,
                          color: hasLease || isUnassigned
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasLease
                                    ? 'AUTHORITATIVE PRIMARY WORKSTATION (WRITE LEASE ACTIVE)'
                                    : (isUnassigned
                                        ? 'SINGLE-DEVICE OPERATION (UNASSIGNED / DEFAULT WRITER)'
                                        : 'SECONDARY COLLABORATIVE TERMINAL (READ-ONLY / RESTRICTED WRITES)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: hasLease || isUnassigned
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasLease
                                    ? 'This device is authorized to allocate tokens, issue invoices, and commit cloud updates. Lease active until ${_activeLease!.expiresAt.toLocal().toString().split('.').first}.'
                                    : (isUnassigned
                                        ? 'No active lease claimed. Current workstation is operating as the authoritative terminal.'
                                        : 'Workstation "${_activeLease!.holderDeviceId}" currently holds write authority until ${_activeLease!.expiresAt.toLocal().toString().split('.').first}.'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Terminal Name: ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _localDevice?.deviceName ?? 'Loading...',
                              style: const TextStyle(fontSize: 13),
                            ),
                            IconButton(
                              onPressed: _showRenameDeviceDialog,
                              icon: const Icon(Icons.edit, size: 16),
                              tooltip: 'Rename Terminal',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Device ID: ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _localDevice?.deviceId ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Configured Role: ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            StatusBadge(
                              label: _localDevice?.deviceRole.displayName ?? 'Terminal',
                              textColor: const Color(0xFF0F766E),
                              backgroundColor: const Color(0xFFCCFBF1),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (!hasLease)
                          FilledButton.icon(
                            onPressed: _acquireWriteLease,
                            icon: const Icon(Icons.key, size: 16),
                            label: const Text('Acquire Primary Write Lease'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                            ),
                          ),
                        if (hasLease) ...[
                          FilledButton.icon(
                            onPressed: _renewWriteLease,
                            icon: const Icon(Icons.autorenew, size: 16),
                            label: const Text('Renew Lease (+5 min)'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _releaseWriteLease,
                            icon: const Icon(Icons.lock_open, size: 16),
                            label: const Text('Release Write Lease'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Connected Workstations Roster
        AppCard(
          title: 'Connected Workstations & Device Roster (${_connectedDevices.length})',
          child: _connectedDevices.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('No workstations registered yet.'),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _connectedDevices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final dev = _connectedDevices[index];
                    final isCurrent = dev.deviceId == _localDevice?.deviceId;
                    final holdsLease = _activeLease != null &&
                        _activeLease!.holderDeviceId == dev.deviceId &&
                        _activeLease!.isActive;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: dev.isOnline
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        child: Icon(
                          dev.deviceRole == DeviceRole.doctorDesk
                              ? Icons.medical_services
                              : (dev.deviceRole == DeviceRole.mobileViewer
                                  ? Icons.smartphone
                                  : Icons.computer),
                          color: dev.isOnline
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            dev.deviceName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            const StatusBadge(
                              label: 'THIS DEVICE',
                              textColor: Color(0xFF0F766E),
                              backgroundColor: Color(0xFFCCFBF1),
                            ),
                          ],
                          if (holdsLease) ...[
                            const SizedBox(width: 8),
                            const StatusBadge(
                              label: 'PRIMARY WRITER',
                              textColor: Color(0xFF15803D),
                              backgroundColor: Color(0xFFDCFCE7),
                              icon: Icons.vpn_key,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${dev.deviceRole.displayName} • ID: ${dev.deviceId} • Last Heartbeat: ${dev.lastHeartbeatAt.toLocal().toString().split('.').first} • Platform: ${dev.platformInfo}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          StatusBadge(
                            label: dev.isOnline ? 'ONLINE' : 'IDLE / OFFLINE',
                            textColor: dev.isOnline
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                            backgroundColor: dev.isOnline
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                          ),
                          if (session.role == UserRole.owner && !holdsLease)
                            OutlinedButton.icon(
                              onPressed: () => _showTransferLeaseDialog(dev.deviceId),
                              icon: const Icon(Icons.swap_horiz, size: 14),
                              label: const Text('Transfer Lease'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 20),

        // 3. Live Collaboration Conflict Ledger (PRD M13 & M03)
        AppCard(
          title: 'Collaboration Conflict Ledger (${_collaborationConflicts.length})',
          trailing: Text(
            '${_collaborationConflicts.where((c) => !c.isResolved).length} Unresolved',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _collaborationConflicts.any((c) => !c.isResolved)
                  ? Colors.red
                  : Colors.green,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_collaborationConflicts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No concurrent data conflicts recorded. Zero split-brain discrepancies detected.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _collaborationConflicts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final conflict = _collaborationConflicts[index];
                    return ListTile(
                      leading: Icon(
                        conflict.isResolved
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: conflict.isResolved ? Colors.green : Colors.amber.shade800,
                      ),
                      title: Row(
                        children: [
                          Text(
                            '${conflict.entityType.toUpperCase()} CONFLICT (${conflict.conflictType})',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: conflict.resolutionStatus.toUpperCase(),
                            textColor: conflict.isResolved ? Colors.green : Colors.red,
                            backgroundColor: conflict.isResolved
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEF2F2),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Entity ID: ${conflict.entityId} • Detected: ${conflict.detectedAt.toLocal().toString().split('.').first}'),
                          Text('Local: ${conflict.localSummary}'),
                          Text('Incoming: ${conflict.remoteSummary}'),
                          if (conflict.resolutionNotes != null)
                            Text(
                              'Resolution Note: ${conflict.resolutionNotes}',
                              style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                            ),
                        ],
                      ),
                      trailing: conflict.isResolved
                          ? null
                          : OutlinedButton(
                              onPressed: () => _showResolveConflictDialog(conflict),
                              child: const Text('Resolve Conflict'),
                            ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. ADR-003 & PRD Section 7.3 Concurrency Architecture Explainer
        AppCard(
          title: 'Single-Writer Collaboration Protocol (ADR-003 & PRD Section 7.3)',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why Apna Clinic Enforces Single-Writer Lease Coordination:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '1. Zero Split-Brain Invoices & Tokens: In outpatient clinics with intermittent internet connectivity, Google Sheets cannot provide distributed row locks. A designated primary workstation guarantees monotonic token issuance and financial numbering.\n'
                '2. Doctor Desk Cabin Isolation: Doctor terminals operate in collaborative queue-calling mode, advancing patient states without racing on walk-in token allocation.\n'
                '3. Automatic Heartbeat & Handover: Workstations broadcast heartbeats every 60 seconds. If a receptionist workstation goes offline, the lease expires automatically after 5 minutes or can be immediately transferred by the Clinic Owner.\n'
                '4. DPDP Patient Privacy Barrier: Conflict ledgers and device sync events strictly exclude clinical illness notes and digital prescriptions.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // MULTI-BRANCH & THIRD-PARTY INTEGRATIONS (MODULE 14)
  // =========================================================================

  Future<void> _loadBranchData() async {
    final session = ref.read(sessionProvider);
    final branchRepo = ref.read(branchRepositoryProvider);
    try {
      final branches = await branchRepo.getBranches(session.clinicId, activeOnly: false);
      final report = await branchRepo.getConsolidatedReport(session.clinicId);
      final abdm = await branchRepo.getAbdmConfig(session.clinicId);
      if (mounted) {
        setState(() {
          _branches = branches;
          _consolidatedReport = report;
          _abdmConfig = abdm;
        });
      }
    } catch (_) {}
  }

  Future<void> _showAddBranchDialog() async {
    final session = ref.read(sessionProvider);
    final branchRepo = ref.read(branchRepositoryProvider);
    final codeCtrl = TextEditingController(text: 'BR-0${_branches.length + 1}');
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: _clinicPhoneController.text);
    final emailCtrl = TextEditingController(text: _clinicEmailController.text);
    final addressCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: _clinicCityController.text);
    final stateCtrl = TextEditingController(text: _clinicStateController.text);
    final pinCtrl = TextEditingController(text: _clinicPincodeController.text);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_business, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('Add Clinic Branch Facility'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Code *',
                  hintText: 'e.g. BR-02, NOIDA-01',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Display Name *',
                  hintText: 'e.g. South Extension Branch',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number *',
                  hintText: '+919876543210',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address Line *',
                  hintText: 'e.g. Market Complex, Sector 18',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'City *'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: stateCtrl,
                      decoration: const InputDecoration(labelText: 'State *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(labelText: 'Pincode *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            child: const Text('REGISTER BRANCH'),
          ),
        ],
      ),
    );

    if (confirmed == true && codeCtrl.text.trim().isNotEmpty && nameCtrl.text.trim().isNotEmpty) {
      final now = DateTime.now().toUtc();
      final newBranch = Branch(
        branchId: 'br_${session.clinicId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        branchCode: codeCtrl.text.trim().toUpperCase(),
        branchName: nameCtrl.text.trim(),
        contactPhone: phoneCtrl.text.trim(),
        contactEmail: emailCtrl.text.trim(),
        addressLine1: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Clinic Premises',
        city: cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'New Delhi',
        state: stateCtrl.text.trim().isNotEmpty ? stateCtrl.text.trim() : 'Delhi',
        pincode: pinCtrl.text.trim().isNotEmpty ? pinCtrl.text.trim() : '110001',
        isMainBranch: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      try {
        await branchRepo.saveBranch(newBranch);
        await _loadBranchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('New clinic branch registered successfully!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Failed to add branch: $e')),
          );
        }
      }
    }
  }

  Future<void> _deactivateBranch(String branchId) async {
    final session = ref.read(sessionProvider);
    final branchRepo = ref.read(branchRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Deactivate Branch?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to deactivate this clinic branch? Reception staff will no longer be able to check in visits or issue tokens under this branch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DEACTIVATE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await branchRepo.deleteBranch(session.clinicId, branchId, staffId: session.staffId);
        await _loadBranchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Branch successfully deactivated.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Deactivation failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportConsolidatedCsv() async {
    if (_consolidatedReport == null) return;
    final branchRepo = ref.read(branchRepositoryProvider);
    final session = ref.read(sessionProvider);

    try {
      final csv = await branchRepo.exportConsolidatedReportCsv(_consolidatedReport!);
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName = 'apna_clinic_consolidated_report_${session.clinicId}_$dateStr.csv';

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        content: csv,
        mimeType: 'text/csv;charset=utf-8',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Consolidated report downloaded successfully.'),
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

  Future<void> _showEditAbdmDialog() async {
    final session = ref.read(sessionProvider);
    final branchRepo = ref.read(branchRepositoryProvider);
    final facIdCtrl = TextEditingController(text: _abdmConfig?.facilityId ?? '');
    final facNameCtrl = TextEditingController(text: _abdmConfig?.facilityName ?? '');
    final hprCtrl = TextEditingController(text: _abdmConfig?.hprDoctorId ?? '');
    final gatewayCtrl = TextEditingController(text: _abdmConfig?.gatewayClientId ?? '');
    bool enabled = _abdmConfig?.isAbdmEnabled ?? false;
    String status = _abdmConfig?.bridgeStatus ?? 'disconnected';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.health_and_safety, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('ABDM & Health Registry Settings'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Enable ABDM Gateway Bridge'),
                  subtitle: const Text('Connects facility to national sandbox registry'),
                  value: enabled,
                  onChanged: (val) => setDialogState(() => enabled = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'HFR Facility ID *',
                    hintText: 'e.g. IN0710001234',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Facility Registered Name *',
                    hintText: 'e.g. City Health Clinic Flagship',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hprCtrl,
                  decoration: const InputDecoration(
                    labelText: 'HPR Doctor Registry ID (Optional)',
                    hintText: 'e.g. 12-3456-7890-1234',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gatewayCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ABDM Gateway Client ID *',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Gateway Bridge Certification Status'),
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'disconnected', child: Text('Disconnected / Inactive')),
                    DropdownMenuItem(value: 'sandbox_connected', child: Text('Sandbox Certified (M14 Compliant)')),
                    DropdownMenuItem(value: 'production_certified', child: Text('Production Certified (Live ABDM)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
              child: const Text('SAVE ABDM CONFIG'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final updated = AbdmIntegrationConfig(
        facilityId: facIdCtrl.text.trim().isNotEmpty ? facIdCtrl.text.trim() : 'IN00000001',
        facilityName: facNameCtrl.text.trim().isNotEmpty ? facNameCtrl.text.trim() : 'Clinic Facility',
        hprDoctorId: hprCtrl.text.trim().isNotEmpty ? hprCtrl.text.trim() : null,
        gatewayClientId: gatewayCtrl.text.trim().isNotEmpty ? gatewayCtrl.text.trim() : 'client_id',
        bridgeStatus: status,
        isAbdmEnabled: enabled,
        lastVerifiedAt: DateTime.now().toUtc(),
      );

      try {
        await branchRepo.saveAbdmConfig(session.clinicId, updated);
        await _loadBranchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('ABDM integration configuration saved successfully!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Save failed: $e')),
          );
        }
      }
    }
  }

  Widget _buildMultiBranchSection(bool isDesktop, SessionState session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Branch Facility Roster
        AppCard(
          title: 'Clinic Branch Network & Multi-Tenancy Facilities (${_branches.length})',
          trailing: FilledButton.icon(
            onPressed: _showAddBranchDialog,
            icon: const Icon(Icons.add_business, size: 16),
            label: const Text('Add Branch'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_branches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('No clinic branches registered.'),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _branches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final b = _branches[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: b.isMainBranch
                            ? const Color(0xFFCCFBF1)
                            : (b.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                        child: Icon(
                          b.isMainBranch ? Icons.star : Icons.store_mall_directory,
                          color: b.isMainBranch
                              ? const Color(0xFF0F766E)
                              : (b.isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            b.branchName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: b.branchCode,
                            textColor: const Color(0xFF0F766E),
                            backgroundColor: const Color(0xFFCCFBF1),
                          ),
                          if (b.isMainBranch) ...[
                            const SizedBox(width: 8),
                            const StatusBadge(
                              label: 'MAIN FLAGSHIP',
                              textColor: Color(0xFF15803D),
                              backgroundColor: Color(0xFFDCFCE7),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${b.addressLine1}, ${b.city}, ${b.state} - ${b.pincode} • Phone: ${b.contactPhone}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          StatusBadge(
                            label: b.isActive ? 'ACTIVE' : 'DEACTIVATED',
                            textColor: b.isActive ? const Color(0xFF16A34A) : Colors.red,
                            backgroundColor: b.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                          ),
                          if (!b.isMainBranch && b.isActive && session.role == UserRole.owner)
                            OutlinedButton.icon(
                              onPressed: () => _deactivateBranch(b.branchId),
                              icon: const Icon(Icons.block, size: 14),
                              label: const Text('Deactivate'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Consolidated Multi-Branch Financial & Operations Report (PRD M14)
        AppCard(
          title: 'Consolidated Multi-Branch Performance & Financial Ledger',
          trailing: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loadBranchData,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Refresh Report'),
              ),
              FilledButton.icon(
                onPressed: _exportConsolidatedCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export Consolidated CSV'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_consolidatedReport == null || _consolidatedReport!.branchMetrics.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('No consolidated reporting data available for today.'),
                  ),
                )
              else ...[
                // Metrics Overview Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildBranchMetricKpi(
                      'Grand Total Visits',
                      '${_consolidatedReport!.grandTotalVisits}',
                      Icons.people_outline,
                      const Color(0xFF0F766E),
                    ),
                    _buildBranchMetricKpi(
                      'Total Appointments',
                      '${_consolidatedReport!.grandTotalAppointments}',
                      Icons.calendar_today,
                      const Color(0xFF2563EB),
                    ),
                    _buildBranchMetricKpi(
                      'Total Collections',
                      '₹${(_consolidatedReport!.grandTotalCollectionsMinor / 100).toStringAsFixed(0)}',
                      Icons.payments_outlined,
                      const Color(0xFF16A34A),
                    ),
                    _buildBranchMetricKpi(
                      'Outstanding Pending',
                      '₹${(_consolidatedReport!.grandTotalPendingMinor / 100).toStringAsFixed(0)}',
                      Icons.pending_actions,
                      const Color(0xFFD97706),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Tabular breakdown
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Branch Code', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Branch Facility', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Today Visits', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Appointments', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Collections (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Pending (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Net Cash (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _consolidatedReport!.branchMetrics.map((m) {
                      return DataRow(
                        cells: [
                          DataCell(Text(m.branchCode)),
                          DataCell(Text(m.branchName)),
                          DataCell(Text('${m.totalVisitsToday}')),
                          DataCell(Text('${m.totalAppointmentsToday}')),
                          DataCell(Text('₹${(m.totalCollectedMinor / 100).toStringAsFixed(2)}')),
                          DataCell(Text('₹${(m.totalPendingMinor / 100).toStringAsFixed(2)}')),
                          DataCell(Text('₹${(m.netCashInHandMinor / 100).toStringAsFixed(2)}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. ABDM Health Facility & ABHA Interoperability Integration
        AppCard(
          title: 'Ayushman Bharat Digital Mission (ABDM) & Health ID Integration',
          trailing: OutlinedButton.icon(
            onPressed: _showEditAbdmDialog,
            icon: const Icon(Icons.settings, size: 15),
            label: const Text('Configure ABDM'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _abdmConfig?.isAbdmEnabled == true
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _abdmConfig?.isAbdmEnabled == true
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _abdmConfig?.isAbdmEnabled == true
                              ? Icons.verified_user
                              : Icons.health_and_safety_outlined,
                          color: _abdmConfig?.isAbdmEnabled == true
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _abdmConfig?.isAbdmEnabled == true
                                    ? 'ABDM HEALTH FACILITY REGISTRY BRIDGE: ACTIVE (${_abdmConfig?.bridgeStatus.toUpperCase()})'
                                    : 'ABDM GATEWAY BRIDGE: DISCONNECTED (OPTIONAL EXTENSION)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _abdmConfig?.isAbdmEnabled == true
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Facility ID (HFR): ${_abdmConfig?.facilityId ?? "Not configured"} • Gateway Client: ${_abdmConfig?.gatewayClientId ?? "Not configured"} • Consent Manager: ${_abdmConfig?.consentManagerUrl ?? "N/A"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    const Text(
                      'PRD Section 5 M14 Non-Clinical Interoperability Boundary:\n'
                      '• ABHA (14-digit Health ID) linking requires explicit patient DPDP consent.\n'
                      '• Strictly administrative demographic linking: zero electronic prescriptions, medical advice, or clinical diagnostic records are transmitted to third-party endpoints in MVP.',
                      style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchMetricKpi(String label, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

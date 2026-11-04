// Apna Clinic - Add Patient to Queue Dialog
// Primary source of truth: PRD Section 1.1 Goal 1, Section 28, TRD Section 8
// Rapid search & select or quick registration of patient to allocate token into live queue

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/entities.dart';
import '../../../application/providers.dart';
import '../../../core/utils/phone_normalizer.dart';
import 'create_visit_dialog.dart';

class AddPatientToQueueDialog extends ConsumerStatefulWidget {
  final void Function(Patient patient) onPatientSelected;

  const AddPatientToQueueDialog({
    super.key,
    required this.onPatientSelected,
  });

  /// Convenient helper to open the full workflow:
  /// 1) Select or register patient
  /// 2) Issue token & create visit with billing
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onVisitCreated,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AddPatientToQueueDialog(
        onPatientSelected: (patient) {
          // Open visit creation dialog for selected patient
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (visitCtx) => CreateVisitDialog(
              patient: patient,
              onVisitCreated: onVisitCreated,
            ),
          );
        },
      ),
    );
  }

  @override
  ConsumerState<AddPatientToQueueDialog> createState() =>
      _AddPatientToQueueDialogState();
}

class _AddPatientToQueueDialogState
    extends ConsumerState<AddPatientToQueueDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search tab state
  final _searchController = TextEditingController();
  List<Patient> _searchResults = [];
  bool _isSearching = false;

  // Quick Register tab state
  final _regFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianRelationController = TextEditingController();
  String _gender = 'Male';
  bool _isRegistering = false;
  List<Patient> _possibleDuplicates = [];
  Patient? _detectedDuplicate;

  bool get _isMinor {
    final age = int.tryParse(_ageController.text.trim());
    return age != null && age < 18;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ageController.addListener(() => setState(() {}));
    _nameController.addListener(() {
      if (_detectedDuplicate != null) {
        setState(() => _detectedDuplicate = null);
      }
    });
    _phoneController.addListener(() {
      if (_detectedDuplicate != null) {
        setState(() => _detectedDuplicate = null);
      }
    });
    _loadInitialPatients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _guardianNameController.dispose();
    _guardianRelationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPatients() async {
    setState(() => _isSearching = true);
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    final results = await patientRepo.searchPatients(
      session.clinicId,
      '',
      limit: 10,
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    final trimmed = query.trim();
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    setState(() => _isSearching = true);
    final results = await patientRepo.searchPatients(
      session.clinicId,
      trimmed,
      limit: 25,
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _checkDuplicatesBeforeRegister() async {
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    final duplicates = await patientRepo.findPossibleDuplicates(
      session.clinicId,
      phone: _phoneController.text.trim(),
      fullName: _nameController.text.trim(),
    );
    if (mounted) {
      setState(() {
        _possibleDuplicates = duplicates;
      });
    }
  }

  Future<void> _submitQuickRegistration() async {
    if (!_regFormKey.currentState!.validate()) return;

    setState(() => _isRegistering = true);
    await _checkDuplicatesBeforeRegister();

    // Check exact duplicate
    final cleanPhone = PhoneNormalizer.normalize(_phoneController.text.trim());
    final cleanName = _nameController.text.trim().toLowerCase();
    Patient? exactDuplicate;
    for (final dup in _possibleDuplicates) {
      final dupPhone = PhoneNormalizer.normalize(dup.phoneOptional);
      final dupName = dup.fullName.trim().toLowerCase();
      if (cleanPhone != null &&
          cleanPhone.isNotEmpty &&
          dupPhone == cleanPhone &&
          dupName == cleanName) {
        exactDuplicate = dup;
        break;
      }
    }

    if (exactDuplicate != null) {
      final selectedDuplicate = exactDuplicate;
      setState(() {
        _isRegistering = false;
        _detectedDuplicate = selectedDuplicate;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patient "${selectedDuplicate.fullName}" (${selectedDuplicate.patientNumber}) is already registered with this phone. Please select them directly.',
            ),
            backgroundColor: Colors.orange.shade900,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            action: SnackBarAction(
              label: 'SELECT EXISTING',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.of(context).pop();
                widget.onPatientSelected(selectedDuplicate);
              },
            ),
          ),
        );
      }
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
      phoneOptional: cleanPhone ?? _phoneController.text.trim(),
      ageIfDobUnknown: int.tryParse(_ageController.text.trim()),
      sexOptional: _gender,
      guardianNameOptional:
          _isMinor && _guardianNameController.text.trim().isNotEmpty
              ? _guardianNameController.text.trim()
              : null,
      guardianRelationOptional:
          _isMinor && _guardianRelationController.text.trim().isNotEmpty
              ? _guardianRelationController.text.trim()
              : null,
      consentStatus: 'granted',
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
      consentAction: 'granted',
      collectionChannel: 'reception_in_person',
      recordedByStaffId: session.staffId,
      recordedAt: now,
    );

    try {
      await patientRepo.savePatient(newPatient, consentEvent: consentEvent);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPatientSelected(newPatient);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 640 ? 580.0 : double.maxFinite;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Color(0xFF0F766E),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Patient to Live Queue',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      Text(
                        'Search existing patient or quickly register a new walk-in',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tabs: Search Existing vs Register New
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF0F766E),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.search, size: 18),
                    text: 'Search Existing Patient',
                  ),
                  Tab(
                    icon: Icon(Icons.person_add, size: 18),
                    text: 'Register New Walk-In',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSearchTab(),
                  _buildRegisterTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search Input
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by Name, Phone (98765...), or ID (P-2026-...)',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF0F766E)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _loadInitialPatients();
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Results or Empty
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.trim().isEmpty
                                ? 'No registered patients yet.'
                                : 'No patient found matching "${_searchController.text.trim()}"',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              final query = _searchController.text.trim();
                              // Prefill phone or name if user typed it
                              if (RegExp(r'^[0-9+]+$').hasMatch(query)) {
                                _phoneController.text = query;
                              } else if (query.isNotEmpty) {
                                _nameController.text = query;
                              }
                              _tabController.animateTo(1);
                            },
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('Register as New Walk-In'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (ctx, i) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, i) {
                        final p = _searchResults[i];
                        final ageDisplay = p.ageIfDobUnknown != null
                            ? '${p.ageIfDobUnknown} yrs'
                            : (p.dateOfBirth != null
                                ? '${DateTime.now().year - p.dateOfBirth!.year} yrs'
                                : '');
                        final genderDisplay = p.sexOptional ?? '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFCCFBF1),
                            child: Text(
                              p.fullName.isNotEmpty
                                  ? p.fullName[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  p.patientNumber,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Phone: ${p.maskedPhone.isNotEmpty ? p.maskedPhone : "None"}${ageDisplay.isNotEmpty ? " • $ageDisplay" : ""}${genderDisplay.isNotEmpty ? " • $genderDisplay" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onPatientSelected(p);
                            },
                            icon: const Icon(Icons.arrow_forward, size: 14),
                            label: const Text('SELECT & ISSUE TOKEN'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRegisterTab() {
    return Form(
      key: _regFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_detectedDuplicate != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Patient "${_detectedDuplicate!.fullName}" (${_detectedDuplicate!.patientNumber}) is already registered with this phone.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        Navigator.of(context).pop();
                        widget.onPatientSelected(_detectedDuplicate!);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade900,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      child: const Text('SELECT',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Patient Full Name *',
                hintText: 'e.g. Ramesh Kumar',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
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
                      labelText: 'Phone Number',
                      hintText: '10-digit mobile number',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age (Years)',
                      hintText: 'e.g. 32',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Gender: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: ['Male', 'Female', 'Other'].map((g) {
                    return ChoiceChip(
                      label: Text(g),
                      selected: _gender == g,
                      selectedColor: const Color(0xFFCCFBF1),
                      onSelected: (sel) {
                        if (sel) setState(() => _gender = g);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            if (_isMinor) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guardian Information (Patient is under 18)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _guardianNameController,
                            decoration: const InputDecoration(
                              labelText: 'Guardian Name',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _guardianRelationController,
                            decoration: const InputDecoration(
                              labelText: 'Relationship (e.g. Mother)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('BACK TO SEARCH'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isRegistering ? null : _submitQuickRegistration,
                  icon: _isRegistering
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.how_to_reg, size: 16),
                  label: Text(_isRegistering
                      ? 'REGISTERING...'
                      : 'REGISTER & ISSUE TOKEN'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

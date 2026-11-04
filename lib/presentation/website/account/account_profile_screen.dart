// Apna Clinic - Account Profile Management Screen
// Route: /account/profile
// Enables editing client profile details (Name, Phone, Clinic) while protecting privileged subscription fields.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../common/website_scaffold.dart';

class AccountProfileScreen extends ConsumerStatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  ConsumerState<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends ConsumerState<AccountProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _orgController;

  bool _isSaving = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final account = ref.read(appAccessProvider).account;
    _nameController = TextEditingController(text: account?.fullName ?? '');
    _phoneController = TextEditingController(text: account?.phone ?? '');
    _orgController = TextEditingController(text: account?.organizationName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _isSuccess = false;
    });

    try {
      final notifier = ref.read(appAccessProvider.notifier);
      await notifier.updateUserProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        organizationName: _orgController.text.trim(),
      );

      setState(() {
        _isSaving = false;
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save changes: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessState = ref.watch(appAccessProvider);
    final account = accessState.account;

    return WebsiteScaffold(
      activeRoute: '/account',
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go('/account'),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Edit Profile Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Update your personal information and clinic practice branding.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 32, color: Color(0xFFE2E8F0)),

                  if (_isSuccess)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                          SizedBox(width: 10),
                          Text('Profile updated successfully!', style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF991B1B))),
                    ),

                  // Account Email (Read-only for security)
                  TextFormField(
                    initialValue: account?.email.isNotEmpty == true ? account!.email : (accessState.firebaseEmail ?? ''),
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Registered Account Email (Immutable)',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF1F5F9),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      helperText: 'For security, email updates require provider re-authentication.',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Doctor / Representative Name *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 18),

                  // Mobile Phone
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Phone Number',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Clinic / Practice Name
                  TextFormField(
                    controller: _orgController,
                    decoration: const InputDecoration(
                      labelText: 'Clinic / Practice Name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save Action
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

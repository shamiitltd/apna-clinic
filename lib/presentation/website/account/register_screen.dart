// Apna Clinic - Official Account Registration Portal
// Route: /register
// Integrates Firebase Authentication (Google & Email/Password) with Cloud Firestore account initialization.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../common/website_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _orgController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _termsAgreed = false;
  bool _showEmailFields = false;
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _orgController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignup() async {
    setState(() => _localError = null);
    final notifier = ref.read(appAccessProvider.notifier);
    await notifier.registerWithGoogle(
      organizationName: _orgController.text.trim().isNotEmpty ? _orgController.text.trim() : null,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    final state = ref.read(appAccessProvider);
    if (state.isAuthenticated && mounted) {
      context.go('/account');
    } else if (state.errorMessage != null && mounted) {
      setState(() => _localError = state.errorMessage);
    }
  }

  Future<void> _handleEmailSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAgreed) {
      setState(() => _localError = 'Please agree to the Terms of Service & Privacy Policy.');
      return;
    }

    setState(() => _localError = null);
    final notifier = ref.read(appAccessProvider.notifier);
    await notifier.registerWithEmailPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      organizationName: _orgController.text.trim(),
    );

    final state = ref.read(appAccessProvider);
    if (state.isAuthenticated && mounted) {
      context.go('/account');
    } else if (state.errorMessage != null && mounted) {
      setState(() => _localError = state.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessState = ref.watch(appAccessProvider);
    final isLoading = accessState.isLoading;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return WebsiteScaffold(
      activeRoute: '/register',
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 64 : 20,
          vertical: 48,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create Your Apna Clinic Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join independent doctors and OPD clinics managing daily practice with ease.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 28),

                // Error feedback
                if (_localError != null || accessState.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _localError ?? accessState.errorMessage ?? 'An error occurred',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Primary Action: Continue with Google
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _handleGoogleSignup,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _showEmailFields ? 'OR ENTER DETAILS' : 'OR REGISTER WITH EMAIL',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  ],
                ),
                const SizedBox(height: 20),

                if (!_showEmailFields)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showEmailFields = true),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Register with Email & Password'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name (Doctor / Admin) *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email is required';
                            if (!v.contains('@') || !v.contains('.')) return 'Invalid email format';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Phone Number',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _orgController,
                          decoration: const InputDecoration(
                            labelText: 'Clinic / Practice Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password * (min 6 characters)',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password *',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _termsAgreed,
                              activeColor: const Color(0xFF0F766E),
                              onChanged: (val) => setState(() => _termsAgreed = val ?? false),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _termsAgreed = !_termsAgreed),
                                child: const Text(
                                  'I agree to the Terms of Service and Privacy Policy',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleEmailSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Complete Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Link to Login
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    InkWell(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
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
}

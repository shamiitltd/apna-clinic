// Apna Clinic - Password Reset Screen
// Route: /forgot-password

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../common/website_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(appAccessProvider.notifier);
      await notifier.sendPasswordResetEmail(_emailController.text.trim());
      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to send password reset email: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebsiteScaffold(
      activeRoute: '/forgot-password',
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 64),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0F766E), size: 24),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reset Your Password',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your registered account email and we will send you a secure link to reset your password.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 24),

                if (_isSuccess)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.mark_email_read_outlined, color: Color(0xFF16A34A), size: 36),
                        const SizedBox(height: 10),
                        const Text(
                          'Password Reset Link Sent',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Check your inbox at ${_emailController.text.trim()} for instructions to reset your password.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Return to Login'),
                        ),
                      ],
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                            ),
                          ),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Registered Email Address *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your email';
                            if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleReset,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to Login', style: TextStyle(color: Color(0xFF0F766E))),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

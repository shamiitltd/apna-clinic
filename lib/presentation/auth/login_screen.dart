// Apna Clinic - Platform Login Screen (Layer 1: Firebase Authentication)
// Primary source of truth: New Login, Account & Google Drive Data Architecture Plan
// Supports Google Sign-In, Email/Password Sign-In, Forgot Password, and direct navigation to /register.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth/app_access_notifier.dart';
import '../../application/providers.dart';
import '../../core/constants/app_constants.dart';
import '../website/common/website_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  StreamSubscription<String?>? _authSubscription;

  bool _obscurePassword = true;
  bool _showEmailLogin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accessState = ref.read(appAccessProvider);
      final authRepo = ref.read(authRepositoryProvider);
      if (accessState.isAuthenticated || authRepo.isAuthenticated) {
        context.go('/dashboard');
      }
    });
    _authSubscription = ref.read(authRepositoryProvider).authStateChanges.listen((uid) {
      if (uid != null && uid.isNotEmpty && mounted) {
        context.go('/dashboard');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(appAccessProvider.notifier);
    await notifier.signInWithEmailPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    final accessState = ref.read(appAccessProvider);
    final authRepo = ref.read(authRepositoryProvider);
    if (accessState.isAuthenticated || authRepo.isAuthenticated) {
      context.go('/dashboard');
    }
  }

  Future<void> _handleGoogleLogin() async {
    final notifier = ref.read(appAccessProvider.notifier);
    await notifier.signInWithGoogle();
    if (!mounted) return;
    final accessState = ref.read(appAccessProvider);
    final authRepo = ref.read(authRepositoryProvider);
    if (accessState.isAuthenticated || authRepo.isAuthenticated) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppAccessState>(appAccessProvider, (prev, next) {
      if (next.isAuthenticated && mounted) {
        context.go('/dashboard');
      }
    });

    final accessState = ref.watch(appAccessProvider);
    final isLoading = accessState.isLoading;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return WebsiteScaffold(
      activeRoute: '/login',
      showFooter: false,
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 64 : 20,
          vertical: 48,
        ),
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
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Icon
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
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Welcome Header
                const Text(
                  'Welcome Back',
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
                  'Sign in to your Apna Clinic account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Error Banner
                if (accessState.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, size: 20, color: Color(0xFFDC2626)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            accessState.errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Firebase Google Sign-In Button
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                        Text(
                          isLoading ? 'Signing in...' : 'Continue with Google',
                          style: const TextStyle(
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

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        _showEmailLogin ? 'OR USE EMAIL' : 'OR SIGN IN WITH EMAIL',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  ],
                ),

                const SizedBox(height: 20),

                if (!_showEmailLogin)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showEmailLogin = true),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Sign in with Email & Password'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your email';
                            if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password *',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => context.go('/forgot-password'),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleEmailLogin,
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
                                : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Don't have an account? -> Register
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    InkWell(
                      onTap: () => context.go('/register'),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Clinical Disclaimer
                const Text(
                  AppConstants.clinicalDisclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

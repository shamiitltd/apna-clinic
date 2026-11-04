// Apna Clinic - Account Required Screen
// Displayed when Firebase authentication succeeds, but no registered
// platform account document exists in Firestore for the UID.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';

class AccountRequiredScreen extends ConsumerWidget {
  const AccountRequiredScreen({super.key});

  Future<void> _openRegistrationUrl(BuildContext context) async {
    context.go('/register');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessState = ref.watch(appAccessProvider);
    final notifier = ref.read(appAccessProvider.notifier);

    final email = accessState.firebaseEmail ?? 'your Google account';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_off_rounded,
                    size: 40,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Your Google account is not registered with Apna Clinic.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Please create an Apna Clinic account from the official website.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 8),

                Text(
                  'Authenticated Identity: $email',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 28),

                // Create Account Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _openRegistrationUrl(context),
                    icon: const Icon(Icons.person_add_rounded, size: 20),
                    label: const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Sign in with different account
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => notifier.signOut(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text(
                      'Sign In with Different Account',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Powered by SHAMIIT LLP',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
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

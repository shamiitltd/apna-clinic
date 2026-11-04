// Apna Clinic - Account Inactive / Blocked Screen
// Displayed when an account exists in Firestore, but its status is inactive or suspended.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers.dart';
import '../../core/config/app_config.dart';

class AccountInactiveScreen extends ConsumerWidget {
  const AccountInactiveScreen({super.key});

  Future<void> _openSupportUrl(BuildContext context) async {
    final url = AppConfig.current.accountRegistrationUrl;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessState = ref.watch(appAccessProvider);
    final notifier = ref.read(appAccessProvider.notifier);

    final status = accessState.account?.accountStatus ?? 'inactive';

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
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block_rounded,
                    size: 40,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Account Inactive or Suspended',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Your Apna Clinic account status is currently "$status". Access to the management system has been suspended.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 8),

                Text(
                  'Please contact SHAMIIT support or visit the customer portal to reactivate your subscription.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 28),

                // Contact Support / Reactivate
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _openSupportUrl(context),
                    icon: const Icon(Icons.support_agent, size: 20),
                    label: const Text(
                      'Contact Support / Renew',
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

                // Sign Out
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => notifier.signOut(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text(
                      'Sign Out',
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

// Apna Clinic - Account Subscription Details Screen
// Route: /account/subscription

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../common/website_scaffold.dart';

class AccountSubscriptionScreen extends ConsumerWidget {
  const AccountSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessState = ref.watch(appAccessProvider);
    final account = accessState.account;

    return WebsiteScaffold(
      activeRoute: '/account',
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
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
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/account'),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Subscription & Licensing',
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
                  'Review your current active license, evaluation timeline, and entitlement status.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const Divider(height: 32, color: Color(0xFFE2E8F0)),

                // Current Plan Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CURRENT PLAN: ${(account?.plan ?? 'Standard Evaluation').toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (account?.subscriptionStatus ?? 'Active Trial').toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Full Access to All 12 Clinic Management Modules',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Includes Patient Management, Smart Queue, Consultation Billing, Receipts, Reports, and Google Drive Cloud Sync.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Details Rows
                _buildDetailRow('Account Identifier', account?.uid ?? accessState.firebaseUid ?? 'N/A'),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                _buildDetailRow('Account Status', (account?.accountStatus ?? 'Active').toUpperCase()),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                _buildDetailRow(
                  'Trial End / Renewal Date',
                  account?.trialEnd != null
                      ? '${account!.trialEnd!.day}/${account.trialEnd!.month}/${account.trialEnd!.year}'
                      : 'Complimentary Evaluation Active',
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                _buildDetailRow('License Verification', (account?.licenseStatus ?? 'Valid').toUpperCase()),

                const SizedBox(height: 36),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/pricing'),
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        label: const Text('Upgrade Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/contact'),
                        icon: const Icon(Icons.mail_outline, size: 16),
                        label: const Text('Contact Sales'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      ],
    );
  }
}

// Apna Clinic - Account Dashboard Screen
// Route: /account
// Displays authenticated user profile, product access entitlements, Google Drive connection status,
// and the primary action button: "Open Apna Clinic".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config/website_config.dart';
import '../common/website_scaffold.dart';

class AccountDashboardScreen extends ConsumerWidget {
  const AccountDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessState = ref.watch(appAccessProvider);
    final account = accessState.account;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return WebsiteScaffold(
      activeRoute: '/account',
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
          vertical: 48,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Banner & Welcome
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account?.fullName.isNotEmpty == true ? account!.fullName : 'Apna Clinic Doctor',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              account?.email.isNotEmpty == true ? account!.email : (accessState.firebaseEmail ?? ''),
                              style: const TextStyle(fontSize: 13, color: Color(0xFFCCFBF1)),
                            ),
                            if (account?.organizationName.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                account!.organizationName,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF99F6E4), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Prominent "Open Apna Clinic" Button
                      ElevatedButton.icon(
                        onPressed: () => context.go('/dashboard'),
                        icon: const Icon(Icons.local_hospital_rounded, size: 18),
                        label: const Text('Open Apna Clinic'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Main Info Cards Grid
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    // Card 1: Account & Subscription
                    _buildInfoCard(
                      title: 'Product Access & Subscription',
                      icon: Icons.verified_user_outlined,
                      color: const Color(0xFF0F766E),
                      actionLabel: 'Manage Plan',
                      onAction: () => context.go('/account/subscription'),
                      rows: [
                        const _CardRow('Product', 'Apna Clinic Management System'),
                        _CardRow(
                          'Account Status',
                          (account?.accountStatus ?? 'Active').toUpperCase(),
                          badgeColor: const Color(0xFF059669),
                        ),
                        _CardRow(
                          'Subscription Tier',
                          (account?.plan ?? 'Standard / Evaluation').toUpperCase(),
                        ),
                        _CardRow(
                          'Status',
                          (account?.subscriptionStatus ?? 'Trial').toUpperCase(),
                          badgeColor: const Color(0xFF0284C7),
                        ),
                        if (account?.trialEnd != null)
                          _CardRow('Trial Expiry', '${account!.trialEnd!.day}/${account.trialEnd!.month}/${account.trialEnd!.year}'),
                      ],
                    ),

                    // Card 2: Google Drive & Cloud Synchronization
                    _buildInfoCard(
                      title: 'Google Drive Data Synchronization',
                      icon: Icons.cloud_done_outlined,
                      color: const Color(0xFF0284C7),
                      actionLabel: 'Storage Architecture',
                      onAction: () => context.go('/data-privacy'),
                      rows: [
                        _CardRow(
                          'Sync Status',
                          accessState.driveConnected ? 'Connected & Active' : 'Pending Authorization',
                          badgeColor: accessState.driveConnected ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                        if (accessState.driveEmail != null)
                          _CardRow('Connected Account', accessState.driveEmail!),
                        const _CardRow('Target Storage', 'Clinic Owner\'s Google Drive'),
                        const _CardRow('Spreadsheet Sync', 'Structured Google Sheets'),
                      ],
                    ),

                    // Card 3: Clinic Setup Status
                    _buildInfoCard(
                      title: 'Clinic Configuration',
                      icon: Icons.tune_outlined,
                      color: const Color(0xFFD97706),
                      actionLabel: 'Edit Profile',
                      onAction: () => context.go('/account/profile'),
                      rows: [
                        _CardRow(
                          'Onboarding Setup',
                          account?.clinicSetupCompleted == true ? 'Completed' : 'Ready for Configuration',
                          badgeColor: account?.clinicSetupCompleted == true ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                        _CardRow('Clinic Name', account?.organizationName.isNotEmpty == true ? account!.organizationName : 'Not Set'),
                        _CardRow('Doctor Contact', account?.phone.isNotEmpty == true ? account!.phone : 'Not Set'),
                      ],
                    ),

                    // Card 4: Quick Actions & Support
                    _buildInfoCard(
                      title: 'Support & Assistance',
                      icon: Icons.support_agent_outlined,
                      color: const Color(0xFF64748B),
                      actionLabel: 'Contact Desk',
                      onAction: () => context.go('/contact'),
                      rows: const [
                        _CardRow('Support Email', WebsiteConfig.supportEmail),
                        _CardRow('Help Center', 'Help Articles & Setup Guides'),
                        _CardRow('Version', 'Apna Clinic v1.0 Production'),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // Bottom Logout / Session control
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Home'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(appAccessProvider.notifier).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, size: 16, color: Color(0xFFDC2626)),
                      label: const Text('Log Out', style: TextStyle(color: Color(0xFFDC2626))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
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

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required String actionLabel,
    required VoidCallback onAction,
    required List<_CardRow> rows,
  }) {
    return Container(
      width: 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Flexible(
                    child: r.badgeColor != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: r.badgeColor!.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: r.badgeColor!.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              r.value,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: r.badgeColor!,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : Text(
                            r.value,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRow {
  final String label;
  final String value;
  final Color? badgeColor;

  const _CardRow(this.label, this.value, {this.badgeColor});
}

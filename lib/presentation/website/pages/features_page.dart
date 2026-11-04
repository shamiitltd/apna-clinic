// Apna Clinic - Official Features Documentation Page
// Route: /features

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/website_scaffold.dart';

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return WebsiteScaffold(
      activeRoute: '/features',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            color: const Color(0xFFF0FDFA),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
              vertical: 48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'FEATURE DOCUMENTATION & WORKFLOWS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Comprehensive Clinic Features',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 38 : 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Explore how Apna Clinic manages patients, sequential token queues, consultation billing, receipt printing, and Google Drive cloud synchronization.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Features Grid
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
              vertical: 64,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 28,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildFeatureCard(
                      'Patient Management',
                      Icons.person_add_alt_1_outlined,
                      'Rapid registration in 30 seconds, unique patient identifier, mobile number search, and returning patient history.',
                      [
                        'Single-click lookup by 10-digit mobile number',
                        'Duplicate patient prevention alerts',
                        'Automatic age, gender, and contact logging',
                        'Historical visit logs and past consultation references',
                      ],
                    ),
                    _buildFeatureCard(
                      'Smart Queue & Tokens',
                      Icons.confirmation_number_outlined,
                      'Sequential token generation for today\'s OPD with Waiting, In-Cabin, and Completed status handling.',
                      [
                        'Separate queues for multiple practicing doctors',
                        'Receptionist "Call Next" with chime alert',
                        'Waiting time estimation for waiting room displays',
                        'Prioritize emergency walk-ins when needed',
                      ],
                    ),
                    _buildFeatureCard(
                      'Doctor Desk Station',
                      Icons.medical_services_outlined,
                      'Focused, distraction-free cabin interface for consulting physicians and specialists.',
                      [
                        'Large token display and patient demographics',
                        'Single click to call, start, and complete visits',
                        'Set follow-up date and next visit reminders',
                        'No complex electronic health coding required',
                      ],
                    ),
                    _buildFeatureCard(
                      'Appointments',
                      Icons.event_available_outlined,
                      'Dynamic appointment calendar with doctor time-slot allocation and conflict prevention.',
                      [
                        'Pre-booking for future dates and slots',
                        'Seamless appointment check-in converting to queue token',
                        'Reschedule or cancel appointments with reason',
                        'Prevents double-booking clashes',
                      ],
                    ),
                    _buildFeatureCard(
                      'Consultation Billing',
                      Icons.request_quote_outlined,
                      'Transparent invoice generation with Cash, UPI, and Card tracking.',
                      [
                        'Itemized consultation fees and clinic procedures',
                        'Multi-mode split payments (e.g. ₹500 Cash + ₹500 UPI)',
                        'Sequential, tamper-evident invoice numbering',
                        'Accurate paise calculations without floating-point errors',
                      ],
                    ),
                    _buildFeatureCard(
                      'Slips & Receipt Printing',
                      Icons.print_outlined,
                      'Print professional consultation slips and thermal receipts on standard clinic hardware.',
                      [
                        'A4 and A5 printable consultation slip layouts',
                        'Clinic branding, address, and doctor registration header',
                        'Thermal POS receipt printing (58mm / 80mm)',
                        'Reprint historical receipts with audit stamps',
                      ],
                    ),
                    _buildFeatureCard(
                      'Daily Cash Reconciliation',
                      Icons.account_balance_wallet_outlined,
                      'Audit end-of-day physical cash against system collections and bank UPI settlements.',
                      [
                        'Denomination counter for physical cash counting',
                        'Instant calculation of surplus or cash deficit',
                        'End-of-day register closure report',
                        'Reconciliation audit trail for clinic owners',
                      ],
                    ),
                    _buildFeatureCard(
                      'Google Drive Sync',
                      Icons.add_to_drive_outlined,
                      'Sync clinic records directly to the owner\'s Google Drive and structured Google Sheets.',
                      [
                        'Zero vendor lock-in — your data lives in your Drive',
                        'Structured spreadsheets automatically created',
                        'Periodic encrypted backup snapshots',
                        'Standard Google OAuth 2.0 authorization',
                      ],
                    ),
                    _buildFeatureCard(
                      'Offline-Friendly Operations',
                      Icons.cloud_off_outlined,
                      'Front-desk registration and billing never stall when broadband internet goes down.',
                      [
                        'Local database cache powers daily operations',
                        'Automatic queue token generation without active network',
                        'Pending records queue for background sync',
                        'Designed for volatile broadband conditions',
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom CTA
          _buildFeatureCta(context),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    String desc,
    List<String> items,
  ) {
    return Container(
      width: 330,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E), size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 14, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      it,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
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

  Widget _buildFeatureCta(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Text(
              'Experience Apna Clinic in Your Practice',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your free account today and discover how easy clinic management can be.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Create Apna Clinic Account'),
            ),
          ],
        ),
      ),
    );
  }
}

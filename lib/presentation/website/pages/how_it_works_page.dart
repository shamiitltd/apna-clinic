// Apna Clinic - How It Works Page
// Route: /how-it-works

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/website_scaffold.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    const detailedSteps = [
      {
        'step': 'Step 1',
        'title': 'Create Your Account',
        'desc': 'Register your Apna Clinic account from this official website. You can sign up with your Google account or provide your clinic details with email and password.',
        'icon': Icons.person_add_alt_outlined,
      },
      {
        'step': 'Step 2',
        'title': 'Login to the Management System',
        'desc': 'Sign into the Apna Clinic Management System using your registered platform credentials to initialize your clinic workstation.',
        'icon': Icons.login_outlined,
      },
      {
        'step': 'Step 3',
        'title': 'Connect Google Drive',
        'desc': 'Authorize your clinic\'s Google account using standard OAuth. Apna Clinic creates a dedicated workspace and structured Google Sheets for cloud data storage.',
        'icon': Icons.add_to_drive_outlined,
      },
      {
        'step': 'Step 4',
        'title': 'Configure Your Clinic Profile',
        'desc': 'Enter your clinic name, practicing doctor names, medical registration numbers, standard consultation fees, and working hours.',
        'icon': Icons.tune_outlined,
      },
      {
        'step': 'Step 5',
        'title': 'Register & Manage Patients',
        'desc': 'Start registering walk-in and pre-booked patients. Lookup returning patients by phone number in seconds and generate sequential queue tokens.',
        'icon': Icons.people_outline,
      },
      {
        'step': 'Step 6',
        'title': 'Run Daily Clinic Operations',
        'desc': 'Execute the seamless daily flow: Appointments → Queue → Doctor Cabin → Billing → Receipts → Daily Cash Reconciliation.',
        'icon': Icons.check_circle_outline,
      },
    ];

    return WebsiteScaffold(
      activeRoute: '/how-it-works',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
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
                        'STEP-BY-STEP WORKFLOW GUIDE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'How Apna Clinic Works',
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
                      'From registration to daily queue management and billing, see how easily Apna Clinic fits into your daily practice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Steps list
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
              vertical: 64,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  children: detailedSteps.map((s) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(s['icon'] as IconData, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['step'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s['desc'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Bottom CTA
          Container(
            color: const Color(0xFFF0FDFA),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Center(
              child: Column(
                children: [
                  const Text(
                    'Ready to Start with Step 1?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Create Your Apna Clinic Account'),
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

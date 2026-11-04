// Apna Clinic - Official Terms & Conditions Page
// Route: /terms

import 'package:flutter/material.dart';

import '../../../core/config/website_config.dart';
import '../common/website_scaffold.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return WebsiteScaffold(
      activeRoute: '/terms',
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
                        'TERMS OF SERVICE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Terms & Conditions',
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
                      'Published by ${WebsiteConfig.companyName} • Effective October 2026',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Terms Body
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
              vertical: 64,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TermSection(
                      title: '1. Acceptance of Terms',
                      content:
                          'By creating an account, accessing the Apna Clinic website, or utilizing the Apna Clinic Management System, you agree to comply with and be bound by these Terms and Conditions. If you do not agree, please do not use the Software.',
                    ),
                    _TermSection(
                      title: '2. Eligibility & Account Responsibilities',
                      content:
                          'You must be a legally recognized healthcare practitioner, clinic administrator, or authorized representative of a medical practice to create an account. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.',
                    ),
                    _TermSection(
                      title: '3. Clinical Responsibility & Disclaimers',
                      content:
                          'Apna Clinic is exclusively an administrative practice management tool (patient registration, token queues, billing, and reporting). It is NOT a medical diagnostic device, clinical decision-support system, or automated medical practitioner. All clinical diagnoses, prescription decisions, and medical treatments remain the sole responsibility of the practicing physician.',
                    ),
                    _TermSection(
                      title: '4. Google Drive Integration & Data Storage',
                      content:
                          'When you connect your Google Account, Apna Clinic uses Google Drive and Google Sheets APIs to synchronize your clinic records. You remain the legal owner and custodian of your Google Drive files. You are responsible for ensuring sufficient storage quota in your Google Account and maintaining proper access controls for your clinic staff.',
                    ),
                    _TermSection(
                      title: '5. Subscription & Payment Terms',
                      content:
                          'Certain features and access licenses may be subject to subscription fees as outlined in our Pricing Plans or commercial agreements. Subscriptions renew in accordance with agreed billing terms unless cancelled prior to the renewal date.',
                    ),
                    _TermSection(
                      title: '6. Acceptable Use',
                      content:
                          'You agree not to misuse the Software, attempt reverse engineering, tamper with authentication protocols, or transmit malicious code. Any unlawful exploitation of the platform will result in immediate account suspension.',
                    ),
                    _TermSection(
                      title: '7. Limitation of Liability',
                      content:
                          'To the maximum extent permitted by applicable law, SHAMIIT LLP shall not be liable for indirect, incidental, special, consequential, or punitive damages arising out of your access to or inability to use the Software.',
                    ),
                    _TermSection(
                      title: '8. Governing Law & Jurisdiction',
                      content:
                          'These terms shall be governed by and construed in accordance with the laws of India, and any disputes shall be subject to the exclusive jurisdiction of the competent courts.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6),
          ),
        ],
      ),
    );
  }
}

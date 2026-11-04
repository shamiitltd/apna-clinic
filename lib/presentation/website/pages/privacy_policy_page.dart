// Apna Clinic - Official Privacy Policy Page
// Route: /privacy

import 'package:flutter/material.dart';

import '../../../core/config/website_config.dart';
import '../common/website_scaffold.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return WebsiteScaffold(
      activeRoute: '/privacy',
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
                        'LEGAL & COMPLIANCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Privacy Policy',
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
                      'Last Updated: October 2026 • Published by ${WebsiteConfig.companyName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Policy Text
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
                    _LegalSection(
                      title: '1. Introduction & Overview',
                      content:
                          'This Privacy Policy describes how SHAMIIT LLP ("we", "our", or "us"), operator of Apna Clinic ("the Software"), handles information when you use our website (apnaclinic.in) and software applications. We are committed to maintaining transparent data management standards and protecting customer privacy.',
                    ),
                    _LegalSection(
                      title: '2. Information We Collect',
                      content:
                          'We collect information required to deliver, authenticate, and maintain the Software:\n'
                          '• Account Registration Data: Your name, email address, mobile number, clinic/practice name, and authentication credentials.\n'
                          '• Technical & Log Data: Device type, browser environment, IP address, and application diagnostic reports for troubleshooting.\n'
                          '• Inquiries & Communications: Information submitted via our contact and support forms.',
                    ),
                    _LegalSection(
                      title: '3. Authentication & Account Data (Firebase)',
                      content:
                          'We use Google Firebase Authentication and Cloud Firestore to verify account credentials and maintain product access entitlement records. Firebase stores your registered account identity, subscription tier, and clinic setup status.',
                    ),
                    _LegalSection(
                      title: '4. Clinic Operational Records (Google Drive & Google Sheets)',
                      content:
                          'Apna Clinic is architected with customer data sovereignty at its core. Patient demographics, appointment logs, queue tokens, billing invoices, and financial summaries are synchronized directly to the clinic owner\'s authorized Google Drive account using Google Sheets APIs. SHAMIIT LLP does not hold, harvest, or monetize your clinic\'s patient records in proprietary centralized databases.',
                    ),
                    _LegalSection(
                      title: '5. Local Storage & Offline Operations',
                      content:
                          'To ensure daily continuity during broadband disruptions, the Software caches temporary operational records locally within your browser/application storage. These local records synchronize with your Google Drive once connectivity is re-established.',
                    ),
                    _LegalSection(
                      title: '6. Security Safeguards',
                      content:
                          'All network communications with Firebase and Google APIs are transmitted over encrypted TLS/HTTPS protocols. We employ strict client and server authorization controls to prevent unauthorized access to your account profile.',
                    ),
                    _LegalSection(
                      title: '7. Your Rights & Data Portability',
                      content:
                          'Because your operational clinic records are stored directly within your own Google Drive and Google Sheets, you possess complete, continuous access to export, duplicate, or delete your clinic spreadsheets at any time without dependence on our servers.',
                    ),
                    _LegalSection(
                      title: '8. Contact Information',
                      content:
                          'For questions or privacy concerns regarding this policy, please reach out via our official contact portal or email support@apnaclinic.in.',
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

class _LegalSection extends StatelessWidget {
  final String title;
  final String content;

  const _LegalSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6),
          ),
        ],
      ),
    );
  }
}

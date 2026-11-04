// Apna Clinic - Official Data Privacy & Storage Architecture Page
// Route: /data-privacy
// Accurately describes the distinction between Firebase (Auth/Access), Google Drive (Operational Data),
// and Local Storage (Offline Cache) without claiming unobtained regulatory certifications.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/website_scaffold.dart';

class DataPrivacyPage extends StatelessWidget {
  const DataPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return WebsiteScaffold(
      activeRoute: '/data-privacy',
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
                        'TRANSPARENT SYSTEM ARCHITECTURE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Data Storage & Privacy Architecture',
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
                      'Understanding how Apna Clinic separates account authentication from clinic operational data, ensuring you maintain complete control over your practice records.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Core 3-Layer Breakdown
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
              vertical: 64,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The 3-Layer Architecture Explained',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Apna Clinic utilizes a clear, decoupled architectural design to protect clinic autonomy and data sovereignty. Different components handle authentication, day-to-day operations, and cloud synchronization:',
                      style: TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.6),
                    ),
                    const SizedBox(height: 36),

                    // Layer 1: Firebase
                    _buildLayerBox(
                      number: 'LAYER 1',
                      title: 'Firebase Authentication & Account Verification',
                      role: 'Customer Account Identity & Product Access',
                      icon: Icons.vpn_key_outlined,
                      color: const Color(0xFF0284C7),
                      items: [
                        'Used exclusively for user identity management (sign-in via Google or email/password).',
                        'Stores minimal account metadata: account status, product entitlement, and subscription tier.',
                        'Does NOT store your patients\' clinical notes, diagnostic summaries, or appointment history.',
                        'Protected by strict Firebase security rules restricting access to the authenticated account owner.',
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Layer 2: Google Drive & Sheets
                    _buildLayerBox(
                      number: 'LAYER 2',
                      title: 'Google Drive & Google Sheets Cloud Synchronization',
                      role: 'Clinic Operational Records & Backups',
                      icon: Icons.add_to_drive_outlined,
                      color: const Color(0xFF0F766E),
                      items: [
                        'Operational records (patient registers, queue tokens, billing invoices, receipts) synchronize to your own Google Account.',
                        'Data is organized in structured Google Sheets inside a dedicated "Apna Clinic" workspace in the clinic owner\'s Google Drive.',
                        'Zero vendor lock-in: You retain direct access to your Google Sheets at all times, even outside the application.',
                        'All communication with Google APIs occurs over secure, encrypted HTTPS OAuth 2.0 connections.',
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Layer 3: Local Storage
                    _buildLayerBox(
                      number: 'LAYER 3',
                      title: 'Local Secure Storage',
                      role: 'Offline-Friendly Performance & High Availability',
                      icon: Icons.storage_outlined,
                      color: const Color(0xFFD97706),
                      items: [
                        'Enables seamless front-desk operations even when local internet connectivity is erratic or unavailable.',
                        'Maintains local encrypted caching of today\'s queue tokens, patient lookup indexes, and clinic profile.',
                        'Pending changes synchronize automatically to Google Drive once network connectivity is re-established.',
                        'Operates on the user\'s local device environment without exposing clinic traffic to unverified networks.',
                      ],
                    ),

                    const SizedBox(height: 48),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 36),

                    // Ethical & Regulatory Notice
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.gavel_outlined, color: Color(0xFF475569), size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Ethical Product Disclosure & Standards',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Apna Clinic is designed as an operational practice management tool for general practitioners and small healthcare clinics. We believe in total honesty with our users: we do not claim unobtained medical certifications (such as HIPAA, ABDM, or ISO accreditation) unless officially certified. Practitioners are responsible for adhering to their local clinical jurisdiction and ethical obligations regarding patient privacy and consent.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/privacy'),
                            icon: const Icon(Icons.description_outlined, size: 16),
                            label: const Text('Read Full Privacy Policy'),
                          ),
                        ],
                      ),
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

  Widget _buildLayerBox({
    required String number,
    required String title,
    required String role,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    ),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Primary Responsibility: $role',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      it,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
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

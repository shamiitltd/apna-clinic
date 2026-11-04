// Apna Clinic - Official About Page
// Route: /about
// Focuses on product mission, principles, and official SHAMIIT LLP development.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/website_scaffold.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    const principles = [
      {
        'title': 'Radical Simplicity',
        'desc': 'Clinic staff should not need weeks of technical training. Front-desk registration, token generation, and billing can be learned in 10 minutes.',
        'icon': Icons.bolt_outlined,
      },
      {
        'title': 'Practical Daily Workflows',
        'desc': 'Built around the actual rhythm of outpatient consultation: fast walk-ins, phone lookups, physical cash reconciliation, and print-ready slips.',
        'icon': Icons.assignment_outlined,
      },
      {
        'title': 'Customer Data Control',
        'desc': 'No proprietary database lock-in. Clinic operational records synchronize directly to the clinic owner\'s Google Drive and Google Sheets.',
        'icon': Icons.security_outlined,
      },
      {
        'title': 'Affordable Digital Operations',
        'desc': 'Quality clinic software shouldn\'t require expensive server infrastructure, dedicated IT engineers, or exorbitant enterprise licenses.',
        'icon': Icons.savings_outlined,
      },
      {
        'title': 'Fast Learning Curve',
        'desc': 'Intuitive visual layouts for receptionists and doctors mean zero friction during staff turnover.',
        'icon': Icons.school_outlined,
      },
      {
        'title': 'Reliable Daily Usage',
        'desc': 'Local data caching ensures clinic operations never halt when broadband connections encounter downtime.',
        'icon': Icons.offline_bolt_outlined,
      },
    ];

    return WebsiteScaffold(
      activeRoute: '/about',
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
                        'ABOUT APNA CLINIC & SHAMIIT LLP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Empowering Primary Healthcare Practices',
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
                      'Making practical, digital clinic administration accessible to solo practitioners, OPD centers, and independent local healthcare clinics.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Mission & Principles
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
                      'Our Mission',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Most modern healthcare software is engineered for multi-specialty hospitals with complex bureaucratic workflows, high price tags, and mandatory cloud silos. Apna Clinic was created with the conviction that small clinics and general practitioners deserve software tailored to their exact daily reality — lightning-fast registration, simple sequential queues, accurate billing, and complete data ownership.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.6),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Core Product Principles',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: principles.map((p) {
                        return Container(
                          width: isDesktop ? 440 : double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(p['icon'] as IconData, color: const Color(0xFF0F766E), size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      p['desc'] as String,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF475569),
                                        height: 1.4,
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
                    const SizedBox(height: 48),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 36),

                    // Developed by SHAMIIT LLP
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
                          const Row(
                            children: [
                              Icon(Icons.business_outlined, color: Color(0xFF0F766E), size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Developed by SHAMIIT LLP',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Apna Clinic is a proprietary healthcare technology product engineered by SHAMIIT LLP. For official corporate inquiries, licensing agreements, and partnerships, please contact our team through the official contact portal.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF334155),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/contact'),
                            icon: const Icon(Icons.mail_outline, size: 16),
                            label: const Text('Contact SHAMIIT LLP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
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
}

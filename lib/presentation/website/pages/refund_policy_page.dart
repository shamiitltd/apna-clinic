// Apna Clinic - Official Refund Policy Page
// Route: /refund-policy

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/website_config.dart';
import '../common/website_scaffold.dart';

class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return WebsiteScaffold(
      activeRoute: '/refund-policy',
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
                        'CANCELLATION & REFUNDS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Refund Policy',
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

          // Content
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
              vertical: 64,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commercial Evaluation & Refund Guidelines',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'We want every medical practitioner and clinic administrator to feel confident in choosing Apna Clinic. We encourage all new users to fully utilize our complimentary evaluation period to verify that the Software meets their front-desk, queue, and billing requirements before committing to a paid commercial license.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Subscription Cancellations',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'You may cancel your recurring subscription at any time through your Account Dashboard or by submitting a written request to support@apnaclinic.in. Upon cancellation, your account will remain active until the conclusion of the current prepaid billing period, and no further recurring charges will be billed.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Refund Requests & Inquiries',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Refund requests are reviewed on a case-by-case basis by our billing administration team in instances of duplicate billing or verifiable service unavailability. To request an audit of your billing, please contact our support desk with your invoice number and account email.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6),
                    ),
                    const SizedBox(height: 36),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/contact'),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Contact Billing Support'),
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

// Apna Clinic - Official Pricing Page
// Route: /pricing
// Driven strictly by centralized WebsiteConfig.pricingPlans.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/website_config.dart';
import '../common/website_scaffold.dart';

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;
    const plans = WebsiteConfig.pricingPlans;

    return WebsiteScaffold(
      activeRoute: '/pricing',
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
                        'PLANS & LICENSING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Simple, Fair & Predictable Plans',
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
                      'Start with our complete 30-day evaluation. Contact our team for customized clinic licensing tailored to your doctor count and practice scale.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pricing Cards
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
                  children: plans.map((plan) {
                    final isHighlighted = plan.badge != null;
                    return Container(
                      width: isDesktop ? 340 : (isTablet ? 300 : double.infinity),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: isHighlighted ? const Color(0xFFF0FDFA) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isHighlighted ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
                          width: isHighlighted ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isHighlighted)
                            BoxShadow(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (plan.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                plan.badge!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            plan.description,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.price,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (plan.billingPeriod.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  plan.billingPeriod,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                          const Divider(height: 32, color: Color(0xFFE2E8F0)),
                          ...plan.features.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    f.included ? Icons.check : Icons.close,
                                    size: 16,
                                    color: f.included ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: f.included ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (plan.id == 'trial') {
                                  context.go('/register');
                                } else {
                                  context.go('/contact');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isHighlighted
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(plan.cta),
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

          // FAQ Callout
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Center(
              child: Column(
                children: [
                  const Text(
                    'Need custom multi-doctor clinic deployment?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our engineering team can assist with data migration, thermal printer setups, and multi-cabin workflows.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/contact'),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Contact Clinic Sales & Onboarding'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

// Apna Clinic - Official Website Footer
// Rich, responsive footer with product navigation, resource links, legal terms, and dynamic company copyright.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/website_config.dart';

class WebsiteFooter extends StatelessWidget {
  const WebsiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return Container(
      color: const Color(0xFF0F172A), // Deep Slate
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Grid / Columns
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Column
                Expanded(
                  flex: 3,
                  child: _buildBrandColumn(context),
                ),
                const SizedBox(width: 48),
                // Product Links
                Expanded(
                  flex: 2,
                  child: _buildLinkColumn(
                    context,
                    title: 'Product',
                    links: const [
                      _FooterLinkItem('Features', '/features'),
                      _FooterLinkItem('How It Works', '/how-it-works'),
                      _FooterLinkItem('Pricing Plans', '/pricing'),
                      _FooterLinkItem('Login Portal', '/login'),
                      _FooterLinkItem('Create Account', '/register'),
                    ],
                  ),
                ),
                // Resources Links
                Expanded(
                  flex: 2,
                  child: _buildLinkColumn(
                    context,
                    title: 'Resources',
                    links: const [
                      _FooterLinkItem('Support & Help', '/support'),
                      _FooterLinkItem('Data Privacy', '/data-privacy'),
                      _FooterLinkItem('FAQ', '/#faq'),
                      _FooterLinkItem('Contact Support', '/contact'),
                    ],
                  ),
                ),
                // Legal Links
                Expanded(
                  flex: 2,
                  child: _buildLinkColumn(
                    context,
                    title: 'Legal',
                    links: const [
                      _FooterLinkItem('Privacy Policy', '/privacy'),
                      _FooterLinkItem('Terms & Conditions', '/terms'),
                      _FooterLinkItem('Refund Policy', '/refund-policy'),
                      _FooterLinkItem('Data Ownership', '/data-privacy'),
                    ],
                  ),
                ),
                // Company Links
                Expanded(
                  flex: 2,
                  child: _buildLinkColumn(
                    context,
                    title: 'Company',
                    links: const [
                      _FooterLinkItem('About Apna Clinic', '/about'),
                      _FooterLinkItem('SHAMIIT LLP', '/about'),
                      _FooterLinkItem('Contact Us', '/contact'),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildBrandColumn(context),
            const SizedBox(height: 36),
            Wrap(
              spacing: 32,
              runSpacing: 32,
              children: [
                SizedBox(
                  width: isTablet ? 200 : (screenWidth - 40) / 2 - 16,
                  child: _buildLinkColumn(
                    context,
                    title: 'Product',
                    links: const [
                      _FooterLinkItem('Features', '/features'),
                      _FooterLinkItem('How It Works', '/how-it-works'),
                      _FooterLinkItem('Pricing Plans', '/pricing'),
                      _FooterLinkItem('Login', '/login'),
                      _FooterLinkItem('Create Account', '/register'),
                    ],
                  ),
                ),
                SizedBox(
                  width: isTablet ? 200 : (screenWidth - 40) / 2 - 16,
                  child: _buildLinkColumn(
                    context,
                    title: 'Resources',
                    links: const [
                      _FooterLinkItem('Support', '/support'),
                      _FooterLinkItem('Data Privacy', '/data-privacy'),
                      _FooterLinkItem('FAQ', '/#faq'),
                      _FooterLinkItem('Contact', '/contact'),
                    ],
                  ),
                ),
                SizedBox(
                  width: isTablet ? 200 : (screenWidth - 40) / 2 - 16,
                  child: _buildLinkColumn(
                    context,
                    title: 'Legal',
                    links: const [
                      _FooterLinkItem('Privacy Policy', '/privacy'),
                      _FooterLinkItem('Terms', '/terms'),
                      _FooterLinkItem('Refund Policy', '/refund-policy'),
                    ],
                  ),
                ),
                SizedBox(
                  width: isTablet ? 200 : (screenWidth - 40) / 2 - 16,
                  child: _buildLinkColumn(
                    context,
                    title: 'Company',
                    links: const [
                      _FooterLinkItem('About', '/about'),
                      _FooterLinkItem('SHAMIIT LLP', '/about'),
                      _FooterLinkItem('Contact Sales', '/contact'),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 48),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 24),

          // Bottom Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '© $currentYear ${WebsiteConfig.companyName}. All rights reserved.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BottomLegalLink(
                    label: 'Privacy',
                    onTap: () => context.go('/privacy'),
                  ),
                  const SizedBox(width: 16),
                  _BottomLegalLink(
                    label: 'Terms',
                    onTap: () => context.go('/terms'),
                  ),
                  const SizedBox(width: 16),
                  _BottomLegalLink(
                    label: 'Refunds',
                    onTap: () => context.go('/refund-policy'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              WebsiteConfig.productName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          WebsiteConfig.tagline,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2DD4BF), // Teal accent
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Built specifically for individual practitioners, OPD clinics, and local healthcare centers to streamline daily patient flows, token queues, billing, and cloud synchronization.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Color(0xFF2DD4BF)),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Google Drive & Sheets Cloud Sync Architecture',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkColumn(
    BuildContext context, {
    required String title,
    required List<_FooterLinkItem> links,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () {
                if (link.route.startsWith('/#')) {
                  // In SPA, anchor or home
                  context.go('/');
                } else {
                  context.go(link.route);
                }
              },
              child: Text(
                link.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterLinkItem {
  final String label;
  final String route;
  const _FooterLinkItem(this.label, this.route);
}

class _BottomLegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BottomLegalLink({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF94A3B8),
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

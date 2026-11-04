// Apna Clinic - Official Website Navigation Bar
// Sticky responsive navigation with desktop links, mobile drawer, and authentication awareness.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config/website_config.dart';

class WebsiteNavbar extends ConsumerWidget implements PreferredSizeWidget {
  final String activeRoute;

  const WebsiteNavbar({
    super.key,
    required this.activeRoute,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessState = ref.watch(appAccessProvider);
    final isAuthenticated = accessState.isAuthenticated;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 960;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (screenWidth > 1200 ? 64 : 32),
      ),
      child: Row(
        children: [
          // Logo & Branding
          InkWell(
            onTap: () => context.go('/'),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      WebsiteConfig.productName,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'by ${WebsiteConfig.companyName}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Desktop Navigation Links
          if (!isMobile) ...[
            _NavLink(
              label: 'Home',
              route: '/',
              isActive: activeRoute == '/',
              onTap: () => context.go('/'),
            ),
            _NavLink(
              label: 'Features',
              route: '/features',
              isActive: activeRoute == '/features',
              onTap: () => context.go('/features'),
            ),
            _NavLink(
              label: 'How It Works',
              route: '/how-it-works',
              isActive: activeRoute == '/how-it-works',
              onTap: () => context.go('/how-it-works'),
            ),
            _NavLink(
              label: 'Pricing',
              route: '/pricing',
              isActive: activeRoute == '/pricing',
              onTap: () => context.go('/pricing'),
            ),
            _NavLink(
              label: 'About',
              route: '/about',
              isActive: activeRoute == '/about',
              onTap: () => context.go('/about'),
            ),
            _NavLink(
              label: 'Contact',
              route: '/contact',
              isActive: activeRoute == '/contact',
              onTap: () => context.go('/contact'),
            ),
            const SizedBox(width: 16),
          ],

          // Right CTAs (Desktop & Mobile)
          if (!isAuthenticated) ...[
            if (!isMobile)
              TextButton(
                onPressed: () => context.go('/login'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                child: const Text('Login'),
              ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: const Text('Create Account'),
            ),
          ] else ...[
            if (!isMobile)
              OutlinedButton.icon(
                onPressed: () => context.go('/account'),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('My Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => context.go('/dashboard'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Apna Clinic'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],

          // Mobile Drawer Hamburger Button
          if (isMobile) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
              tooltip: 'Navigation Menu',
              onPressed: () => _openMobileMenu(context, isAuthenticated, ref),
            ),
          ],
        ],
      ),
    );
  }

  void _openMobileMenu(BuildContext context, bool isAuthenticated, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          WebsiteConfig.productName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _MobileNavLink(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  route: '/',
                  isActive: activeRoute == '/',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/');
                  },
                ),
                _MobileNavLink(
                  icon: Icons.featured_play_list_outlined,
                  label: 'Features',
                  route: '/features',
                  isActive: activeRoute == '/features',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/features');
                  },
                ),
                _MobileNavLink(
                  icon: Icons.lightbulb_outline,
                  label: 'How It Works',
                  route: '/how-it-works',
                  isActive: activeRoute == '/how-it-works',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/how-it-works');
                  },
                ),
                _MobileNavLink(
                  icon: Icons.local_offer_outlined,
                  label: 'Pricing',
                  route: '/pricing',
                  isActive: activeRoute == '/pricing',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/pricing');
                  },
                ),
                _MobileNavLink(
                  icon: Icons.info_outline,
                  label: 'About Apna Clinic',
                  route: '/about',
                  isActive: activeRoute == '/about',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/about');
                  },
                ),
                _MobileNavLink(
                  icon: Icons.mail_outline,
                  label: 'Contact Us',
                  route: '/contact',
                  isActive: activeRoute == '/contact',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/contact');
                  },
                ),
                _MobileNavLink(
                  icon: Icons.help_outline,
                  label: 'Support & Help',
                  route: '/support',
                  isActive: activeRoute == '/support',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/support');
                  },
                ),
                const Divider(height: 24),
                if (!isAuthenticated) ...[
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/login');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Login to Account'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/register');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Create Apna Clinic Account'),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/account');
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('My Account Portal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/dashboard');
                    },
                    icon: const Icon(Icons.local_hospital_rounded),
                    label: const Text('Open Apna Clinic Management'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final String route;
  final bool isActive;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.route,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFCCFBF1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFF0F766E) : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final VoidCallback onTap;

  const _MobileNavLink({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xFF0F766E) : const Color(0xFF64748B),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
        ),
      ),
      selected: isActive,
      selectedTileColor: const Color(0xFFF0FDFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: onTap,
    );
  }
}

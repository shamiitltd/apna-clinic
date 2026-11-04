// Apna Clinic - Official Support & Help Page
// Route: /support

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/website_scaffold.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _searchController = TextEditingController();
  String _filter = '';

  final List<Map<String, dynamic>> _articles = [
    {
      'category': 'Getting Started',
      'title': 'How to set up your clinic for the first time',
      'desc': 'Walkthrough of setting clinic name, doctor credentials, working hours, and standard consultation charges.',
      'icon': Icons.rocket_launch_outlined,
    },
    {
      'category': 'Account & Login',
      'title': 'Signing in with Google or Email/Password',
      'desc': 'Step-by-step guidance on authenticating your account, password resets, and session recovery.',
      'icon': Icons.lock_open_outlined,
    },
    {
      'category': 'Google Drive Connection',
      'title': 'Connecting your clinic Google account for cloud sync',
      'desc': 'Authorize required Google Drive & Sheets permissions to enable automated operational record syncing.',
      'icon': Icons.add_to_drive_outlined,
    },
    {
      'category': 'Patient Management',
      'title': 'Registering walk-ins and phone lookup',
      'desc': 'How to register a new patient in 30 seconds and find returning patients using their 10-digit mobile number.',
      'icon': Icons.people_outline,
    },
    {
      'category': 'Queue & Tokens',
      'title': 'Managing daily token sequences and calling patients',
      'desc': 'Generating daily tokens, updating waiting and in-cabin statuses, and multi-doctor queue flows.',
      'icon': Icons.confirmation_number_outlined,
    },
    {
      'category': 'Billing & Payments',
      'title': 'Recording Cash, UPI, and Card split payments',
      'desc': 'Creating itemized invoices, handling multiple payment methods, and tracking outstanding balances.',
      'icon': Icons.payments_outlined,
    },
    {
      'category': 'Printing & Hardware',
      'title': 'Configuring thermal receipt printers and consultation slips',
      'desc': 'Supported thermal POS printers (58mm/80mm), standard A4/A5 printers, and reprint options.',
      'icon': Icons.print_outlined,
    },
    {
      'category': 'Reports & Audits',
      'title': 'Daily cash reconciliation and CSV exports',
      'desc': 'Performing end-of-day register closure, counting physical denominations, and auditing cash drawer discrepancies.',
      'icon': Icons.bar_chart_outlined,
    },
    {
      'category': 'Troubleshooting',
      'title': 'Handling internet downtime and offline synchronization',
      'desc': 'How Apna Clinic functions during broadband drops and automatically reconciles pending sync queues upon reconnection.',
      'icon': Icons.wifi_off_outlined,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    final filteredArticles = _articles.where((a) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      final title = (a['title'] as String).toLowerCase();
      final desc = (a['desc'] as String).toLowerCase();
      final cat = (a['category'] as String).toLowerCase();
      return title.contains(q) || desc.contains(q) || cat.contains(q);
    }).toList();

    return WebsiteScaffold(
      activeRoute: '/support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner & Search
          Container(
            color: const Color(0xFFF0FDFA),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
              vertical: 48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'HELP CENTER & DOCUMENTATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'How Can We Help You Today?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 38 : 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _filter = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search help guides (e.g. printing, google drive, billing, tokens)...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0F766E)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Guides Grid
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
              vertical: 64,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: filteredArticles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 16),
                            Text(
                              'No guides found matching "$_filter"',
                              style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: filteredArticles.map((art) {
                          return Container(
                            width: isDesktop ? 460 : double.infinity,
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
                                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(art['icon'] as IconData, color: const Color(0xFF0F766E), size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        art['category'] as String,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        art['title'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        art['desc'] as String,
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
              ),
            ),
          ),

          // Still Need Help?
          Container(
            color: const Color(0xFFF0FDFA),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Center(
              child: Column(
                children: [
                  const Text(
                    'Still have questions or need technical support?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our technical support team is available to assist you with account setup, printer configuration, or sync inquiries.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/contact'),
                    icon: const Icon(Icons.support_agent_outlined, size: 18),
                    label: const Text('Contact Support Team'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
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

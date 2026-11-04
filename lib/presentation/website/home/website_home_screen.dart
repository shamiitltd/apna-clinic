// Apna Clinic - Official Landing Page & Homepage
// Implements complete 19-section SaaS presentation architecture with Deep Medical Teal design tokens,
// responsive layouts, realistic clinic UI previews, Google Drive data ownership, and interactive FAQ.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/website_config.dart';
import '../common/website_scaffold.dart';

class WebsiteHomeScreen extends StatefulWidget {
  const WebsiteHomeScreen({super.key});

  @override
  State<WebsiteHomeScreen> createState() => _WebsiteHomeScreenState();
}

class _WebsiteHomeScreenState extends State<WebsiteHomeScreen> {
  int _activePreviewTab = 0;
  final Set<int> _expandedFaqIndices = {0, 1, 7}; // Default open items

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return WebsiteScaffold(
      activeRoute: '/',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 2: Hero Section
          _buildHeroSection(context, isDesktop, isTablet, screenWidth),

          // Section 3: Trust / Value Strip
          _buildTrustStrip(context, isDesktop, isTablet),

          // Section 4: Problem Statement
          _buildProblemSection(context, isDesktop, isTablet),

          // Section 5: Main Feature Overview
          _buildMainFeatureOverview(context, isDesktop, isTablet),

          // Section 6: Detailed Feature Showcase (12 Features)
          _buildDetailedFeatures(context, isDesktop, isTablet),

          // Section 7: How Apna Clinic Works (6 Steps)
          _buildHowItWorks(context, isDesktop, isTablet),

          // Section 8: Google Drive Data Ownership
          _buildGoogleDriveSection(context, isDesktop, isTablet),

          // Section 9 & 10: Offline-Friendly & Security Architecture
          _buildOfflineAndSecuritySection(context, isDesktop, isTablet),

          // Section 11: Who is Apna Clinic For?
          _buildWhoIsItFor(context, isDesktop, isTablet),

          // Section 12: Benefits Section
          _buildBenefitsSection(context, isDesktop, isTablet),

          // Section 13: Product Workflow (Visual Pipeline)
          _buildProductWorkflow(context, isDesktop, isTablet),

          // Section 14: Screens / Product Preview Showcase
          _buildProductPreview(context, isDesktop, isTablet),

          // Section 15: Pricing Overview
          _buildPricingSection(context, isDesktop, isTablet),

          // Section 16: FAQ Accordion
          _buildFaqSection(context, isDesktop, isTablet),

          // Section 17 & 18: High-Conversion CTA & Contact Banner
          _buildCtaAndContactSection(context, isDesktop, isTablet),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 2: HERO SECTION
  // ---------------------------------------------------------------------------
  Widget _buildHeroSection(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    double screenWidth,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF0FDFA), // Very light teal
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: isDesktop ? 64 : 40,
      ),
      child: Column(
        children: [
          // Trust Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF99F6E4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: Color(0xFF0F766E),
                ),
                SizedBox(width: 8),
                Text(
                  'Modern Healthcare SaaS by ${WebsiteConfig.companyName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Headline
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Text(
              'Manage Your Clinic. Simply.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: isDesktop ? 52 : (isTablet ? 38 : 28),
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                height: 1.15,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Subtitle / Supporting Copy
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              'Apna Clinic helps doctors and clinics manage patients, appointments, queues, consultation billing, payments, receipts and daily operations from one simple platform.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 18 : 15,
                color: const Color(0xFF475569),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/register'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Start with Apna Clinic'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/features'),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Explore Features'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Interactive Product UI Mockup / Dashboard Preview
          _buildHeroProductMockup(context, isDesktop, isTablet),
        ],
      ),
    );
  }

  Widget _buildHeroProductMockup(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1100),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Browser / App Window Chrome
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text(
                          'https://apnaclinic.in/dashboard — Reception Desk & Live OPD Queue',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_done, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text('Drive Synced', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Dashboard Screen Content Preview
          Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Statistics Row
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildHeroMetricCard(
                      title: 'TODAY\'S REGISTERED',
                      value: '24 Patients',
                      subtitle: '9 Walk-in • 15 Booked',
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF0F766E),
                    ),
                    _buildHeroMetricCard(
                      title: 'ACTIVE QUEUE',
                      value: 'Token #07 Calling',
                      subtitle: '4 Waiting in Reception',
                      icon: Icons.confirmation_number_outlined,
                      color: const Color(0xFF0284C7),
                    ),
                    _buildHeroMetricCard(
                      title: 'COLLECTIONS TODAY',
                      value: '₹14,200',
                      subtitle: '₹8,500 Cash • ₹5,700 UPI',
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF059669),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Mock Live Queue Table
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 1, child: Text('TOKEN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                            Expanded(flex: 3, child: Text('PATIENT NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                            Expanded(flex: 2, child: Text('PHONE / UHID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                            Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                            Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                          ],
                        ),
                      ),
                      _buildMockQueueRow('#07', 'Ramesh Kumar', '+91 98765 43210', 'In Cabin (Dr. Sharma)', const Color(0xFF059669), isCurrent: true),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      _buildMockQueueRow('#08', 'Sunita Devi', '+91 98123 45678', 'Waiting (Est. 10m)', const Color(0xFF0284C7)),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      _buildMockQueueRow('#09', 'Amit Patel', '+91 99887 76655', 'Waiting', const Color(0xFF64748B)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockQueueRow(
    String token,
    String patientName,
    String phone,
    String status,
    Color statusColor, {
    bool isCurrent = false,
  }) {
    return Container(
      color: isCurrent ? const Color(0xFFF0FDF4) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              token,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isCurrent ? const Color(0xFF059669) : const Color(0xFF0F172A),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              patientName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              phone,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF059669) : const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCurrent ? 'Consulting' : 'Call Next',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 3: TRUST / VALUE STRIP
  // ---------------------------------------------------------------------------
  Widget _buildTrustStrip(BuildContext context, bool isDesktop, bool isTablet) {
    const items = [
      {'icon': Icons.flash_on_outlined, 'title': 'Fast Patient Registration'},
      {'icon': Icons.queue_outlined, 'title': 'Smart Queue Management'},
      {'icon': Icons.receipt_long_outlined, 'title': 'Simple Consultation Billing'},
      {'icon': Icons.calendar_today_outlined, 'title': 'Appointment Scheduling'},
      {'icon': Icons.cloud_done_outlined, 'title': 'Google Drive Data Ownership'},
      {'icon': Icons.wifi_off_outlined, 'title': 'Offline-Friendly Operations'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 16),
        vertical: 24,
      ),
      child: Center(
        child: Wrap(
          spacing: isDesktop ? 36 : 20,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: items.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 20,
                  color: const Color(0xFF0F766E),
                ),
                const SizedBox(width: 8),
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 4: PROBLEM STATEMENT
  // ---------------------------------------------------------------------------
  Widget _buildProblemSection(BuildContext context, bool isDesktop, bool isTablet) {
    final problems = [
      {'title': 'Manual Patient Registers', 'desc': 'Handwritten notebooks get lost, torn, or misplaced when returning patients visit.'},
      {'title': 'Difficult Patient Lookup', 'desc': 'Flipping through paper pages wastes precious minutes at the reception desk.'},
      {'title': 'Handwritten Queue Tracking', 'desc': 'Arguments over waiting order and token sequences create clinic chaos.'},
      {'title': 'Manual Billing Calculations', 'desc': 'Errors in pricing, discounts, and handwritten receipts cause financial loss.'},
      {'title': 'Missing Consultation Slips', 'desc': 'Unprofessional or illegible paper slips reduce patient trust.'},
      {'title': 'Appointment Confusion', 'desc': 'Double-booked slots and walk-in clashes overwhelm the doctor cabin.'},
      {'title': 'Cash & UPI Reconciliation', 'desc': 'End-of-day math doesn\'t match actual money in the drawer.'},
      {'title': 'Scattered Clinic Records', 'desc': 'No single place to analyze patient visit trends and clinic revenue.'},
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'THE PROBLEM WITH TRADITIONAL CLINIC ADMINISTRATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Running a Clinic Shouldn\'t Mean Managing Paperwork All Day',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: const Text(
              'Most doctors spend unnecessary energy juggling paper registers, tracking tokens on whiteboards, and calculating bills manually at the end of every exhausting OPD shift.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5),
            ),
          ),
          const SizedBox(height: 40),

          // Problem Cards Grid
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: problems.map((p) {
              return Container(
                width: isDesktop ? 260 : (isTablet ? 280 : double.infinity),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cancel_outlined, color: Color(0xFFE11D48), size: 22),
                    const SizedBox(height: 12),
                    Text(
                      p['title']!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF881337),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p['desc']!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4C0519),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 48),

          // Solution Banner
          Container(
            constraints: const BoxConstraints(maxWidth: 880),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF5EEAD4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF0F766E), size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Apna Clinic brings these daily operations together without turning your clinic into a complicated hospital ERP.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF134E4A),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 5: MAIN FEATURE OVERVIEW
  // ---------------------------------------------------------------------------
  Widget _buildMainFeatureOverview(BuildContext context, bool isDesktop, bool isTablet) {
    const pillars = [
      {
        'icon': Icons.badge_outlined,
        'title': 'Front-Desk Patient Desk',
        'desc': 'Quick registration, returning patient lookup by mobile number, duplicate detection, and instant token generation.',
      },
      {
        'icon': Icons.queue_music_outlined,
        'title': 'Intelligent Live Queue',
        'desc': 'Real-time doctor queues, automatic status progression, next-patient callout, and smooth waiting-room flow.',
      },
      {
        'icon': Icons.point_of_sale_outlined,
        'title': 'Consultation Billing & Slips',
        'desc': 'Itemized invoices, Cash / UPI / Card splits, sequential invoice numbering, and print-ready receipts.',
      },
      {
        'icon': Icons.folder_shared_outlined,
        'title': 'Google Drive Cloud Sync',
        'desc': 'Synchronize operational records directly to the clinic owner\'s Google Drive and Google Sheets with zero vendor lock-in.',
      },
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'ENGINEERED FOR PRACTICAL CLINICAL DAILY USE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Core Operational Pillars',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: pillars.map((p) {
              return Container(
                width: isDesktop ? 260 : (isTablet ? 280 : double.infinity),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(p['icon'] as IconData, color: const Color(0xFF0F766E), size: 28),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      p['title'] as String,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p['desc'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 6: DETAILED FEATURE SHOWCASE (12 Features)
  // ---------------------------------------------------------------------------
  Widget _buildDetailedFeatures(BuildContext context, bool isDesktop, bool isTablet) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'FEATURE DOCUMENTATION & CAPABILITIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0369A1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Complete Feature Breakdown',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Every capability is built around real daily clinic workflows, not bloated hospital ERP overhead.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 48),

          // 12 Feature Cards in a 3-column / responsive grid
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureDetailCard(
                number: '01',
                title: 'Patient Management',
                icon: Icons.person_add_alt_1_outlined,
                bullets: [
                  'Quick patient registration in under 30 seconds',
                  'Unique Patient Identification (UHID)',
                  'Instant search by 10-digit mobile number or name',
                  'Duplicate registration prevention and warning',
                  'Returning patient workflow with historical visits',
                ],
              ),
              _buildFeatureDetailCard(
                number: '02',
                title: 'Smart Queue Management',
                icon: Icons.confirmation_number_outlined,
                bullets: [
                  'Daily sequential token generation',
                  'Doctor-wise individual consultation queues',
                  'Waiting, In-Cabin, and Completed status tracker',
                  'Call Next Patient button with cabin notification',
                  'Real-time reception and waiting room synchronization',
                ],
              ),
              _buildFeatureDetailCard(
                number: '03',
                title: 'Doctor Workstation',
                icon: Icons.medical_services_outlined,
                bullets: [
                  'Doctor-specific queue screen with large token view',
                  'One-click Call Next, Start, and Complete visit',
                  'Follow-up date picker and patient history view',
                  'Distraction-free cabin interface optimized for speed',
                  'Clear distinction between operational and clinical notes',
                ],
              ),
              _buildFeatureDetailCard(
                number: '04',
                title: 'Appointments',
                icon: Icons.event_note_outlined,
                bullets: [
                  'Interactive appointment calendar and daily schedule',
                  'Doctor selection and dynamic time-slot configuration',
                  'Double-booking and schedule conflict detection',
                  'One-click rescheduling and cancellation with reason',
                  'Seamless appointment-to-queue check-in on patient arrival',
                ],
              ),
              _buildFeatureDetailCard(
                number: '05',
                title: 'Consultation Billing',
                icon: Icons.request_quote_outlined,
                bullets: [
                  'Transparent consultation billing and procedure charges',
                  'Multi-mode payments: Cash, UPI (QR), and Card',
                  'Partial payments and outstanding balance tracking',
                  'Sequential, tamper-evident invoice numbering',
                  'Accurate integer calculations with zero rounding drift',
                ],
              ),
              _buildFeatureDetailCard(
                number: '06',
                title: 'Consultation Slip',
                icon: Icons.description_outlined,
                bullets: [
                  'Standard A4 and A5 printable consultation slips',
                  'Clinic branding, clinic address, and contact numbers',
                  'Doctor qualification and registration number header',
                  'Patient demographic details and daily token number',
                  'Structured sections for diagnosis, vitals, and follow-up',
                ],
              ),
              _buildFeatureDetailCard(
                number: '07',
                title: 'Receipt Printing',
                icon: Icons.receipt_outlined,
                bullets: [
                  'Professional tax-compliant patient receipts',
                  'Clear itemized breakdown of consultation & procedures',
                  'Exact payment method logged (Cash/UPI/Card/Split)',
                  'Reprint functionality for historical visits',
                  'Thermal receipt and standard desktop printer compatible',
                ],
              ),
              _buildFeatureDetailCard(
                number: '08',
                title: 'Daily Cash Reconciliation',
                icon: Icons.account_balance_wallet_outlined,
                bullets: [
                  'Total daily collections broken down by payment mode',
                  'Physical cash counting tool (Denomination calculator)',
                  'Automated cash drawer difference detection (Surplus/Deficit)',
                  'End-of-day register closure and reconciliation summary',
                  'Accountant & Owner audit trail for financial accountability',
                ],
              ),
              _buildFeatureDetailCard(
                number: '09',
                title: 'Reports & Analytics',
                icon: Icons.insert_chart_outlined,
                bullets: [
                  'Daily, weekly, and monthly clinic operational statistics',
                  'Patient visit volume and peak OPD hour analysis',
                  'Revenue and collection summaries by payment channel',
                  'Doctor-wise visit counts and fee breakdowns',
                  'CSV spreadsheet export for tax and external accounting',
                ],
              ),
              _buildFeatureDetailCard(
                number: '10',
                title: 'Google Drive Integration',
                icon: Icons.add_to_drive_outlined,
                bullets: [
                  'Connect directly to the clinic owner\'s Google Account',
                  'Automatically maintains structured Google Sheets records',
                  'Encrypted periodic cloud backups stored in Drive',
                  'Zero vendor lock-in — you own your operational sheets',
                  'Transparent OAuth 2.0 authorization with scoped access',
                ],
              ),
              _buildFeatureDetailCard(
                number: '11',
                title: 'Offline-Friendly Operations',
                icon: Icons.cloud_off_outlined,
                bullets: [
                  'Continue registering patients even during internet outages',
                  'Queue progression and token generation work locally',
                  'Local SQLite / secure cache ensures high availability',
                  'Automatic pending sync when connection restores',
                  'Never halts front-desk operations during broadband drops',
                ],
              ),
              _buildFeatureDetailCard(
                number: '12',
                title: 'Multi-Role Staff Access',
                icon: Icons.groups_outlined,
                bullets: [
                  'Role-tailored interfaces: Owner, Doctor, Receptionist, Accountant',
                  'Receptionist: Patient registration, token queue, billing',
                  'Doctor: Cabin workstation, queue callout, follow-up dates',
                  'Accountant: Financial ledger, reconciliation, revenue reports',
                  'Owner: Comprehensive admin settings, staff, and analytics',
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDetailCard({
    required String number,
    required String title,
    required IconData icon,
    required List<String> bullets,
  }) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF0F766E), size: 24),
              ),
              Text(
                number,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check, size: 14, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
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

  // ---------------------------------------------------------------------------
  // SECTION 7: HOW APNA CLINIC WORKS (6 Steps)
  // ---------------------------------------------------------------------------
  Widget _buildHowItWorks(BuildContext context, bool isDesktop, bool isTablet) {
    const steps = [
      {
        'step': '1',
        'title': 'Create Your Account',
        'desc': 'Register your Apna Clinic account from this official website using Google Sign-in or email.',
      },
      {
        'step': '2',
        'title': 'Login to Management Portal',
        'desc': 'Sign into the Apna Clinic Management System using your verified platform credentials.',
      },
      {
        'step': '3',
        'title': 'Connect Google Drive',
        'desc': 'Authorize your clinic\'s Google account to initialize your structured cloud sheets and backups.',
      },
      {
        'step': '4',
        'title': 'Configure Your Clinic',
        'desc': 'Set clinic name, practicing doctor names, registration numbers, consultation fees, and timings.',
      },
      {
        'step': '5',
        'title': 'Start Managing Patients',
        'desc': 'Register incoming patients, schedule appointments, and generate daily sequential tokens.',
      },
      {
        'step': '6',
        'title': 'Run Daily Operations',
        'desc': 'Execute the seamless flow: Appointments → Queue → Consultation → Billing → Receipts → Reports.',
      },
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'SIMPLE 6-STEP ONBOARDING & SETUP',
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
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Get your clinic operational in minutes without complicated server installations or IT consultants.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 48),

          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: steps.map((s) {
              return Container(
                width: isDesktop ? 340 : (isTablet ? 280 : double.infinity),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F766E),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          s['step']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s['title']!,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s['desc']!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 8: GOOGLE DRIVE DATA OWNERSHIP
  // ---------------------------------------------------------------------------
  Widget _buildGoogleDriveSection(BuildContext context, bool isDesktop, bool isTablet) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: EdgeInsets.all(isDesktop ? 48 : 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF115E59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'SOVEREIGN CLINIC DATA STORAGE',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your Clinic Data, Connected to Your Google Drive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),
                child: const Text(
                  'Unlike closed proprietary software where your clinic data is held hostage in third-party databases, Apna Clinic connects directly to the clinic owner\'s Google Drive workspace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFFCCFBF1), height: 1.6),
                ),
              ),
              const SizedBox(height: 36),

              // Architectural Pipeline Diagram
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildPipelineStep('Apna Clinic App', Icons.computer),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF5EEAD4), size: 18),
                    _buildPipelineStep('Local Secure Cache', Icons.save_alt),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF5EEAD4), size: 18),
                    _buildPipelineStep('Secure OAuth Sync', Icons.sync),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF5EEAD4), size: 18),
                    _buildPipelineStep('Google Sheets', Icons.table_chart),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF5EEAD4), size: 18),
                    _buildPipelineStep('Owner\'s Google Drive', Icons.cloud),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/data-privacy'),
                    icon: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                    label: const Text('See How Data Storage Works'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineStep(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF5EEAD4)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 9 & 10: OFFLINE-FRIENDLY & SECURITY ARCHITECTURE
  // ---------------------------------------------------------------------------
  Widget _buildOfflineAndSecuritySection(BuildContext context, bool isDesktop, bool isTablet) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'RELIABILITY & ARCHITECTURE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Offline-First Engineering Meets Modern Security',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),

          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildArchitectureBox(
                title: 'Offline-Friendly Daily Operations',
                subtitle: 'Designed for real clinic internet conditions',
                icon: Icons.wifi_off_rounded,
                desc: 'Day-to-day clinic operations can continue using local application data even when connectivity is unstable. Staff can register walk-in patients, update queue tokens, and generate bills offline. Pending changes synchronize seamlessly to Google Drive when internet connectivity restores.',
              ),
              _buildArchitectureBox(
                title: 'Clear Separation of Responsibilities',
                subtitle: 'Firebase Access vs Google Drive Operational Data',
                icon: Icons.lock_outline_rounded,
                desc: 'Firebase Authentication is used solely for customer account verification and product access entitlements. Medical operational records and patient details are synchronized directly to the clinic owner\'s Google Drive and Google Sheets, ensuring strict ownership and transparency.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required String desc,
  }) {
    return Container(
      width: 520,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF0F766E), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 11: WHO IS IT FOR?
  // ---------------------------------------------------------------------------
  Widget _buildWhoIsItFor(BuildContext context, bool isDesktop, bool isTablet) {
    const segments = [
      {
        'title': 'Independent Doctors',
        'subtitle': 'Solo Practitioners',
        'desc': 'Simple daily clinic administration, queue management, and patient record keeping without receptionist overhead.',
        'icon': Icons.person_pin_outlined,
      },
      {
        'title': 'Small OPD Clinics',
        'subtitle': 'Front-Desk & Consulting',
        'desc': 'Streamline front-desk reception, appointment calendars, token printing, and consultation billing effortlessly.',
        'icon': Icons.storefront_outlined,
      },
      {
        'title': 'Multi-Doctor Clinics',
        'subtitle': 'Shared Reception',
        'desc': 'Doctor-specific consultation queues, distinct fee structures, and doctor-wise daily collection summaries.',
        'icon': Icons.groups_outlined,
      },
      {
        'title': 'Growing Practices',
        'subtitle': 'Local Healthcare Centers',
        'desc': 'Structured clinic operations and daily cash reconciliation without the massive cost of hospital ERPs.',
        'icon': Icons.trending_up_outlined,
      },
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'TAILORED FOR PRIMARY & SPECIALTY CARE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0369A1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Who Is Apna Clinic For?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),

          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: segments.map((s) {
              return Container(
                width: isDesktop ? 260 : (isTablet ? 280 : double.infinity),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(s['icon'] as IconData, size: 32, color: const Color(0xFF0F766E)),
                    const SizedBox(height: 16),
                    Text(
                      s['title'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      s['subtitle'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s['desc'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 12: BENEFITS SECTION
  // ---------------------------------------------------------------------------
  Widget _buildBenefitsSection(BuildContext context, bool isDesktop, bool isTablet) {
    const benefits = [
      {'title': 'Save Reception Time', 'desc': 'Fast patient registration and phone-based lookup reduce check-in time to seconds.'},
      {'title': 'Organize Patient Flow', 'desc': 'Clear sequential tokens eliminate waiting-room congestion and disputes.'},
      {'title': 'Simplify Billing & Ledger', 'desc': 'Manage consultation charges, Cash/UPI/Card splits, and instant receipts.'},
      {'title': 'Reduce Manual Records', 'desc': 'Move away from paper notebooks to searchable, permanent structured records.'},
      {'title': 'Know Daily Collections', 'desc': 'Understand exact cash drawer collections versus bank UPI deposits every evening.'},
      {'title': 'Control Your Clinic Data', 'desc': 'Your records stay synchronized in your personal Google Drive and Google Sheets.'},
      {'title': 'Work Through Disconnections', 'desc': 'Offline-friendly architecture ensures clinic staff can always work uninterrupted.'},
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'MEASURABLE CLINIC ADVANTAGES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tangible Daily Benefits',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),

          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: benefits.map((b) {
              return Container(
                width: isDesktop ? 340 : (isTablet ? 280 : double.infinity),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF0F766E), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b['title']!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b['desc']!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 13: PRODUCT WORKFLOW
  // ---------------------------------------------------------------------------
  Widget _buildProductWorkflow(BuildContext context, bool isDesktop, bool isTablet) {
    const pipeline = [
      {'title': 'Patient Arrival', 'icon': Icons.directions_walk_outlined},
      {'title': 'Registration', 'icon': Icons.how_to_reg_outlined},
      {'title': 'Appointment / Walk-in', 'icon': Icons.calendar_month_outlined},
      {'title': 'Token Issuance', 'icon': Icons.confirmation_number_outlined},
      {'title': 'Live Queue', 'icon': Icons.format_list_numbered_outlined},
      {'title': 'Doctor Cabin', 'icon': Icons.medical_services_outlined},
      {'title': 'Billing & Split', 'icon': Icons.point_of_sale_outlined},
      {'title': 'Payment & Receipt', 'icon': Icons.receipt_long_outlined},
      {'title': 'Cloud Sync & Reports', 'icon': Icons.analytics_outlined},
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'END-TO-END PATIENT LIFECYCLE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'The Daily Clinic Operational Workflow',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),

          Wrap(
            spacing: 12,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (int i = 0; i < pipeline.length; i++) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        pipeline[i]['icon'] as IconData,
                        color: const Color(0xFF0F766E),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pipeline[i]['title'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < pipeline.length - 1)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF94A3B8),
                    size: 18,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 14: SCREENS / PRODUCT PREVIEW
  // ---------------------------------------------------------------------------
  Widget _buildProductPreview(BuildContext context, bool isDesktop, bool isTablet) {
    const tabs = ['Dashboard', 'Patient Desk', 'Doctor Queue', 'Billing & Ledger', 'Reports'];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'LIVE PRODUCT SCREENS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Explore the Actual Clinic Management System',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),

          // Tabs
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(tabs.length, (idx) {
              final isSelected = _activePreviewTab == idx;
              return ChoiceChip(
                label: Text(tabs[idx]),
                selected: isSelected,
                selectedColor: const Color(0xFF0F766E),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _activePreviewTab = idx);
                },
              );
            }),
          ),
          const SizedBox(height: 32),

          // Active Preview Screen Card
          Container(
            constraints: const BoxConstraints(maxWidth: 960),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _buildSelectedTabPreview(_activePreviewTab),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTabPreview(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _buildPreviewCard(
          title: 'Reception Dashboard & Today\'s Overview',
          summary: 'Live token distribution, registered walk-ins, and active cash drawer statistics.',
          content: const [
            'Total Patients Today: 24 (9 Walk-in • 15 Pre-booked Appointments)',
            'Tokens Active: 4 Waiting • 1 In-Cabin • 19 Completed Visits',
            'Financial Collections: ₹14,200 (Cash: ₹8,500, UPI: ₹5,700)',
            'Google Drive Status: Connected & Synchronized to primary clinic sheet',
          ],
        );
      case 1:
        return _buildPreviewCard(
          title: 'Patient Management Desk',
          summary: 'Fast 30-second patient registration and 10-digit mobile number lookup.',
          content: [
            'Instant duplicate warning when mobile number matches existing records',
            'Complete historical visit log with consultation dates and billed items',
            'Printable patient demographic summary and registration barcode',
            'Search filters by Name, Phone, and UHID identification number',
          ],
        );
      case 2:
        return _buildPreviewCard(
          title: 'Doctor Cabin Workstation',
          summary: 'Clean, focused interface designed specifically for consulting doctors.',
          content: [
            'Large active token display with clear patient age and gender badge',
            'Call Next Patient button with audio/visual reception chime',
            'Quick follow-up date calendar and consultation status progression',
            'No cumbersome electronic health record typing required',
          ],
        );
      case 3:
        return _buildPreviewCard(
          title: 'Billing, Receipts & Cash Drawer',
          summary: 'Transparent billing calculations with zero rounding discrepancies.',
          content: [
            'Sequential invoice generation with clinic header and GSTIN if configured',
            'Support for split payment combinations (e.g. ₹500 Cash + ₹700 UPI)',
            'Standard thermal receipt printing and A5 invoice format',
            'Cash drawer reconciliation tool to audit end-of-day physical currency',
          ],
        );
      case 4:
      default:
        return _buildPreviewCard(
          title: 'Clinic Performance & Revenue Reports',
          summary: 'Accurate operational insights without complex database exports.',
          content: [
            'Daily, weekly, and monthly patient count graphs and trends',
            'Revenue breakdown categorized by cash, UPI, and debit cards',
            'Doctor-wise patient volumes and consultation earnings',
            'Instant CSV download compatible with Google Sheets and MS Excel',
          ],
        );
    }
  }

  Widget _buildPreviewCard({
    required String title,
    required String summary,
    required List<String> content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF0F766E), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          summary,
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        const Divider(height: 32, color: Color(0xFFE2E8F0)),
        ...content.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.chevron_right_rounded, color: Color(0xFF0F766E), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 15: PRICING SECTION
  // ---------------------------------------------------------------------------
  Widget _buildPricingSection(BuildContext context, bool isDesktop, bool isTablet) {
    const plans = WebsiteConfig.pricingPlans;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'AFFORDABLE & TRANSPARENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Simple Pricing for Every Clinic',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start with our complete feature evaluation. Contact our team for customized clinic licensing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 48),

          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: plans.map((plan) {
              return Container(
                width: isDesktop ? 340 : (isTablet ? 300 : double.infinity),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: plan.badge != null ? const Color(0xFFF0FDFA) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: plan.badge != null ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
                    width: plan.badge != null ? 2 : 1,
                  ),
                  boxShadow: [
                    if (plan.badge != null)
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
                          backgroundColor: plan.badge != null ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 16: FAQ ACCORDION
  // ---------------------------------------------------------------------------
  Widget _buildFaqSection(BuildContext context, bool isDesktop, bool isTablet) {
    const faqs = WebsiteConfig.faqList;

    return Container(
      key: const ValueKey('faq_section'),
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Center(
        child: Container(
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
                  'FREQUENTLY ASKED QUESTIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Got Questions? We Have Answers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 40),

              // Accordion list
              Column(
                children: List.generate(faqs.length, (idx) {
                  final faq = faqs[idx];
                  final isExpanded = _expandedFaqIndices.contains(idx);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isExpanded ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
                        width: isExpanded ? 1.5 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              faq.question,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isExpanded ? const Color(0xFF0F766E) : const Color(0xFF0F172A),
                              ),
                            ),
                            trailing: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: isExpanded ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                            ),
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedFaqIndices.remove(idx);
                                } else {
                                  _expandedFaqIndices.add(idx);
                                }
                              });
                            },
                          ),
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                faq.answer,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF475569),
                                  height: 1.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 17 & 18: HIGH-CONVERSION CTA & CONTACT STRIP
  // ---------------------------------------------------------------------------
  Widget _buildCtaAndContactSection(BuildContext context, bool isDesktop, bool isTablet) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
        vertical: 64,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 960),
          padding: EdgeInsets.all(isDesktop ? 48 : 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Ready to Simplify Your Clinic Operations?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: const Text(
                  'Create your Apna Clinic account today, connect your clinic\'s Google Drive, and start managing patients with professional precision.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFCCFBF1),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F766E),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Create Free Account'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/pricing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('View Pricing Plans'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/contact'),
                    icon: const Icon(Icons.mail_outline, size: 18, color: Colors.white),
                    label: const Text('Contact Support & Sales'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

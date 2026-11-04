// Apna Clinic - Official Contact & Inquiry Page
// Route: /contact
// Backed by real Firestore persistence (`contact_inquiries/{id}`) with complete validation and feedback states.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/config/website_config.dart';
import '../common/website_scaffold.dart';

class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _orgController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedCategory = 'Product Inquiry';
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _errorMessage;

  final List<String> _categories = [
    'Product Inquiry',
    'Pricing & Licensing',
    'Schedule a Demo',
    'Technical Support',
    'Account Issue',
    'Partnership',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _orgController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitInquiry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final success = await authRepo.submitContactInquiry(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        message: _messageController.text.trim(),
        phone: _phoneController.text.trim(),
        organization: _orgController.text.trim(),
        subject: _subjectController.text.trim().isEmpty ? _selectedCategory : _subjectController.text.trim(),
        category: _selectedCategory,
      );

      if (success) {
        setState(() {
          _isSuccess = true;
          _isSubmitting = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Unable to send message at this time. Please try again or email us directly.';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error submitting message: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return WebsiteScaffold(
      activeRoute: '/contact',
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
                        'CONTACT & SUPPORT PORTAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Get in Touch with Our Team',
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
                      'Have questions about Apna Clinic, need a live demonstration, or require assistance with your account? Fill out the inquiry form below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.5),
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
                constraints: const BoxConstraints(maxWidth: 960),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildContactForm()),
                          const SizedBox(width: 48),
                          Expanded(flex: 2, child: _buildContactInfoBox()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildContactForm(),
                          const SizedBox(height: 48),
                          _buildContactInfoBox(),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactForm() {
    if (_isSuccess) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Thank You! Message Received',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your inquiry has been successfully sent to the Apna Clinic support team. We will review your message and reach out shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF166534), height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isSuccess = false;
                  _nameController.clear();
                  _emailController.clear();
                  _phoneController.clear();
                  _orgController.clear();
                  _subjectController.clear();
                  _messageController.clear();
                });
              },
              child: const Text('Send Another Message'),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send an Inquiry',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 20),

          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B))),
                  ),
                ],
              ),
            ),

          // Name & Email
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Phone & Clinic Name
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _orgController,
                  decoration: const InputDecoration(
                    labelText: 'Clinic / Organization',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Purpose Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Inquiry Purpose',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
          const SizedBox(height: 16),

          // Subject
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Message
          TextFormField(
            controller: _messageController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Message / Details *',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              contentPadding: EdgeInsets.all(14),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your message' : null,
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitInquiry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Inquiry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoBox() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Official Contact Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Apna Clinic is developed and maintained by SHAMIIT LLP. Reach out to us through any of our official channels:',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
          ),
          const Divider(height: 32, color: Color(0xFFE2E8F0)),
          _buildInfoRow(Icons.email_outlined, 'Support & Sales Email', WebsiteConfig.supportEmail),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.business_outlined, 'Company Entity', WebsiteConfig.companyName),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.cloud_outlined, 'Web Portal', WebsiteConfig.websiteUrl),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF99F6E4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.access_time_outlined, color: Color(0xFF0F766E), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Inquiry Response Time: Within 24-48 business hours.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF134E4A), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0F766E)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            ],
          ),
        ),
      ],
    );
  }
}

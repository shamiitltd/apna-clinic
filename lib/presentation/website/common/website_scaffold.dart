// Apna Clinic - Website Scaffold
// Provides unified layout structure, sticky navbar, scroll view, and footer across all marketing and public pages.

import 'package:flutter/material.dart';

import 'website_navbar.dart';
import 'website_footer.dart';

class WebsiteScaffold extends StatelessWidget {
  final String activeRoute;
  final Widget child;
  final bool showFooter;
  final ScrollController? scrollController;

  const WebsiteScaffold({
    super.key,
    required this.activeRoute,
    required this.child,
    this.showFooter = true,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: WebsiteNavbar(activeRoute: activeRoute),
      body: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            child,
            if (showFooter) const WebsiteFooter(),
          ],
        ),
      ),
    );
  }
}

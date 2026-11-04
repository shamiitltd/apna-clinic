// Apna Clinic - Centralized Application Router & Route Guard
// Manages public marketing website routes, customer account portal routes, and clinical management barriers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth/app_access_notifier.dart';
import '../../application/providers.dart';
import '../../core/permissions/roles.dart';
import '../../domain/services/authorization_service.dart';

// Presentation - Website Public Pages
import '../../presentation/website/home/website_home_screen.dart';
import '../../presentation/website/pages/features_page.dart';
import '../../presentation/website/pages/how_it_works_page.dart';
import '../../presentation/website/pages/pricing_page.dart';
import '../../presentation/website/pages/about_page.dart';
import '../../presentation/website/pages/contact_page.dart';
import '../../presentation/website/pages/support_page.dart';
import '../../presentation/website/pages/data_privacy_page.dart';
import '../../presentation/website/pages/privacy_policy_page.dart';
import '../../presentation/website/pages/terms_page.dart';
import '../../presentation/website/pages/refund_policy_page.dart';

// Presentation - Account Portal & Auth
import '../../presentation/auth/login_screen.dart';
import '../../presentation/website/account/register_screen.dart';
import '../../presentation/website/account/forgot_password_screen.dart';
import '../../presentation/website/account/account_dashboard_screen.dart';
import '../../presentation/website/account/account_profile_screen.dart';
import '../../presentation/website/account/account_subscription_screen.dart';

// Presentation - Clinic Management Screens
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/auth/account_required_screen.dart';
import '../../presentation/auth/account_inactive_screen.dart';
import '../../presentation/auth/drive_setup_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/appointments/appointments_screen.dart';
import '../../presentation/doctor/doctor_queue_screen.dart';
import '../../presentation/patients/patients_screen.dart';
import '../../presentation/queue/queue_screen.dart';
import '../../presentation/billing/billing_screen.dart';
import '../../presentation/reports/reports_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/shared/widgets/unauthorized_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

final AppRouterRefreshNotifier appRouterRefreshNotifier = AppRouterRefreshNotifier();

typedef ClinicConfiguredCheck = bool Function();

ClinicConfiguredCheck? isClinicConfiguredOverride;
AppAccessStatus? appAccessStatusOverride;

ProviderContainer? _getContainer([BuildContext? context]) {
  if (appProviderContainer != null) {
    return appProviderContainer;
  }
  if (context != null) {
    try {
      return ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
  }
  final navContext = rootNavigatorKey.currentContext;
  if (navContext != null) {
    try {
      return ProviderScope.containerOf(navContext, listen: false);
    } catch (_) {}
  }
  return null;
}

bool isClinicConfigured([BuildContext? context]) {
  if (isClinicConfiguredOverride != null) {
    return isClinicConfiguredOverride!();
  }
  final container = _getContainer(context);
  if (container != null) {
    try {
      final db = container.read(localDatabaseProvider);
      return db.query('Clinic_Config').isNotEmpty;
    } catch (_) {}
  }
  return true;
}

AppAccessStatus getAppAccessStatus(BuildContext context) {
  if (appAccessStatusOverride != null) {
    return appAccessStatusOverride!;
  }
  final container = _getContainer(context);
  if (container != null) {
    try {
      return container.read(appAccessProvider).status;
    } catch (_) {}
  }
  final configured = isClinicConfigured(context);
  return configured ? AppAccessStatus.ready : AppAccessStatus.clinicSetupRequired;
}

bool _isPublicRoute(String loc) {
  return loc == '/' ||
      loc == '/features' ||
      loc == '/how-it-works' ||
      loc == '/pricing' ||
      loc == '/about' ||
      loc == '/contact' ||
      loc == '/support' ||
      loc == '/privacy' ||
      loc == '/terms' ||
      loc == '/refund-policy' ||
      loc == '/data-privacy' ||
      loc == '/login' ||
      loc == '/register' ||
      loc == '/forgot-password';
}

bool _isAccountRoute(String loc) {
  return loc.startsWith('/account');
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  refreshListenable: appRouterRefreshNotifier,
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final container = _getContainer(context);
    final status = getAppAccessStatus(context);
    final loc = state.matchedLocation;

    // Check if authRepository has an authenticated user directly
    bool isRepoAuthenticated = false;
    if (container != null) {
      try {
        isRepoAuthenticated = container.read(authRepositoryProvider).isAuthenticated;
      } catch (_) {}
    }

    final isAuthenticated = (status != AppAccessStatus.unauthenticated &&
            status != AppAccessStatus.authenticating &&
            status != AppAccessStatus.error) ||
        isRepoAuthenticated;

    final session = container?.read(sessionProvider);
    final role = session?.role ?? UserRole.receptionist;

    // While app access is initializing (e.g. cold start / browser reload reading IndexedDB),
    // do not prematurely kick user out of protected routes
    if (status == AppAccessStatus.initializing) {
      if (loc == '/login' && isAuthenticated) {
        return role == UserRole.doctor ? '/doctor' : '/dashboard';
      }
      return null;
    }

    // 1. If authenticated user visits /login, redirect directly to role-appropriate home
    if (loc == '/login') {
      if (isAuthenticated) {
        return role == UserRole.doctor ? '/doctor' : '/dashboard';
      }
      return null;
    }

    // 2. Allow public website pages without interruption
    if (_isPublicRoute(loc)) {
      return null;
    }

    // 3. Protected Account Portal routes (/account, /account/profile, /account/subscription)
    if (_isAccountRoute(loc)) {
      if (!isAuthenticated) {
        return '/login';
      }
      return null;
    }

    // 4. Clinical Management System Routes (/dashboard, /app, /patients, /queue, etc.)
    if (!isAuthenticated) {
      return '/login';
    }

    // If currently on an auth/setup screen and fully ready, route to role-appropriate home
    if (loc == '/account-required' ||
        loc == '/account-inactive' ||
        loc == '/drive-setup' ||
        loc == '/onboarding') {
      if (status == AppAccessStatus.ready) {
        return role == UserRole.doctor ? '/doctor' : '/dashboard';
      }
      return null;
    }

    // Allow /unauthorized to display without circular redirect
    if (loc == '/unauthorized') {
      return null;
    }

    // Module 8: Role-based Route Guard Enforcement (PRD Section 2 & Section 5 M08)
    // Doctor Workspace Enforcement:
    // Doctors do not operate reception dashboards. If visiting /dashboard or /app,
    // route directly to the Doctor Queue Desk (/doctor).
    if (role == UserRole.doctor && (loc == '/dashboard' || loc == '/app')) {
      return '/doctor';
    }

    // Enforce strict PRD Route Boundaries across all roles:
    // Owner: Full administrative access to all modules
    // Receptionist: Allowed (/dashboard, /appointments, /patients, /queue, /billing, /reports). Blocked: /settings, /doctor
    // Doctor: Allowed (/doctor, /queue, /appointments, /patients). Blocked: /settings, /billing, /reports, /dashboard
    // Accountant: Allowed (/dashboard, /billing, /reports). Blocked: /settings, /doctor, /queue, /appointments, /patients
    if (!AuthorizationService.isRouteAllowed(role: role, routePath: loc)) {
      return '/unauthorized';
    }

    return null;
  },
  routes: [
    // Public Website Routes
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const WebsiteHomeScreen(),
    ),
    GoRoute(
      path: '/features',
      name: 'features',
      builder: (context, state) => const FeaturesPage(),
    ),
    GoRoute(
      path: '/how-it-works',
      name: 'how_it_works',
      builder: (context, state) => const HowItWorksPage(),
    ),
    GoRoute(
      path: '/pricing',
      name: 'pricing',
      builder: (context, state) => const PricingPage(),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (context, state) => const AboutPage(),
    ),
    GoRoute(
      path: '/contact',
      name: 'contact',
      builder: (context, state) => const ContactPage(),
    ),
    GoRoute(
      path: '/support',
      name: 'support',
      builder: (context, state) => const SupportPage(),
    ),
    GoRoute(
      path: '/data-privacy',
      name: 'data_privacy',
      builder: (context, state) => const DataPrivacyPage(),
    ),
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
    GoRoute(
      path: '/terms',
      name: 'terms',
      builder: (context, state) => const TermsPage(),
    ),
    GoRoute(
      path: '/refund-policy',
      name: 'refund_policy',
      builder: (context, state) => const RefundPolicyPage(),
    ),

    // Account & Auth Routes
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot_password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/account',
      name: 'account',
      builder: (context, state) => const AccountDashboardScreen(),
      routes: [
        GoRoute(
          path: 'profile',
          name: 'account_profile',
          builder: (context, state) => const AccountProfileScreen(),
        ),
        GoRoute(
          path: 'subscription',
          name: 'account_subscription',
          builder: (context, state) => const AccountSubscriptionScreen(),
        ),
      ],
    ),

    // Clinic Management System Routes
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/app',
      name: 'app',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/account-required',
      name: 'account_required',
      builder: (context, state) => const AccountRequiredScreen(),
    ),
    GoRoute(
      path: '/account-inactive',
      name: 'account_inactive',
      builder: (context, state) => const AccountInactiveScreen(),
    ),
    GoRoute(
      path: '/drive-setup',
      name: 'drive_setup',
      builder: (context, state) => const DriveSetupScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/doctor',
      name: 'doctor',
      builder: (context, state) => const DoctorQueueScreen(),
    ),
    GoRoute(
      path: '/appointments',
      name: 'appointments',
      builder: (context, state) => const AppointmentsScreen(),
    ),
    GoRoute(
      path: '/patients',
      name: 'patients',
      builder: (context, state) => const PatientsScreen(),
    ),
    GoRoute(
      path: '/queue',
      name: 'queue',
      builder: (context, state) => QueueScreen(
        autoOpenNewVisit: state.uri.queryParameters['action'] == 'new_visit' ||
            state.extra == 'new_visit',
      ),
    ),
    GoRoute(
      path: '/billing',
      name: 'billing',
      builder: (context, state) => const BillingScreen(),
    ),
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/unauthorized',
      name: 'unauthorized',
      builder: (context, state) => const UnauthorizedScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          Text(
            'Page Not Found: ${state.uri.toString()}',
            style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => appRouter.go('/'),
            child: const Text('Return to Home'),
          ),
        ],
      ),
    ),
  ),
);

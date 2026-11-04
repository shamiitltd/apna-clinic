// Apna Clinic - Route Authorization & Security Barrier Verification Test
// Validates PRD Section 2 (Role Boundaries) and Section 5 M08 (Staff & Access Authorization).
// Ensures zero unauthorized direct route access or parameter bypass across all roles.

import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';

void main() {
  int passed = 0;
  int failed = 0;

  void expect(bool condition, String message) {
    if (condition) {
      print('  [PASS] $message');
      passed++;
    } else {
      print('  [FAIL] $message');
      failed++;
    }
  }

  print('================================================================');
  print('APNA CLINIC - PRD ROLE-BASED ROUTE ACCESS SECURITY SUITE');
  print('================================================================\n');

  // 1. OWNER / ADMINISTRATOR ACCESS BOUNDARIES (Full administrative access)
  print('--- TEST SET 1: OWNER / ADMIN ROLE ROUTE ACCESS ---');
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.owner, routePath: '/settings'),
    'Owner allowed on /settings',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.owner, routePath: '/doctor'),
    'Owner allowed on /doctor',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.owner, routePath: '/billing'),
    'Owner allowed on /billing',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.owner, routePath: '/reports'),
    'Owner allowed on /reports',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.owner, routePath: '/queue'),
    'Owner allowed on /queue',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.owner, routePath: '/appointments'),
    'Owner allowed on /appointments',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.owner, routePath: '/patients'),
    'Owner allowed on /patients',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.owner, routePath: '/dashboard'),
    'Owner allowed on /dashboard',
  );

  // 2. RECEPTIONIST ACCESS BOUNDARIES
  print('\n--- TEST SET 2: RECEPTIONIST ROLE ROUTE ACCESS ---');
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/settings'),
    'Receptionist STRICTLY BLOCKED from /settings',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/doctor'),
    'Receptionist STRICTLY BLOCKED from /doctor desk',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/dashboard'),
    'Receptionist allowed on /dashboard',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/appointments'),
    'Receptionist allowed on /appointments',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/patients'),
    'Receptionist allowed on /patients',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/queue'),
    'Receptionist allowed on /queue',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/billing'),
    'Receptionist allowed on /billing',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/reports'),
    'Receptionist allowed on /reports',
  );

  // 3. DOCTOR ACCESS BOUNDARIES (Doctor Queue Desk, Appointments, Patients. No Billing/Reports/Settings)
  print('\n--- TEST SET 3: DOCTOR ROLE ROUTE ACCESS ---');
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/doctor'),
    'Doctor allowed on /doctor desk',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/queue'),
    'Doctor allowed on /queue',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/appointments'),
    'Doctor allowed on /appointments',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/patients'),
    'Doctor allowed on /patients',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/billing'),
    'Doctor STRICTLY BLOCKED from /billing & ledger',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/reports'),
    'Doctor STRICTLY BLOCKED from /reports',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/settings'),
    'Doctor STRICTLY BLOCKED from /settings',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/dashboard'),
    'Doctor blocked on /dashboard (forced redirect to /doctor)',
  );

  // 4. ACCOUNTANT ACCESS BOUNDARIES (Billing, Reports, Dashboard. No Queue/Patients/Appointments/Settings/Doctor)
  print('\n--- TEST SET 4: ACCOUNTANT ROLE ROUTE ACCESS ---');
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/billing'),
    'Accountant allowed on /billing & ledger',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/reports'),
    'Accountant allowed on /reports',
  );
  expect(
    AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/dashboard'),
    'Accountant allowed on /dashboard',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/settings'),
    'Accountant STRICTLY BLOCKED from /settings',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/doctor'),
    'Accountant STRICTLY BLOCKED from /doctor desk',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/queue'),
    'Accountant STRICTLY BLOCKED from /queue & clinical records',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/appointments'),
    'Accountant STRICTLY BLOCKED from /appointments',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/patients'),
    'Accountant STRICTLY BLOCKED from /patients directory',
  );

  // 5. QUERY PARAMETERS & HASH TAMPERING RESILIENCE
  print('\n--- TEST SET 5: QUERY STRING & URL ANCHOR TAMPERING RESILIENCE ---');
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.doctor, routePath: '/billing?action=settle&token=123'),
    'Doctor blocked from /billing even with injected query string',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.accountant, routePath: '/patients?filter=all#top'),
    'Accountant blocked from /patients even with injected query parameters and anchor',
  );
  expect(
    !AuthorizationService.isRouteAllowed(role: UserRole.receptionist, routePath: '/settings/fees?override=1'),
    'Receptionist blocked from /settings sub-path',
  );

  print('\n================================================================');
  print('TEST SUMMARY: $passed Passed | $failed Failed');
  print('================================================================\n');

  if (failed > 0) {
    throw Exception('$failed security authorization tests failed.');
  }
}


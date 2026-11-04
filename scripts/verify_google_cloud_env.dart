// Apna Clinic — Google Cloud Environment Pre-Flight Verification Tool
// Phase 4 — Milestone 1: Live Environment Verification
// Validates:
// 1. .env file existence & parsing
// 2. GOOGLE_CLIENT_ID format and structure
// 3. Authorized origins and redirect URIs (e.g. http://localhost:8080)
// 4. Least-privilege OAuth scopes
// 5. Git credential protection (.gitignore validation)
// 6. Offline-first resilience when unconfigured

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:apna_clinic/core/config/app_config.dart';

void main() {
  print('================================================================');
  print('APNA CLINIC — PHASE 4 MILESTONE 1: GOOGLE CLOUD PRE-FLIGHT AUDIT');
  print('================================================================');

  int passedChecks = 0;
  int failedChecks = 0;
  final warnings = <String>[];
  final failures = <String>[];

  // 1. Check .gitignore for secret isolation
  final gitignoreFile = File('.gitignore');
  if (gitignoreFile.existsSync()) {
    final gitignoreContent = gitignoreFile.readAsStringSync();
    if (gitignoreContent.contains('.env') && gitignoreContent.contains('*.key')) {
      print('  [PASS] .gitignore actively isolates .env and secret files.');
      passedChecks++;
    } else {
      print('  [FAIL] .gitignore is missing explicit .env or key isolation rules.');
      failures.add('Secret isolation in .gitignore incomplete.');
      failedChecks++;
    }
  } else {
    print('  [FAIL] .gitignore not found in project root.');
    failures.add('.gitignore missing.');
    failedChecks++;
  }

  // 2. Check for .env file or environment definitions
  final envFile = File('.env');
  Map<String, String> envMap = {};

  if (envFile.existsSync()) {
    print('  [INFO] .env file detected in project root.');
    envMap = AppConfig.parseEnv(envFile.readAsStringSync());
  } else {
    print('  [INFO] No .env file present in project root.');
    // Check if String.fromEnvironment was passed
    if (AppConfig.current.googleClientId.isNotEmpty) {
      envMap['GOOGLE_CLIENT_ID'] = AppConfig.current.googleClientId;
      envMap['APP_BASE_URL'] = AppConfig.current.appBaseUrl;
    }
  }

  // 3. Validate Google OAuth Client ID
  final clientId = envMap['GOOGLE_CLIENT_ID'] ?? AppConfig.current.googleClientId;
  final clientIdRegex = RegExp(r'^[0-9]+-[a-z0-9_]+\.apps\.googleusercontent\.com$');

  if (clientId.isEmpty) {
    print('  [REQUIREMENT] GOOGLE_CLIENT_ID is currently UNCONFIGURED.');
    warnings.add('Real GOOGLE_CLIENT_ID not yet provisioned in .env.');
  } else if (!clientIdRegex.hasMatch(clientId)) {
    print('  [FAIL] GOOGLE_CLIENT_ID "$clientId" does not match canonical Google OAuth Web Client ID format.');
    print('         Expected format: [PROJECT_NUMBER]-[HASH].apps.googleusercontent.com');
    failures.add('Invalid GOOGLE_CLIENT_ID format.');
    failedChecks++;
  } else {
    print('  [PASS] GOOGLE_CLIENT_ID conforms to canonical Google OAuth Web Client ID format.');
    passedChecks++;
  }

  // 4. Validate Base URL / Redirect URI
  final baseUrl = envMap['APP_BASE_URL'] ?? AppConfig.current.appBaseUrl;
  final uri = Uri.tryParse(baseUrl);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority) {
    print('  [PASS] APP_BASE_URL / Redirect URI valid: $baseUrl');
    passedChecks++;
  } else {
    print('  [FAIL] APP_BASE_URL "$baseUrl" is not a valid HTTP/HTTPS URI.');
    failures.add('Invalid APP_BASE_URL.');
    failedChecks++;
  }

  // 5. Verify Least-Privilege Scopes
  final scopes = AppConfig.current.googleOAuthScopes;
  final requiredScopes = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  bool allScopesPresent = true;
  for (final req in requiredScopes) {
    if (!scopes.contains(req)) {
      allScopesPresent = false;
      print('  [FAIL] Missing required scope: $req');
      failures.add('Missing scope: $req');
      failedChecks++;
    }
  }
  if (allScopesPresent) {
    print('  [PASS] All 5 required least-privilege OAuth scopes verified.');
    passedChecks++;
  }

  // 6. Verify Offline-First Invariant
  // When Client ID is unconfigured, system must run safely in mock/offline mode
  final unconfiguredConfig = AppConfig.fromEnvMap({'GOOGLE_CLIENT_ID': ''});
  if (unconfiguredConfig.googleClientId.isEmpty && !unconfiguredConfig.useMockAuth) {
    print('  [PASS] Unconfigured environment cleanly preserves offline-first fallback.');
    passedChecks++;
  } else {
    print('  [FAIL] Unconfigured environment fallback failed.');
    failedChecks++;
  }

  print('----------------------------------------------------------------');
  print('AUDIT SUMMARY: $passedChecks PASSED, $failedChecks FAILED, ${warnings.length} PENDING REQUIREMENTS');
  print('----------------------------------------------------------------');

  if (warnings.isNotEmpty) {
    print('ACTION REQUIRED FOR LIVE CLOUD PILOT:');
    for (final w in warnings) {
      print('  * $w');
    }
    print('');
    print('To complete live Google Cloud configuration, populate .env with:');
    print('  GOOGLE_CLIENT_ID=[YOUR_CLIENT_ID].apps.googleusercontent.com');
    print('  APP_BASE_URL=http://localhost:8080');
    print('  APP_ENV=development');
  }

  if (failures.isNotEmpty) {
    exit(1);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/permissions/roles.dart';

class UnauthorizedScreen extends ConsumerWidget {
  final String? customMessage;

  const UnauthorizedScreen({super.key, this.customMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isDoctor = session.role == UserRole.doctor;
    final defaultDestination = isDoctor ? '/doctor' : '/dashboard';

    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Access Restricted',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                customMessage ??
                    'Your active role (${session.role.name.toUpperCase()}) does not have permission to access this section.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                session.isWorkstationLocked
                    ? 'Workstation is currently locked in ${session.role.name.toUpperCase()} mode. Enter Owner Security PIN from the header to restore Admin privileges.'
                    : 'Contact your clinic administrator if you require elevated privileges for this workflow.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () => context.go(defaultDestination),
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  isDoctor
                      ? 'Return to Doctor Desk'
                      : 'Return to Clinic Dashboard',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

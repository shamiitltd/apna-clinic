import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/entities/staff.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/repositories/clinic_repository.dart';

void main() {
  test('Staff member management & deactivation', () async {
    final db = LocalDatabase(MemoryStorageAdapter());
    await db.initialize();
    final repo = ClinicRepository(db);

    final now = DateTime.now().toUtc();
    const clinicId = 'clinic_test_123';

    // 1. Create a staff member (Receptionist)
    final staff1 = Staff(
      staffId: 'staff_rec_01',
      clinicId: clinicId,
      displayName: 'Aarti Verma',
      role: UserRole.receptionist,
      email: 'aarti@clinic.com',
      phone: '9876543210',
      active: true,
      createdAt: now,
      updatedAt: now,
    );
    await repo.saveStaff(staff1);

    // 2. Query staff by email
    final retrieved = await repo.getStaffByEmail(clinicId, 'aarti@clinic.com');
    expect(retrieved, isNotNull, reason: 'Staff should be found by email');
    expect(retrieved!.displayName, 'Aarti Verma');
    expect(retrieved.role, UserRole.receptionist);
    expect(retrieved.active, isTrue);

    // 3. Update staff member role to Doctor
    final updatedRole = retrieved.copyWith(role: UserRole.doctor);
    await repo.saveStaff(updatedRole);

    final afterRoleUpdate = await repo.getStaff(clinicId, 'staff_rec_01');
    expect(afterRoleUpdate, isNotNull);
    expect(afterRoleUpdate!.role, UserRole.doctor);

    // 4. Deactivate staff member
    final deactivated = afterRoleUpdate.copyWith(active: false);
    await repo.saveStaff(deactivated);

    final afterDeactivation = await repo.getStaff(clinicId, 'staff_rec_01');
    expect(afterDeactivation, isNotNull);
    expect(afterDeactivation!.active, isFalse);

    // Verify activeOnly query excludes deactivated staff
    final activeStaff = await repo.getStaffMembers(clinicId, activeOnly: true);
    expect(activeStaff.any((s) => s.staffId == 'staff_rec_01'), isFalse);

    // 5. Delete staff member
    await repo.deleteStaff('staff_rec_01');
    final afterDelete = await repo.getStaff(clinicId, 'staff_rec_01');
    expect(afterDelete, isNull);
  });
}

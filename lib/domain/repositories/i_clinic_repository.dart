// Apna Clinic - Clinic Repository Interface

import '../entities/entities.dart';

abstract class IClinicRepository {
  Future<Clinic?> getClinic(String clinicId);
  Future<void> saveClinic(Clinic clinic);
  Future<List<Doctor>> getDoctors(String clinicId, {bool activeOnly = false});
  Future<Doctor?> getDoctor(String clinicId, String doctorId);
  Future<void> saveDoctor(Doctor doctor);
  Future<List<Staff>> getStaffMembers(
    String clinicId, {
    bool activeOnly = false,
  });
  Future<Staff?> getStaff(String clinicId, String staffId);
  Future<Staff?> getStaffByEmail(String clinicId, String email);
  Future<void> saveStaff(Staff staff);
  Future<void> deleteStaff(String staffId);
}

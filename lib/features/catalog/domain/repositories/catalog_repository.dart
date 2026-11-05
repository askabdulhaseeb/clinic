import '../entities/department.dart';
import '../entities/doctor.dart';
import '../entities/visit_type.dart';

/// Departments, doctors and visit types (FIREBASE_ARCHITECTURE §4.4–§4.6).
/// Streams include inactive records; screens filter. Writes are Admin only.
abstract class CatalogRepository {
  /// Sorted by `sortOrder`, then name.
  Stream<List<Department>> watchDepartments();

  /// Sorted by name.
  Stream<List<Doctor>> watchDoctors();

  /// Sorted by department, then `sortOrder`, then name.
  Stream<List<VisitType>> watchVisitTypes();

  /// Returns the new ID. [department.id] is ignored.
  Future<String> createDepartment(Department department);

  /// Also rewrites `departmentCode` on the department's doctors when the
  /// code changed, in the same batch.
  Future<void> updateDepartment(Department department);

  /// Returns the new ID. [doctor.id] and [doctor.userId] are ignored.
  Future<String> createDoctor(Doctor doctor);

  /// Never touches `userId` (owned by the user-management functions).
  Future<void> updateDoctor(Doctor doctor);

  /// Replaces the fee map of one doctor (fee grid row save).
  Future<void> updateDoctorFees(String doctorId, Map<String, int> fees);

  /// Returns the new ID. [visitType.id] is ignored.
  Future<String> createVisitType(VisitType visitType);

  Future<void> updateVisitType(VisitType visitType);

  /// Doctor edit of an operation type's defaults (Phase 5B): only the
  /// checklist and post-op days change.
  Future<void> updateVisitTypeDefaults(
    String visitTypeId, {
    required List<ChecklistItem> checklist,
    required List<int> postOpDays,
  });
}

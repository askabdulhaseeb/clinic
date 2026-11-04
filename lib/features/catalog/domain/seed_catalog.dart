import 'entities/department.dart';
import 'entities/visit_type.dart';

/// Master data created by the first-run setup (FIREBASE_ARCHITECTURE §10).
/// Fixed IDs so the emulator seed and the setup screen agree.
abstract final class SeedCatalog {
  static const String eyeId = 'eye';
  static const String homeoId = 'homeo';

  static const List<Department> departments = [
    Department(id: eyeId, name: 'Eye', code: 'E', sortOrder: 1),
    Department(id: homeoId, name: 'Homeopathy', code: 'H', sortOrder: 2),
  ];

  static const List<VisitType> visitTypes = [
    VisitType(
      id: 'eye-checkup',
      departmentId: eyeId,
      name: 'Checkup',
      sortOrder: 1,
    ),
    VisitType(
      id: 'eye-follow-up',
      departmentId: eyeId,
      name: 'Follow-up',
      isFollowUp: true,
      sortOrder: 2,
    ),
    VisitType(
      id: 'eye-eye-test',
      departmentId: eyeId,
      name: 'Eye Test',
      sortOrder: 3,
    ),
    VisitType(
      id: 'homeo-checkup',
      departmentId: homeoId,
      name: 'Checkup',
      sortOrder: 1,
    ),
    VisitType(
      id: 'homeo-follow-up',
      departmentId: homeoId,
      name: 'Follow-up',
      isFollowUp: true,
      sortOrder: 2,
    ),
  ];
}

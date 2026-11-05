import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/entities/visit_type.dart';
import '../../../visits/domain/entities/visit.dart';
import '../entities/operation.dart';

/// What the schedule sheet hands over (UI_DESIGN §4.7a).
class ScheduleOperationInput {
  const ScheduleOperationInput({
    required this.visit,
    required this.visitType,
    required this.surgeon,
    required this.scheduledById,
    required this.scheduledDate,
    required this.notes,
  });

  /// The checkup the operation is scheduled from.
  final Visit visit;
  final VisitType visitType;
  final Doctor surgeon;

  /// Doctor record of the user scheduling it.
  final String scheduledById;
  final String scheduledDate;
  final String notes;
}

/// `operations` (FIREBASE_ARCHITECTURE §4.14). Every change that touches the
/// date or the post-op days regenerates the appointments in the same batch.
abstract class OperationsRepository {
  /// Operations where [doctorId] is the surgeon, soonest first.
  Stream<List<Operation>> watchSurgeonOperations(String doctorId);

  /// A patient's operations, soonest first.
  Stream<List<Operation>> watchPatientOperations(String patientId);

  Stream<Operation?> watchOperation(String id);

  /// Copies the type's checklist and post-op days, writes the operation,
  /// the surgery-day appointment and one post-op appointment per day.
  Future<Operation> schedule(ScheduleOperationInput input);

  Future<void> setChecklistItem(
    Operation operation,
    String itemId, {
    required bool done,
    required String byName,
  });

  Future<void> addChecklistItem(Operation operation, String label);

  /// New date and/or days; cancels the old appointments and books new ones.
  Future<Operation> reschedule(
    Operation operation, {
    String? scheduledDate,
    List<int>? postOpDays,
  });

  /// Needs every item ticked or [overrideReason] (FEATURES §6.4).
  Future<void> markDone(
    Operation operation, {
    required String byName,
    String? overrideReason,
  });

  /// Cancels the operation and all of its appointments.
  Future<void> cancel(Operation operation, {required String reason});
}

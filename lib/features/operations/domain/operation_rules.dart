import '../../../core/utils/karachi_date.dart';
import 'entities/operation.dart';

/// A default checklist line as the visit type stores it.
class ChecklistSeed {
  const ChecklistSeed({required this.id, required this.label});

  final String id;
  final String label;
}

/// Checklist and status rules (FEATURES §6.4, decided 5 Nov 2026: Mark done
/// needs every item ticked or an override reason).
abstract final class OperationRules {
  static const String incompleteMessage =
      'Tick every checklist item or override with a reason';
  static const String reasonMessage = 'Enter a reason';

  static String? canMarkDone({
    required List<OperationChecklistItem> checklist,
    String? overrideReason,
  }) {
    if (checklist.every((c) => c.done)) return null;
    if (overrideReason != null && overrideReason.trim().isNotEmpty) {
      return null;
    }
    return incompleteMessage;
  }

  static String? validateReason(String raw) =>
      raw.trim().isEmpty ? reasonMessage : null;

  /// The type's default items as unticked operation items, same IDs.
  static List<OperationChecklistItem> copyChecklist(
    Iterable<ChecklistSeed> seeds,
  ) => [
    for (final s in seeds) OperationChecklistItem(id: s.id, label: s.label),
  ];
}

/// Post-op follow-up day arithmetic.
abstract final class PostOp {
  static const int maxDay = 365;
  static const String pastMessage = 'Date cannot be in the past';
  static const String invalidMessage = 'Not a valid date';

  /// Sorted, unique, 1 to [maxDay].
  static List<int> normalise(Iterable<int> days) {
    final set = days.where((d) => d >= 1 && d <= maxDay).toSet().toList()
      ..sort();
    return set;
  }

  /// One `YYYY-MM-DD` per day after [scheduledDate].
  static List<String> dates({
    required String scheduledDate,
    required List<int> days,
  }) => [for (final d in days) KarachiDate.addDays(scheduledDate, d)];

  static String? validateDate(String date, {required String today}) {
    if (!KarachiDate.isValid(date)) return invalidMessage;
    return KarachiDate.daysBetween(today, date) < 0 ? pastMessage : null;
  }
}

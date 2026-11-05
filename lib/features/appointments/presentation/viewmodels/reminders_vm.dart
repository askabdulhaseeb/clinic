import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/phone.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/reminder_rules.dart';
import '../../domain/repositories/appointments_repository.dart';

/// Reminders due today (UI_DESIGN §4.11): one range read, grouped by
/// `ReminderRules`; Send opens WhatsApp Web through [openUrl] and stamps
/// the appointment. Sent rows stay in the list.
class RemindersViewModel extends ChangeNotifier {
  RemindersViewModel({
    required AppointmentsRepository appointmentsRepository,
    required this.settings,
    required this.clinicName,
    required this.uid,
    required this._openUrl,
    DateTime Function()? clock,
  }) : _repo = appointmentsRepository,
       _clock = clock ?? DateTime.now {
    _load();
  }

  final AppointmentsRepository _repo;
  final ClinicSettings settings;
  final String clinicName;
  final String uid;
  final Future<void> Function(Uri uri) _openUrl;
  final DateTime Function() _clock;

  List<Appointment> _all = const [];
  bool _loading = true;
  String? _loadError;
  final _busy = <String>{};
  String? _actionError;
  bool _disposed = false;

  String get today => KarachiDate.today(_clock());
  bool get loading => _loading;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  ReminderSections get sections => ReminderRules.sections(
    _all,
    today: today,
    followUpReminderDays: settings.followUpReminderDays,
    toggles: settings.reminders,
  );

  bool isBusy(String id) => _busy.contains(id);
  bool canSend(Appointment a) => a.phone.isNotEmpty && !isBusy(a.id);

  /// `Sent 06 Nov, 10:32 AM` (+ ` by you`), or null when never sent.
  String? sentLabel(Appointment a) {
    final at = a.reminderSentAt;
    if (at == null) return null;
    final k = KarachiDate.now(at);
    final h12 = k.hour % 12 == 0 ? 12 : k.hour % 12;
    final mm = k.minute.toString().padLeft(2, '0');
    final ampm = k.hour < 12 ? 'AM' : 'PM';
    final date = KarachiDate.display(KarachiDate.format(k));
    final short = date.substring(0, date.length - 5); // drop " 2026"
    return 'Sent $short, $h12:$mm $ampm${a.reminderSentBy == uid ? ' by you' : ''}';
  }

  /// The filled `wa.me` link, or null without a phone.
  Uri? linkFor(Appointment a) {
    if (a.phone.isEmpty) return null;
    final message = ReminderMessage.fill(
      ReminderRules.templateFor(a, settings.whatsappTemplates),
      appointment: a,
      clinicName: clinicName,
    );
    return Phone.whatsAppLink(a.phone, message);
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final w = ReminderRules.window(
        today,
        followUpReminderDays: settings.followUpReminderDays,
      );
      _all = await _repo.remindersWindow(from: w.from, to: w.to);
    } on AppException catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Could not load. Try again.';
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Opens the message, then stamps the appointment. Returns false when
  /// there is no phone or the stamp failed ([actionError] set).
  Future<bool> send(Appointment a) async {
    final link = linkFor(a);
    if (link == null || _busy.contains(a.id)) return false;
    _busy.add(a.id);
    _actionError = null;
    notifyListeners();
    try {
      await _openUrl(link);
      await _repo.markReminderSent(a);
      final stamped = a.copyWith(reminderSentAt: _clock(), reminderSentBy: uid);
      _all = [for (final x in _all) x.id == a.id ? stamped : x];
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busy.remove(a.id);
      if (!_disposed) notifyListeners();
    }
  }

  void clearActionError() {
    _actionError = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

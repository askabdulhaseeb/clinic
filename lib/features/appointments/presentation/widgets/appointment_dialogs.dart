import 'package:flutter/material.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/appointment_rules.dart';
import '../../domain/entities/appointment.dart';

/// `05 Nov 2026`.
String formatAppointmentDate(String date) =>
    ReceiptPdf.formatDate(KarachiDate.parse(date));

/// Reschedule dialog (UI_DESIGN §4.12): date picker plus free-text time.
/// Returns the new date and time, or null when dismissed.
Future<({String date, String time})?> showRescheduleDialog(
  BuildContext context, {
  required Appointment appointment,
  required String today,
}) {
  var date = appointment.date.compareTo(today) < 0 ? today : appointment.date;
  final time = TextEditingController(text: appointment.time);
  return showDialog<({String date, String time})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Reschedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${appointment.patientName} · ${appointment.doctorName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('appt-reschedule-date'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(formatAppointmentDate(date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: KarachiDate.parse(date),
                  firstDate: KarachiDate.parse(today),
                  lastDate: KarachiDate.parse(today)
                      .add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => date = KarachiDate.format(picked));
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('appt-reschedule-time'),
              controller: time,
              maxLength: AppointmentRules.maxTimeLength,
              decoration: const InputDecoration(
                labelText: 'Time (optional)',
                hintText: 'e.g. 10:30',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
          FilledButton(
            key: const Key('appt-reschedule-save'),
            onPressed: () =>
                Navigator.of(context).pop((date: date, time: time.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Confirm for cancel and no-show. [confirmKey] names the confirm button.
Future<bool> confirmAppointmentAction(
  BuildContext context, {
  required String title,
  required String message,
  required Key confirmKey,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Back'),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

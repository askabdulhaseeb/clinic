import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/follow_up.dart';

/// Quick chips, a date picker and a clear button (decided 5 Nov 2026).
class FollowUpRow extends StatelessWidget {
  const FollowUpRow({
    super.key,
    required this.today,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  /// `YYYY-MM-DD` of the visit day.
  final String today;
  final String? value;
  final bool enabled;
  final void Function(String? date) onChanged;

  Future<void> _pick(BuildContext context) async {
    final start = KarachiDate.parse(value ?? KarachiDate.addDays(today, 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: KarachiDate.parse(KarachiDate.addDays(today, 1)),
      lastDate: KarachiDate.parse(today).add(const Duration(days: 365)),
    );
    if (picked != null) onChanged(KarachiDate.format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = FollowUp.quickFor(value, today: today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Follow-up', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 12),
            if (value case final v?)
              Text(ReceiptPdf.formatDate(KarachiDate.parse(v)))
            else
              Text('None', style: TextStyle(color: scheme.outline)),
            if (value != null)
              IconButton(
                key: const Key('rx-follow-clear'),
                tooltip: 'Clear follow-up',
                icon: const Icon(Icons.close, size: 18),
                onPressed: enabled ? () => onChanged(null) : null,
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final q in FollowUp.quick)
              ChoiceChip(
                key: Key('rx-follow-${q.key}'),
                label: Text(q.label),
                selected: selected?.key == q.key,
                onSelected: enabled ? (_) => onChanged(q.from(today)) : null,
              ),
            ActionChip(
              key: const Key('rx-follow-pick'),
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: const Text('Pick date'),
              onPressed: enabled ? () => unawaited(_pick(context)) : null,
            ),
          ],
        ),
      ],
    );
  }
}

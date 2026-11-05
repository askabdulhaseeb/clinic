import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/entities/visit.dart';
import '../../domain/shift_summary.dart';
import '../viewmodels/today_visits_controller.dart';

/// `/reception/summary`: today's totals (FEATURES §5.8, UI_DESIGN §4.3).
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _mine = false;

  @override
  Widget build(BuildContext context) {
    final today = context.watch<TodayVisitsController>();
    final uid = context.watch<SessionController>().user?.uid;
    final summary = ShiftSummary.of(
      today.visits,
      createdBy: _mine ? (uid ?? '') : null,
    );
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Today, ${today.today}', style: text.titleMedium),
                ),
                const Text('My visits only'),
                Switch(
                  key: const Key('summary-mine'),
                  value: _mine,
                  onChanged: (v) => setState(() => _mine = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Tile(
                  key: const Key('summary-visits'),
                  label: 'Visits',
                  value: '${summary.visits}',
                ),
                _Tile(
                  key: const Key('summary-net'),
                  label: 'Collected',
                  value: Money.format(summary.net),
                  emphasis: true,
                ),
                for (final m in PaymentMethod.values)
                  _Tile(
                    key: Key('summary-${m.key}'),
                    label: m.label,
                    value: Money.format(summary.byMethod[m] ?? 0),
                  ),
                _Tile(
                  key: const Key('summary-discounts'),
                  label: 'Discounts',
                  value: Money.format(summary.discounts),
                  hint: '${summary.discountCount} given',
                  warn: summary.discounts > 0,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: summary.byDoctor.isEmpty
                  ? const EmptyState(
                      icon: Icons.summarize_outlined,
                      title: 'No visits yet today',
                    )
                  : Column(
                      children: [
                        ListTile(
                          title: Text('By doctor', style: text.titleMedium),
                        ),
                        for (final d in summary.byDoctor)
                          ListTile(
                            key: Key('summary-doctor-${d.doctorId}'),
                            dense: true,
                            title: Text(d.doctorName),
                            trailing: Text(
                              '${d.visits} visits · ${Money.format(d.net)}',
                              style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.emphasis = false,
    this.warn = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool emphasis;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 180,
      child: Card(
        color: emphasis ? scheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelLarge?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: text.headlineSmall?.copyWith(
                  color: warn ? scheme.error : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

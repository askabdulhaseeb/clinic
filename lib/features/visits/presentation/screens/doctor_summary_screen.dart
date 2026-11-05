import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../../operations/presentation/widgets/operation_defaults_editor.dart';
import '../../domain/doctor_periods.dart';
import '../../domain/repositories/visits_repository.dart';
import '../viewmodels/doctor_summary_vm.dart';

/// `/doctor/me` (UI_DESIGN §4.6b): today, this week, this month.
class DoctorSummaryScreen extends StatelessWidget {
  const DoctorSummaryScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final doctorId = session.user?.doctorId;
    if (doctorId == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'No doctor record linked',
        message: 'Ask Admin to link your login to a doctor.',
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(doctorId),
      create: (context) => DoctorSummaryViewModel(
        visitsRepository: context.read<VisitsRepository>(),
        doctorId: doctorId,
        clock: clock,
      ),
      child: DoctorSummaryView(
        name: session.user?.displayName ?? '',
        doctorId: doctorId,
      ),
    );
  }
}

/// Body; expects a [DoctorSummaryViewModel] above it.
class DoctorSummaryView extends StatelessWidget {
  const DoctorSummaryView({
    super.key,
    required this.name,
    required this.doctorId,
  });

  final String name;
  final String doctorId;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DoctorSummaryViewModel>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final wide = Breakpoints.isExpanded(context);
    final cards = [for (final p in vm.periods) _PeriodCard(period: p, vm: vm)];
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'My summary' : name,
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (vm.loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  key: const Key('me-refresh'),
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => unawaited(vm.refresh()),
                ),
            ],
          ),
          Text(
            'Completed visits and your fees. Needs a connection.',
            style: text.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 12),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            )
          else
            for (final c in cards) ...[c, const SizedBox(height: 12)],
          if (vm.error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(e, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 16),
          OperationDefaultsEditor(doctorId: doctorId),
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.period, required this.vm});

  final DoctorPeriod period;
  final DoctorSummaryViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final t = vm.totalsFor(period.key);
    Widget line(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: scheme.outline)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Card(
      key: Key('me-${period.key}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(period.label, style: text.titleMedium),
            Text(
              period.range.from == period.range.to
                  ? period.range.to
                  : '${period.range.from} to ${period.range.to}',
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
            const Divider(height: 20),
            if (t == null)
              Text(
                vm.loading ? 'Loading…' : '—',
                style: TextStyle(color: scheme.outline),
              )
            else ...[
              line('Patients seen', '${t.visits}', bold: true),
              line('Fees', Money.format(t.fee)),
              line('Discounts', Money.format(t.discount)),
              line('Net', Money.format(t.net), bold: true),
            ],
          ],
        ),
      ),
    );
  }
}

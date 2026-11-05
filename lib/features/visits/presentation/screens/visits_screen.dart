import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/token_chip.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/visit.dart';
import '../receipt/receipt_pdf.dart';
import '../viewmodels/today_visits_controller.dart';

/// `/<role>/visits`: today's visits newest first (UI_DESIGN §4.3). Reads
/// the shared [TodayVisitsController]; no listener of its own.
class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  String _filter = '';

  /// Patient name or token label, case-insensitive.
  static List<Visit> filtered(List<Visit> visits, String filter) {
    final q = filter.trim().toLowerCase();
    if (q.isEmpty) return visits;
    return visits
        .where(
          (v) =>
              v.patientName.toLowerCase().contains(q) ||
              v.tokenLabel.toLowerCase() == q ||
              v.tokenLabel.toLowerCase().startsWith(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final today = context.watch<TodayVisitsController>();
    final visits = filtered(today.visits, _filter);
    final compact = Breakpoints.isCompact(context);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('visits-filter'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Filter by patient or token',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('visits-new'),
                  onPressed: () =>
                      context.go(AppRoutes.patientsFor(widget.role)),
                  icon: const Icon(Icons.add),
                  label: Text(compact ? 'New' : 'New visit'),
                ),
              ],
            ),
          ),
          if (today.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                today.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: today.visits.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No visits yet today',
                    message: 'Find a patient and start a new visit.',
                  )
                : visits.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'No visit matches the filter',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: visits.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => VisitRow(
                      visit: visits[i],
                      onTap: () => context.go(
                        AppRoutes.visitFor(widget.role, visits[i].id),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One visit line: token, time, patient, doctor and type, net, status.
class VisitRow extends StatelessWidget {
  const VisitRow({
    super.key,
    required this.visit,
    this.onTap,
    this.showDate = false,
  });

  final Visit visit;
  final VoidCallback? onTap;

  /// Prefix the line with the clinic date (history lists span days).
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final scheme = Theme.of(context).colorScheme;
    final time = visit.createdAt == null
        ? ''
        : ReceiptPdf.formatTime(
            visit.createdAt!.toUtc().add(const Duration(hours: 5)),
          );
    return ListTile(
      key: Key('visit-row-${visit.id}'),
      onTap: onTap,
      leading: TokenChip(
        label: visit.tokenLabel,
        departmentCode: visit.departmentCode,
      ),
      title: Text(visit.patientName),
      subtitle: Text(
        [
          if (showDate) visit.date,
          if (time.isNotEmpty) time,
          visit.doctorName,
          visit.visitTypeName,
          if (compact) visit.paymentMethod.label,
        ].join(' · '),
        style: TextStyle(color: scheme.outline),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            visit.netAmount,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (!compact) ...[
            const SizedBox(width: 12),
            SizedBox(width: 110, child: Text(visit.paymentMethod.label)),
          ],
          const SizedBox(width: 8),
          StatusChip(status: visit.status),
        ],
      ),
    );
  }
}

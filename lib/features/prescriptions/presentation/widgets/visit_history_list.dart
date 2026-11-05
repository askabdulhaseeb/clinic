import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/token_chip.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../../visits/presentation/viewmodels/patient_history_vm.dart';
import '../../domain/entities/prescription.dart';
import 'prescription_view.dart';

/// A patient's visits, newest first, each expanding to its prescription
/// (UI_DESIGN §4.6a). Shared by the consultation History tab and the
/// doctor's patient page. Pages come from [PatientHistoryViewModel]: the
/// first page loads when the tab opens, "Load more" adds the next one.
class VisitHistoryList extends StatelessWidget {
  const VisitHistoryList({
    super.key,
    required this.visits,
    required this.prescriptionFor,
    this.loading = false,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.error,
    this.shrinkWrap = false,
  });

  final List<Visit> visits;
  final Prescription? Function(String visitId) prescriptionFor;
  final bool loading;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function()? onLoadMore;
  final String? error;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (loading && visits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visits.isEmpty) {
      return EmptyState(
        icon: error == null ? Icons.history : Icons.error_outline,
        title: error == null ? 'No visits yet' : 'Could not load',
        message: error,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final footer = hasMore || error != null;
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: visits.length + (footer ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == visits.length) {
          return LoadMoreRow(
            keyName: 'history-load-more',
            loading: loadingMore,
            error: error,
            onPressed: onLoadMore,
          );
        }
        final v = visits[i];
        final rx = prescriptionFor(v.id);
        return ExpansionTile(
          key: Key('history-visit-${v.id}'),
          leading: TokenChip(
            label: v.tokenLabel,
            departmentCode: v.departmentCode,
          ),
          title: Text(
            '${ReceiptPdf.formatDate(KarachiDate.parse(v.date))} · '
            '${v.doctorName}',
          ),
          subtitle: Text(
            [v.visitTypeName, if (rx != null) 'Rx'].join(' · '),
            style: TextStyle(color: scheme.outline),
          ),
          trailing: StatusChip(status: v.status),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rx == null)
              Text('No prescription', style: TextStyle(color: scheme.outline))
            else
              PrescriptionView(prescription: rx),
          ],
        );
      },
    );
  }
}

/// "Load more" footer row under a paged list; shows the page error when
/// the last page failed.
class LoadMoreRow extends StatelessWidget {
  const LoadMoreRow({
    super.key,
    required this.keyName,
    required this.loading,
    this.error,
    this.onPressed,
  });

  final String keyName;
  final bool loading;
  final String? error;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (error != null)
            Text(error!, style: TextStyle(color: scheme.error)),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              key: Key(keyName),
              onPressed: onPressed == null
                  ? null
                  : () => unawaited(onPressed!()),
              icon: const Icon(Icons.expand_more),
              label: Text(error == null ? 'Load more' : 'Try again'),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/token_chip.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/prescription.dart';
import 'prescription_view.dart';

/// A patient's visits, newest first, each expanding to its prescription
/// (UI_DESIGN §4.6a). Shared by the consultation History tab and the
/// doctor's patient page.
class VisitHistoryList extends StatelessWidget {
  const VisitHistoryList({
    super.key,
    required this.visits,
    required this.prescriptionFor,
    this.shrinkWrap = false,
  });

  final List<Visit> visits;
  final Prescription? Function(String visitId) prescriptionFor;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return const EmptyState(icon: Icons.history, title: 'No visits yet');
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: visits.length,
      itemBuilder: (context, i) {
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

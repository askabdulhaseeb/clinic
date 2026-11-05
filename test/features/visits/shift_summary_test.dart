import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/shift_summary.dart';

import '../../helpers/fakes.dart';

void main() {
  final visits = [
    sampleVisit(id: 'a', token: 1, fee: 1500, createdBy: 'rec-1'),
    sampleVisit(
      id: 'b',
      token: 2,
      fee: 1500,
      discountAmount: 500,
      discountReason: 'Poor patient',
      paymentMethod: PaymentMethod.jazzcash,
      createdBy: 'rec-2',
    ),
    sampleVisit(
      id: 'c',
      token: 1,
      doctor: doctorUnlinked,
      visitType: homeoCheckup,
      fee: 800,
      paymentMethod: PaymentMethod.bank,
      createdBy: 'rec-1',
    ),
  ];

  test('totals for the whole clinic', () {
    final s = ShiftSummary.of(visits);
    expect(s.visits, 3);
    expect(s.gross, 3800);
    expect(s.discounts, 500);
    expect(s.discountCount, 1);
    expect(s.net, 3300);
    expect(s.byMethod[PaymentMethod.cash], 1500);
    expect(s.byMethod[PaymentMethod.jazzcash], 1000);
    expect(s.byMethod[PaymentMethod.bank], 800);
    expect(s.byMethod[PaymentMethod.easypaisa], 0);
    expect(s.byDoctor.map((d) => d.doctorName), ['Dr Sara', 'Dr Imran']);
    expect(s.byDoctor.first.visits, 2);
    expect(s.byDoctor.first.net, 2500);
    expect(s.byDoctor.last.net, 800);
  });

  test('"my visits only" keeps the signed-in user\'s visits', () {
    final s = ShiftSummary.of(visits, createdBy: 'rec-1');
    expect(s.visits, 2);
    expect(s.net, 2300);
    expect(s.discounts, 0);
    expect(s.byDoctor, hasLength(2));
  });

  test('empty day', () {
    final s = ShiftSummary.of(const []);
    expect(s.visits, 0);
    expect(s.net, 0);
    expect(s.byDoctor, isEmpty);
    for (final m in PaymentMethod.values) {
      expect(s.byMethod[m], 0);
    }
  });
}

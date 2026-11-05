import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/visits/data/models/visit_model.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

void main() {
  group('PaymentMethod', () {
    test('keys, labels and which ones take a reference', () {
      expect(PaymentMethod.values.map((m) => m.key), [
        'cash',
        'bank',
        'jazzcash',
        'easypaisa',
      ]);
      expect(PaymentMethod.bank.label, 'Bank transfer');
      expect(PaymentMethod.cash.needsReference, isFalse);
      expect(PaymentMethod.jazzcash.needsReference, isTrue);
      expect(PaymentMethod.parse('easypaisa'), PaymentMethod.easypaisa);
      expect(PaymentMethod.parse('nope'), PaymentMethod.cash);
    });
  });

  group('VisitStatus', () {
    test('parse and next step', () {
      expect(VisitStatus.parse('inProgress'), VisitStatus.inProgress);
      expect(VisitStatus.parse('bogus'), VisitStatus.waiting);
      expect(VisitStatus.waiting.next, VisitStatus.inProgress);
      expect(VisitStatus.inProgress.next, VisitStatus.completed);
      expect(VisitStatus.completed.next, isNull);
    });
  });

  group('VisitModel', () {
    final created = DateTime.utc(2026, 11, 4, 6, 30);
    final visit = Visit(
      id: 'v1',
      patientId: 'pat-ali',
      patientName: 'Ali Khan',
      patientNo: '26-00001',
      phone: '03001234567',
      familyId: 'fam-khan',
      doctorId: 'doctor-sara',
      doctorName: 'Dr Sara',
      departmentId: 'eye',
      departmentCode: 'E',
      visitTypeId: 'eye-checkup',
      visitTypeName: 'Checkup',
      isOperation: false,
      isFollowUp: false,
      token: 12,
      tokenLabel: 'E-12',
      date: '2026-11-04',
      isFirstVisit: true,
      fee: 1500,
      discountAmount: 200,
      discountReason: 'Old patient',
      netAmount: 1300,
      paymentMethod: PaymentMethod.jazzcash,
      paymentRef: 'TX123',
      status: VisitStatus.waiting,
      receiptCopies: 2,
      createdBy: 'rec-1',
      createdAt: created,
    );

    test('round-trips through toMap/fromMap', () {
      final map = VisitModel.toMap(visit);
      expect(map['paymentMethod'], 'jazzcash');
      expect(map['status'], 'waiting');
      expect(map['deleted'], false);
      expect(map['netAmount'], 1300);
      expect(map['hasPrescription'], false);
      expect(map.containsKey('id'), isFalse);
      // Timestamps are added by the repository, not the model.
      expect(map.containsKey('createdAt'), isFalse);

      final back = VisitModel.fromMap('v1', {
        ...map,
        'createdAt': Timestamp.fromDate(created),
        'createdAtLocal': Timestamp.fromDate(created),
      });
      expect(back, visit);
      expect(back.createdAt, created);
    });

    test('fromMap tolerates missing fields and reads completed stamps', () {
      final v = VisitModel.fromMap('x', {
        'status': 'completed',
        'completedAt': Timestamp.fromDate(created),
      });
      expect(v.status, VisitStatus.completed);
      expect(v.completedAt, created);
      expect(v.paymentMethod, PaymentMethod.cash);
      expect(v.fee, 0);
      expect(v.token, 0);
      expect(v.receiptCopies, 1);
      expect(v.deleted, isFalse);
    });

    test('createdAt falls back to the local stamp while unsynced', () {
      final v = VisitModel.fromMap('x', {
        'createdAt': null,
        'createdAtLocal': Timestamp.fromDate(created),
      });
      expect(v.createdAt, created);
    });
  });
}

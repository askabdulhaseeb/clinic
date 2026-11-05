import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/visit.dart';

abstract final class VisitModel {
  static Visit fromMap(String id, Map<String, dynamic> map) => Visit(
    id: id,
    patientId: _s(map['patientId']),
    patientName: _s(map['patientName']),
    patientNo: _s(map['patientNo']),
    phone: _s(map['phone']),
    familyId: _s(map['familyId']),
    doctorId: _s(map['doctorId']),
    doctorName: _s(map['doctorName']),
    departmentId: _s(map['departmentId']),
    departmentCode: _s(map['departmentCode']),
    visitTypeId: _s(map['visitTypeId']),
    visitTypeName: _s(map['visitTypeName']),
    isOperation: (map['isOperation'] as bool?) ?? false,
    isFollowUp: (map['isFollowUp'] as bool?) ?? false,
    token: _i(map['token']),
    tokenLabel: _s(map['tokenLabel']),
    date: _s(map['date']),
    isFirstVisit: (map['isFirstVisit'] as bool?) ?? false,
    fee: _i(map['fee']),
    discountAmount: _i(map['discountAmount']),
    discountReason: _s(map['discountReason']),
    netAmount: _i(map['netAmount']),
    paymentMethod: PaymentMethod.parse(map['paymentMethod']),
    paymentRef: _s(map['paymentRef']),
    status: VisitStatus.parse(map['status']),
    receiptCopies: (map['receiptCopies'] as num?)?.toInt() ?? 1,
    createdBy: _s(map['createdBy']),
    createdAt: _date(map['createdAt']) ?? _date(map['createdAtLocal']),
    startedAt: _date(map['startedAt']),
    completedAt: _date(map['completedAt']),
    hasPrescription: (map['hasPrescription'] as bool?) ?? false,
    deleted: (map['deleted'] as bool?) ?? false,
    branchId: (map['branchId'] as String?) ?? 'main',
  );

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(Visit v) => {
    'patientId': v.patientId,
    'patientName': v.patientName,
    'patientNo': v.patientNo,
    'phone': v.phone,
    'familyId': v.familyId,
    'doctorId': v.doctorId,
    'doctorName': v.doctorName,
    'departmentId': v.departmentId,
    'departmentCode': v.departmentCode,
    'visitTypeId': v.visitTypeId,
    'visitTypeName': v.visitTypeName,
    'isOperation': v.isOperation,
    'isFollowUp': v.isFollowUp,
    'token': v.token,
    'tokenLabel': v.tokenLabel,
    'date': v.date,
    'isFirstVisit': v.isFirstVisit,
    'fee': v.fee,
    'discountAmount': v.discountAmount,
    'discountReason': v.discountReason,
    'netAmount': v.netAmount,
    'paymentMethod': v.paymentMethod.key,
    'paymentRef': v.paymentRef,
    'status': v.status.key,
    'startedAt': v.startedAt == null ? null : Timestamp.fromDate(v.startedAt!),
    'completedAt': v.completedAt == null
        ? null
        : Timestamp.fromDate(v.completedAt!),
    'appointmentId': null,
    'operationId': null,
    'saleId': null,
    'hasPrescription': v.hasPrescription,
    'receiptCopies': v.receiptCopies,
    'deleted': v.deleted,
    'deletedAt': null,
    'deletedBy': null,
    'deleteReason': null,
    'editReason': null,
    'branchId': v.branchId,
    'createdBy': v.createdBy,
  };

  static String _s(Object? v) => (v as String?) ?? '';
  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
  // UTC so entities compare by instant, whatever the device zone.
  static DateTime? _date(Object? v) =>
      v is Timestamp ? v.toDate().toUtc() : null;
}

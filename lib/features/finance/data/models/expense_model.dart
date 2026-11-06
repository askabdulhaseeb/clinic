import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/expense.dart';

abstract final class ExpenseModel {
  static Expense fromMap(String id, Map<String, dynamic> map) => Expense(
    id: id,
    category: ExpenseCategory.parse(map['category']),
    amount: (map['amount'] as num?)?.toInt() ?? 0,
    date: (map['date'] as String?) ?? '',
    note: (map['note'] as String?) ?? '',
    source: ExpenseSource.parse(map['source']),
    refId: map['refId'] as String?,
    deleted: (map['deleted'] as bool?) ?? false,
    createdBy: (map['createdBy'] as String?) ?? '',
    createdAt: map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate().toUtc()
        : null,
    branchId: (map['branchId'] as String?) ?? 'main',
  );

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(Expense e) => {
    'category': e.category.key,
    'amount': e.amount,
    'date': e.date,
    'note': e.note,
    'source': e.source.key,
    'refId': e.refId,
    'deleted': e.deleted,
    'createdBy': e.createdBy,
    'branchId': e.branchId,
  };
}

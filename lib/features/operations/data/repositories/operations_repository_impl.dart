import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../domain/entities/operation.dart';
import '../../domain/operation_rules.dart';
import '../../domain/repositories/operations_repository.dart';
import '../models/operation_model.dart';

class OperationsRepositoryImpl implements OperationsRepository {
  OperationsRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _ops =>
      _db.collection('operations');
  CollectionReference<Map<String, dynamic>> get _appointments =>
      _db.collection('appointments');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  static int _soonestFirst(Operation a, Operation b) {
    final byDate = a.scheduledDate.compareTo(b.scheduledDate);
    if (byDate != 0) return byDate;
    return a.id.compareTo(b.id);
  }

  Stream<List<Operation>> _list(Query<Map<String, dynamic>> q) => q
      .snapshots()
      .map((snap) {
        final list =
            snap.docs
                .map((d) => OperationModel.fromMap(d.id, d.data()))
                .toList()
              ..sort(_soonestFirst);
        return List<Operation>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Stream<List<Operation>> watchSurgeonOperations(String doctorId) =>
      _list(_ops.where('surgeonDoctorId', isEqualTo: doctorId));

  @override
  Stream<List<Operation>> watchPatientOperations(String patientId) =>
      _list(_ops.where('patientId', isEqualTo: patientId));

  @override
  Stream<Operation?> watchOperation(String id) => _ops
      .doc(id)
      .snapshots()
      .map((d) {
        final data = d.data();
        return data == null ? null : OperationModel.fromMap(d.id, data);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  Map<String, dynamic> _stamps(String uid, {bool create = false}) => {
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    if (create) 'createdAtLocal': Timestamp.fromDate(_clock()),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  /// Books the surgery-day and post-op appointments for [op] into [batch]
  /// and returns the operation with their IDs.
  Operation _bookAppointments(WriteBatch batch, Operation op, String uid) {
    Appointment make(
      String id,
      String date,
      AppointmentSource source,
      String notes,
    ) => Appointment(
      id: id,
      patientId: op.patientId,
      patientName: op.patientName,
      patientNo: op.patientNo,
      phone: op.phone,
      doctorId: op.surgeonDoctorId,
      doctorName: op.surgeonName,
      departmentId: op.departmentId,
      date: date,
      source: source,
      operationId: op.id,
      notes: notes,
      createdBy: uid,
      branchId: op.branchId,
    );
    final surgery = _appointments.doc();
    batch.set(surgery, {
      ...AppointmentModel.toMap(
        make(
          surgery.id,
          op.scheduledDate,
          AppointmentSource.operation,
          op.visitTypeName,
        ),
      ),
      ..._stamps(uid, create: true),
    });
    final followUps = <String>[];
    for (final day in op.postOpDays) {
      final ref = _appointments.doc();
      followUps.add(ref.id);
      batch.set(ref, {
        ...AppointmentModel.toMap(
          make(
            ref.id,
            KarachiDate.addDays(op.scheduledDate, day),
            AppointmentSource.postOp,
            'Post-op day $day',
          ),
        ),
        ..._stamps(uid, create: true),
      });
    }
    return op.copyWith(
      surgeryAppointmentId: surgery.id,
      followUpAppointmentIds: followUps,
    );
  }

  void _cancelAppointments(WriteBatch batch, Operation op, String uid) {
    for (final id in [?op.surgeryAppointmentId, ...op.followUpAppointmentIds]) {
      batch.update(_appointments.doc(id), {
        'status': AppointmentStatus.cancelled.key,
        ..._stamps(uid),
      });
    }
  }

  @override
  Future<Operation> schedule(ScheduleOperationInput input) => _guard(() async {
    final uid = _uid;
    if (!input.visitType.isOperation) {
      throw const AppException(
        'Choose an operation type',
        code: 'invalid-argument',
      );
    }
    final dateProblem = PostOp.validateDate(
      input.scheduledDate,
      today: KarachiDate.today(_clock()),
    );
    if (dateProblem != null) {
      throw AppException(dateProblem, code: 'invalid-argument');
    }
    final ref = _ops.doc();
    final v = input.visit;
    var op = Operation(
      id: ref.id,
      patientId: v.patientId,
      patientName: v.patientName,
      patientNo: v.patientNo,
      phone: v.phone,
      visitId: v.id,
      visitTypeId: input.visitType.id,
      visitTypeName: input.visitType.name,
      surgeonDoctorId: input.surgeon.id,
      surgeonName: input.surgeon.name,
      departmentId: input.visitType.departmentId,
      scheduledById: input.scheduledById,
      scheduledDate: input.scheduledDate,
      checklist: OperationRules.copyChecklist([
        for (final c in input.visitType.defaultPreOpChecklist)
          ChecklistSeed(id: c.id, label: c.label),
      ]),
      postOpDays: PostOp.normalise(input.visitType.defaultPostOpDays),
      notes: input.notes.trim(),
      createdBy: uid,
      createdAt: _clock(),
      branchId: v.branchId,
    );
    final batch = _db.batch();
    op = _bookAppointments(batch, op, uid);
    batch.set(ref, {
      ...OperationModel.toMap(op),
      ..._stamps(uid, create: true),
    });
    await commitOrQueue(batch.commit());
    return op;
  });

  @override
  Future<void> setChecklistItem(
    Operation operation,
    String itemId, {
    required bool done,
    required String byName,
  }) => _guard(() async {
    final uid = _uid;
    final now = _clock();
    final list = [
      for (final c in operation.checklist)
        if (c.id != itemId)
          c
        else if (done)
          c.copyWith(done: true, doneBy: byName, doneAt: now)
        else
          c.copyWith(clearDone: true),
    ];
    await commitOrQueue(
      _ops.doc(operation.id).update({
        'checklist': OperationModel.checklistToList(list),
        'checklistComplete': list.every((c) => c.done),
        ..._stamps(uid),
      }),
    );
  });

  @override
  Future<void> addChecklistItem(Operation operation, String label) =>
      _guard(() async {
        final uid = _uid;
        final text = label.trim();
        if (text.isEmpty) {
          throw const AppException(
            'Enter the checklist item',
            code: 'invalid-argument',
          );
        }
        final list = [
          ...operation.checklist,
          OperationChecklistItem(id: _uuid.v4(), label: text),
        ];
        await commitOrQueue(
          _ops.doc(operation.id).update({
            'checklist': OperationModel.checklistToList(list),
            'checklistComplete': false,
            ..._stamps(uid),
          }),
        );
      });

  @override
  Future<Operation> reschedule(
    Operation operation, {
    String? scheduledDate,
    List<int>? postOpDays,
  }) => _guard(() async {
    final uid = _uid;
    final date = scheduledDate ?? operation.scheduledDate;
    final dateProblem = PostOp.validateDate(
      date,
      today: KarachiDate.today(_clock()),
    );
    if (dateProblem != null) {
      throw AppException(dateProblem, code: 'invalid-argument');
    }
    final batch = _db.batch();
    _cancelAppointments(batch, operation, uid);
    var op = operation.copyWith(
      scheduledDate: date,
      postOpDays: PostOp.normalise(postOpDays ?? operation.postOpDays),
    );
    op = _bookAppointments(batch, op, uid);
    batch.update(_ops.doc(op.id), {
      'scheduledDate': op.scheduledDate,
      'postOpDays': List<int>.of(op.postOpDays),
      'surgeryAppointmentId': op.surgeryAppointmentId,
      'followUpAppointmentIds': List<String>.of(op.followUpAppointmentIds),
      ..._stamps(uid),
    });
    await commitOrQueue(batch.commit());
    return op;
  });

  @override
  Future<void> markDone(
    Operation operation, {
    required String byName,
    String? overrideReason,
  }) => _guard(() async {
    final uid = _uid;
    final problem = OperationRules.canMarkDone(
      checklist: operation.checklist,
      overrideReason: overrideReason,
    );
    if (problem != null) {
      throw AppException(problem, code: 'invalid-argument');
    }
    final reason = overrideReason?.trim();
    await commitOrQueue(
      _ops.doc(operation.id).update({
        'status': OperationStatus.done.key,
        'doneAt': Timestamp.fromDate(_clock()),
        'doneBy': byName,
        'checklistOverrideReason': operation.checklistComplete
            ? null
            : (reason == null || reason.isEmpty ? null : reason),
        ..._stamps(uid),
      }),
    );
  });

  @override
  Future<void> cancel(Operation operation, {required String reason}) =>
      _guard(() async {
        final uid = _uid;
        if (OperationRules.validateReason(reason) != null) {
          throw const AppException(
            OperationRules.reasonMessage,
            code: 'invalid-argument',
          );
        }
        final batch = _db.batch();
        _cancelAppointments(batch, operation, uid);
        batch.update(_ops.doc(operation.id), {
          'status': OperationStatus.cancelled.key,
          'cancelReason': reason.trim(),
          ..._stamps(uid),
        });
        await commitOrQueue(batch.commit());
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}

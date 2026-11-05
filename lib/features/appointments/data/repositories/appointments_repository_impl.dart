import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/appointment_rules.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../models/appointment_model.dart';

class AppointmentsRepositoryImpl implements AppointmentsRepository {
  AppointmentsRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _db.collection('appointments');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  String get _today => KarachiDate.today(_clock());

  /// Date, then time (empty last), then patient name.
  static int _dayOrder(Appointment a, Appointment b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    if (a.time.isEmpty != b.time.isEmpty) return a.time.isEmpty ? 1 : -1;
    final byTime = a.time.compareTo(b.time);
    if (byTime != 0) return byTime;
    return a.patientName.compareTo(b.patientName);
  }

  Stream<List<Appointment>> _list(Query<Map<String, dynamic>> q) => q
      .snapshots()
      .map((snap) {
        final list =
            snap.docs
                .map((d) => AppointmentModel.fromMap(d.id, d.data()))
                .toList()
              ..sort(_dayOrder);
        return List<Appointment>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  Future<List<Appointment>> _read(Query<Map<String, dynamic>> q) =>
      _guard(() async {
        final snap = await q.get();
        final list =
            snap.docs
                .map((d) => AppointmentModel.fromMap(d.id, d.data()))
                .toList()
              ..sort(_dayOrder);
        return List<Appointment>.unmodifiable(list);
      });

  @override
  Future<List<Appointment>> remindersWindow({
    required String from,
    required String to,
  }) => _read(
    _appointments
        .where('date', isGreaterThanOrEqualTo: from)
        .where('date', isLessThanOrEqualTo: to),
  );

  @override
  Future<List<Appointment>> doctorUpcoming(
    String doctorId, {
    required String from,
    required String to,
  }) async {
    final list = await _read(
      _appointments
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isGreaterThanOrEqualTo: from)
          .where('date', isLessThanOrEqualTo: to),
    );
    return List<Appointment>.unmodifiable(
      list.where((a) => a.status == AppointmentStatus.booked),
    );
  }

  @override
  Future<void> markReminderSent(Appointment appointment) => _guard(() async {
    final uid = _uid;
    await commitOrQueue(
      _appointments.doc(appointment.id).update({
        'reminderSentAt': Timestamp.fromDate(_clock()),
        'reminderSentBy': uid,
        ..._stamps(uid),
      }),
    );
  });

  @override
  Stream<List<Appointment>> watchDay(String date) =>
      _list(_appointments.where('date', isEqualTo: date));

  @override
  Stream<List<Appointment>> watchPatientAppointments(String patientId) =>
      _list(_appointments.where('patientId', isEqualTo: patientId));

  Map<String, dynamic> _stamps(String uid, {bool create = false}) => {
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    if (create) 'createdAtLocal': Timestamp.fromDate(_clock()),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  @override
  Future<Appointment> book(BookAppointmentInput input) => _guard(() async {
    final uid = _uid;
    final problem = AppointmentRules.validateBooking(
      doctorId: input.doctor.id,
      date: input.date,
      today: _today,
    );
    if (problem != null) throw AppException(problem, code: 'invalid-argument');
    final p = input.patient;
    final ref = _appointments.doc();
    final appointment = Appointment(
      id: ref.id,
      patientId: p.id,
      patientName: p.name,
      patientNo: p.displayNo,
      phone: p.personalPhone ?? p.phones.firstOrNull ?? '',
      doctorId: input.doctor.id,
      doctorName: input.doctor.name,
      departmentId: input.doctor.departmentId,
      date: input.date,
      time: AppointmentRules.normaliseTime(input.time),
      source: AppointmentSource.manual,
      notes: input.notes.trim(),
      createdBy: uid,
      createdAt: _clock(),
      branchId: p.branchId,
    );
    await commitOrQueue(
      ref.set({
        ...AppointmentModel.toMap(appointment),
        ..._stamps(uid, create: true),
      }),
    );
    return appointment;
  });

  void _require(Appointment a, AppointmentAction action) {
    if (!AppointmentRules.actionsFor(a, _today).contains(action)) {
      throw const AppException(
        'This appointment cannot be changed here.',
        code: 'invalid-argument',
      );
    }
  }

  @override
  Future<void> reschedule(
    Appointment appointment, {
    required String date,
    required String time,
  }) => _guard(() async {
    final uid = _uid;
    _require(appointment, AppointmentAction.reschedule);
    final problem = AppointmentRules.validateBooking(
      doctorId: appointment.doctorId,
      date: date,
      today: _today,
    );
    if (problem != null) throw AppException(problem, code: 'invalid-argument');
    await commitOrQueue(
      _appointments.doc(appointment.id).update({
        'date': date,
        'time': AppointmentRules.normaliseTime(time),
        ..._stamps(uid),
      }),
    );
  });

  Future<void> _setStatus(
    Appointment appointment,
    AppointmentAction action,
    AppointmentStatus status,
  ) => _guard(() async {
    final uid = _uid;
    _require(appointment, action);
    await commitOrQueue(
      _appointments.doc(appointment.id).update({
        'status': status.key,
        ..._stamps(uid),
      }),
    );
  });

  @override
  Future<void> cancel(Appointment appointment) => _setStatus(
    appointment,
    AppointmentAction.cancel,
    AppointmentStatus.cancelled,
  );

  @override
  Future<void> markNoShow(Appointment appointment) => _setStatus(
    appointment,
    AppointmentAction.noShow,
    AppointmentStatus.noShow,
  );

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}

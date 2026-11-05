import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/storage/file_store.dart';
import '../../../../core/storage/image_shrinker.dart';
import '../../domain/entities/report.dart';
import '../../domain/report_files.dart';
import '../../domain/repositories/reports_repository.dart';
import '../models/report_model.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FileStore files,
    required ImageShrinker shrinker,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _files = files, // ignore: prefer_initializing_formals
       _shrinker = shrinker, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FileStore _files;
  final ImageShrinker _shrinker;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  @override
  Stream<List<Report>> watchPatientReports(String patientId) => _reports
      .where('patientId', isEqualTo: patientId)
      .snapshots()
      .map((snap) {
        final list =
            snap.docs
                .map((d) => ReportModel.fromMap(d.id, d.data()))
                .where((r) => !r.deleted)
                .toList()
              ..sort((a, b) {
                final at = a.uploadedAt, bt = b.uploadedAt;
                if (at == null || bt == null) {
                  return at == null ? (bt == null ? 0 : 1) : -1;
                }
                return bt.compareTo(at);
              });
        return List<Report>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Future<Report> upload(ReportUpload input) async {
    final uid = _uid;
    final title = input.title.trim();
    if (title.isEmpty) {
      throw const AppException('Enter a title', code: 'invalid-argument');
    }
    if (!ReportFiles.isAllowed(input.mimeType)) {
      throw const AppException(
        ReportFiles.typeMessage,
        code: 'invalid-argument',
      );
    }
    var bytes = input.bytes;
    var mimeType = input.mimeType;
    final sizeProblem = ReportFiles.validate(
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
    if (sizeProblem != null) {
      throw AppException(sizeProblem, code: 'invalid-argument');
    }
    if (ReportFiles.isImage(mimeType)) {
      final shrunk = await _shrinker.shrink(
        bytes: bytes,
        mimeType: mimeType,
        maxSide: ReportFiles.maxImageSide,
        quality: ReportFiles.jpegQuality,
      );
      bytes = shrunk.bytes;
      mimeType = shrunk.mimeType;
    }
    final ref = _reports.doc();
    final path = ReportFiles.storagePath(
      patientId: input.patient.id,
      reportId: ref.id,
      mimeType: mimeType,
    );
    final url = await _files.upload(
      path: path,
      bytes: bytes,
      contentType: mimeType,
    );
    final now = _clock();
    final report = Report(
      id: ref.id,
      patientId: input.patient.id,
      patientName: input.patient.name,
      visitId: input.visitId,
      title: title,
      fileName: input.fileName,
      storagePath: path,
      downloadUrl: url,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      uploadedBy: uid,
      uploadedAt: now,
      branchId: input.patient.branchId,
    );
    try {
      await ref.set({
        ...ReportModel.toMap(report),
        'uploadedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtLocal': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
    return report;
  }

  @override
  Future<void> softDelete(String reportId, {required String reason}) async {
    final uid = _uid;
    if (reason.trim().isEmpty) {
      throw const AppException('Enter a reason', code: 'invalid-argument');
    }
    try {
      await _reports.doc(reportId).update({
        'deleted': true,
        'deleteReason': reason.trim(),
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}

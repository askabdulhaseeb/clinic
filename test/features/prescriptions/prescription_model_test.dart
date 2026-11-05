import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/prescriptions/data/models/prescription_model.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';

void main() {
  const eyeRx = Prescription(
    id: 'v1',
    visitId: 'v1',
    patientId: 'p1',
    patientName: 'Ali Khan',
    patientNo: '26-00001',
    doctorId: 'd1',
    doctorName: 'Dr Sara',
    departmentId: 'eye',
    date: '2026-11-05',
    createdBy: 'doc-1',
    eye: EyePrescription(
      od: EyeValues(sph: '-1.25', cyl: '-0.50', axis: '90', va: '6/6'),
      os: EyeValues(sph: '-1.00', add: '+1.00', va: '6/9'),
    ),
    diagnosis: 'Myopia',
    advice: 'Glasses',
    followUpDate: '2026-11-19',
    followUpAppointmentId: 'a1',
  );

  test('toMap writes the §4.12 shape and fromMap reads it back', () {
    final map = PrescriptionModel.toMap(eyeRx);
    expect(map['visitId'], 'v1');
    expect(map['eye'], {
      'od': {
        'sph': '-1.25',
        'cyl': '-0.50',
        'axis': '90',
        'add': '',
        'va': '6/6',
      },
      'os': {
        'sph': '-1.00',
        'cyl': '',
        'axis': '',
        'add': '+1.00',
        'va': '6/9',
      },
    });
    expect(map['homeo'], isEmpty);
    expect(map['followUpDate'], '2026-11-19');
    expect(map['followUpAppointmentId'], 'a1');
    expect(map['branchId'], 'main');
    expect(
      map.containsKey('createdAt'),
      isFalse,
      reason: 'stamps are added by the repository',
    );

    final back = PrescriptionModel.fromMap('v1', {
      ...map,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 5, 6)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 5, 7)),
    });
    expect(
      back,
      eyeRx.copyWith(
        createdAt: DateTime.utc(2026, 11, 5, 6),
        updatedAt: DateTime.utc(2026, 11, 5, 7),
      ),
    );
  });

  test('homeo rows round-trip and a missing eye map stays null', () {
    const rx = Prescription(
      id: 'v2',
      visitId: 'v2',
      patientId: 'p1',
      patientName: 'Ali Khan',
      patientNo: '26-00001',
      doctorId: 'd2',
      doctorName: 'Dr Imran',
      departmentId: 'homeo',
      date: '2026-11-05',
      createdBy: 'doc-2',
      homeo: [
        HomeoLine(
          medicine: 'Arnica',
          potency: '30C',
          dosage: '3 drops TDS',
          duration: '7 days',
        ),
      ],
      advice: 'Avoid coffee',
    );
    final map = PrescriptionModel.toMap(rx);
    expect(map['eye'], isNull);
    expect(map['homeo'], [
      {
        'medicine': 'Arnica',
        'potency': '30C',
        'dosage': '3 drops TDS',
        'duration': '7 days',
      },
    ]);
    expect(PrescriptionModel.fromMap('v2', map), rx);
  });

  test('fromMap tolerates missing fields', () {
    final rx = PrescriptionModel.fromMap('v3', {'visitId': 'v3'});
    expect(rx.eye, isNull);
    expect(rx.homeo, isEmpty);
    expect(rx.followUpDate, isNull);
    expect(rx.patientName, '');
  });
}

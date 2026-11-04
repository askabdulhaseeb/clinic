import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/settings/domain/entities/clinic_settings.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/initial_setup_vm.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/settings_form_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeSettingsRepository repo;
  setUp(() => repo = FakeSettingsRepository());
  tearDown(() => repo.dispose());

  group('SettingsFormViewModel', () {
    test('validators', () {
      expect(SettingsFormViewModel.validateClinicName(' '), isNotNull);
      expect(SettingsFormViewModel.validateClinicName('C'), isNull);
      expect(SettingsFormViewModel.validateCopies('0'), isNotNull);
      expect(SettingsFormViewModel.validateCopies('6'), isNotNull);
      expect(SettingsFormViewModel.validateCopies('x'), isNotNull);
      expect(SettingsFormViewModel.validateCopies('2'), isNull);
      expect(SettingsFormViewModel.validateReminderDays('-1'), isNotNull);
      expect(SettingsFormViewModel.validateReminderDays('31'), isNotNull);
      expect(SettingsFormViewModel.validateReminderDays('0'), isNull);
    });

    test('save merges form values over the initial document', () async {
      final vm = SettingsFormViewModel(
        repository: repo,
        initial: sampleSettings,
      )..setReminder(postOp: false);
      final ok = await vm.save(
        clinicName: ' New Name ',
        address: 'A',
        phone: 'P',
        receiptFooter: 'F',
        defaultReceiptCopies: 2,
        followUpReminderDays: 1,
        templates: const WhatsappTemplates(adhoc: 'hi {patient}'),
      );
      expect(ok, isTrue);
      final saved = repo.saved.single;
      expect(saved.clinicName, 'New Name');
      expect(saved.defaultReceiptCopies, 2);
      expect(saved.reminders.postOp, isFalse);
      expect(saved.reminders.appointment, isTrue);
      expect(saved.whatsappTemplates.adhoc, 'hi {patient}');
      expect(saved.timezone, sampleSettings.timezone);
    });

    test('save failure keeps the message', () async {
      repo.saveError = const AppException('denied');
      final vm = SettingsFormViewModel(
        repository: repo,
        initial: sampleSettings,
      );
      final ok = await vm.save(
        clinicName: 'C',
        address: '',
        phone: '',
        receiptFooter: '',
        defaultReceiptCopies: 1,
        followUpReminderDays: 0,
        templates: const WhatsappTemplates(),
      );
      expect(ok, isFalse);
      expect(vm.error, 'denied');
      vm.clearError();
      expect(vm.error, isNull);
    });

    test(
      'uploadLogo rejects big or non-image files before uploading',
      () async {
        final vm = SettingsFormViewModel(
          repository: repo,
          initial: sampleSettings,
        );
        expect(
          await vm.uploadLogo(
            bytes: Uint8List(SettingsFormViewModel.maxLogoBytes + 1),
            contentType: 'image/png',
          ),
          isFalse,
        );
        expect(vm.error, contains('2 MB'));
        expect(
          await vm.uploadLogo(
            bytes: Uint8List(10),
            contentType: 'application/pdf',
          ),
          isFalse,
        );
        expect(repo.uploads, isEmpty);

        expect(
          await vm.uploadLogo(bytes: Uint8List(10), contentType: 'image/jpeg'),
          isTrue,
        );
        expect(vm.logoUrl, 'https://example.test/logo.png');
        expect(repo.uploads.single.contentType, 'image/jpeg');
      },
    );
  });

  group('InitialSetupViewModel', () {
    test('runs the setup with trimmed values', () async {
      final vm = InitialSetupViewModel(repository: repo);
      expect(InitialSetupViewModel.validateClinicName(''), isNotNull);
      final ok = await vm.run(clinicName: 'Ramzan', address: 'K', phone: '1');
      expect(ok, isTrue);
      expect(repo.setups.single.clinicName, 'Ramzan');
      expect(vm.running, isFalse);
    });

    test('surfaces failures', () async {
      repo.setupError = const AppException('offline');
      final vm = InitialSetupViewModel(repository: repo);
      expect(await vm.run(clinicName: 'R'), isFalse);
      expect(vm.error, 'offline');
    });
  });
}

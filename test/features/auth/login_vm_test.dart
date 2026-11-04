import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/change_password_vm.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/login_vm.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  group('LoginViewModel', () {
    test('validators', () {
      expect(LoginViewModel.validateEmail(''), isNotNull);
      expect(LoginViewModel.validateEmail('nope'), isNotNull);
      expect(LoginViewModel.validateEmail(' a@b.pk '), isNull);
      expect(LoginViewModel.validatePassword(''), isNotNull);
      expect(LoginViewModel.validatePassword('x'), isNull);
    });

    test('submit success passes credentials through', () async {
      final repo = FakeAuthRepository();
      final vm = LoginViewModel(
        session: SessionController(
          repository: repo,
          store: InMemoryKeyValueStore(),
        ),
      );
      final ok = await vm.submit(email: 'a@b.pk', password: 'secret12');
      expect(ok, isTrue);
      expect(vm.error, isNull);
      expect(vm.submitting, isFalse);
      expect(repo.signInCalls.single.email, 'a@b.pk');
    });

    test('submit failure exposes the message', () async {
      final repo = FakeAuthRepository()
        ..signInError = const AppException('Email or password is incorrect.');
      final vm = LoginViewModel(
        session: SessionController(
          repository: repo,
          store: InMemoryKeyValueStore(),
        ),
      );
      final ok = await vm.submit(email: 'a@b.pk', password: 'bad');
      expect(ok, isFalse);
      expect(vm.error, 'Email or password is incorrect.');
    });
  });

  group('ChangePasswordViewModel', () {
    test('validators', () {
      expect(ChangePasswordViewModel.validateCurrent(''), isNotNull);
      expect(ChangePasswordViewModel.validateNew('short'), isNotNull);
      expect(
        ChangePasswordViewModel.validateNew('samesame', current: 'samesame'),
        isNotNull,
      );
      expect(ChangePasswordViewModel.validateNew('longenough'), isNull);
      expect(
        ChangePasswordViewModel.validateConfirm('a', newPassword: 'b'),
        isNotNull,
      );
      expect(
        ChangePasswordViewModel.validateConfirm('b', newPassword: 'b'),
        isNull,
      );
    });

    test('submit forwards to the session', () async {
      final repo = FakeAuthRepository();
      final vm = ChangePasswordViewModel(
        session: SessionController(
          repository: repo,
          store: InMemoryKeyValueStore(),
        ),
      );
      final ok = await vm.submit(
        currentPassword: 'old',
        newPassword: 'newpass12',
      );
      expect(ok, isTrue);
      expect(repo.changePasswordCalls.single.next, 'newpass12');
    });

    test('submit failure exposes the message', () async {
      final repo = FakeAuthRepository()
        ..changePasswordError = const AppException('wrong');
      final vm = ChangePasswordViewModel(
        session: SessionController(
          repository: repo,
          store: InMemoryKeyValueStore(),
        ),
      );
      expect(await vm.submit(currentPassword: 'x', newPassword: 'y'), isFalse);
      expect(vm.error, 'wrong');
    });
  });
}

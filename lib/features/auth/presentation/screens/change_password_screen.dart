import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/change_password_vm.dart';
import '../viewmodels/session_controller.dart';
import '../widgets/auth_card.dart';

/// Forced on first login (`mustChangePassword`), also reachable from the
/// user menu.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  /// When true the user cannot leave until the password is changed.
  final bool forced;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ChangePasswordViewModel(session: context.read<SessionController>()),
      child: _ChangePasswordForm(forced: forced),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm({required this.forced});

  final bool forced;

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await context.read<ChangePasswordViewModel>().submit(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Password changed')));
    if (!widget.forced && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // When forced, the router redirect moves on once mustChangePassword flips.
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChangePasswordViewModel>();
    return AuthCard(
      title: 'Change password',
      subtitle: widget.forced
          ? 'Set your own password before continuing'
          : null,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: ChangePasswordViewModel.validateCurrent,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 8 characters',
              ),
              validator: (v) => ChangePasswordViewModel.validateNew(
                v,
                current: _current.text,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Repeat new password',
              ),
              validator: (v) => ChangePasswordViewModel.validateConfirm(
                v,
                newPassword: _next.text,
              ),
            ),
            if (vm.error != null) ...[
              const SizedBox(height: 12),
              Text(
                vm.error!,
                key: const Key('change-password-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: vm.submitting ? null : _submit,
              child: vm.submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save password'),
            ),
            if (widget.forced) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.read<SessionController>().signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

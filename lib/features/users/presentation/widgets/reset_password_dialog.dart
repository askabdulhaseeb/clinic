import 'package:flutter/material.dart';

import '../viewmodels/user_form_vm.dart';

/// Asks for a temporary password. Returns it, or null when cancelled.
Future<String?> showResetPasswordDialog(
  BuildContext context, {
  required String displayName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ResetPasswordDialog(displayName: displayName),
  );
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.displayName});

  final String displayName;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.displayName} will sign in with this temporary password '
              'and must change it on first login.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Temporary password',
                helperText: 'At least 8 characters',
              ),
              validator: UserFormViewModel.validateTemporaryPassword,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Reset')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../domain/repositories/user_admin_repository.dart';
import '../viewmodels/user_form_vm.dart';

/// Opens the create or edit form as a dialog. Resolves to true when saved.
Future<bool> showUserFormDialog(
  BuildContext context, {
  AppUser? existing,
}) async {
  final repo = context.read<UserAdminRepository>();
  final catalog = context.read<CatalogRepository>();
  final currentUid = context.read<SessionController>().user?.uid ?? '';
  final saved = await showDialog<bool>(
    context: context,
    // Cancel is the only way out so a tap outside cannot drop a running save.
    barrierDismissible: false,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => UserFormViewModel(
        repository: repo,
        catalog: catalog,
        currentUid: currentUid,
        existing: existing,
      ),
      child: const UserFormDialog(),
    ),
  );
  return saved ?? false;
}

/// Create or edit account form. Expects a [UserFormViewModel] above it.
class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = context.read<UserFormViewModel>().existing;
    _name = TextEditingController(text: existing?.displayName ?? '');
    _email = TextEditingController(text: existing?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = context.read<UserFormViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await vm.submit(
      displayName: _name.text,
      email: _email.text,
      temporaryPassword: _password.text,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserFormViewModel>();
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(vm.isEdit ? 'Edit user' : 'New user'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: !vm.isEdit,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: UserFormViewModel.validateName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  enabled: !vm.isEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: vm.isEdit ? null : UserFormViewModel.validateEmail,
                ),
                if (!vm.isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      helperText: 'User must change it on first login',
                    ),
                    validator: UserFormViewModel.validateTemporaryPassword,
                  ),
                ],
                const SizedBox(height: 16),
                Text('Roles', style: Theme.of(context).textTheme.labelLarge),
                for (final role in UserRole.values)
                  CheckboxListTile(
                    key: Key('role-${role.key}'),
                    value: vm.roles.contains(role),
                    onChanged: vm.canToggleRole(role)
                        ? (v) => vm.toggleRole(role, v ?? false)
                        : null,
                    title: Text(role.label),
                    subtitle: !vm.canToggleRole(role)
                        ? const Text('You cannot remove your own admin role')
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                if (vm.needsDoctorId) ...[
                  const SizedBox(height: 8),
                  _DoctorPicker(vm: vm),
                ],
                if (vm.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    vm.error!,
                    key: const Key('user-form-error'),
                    style: TextStyle(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: vm.submitting ? null : _submit,
          child: vm.submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(vm.isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

/// Dropdown of doctor records that can take this login.
class _DoctorPicker extends StatelessWidget {
  const _DoctorPicker({required this.vm});

  final UserFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (vm.doctorsError != null) {
      return Text(vm.doctorsError!, style: TextStyle(color: scheme.error));
    }
    final options = vm.linkableDoctors;
    final value = options.any((d) => d.id == vm.doctorId) ? vm.doctorId : null;
    return DropdownButtonFormField<String>(
      key: const Key('doctor-picker'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Doctor record',
        helperText: vm.doctorsLoading
            ? 'Loading doctors…'
            : options.isEmpty
            ? 'No unlinked doctor. Add one under Catalog → Doctors first.'
            : 'Links this login to a doctor',
      ),
      items: [
        for (final d in options)
          DropdownMenuItem(
            value: d.id,
            child: Text(
              d.specialisation.isEmpty
                  ? d.name
                  : '${d.name} · ${d.specialisation}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: vm.setDoctorId,
      validator: vm.validateDoctor,
    );
  }
}

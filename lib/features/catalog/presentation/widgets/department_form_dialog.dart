import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/department.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../viewmodels/department_form_vm.dart';

/// Opens the create or edit dialog. Resolves to true when saved.
Future<bool> showDepartmentFormDialog(
  BuildContext context, {
  required List<Department> others,
  Department? existing,
}) async {
  final repo = context.read<CatalogRepository>();
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => DepartmentFormViewModel(
        repository: repo,
        others: others,
        existing: existing,
      ),
      child: const DepartmentFormDialog(),
    ),
  );
  return saved ?? false;
}

/// Name and code. Expects a [DepartmentFormViewModel] above it.
class DepartmentFormDialog extends StatefulWidget {
  const DepartmentFormDialog({super.key});

  @override
  State<DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends State<DepartmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;

  @override
  void initState() {
    super.initState();
    final existing = context.read<DepartmentFormViewModel>().existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _code = TextEditingController(text: existing?.code ?? '');
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<DepartmentFormViewModel>();
    final ok = await vm.submit(name: _name.text, code: _code.text);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DepartmentFormViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final codeChanged = vm.codeChanged(_code.text);
    return AlertDialog(
      title: Text(vm.isEdit ? 'Edit department' : 'New department'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('department-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: DepartmentFormViewModel.validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('department-code'),
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: Department.maxCodeLength,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  helperText: 'Prefixes tokens, e.g. E-12',
                ),
                validator: vm.validateCode,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (codeChanged)
                Text(
                  'Changing the code changes the prefix of every token issued '
                  'from now on. Tokens already printed keep the old one.',
                  key: const Key('department-code-warning'),
                  style: TextStyle(color: scheme.error),
                ),
              if (vm.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  vm.error!,
                  key: const Key('department-form-error'),
                  style: TextStyle(color: scheme.error),
                ),
              ],
            ],
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

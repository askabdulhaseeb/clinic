import 'package:flutter/material.dart';

import '../../../../core/utils/phone.dart';
import '../../domain/entities/family.dart';
import '../viewmodels/patient_form_vm.dart';
import '../viewmodels/patient_search_vm.dart' show FamilyLookup;

/// Edit head name and address.
Future<void> showEditFamilyDialog(
  BuildContext context, {
  required Family family,
  required Future<bool> Function({
    required String headName,
    required String address,
  })
  onSave,
}) => showDialog<void>(
  context: context,
  builder: (_) => _EditFamilyDialog(family: family, onSave: onSave),
);

class _EditFamilyDialog extends StatefulWidget {
  const _EditFamilyDialog({required this.family, required this.onSave});

  final Family family;
  final Future<bool> Function({
    required String headName,
    required String address,
  })
  onSave;

  @override
  State<_EditFamilyDialog> createState() => _EditFamilyDialogState();
}

class _EditFamilyDialogState extends State<_EditFamilyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _head = TextEditingController(text: widget.family.headName);
  late final _address = TextEditingController(text: widget.family.address);
  bool _busy = false;

  @override
  void dispose() {
    _head.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final ok = await widget.onSave(
      headName: _head.text,
      address: _address.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit family'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('family-head-input'),
                controller: _head,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Head of family'),
                validator: PatientFormViewModel.validateHeadName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('family-address-input'),
                controller: _address,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('family-save'),
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Change the family phone; fans out to every member.
Future<void> showChangeFamilyPhoneDialog(
  BuildContext context, {
  required Family family,
  required Future<bool> Function(String raw) onSave,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ChangePhoneDialog(family: family, onSave: onSave),
);

class _ChangePhoneDialog extends StatefulWidget {
  const _ChangePhoneDialog({required this.family, required this.onSave});

  final Family family;
  final Future<bool> Function(String raw) onSave;

  @override
  State<_ChangePhoneDialog> createState() => _ChangePhoneDialogState();
}

class _ChangePhoneDialogState extends State<_ChangePhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final ok = await widget.onSave(_phone.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.family.patientCount;
    return AlertDialog(
      title: const Text('Change family phone'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Current: ${Phone.display(widget.family.phone)}. '
                'The new number applies to all $n patient${n == 1 ? '' : 's'} '
                'of this family.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('change-phone-input'),
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'New phone',
                  hintText: '0300 1234567',
                ),
                validator: PatientFormViewModel.validatePhone,
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('change-phone-save'),
          onPressed: _busy ? null : _save,
          child: const Text('Change'),
        ),
      ],
    );
  }
}

/// Move the patient to the family that owns another phone number.
Future<void> showMovePatientDialog(
  BuildContext context, {
  required String patientName,
  required Future<FamilyLookup> Function(String raw) find,
  required Future<bool> Function(String familyId) onMove,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _MovePatientDialog(patientName: patientName, find: find, onMove: onMove),
);

class _MovePatientDialog extends StatefulWidget {
  const _MovePatientDialog({
    required this.patientName,
    required this.find,
    required this.onMove,
  });

  final String patientName;
  final Future<FamilyLookup> Function(String raw) find;
  final Future<bool> Function(String familyId) onMove;

  @override
  State<_MovePatientDialog> createState() => _MovePatientDialogState();
}

class _MovePatientDialogState extends State<_MovePatientDialog> {
  final _phone = TextEditingController();
  bool _busy = false;
  FamilyLookup? _result;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() => _busy = true);
    final r = await widget.find(_phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r;
    });
  }

  Future<void> _move() async {
    final family = _result?.family;
    if (family == null) return;
    setState(() => _busy = true);
    final ok = await widget.onMove(family.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final family = _result?.family;
    return AlertDialog(
      title: const Text('Move to another family'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the phone of the family ${widget.patientName} '
              'should belong to.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('move-phone-input'),
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Family phone',
                hintText: '0300 1234567',
                errorText: _result?.error,
              ),
              onChanged: (_) {
                if (_result != null) setState(() => _result = null);
              },
              onSubmitted: (_) => _find(),
            ),
            if (family != null) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.family_restroom),
                title: Text('Family of ${family.headName}'),
                subtitle: Text(
                  '${Phone.display(family.phone)} · '
                  '${family.patientCount} patient'
                  '${family.patientCount == 1 ? '' : 's'}',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (family == null)
          FilledButton(
            key: const Key('move-find'),
            onPressed: _busy ? null : _find,
            child: const Text('Find family'),
          )
        else
          FilledButton(
            key: const Key('move-confirm'),
            onPressed: _busy ? null : _move,
            child: const Text('Move'),
          ),
      ],
    );
  }
}

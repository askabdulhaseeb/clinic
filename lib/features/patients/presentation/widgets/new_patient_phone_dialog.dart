import 'package:flutter/material.dart';

import '../../../../core/utils/phone.dart';
import '../../domain/entities/family.dart';
import '../viewmodels/patient_search_vm.dart';

/// What the "New patient" prompt decided.
sealed class NewPatientChoice {
  const NewPatientChoice();
}

class NewPatientNewFamily extends NewPatientChoice {
  const NewPatientNewFamily(this.phone);
  final String phone;
}

class NewPatientAddToFamily extends NewPatientChoice {
  const NewPatientAddToFamily(this.family);
  final Family family;
}

/// "New patient" first asks for the phone and shows the family if it
/// exists (UI_DESIGN §4.2). Resolves to null when cancelled.
Future<NewPatientChoice?> showNewPatientPhoneDialog(
  BuildContext context, {
  required Future<FamilyLookup> Function(String raw) lookup,
  String initialPhone = '',
}) => showDialog<NewPatientChoice>(
  context: context,
  builder: (_) =>
      NewPatientPhoneDialog(lookup: lookup, initialPhone: initialPhone),
);

class NewPatientPhoneDialog extends StatefulWidget {
  const NewPatientPhoneDialog({
    super.key,
    required this.lookup,
    this.initialPhone = '',
  });

  final Future<FamilyLookup> Function(String raw) lookup;
  final String initialPhone;

  @override
  State<NewPatientPhoneDialog> createState() => _NewPatientPhoneDialogState();
}

class _NewPatientPhoneDialogState extends State<NewPatientPhoneDialog> {
  late final TextEditingController _phone;
  bool _busy = false;
  FamilyLookup? _result;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    final r = await widget.lookup(_phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final family = result?.family;
    final phone = result?.phone;
    return AlertDialog(
      title: const Text('New patient'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('new-patient-phone'),
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Family phone',
                hintText: '0300 1234567',
                errorText: result?.error,
              ),
              onChanged: (_) {
                if (_result != null) setState(() => _result = null);
              },
              onSubmitted: (_) => _continue(),
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
            ] else if (phone != null && result?.error == null) ...[
              const SizedBox(height: 16),
              Text(
                'No family has ${Phone.display(phone)} yet. '
                'Register it as a new family.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (family != null)
          FilledButton(
            key: const Key('new-patient-add-to-family'),
            onPressed: () =>
                Navigator.of(context).pop(NewPatientAddToFamily(family)),
            child: const Text('Add to this family'),
          )
        else if (phone != null && result?.error == null)
          FilledButton(
            key: const Key('new-patient-new-family'),
            onPressed: () =>
                Navigator.of(context).pop(NewPatientNewFamily(phone)),
            child: const Text('New family'),
          )
        else
          FilledButton(
            key: const Key('new-patient-continue'),
            onPressed: _busy ? null : _continue,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
      ],
    );
  }
}

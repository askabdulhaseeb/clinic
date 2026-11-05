import 'package:flutter/material.dart';

import '../../domain/entities/prescription.dart';
import '../viewmodels/consultation_vm.dart';

/// OD / OS table of SPH, CYL, AXIS, ADD, VA (UI_DESIGN §4.6). Scrolls
/// sideways on phones; the row labels stay put.
class EyeForm extends StatefulWidget {
  const EyeForm({
    super.key,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final EyePrescription values;
  final bool enabled;
  final void Function(Eye eye, EyeField field, String value) onChanged;

  @override
  State<EyeForm> createState() => _EyeFormState();
}

class _EyeFormState extends State<EyeForm> {
  final _controllers = <(Eye, EyeField), TextEditingController>{
    for (final e in Eye.values)
      for (final f in EyeField.values) (e, f): TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _value(Eye e, EyeField f) {
    final v = e == Eye.od ? widget.values.od : widget.values.os;
    return switch (f) {
      EyeField.sph => v.sph,
      EyeField.cyl => v.cyl,
      EyeField.axis => v.axis,
      EyeField.add => v.add,
      EyeField.va => v.va,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Keep controllers in step with the view model (a saved prescription
    // fills the form) without fighting the field being typed in.
    for (final entry in _controllers.entries) {
      final text = _value(entry.key.$1, entry.key.$2);
      if (entry.value.text != text) entry.value.text = text;
    }
    final scheme = Theme.of(context).colorScheme;
    final head = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: scheme.outline);
    Widget cell(Eye e, EyeField f, {TextInputType? type}) => SizedBox(
      width: 84,
      child: TextField(
        key: Key('rx-${e.name}-${f.name}'),
        controller: _controllers[(e, f)],
        enabled: widget.enabled,
        textAlign: TextAlign.center,
        keyboardType:
            type ??
            const TextInputType.numberWithOptions(signed: true, decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        ),
        onChanged: (v) => widget.onChanged(e, f, v),
      ),
    );
    Widget label(String t) => SizedBox(
      width: 60,
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
    Widget row(Eye e, String name) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          label(name),
          for (final f in EyeField.values) ...[
            const SizedBox(width: 6),
            cell(e, f, type: f == EyeField.va ? TextInputType.text : null),
          ],
        ],
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              label(''),
              for (final h in ['SPH', 'CYL', 'AXIS', 'ADD', 'VA']) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 84,
                  child: Text(h, style: head, textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          row(Eye.od, 'OD (R)'),
          row(Eye.os, 'OS (L)'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/entities/prescription.dart';

/// Rows of medicine, potency, dosage, duration with add and remove
/// (UI_DESIGN §4.6). Free text; inventory suggestions arrive in Phase 7.
class HomeoForm extends StatefulWidget {
  const HomeoForm({
    super.key,
    required this.lines,
    required this.enabled,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<HomeoLine> lines;
  final bool enabled;
  final void Function(int index, HomeoLine line) onChanged;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  State<HomeoForm> createState() => _HomeoFormState();
}

class _HomeoFormState extends State<HomeoForm> {
  final _controllers = <(int, String), TextEditingController>{};

  TextEditingController _controller(int i, String field, String text) {
    final c = _controllers.putIfAbsent((
      i,
      field,
    ), () => TextEditingController(text: text));
    if (c.text != text) c.text = text;
    return c;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    Widget field(
      int i,
      String name,
      String hint,
      String value,
      HomeoLine Function(String) set, {
      int flex = 2,
    }) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: TextField(
          key: Key('rx-homeo-$i-$name'),
          controller: _controller(i, name, value),
          enabled: widget.enabled,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 8,
            ),
          ),
          onChanged: (v) => widget.onChanged(i, set(v)),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                field(
                  i,
                  'medicine',
                  'Medicine',
                  widget.lines[i].medicine,
                  (v) => widget.lines[i].copyWith(medicine: v),
                  flex: 3,
                ),
                field(
                  i,
                  'potency',
                  'Potency',
                  widget.lines[i].potency,
                  (v) => widget.lines[i].copyWith(potency: v),
                ),
                if (!compact) ...[
                  field(
                    i,
                    'dosage',
                    'Dosage',
                    widget.lines[i].dosage,
                    (v) => widget.lines[i].copyWith(dosage: v),
                    flex: 3,
                  ),
                  field(
                    i,
                    'duration',
                    'Duration',
                    widget.lines[i].duration,
                    (v) => widget.lines[i].copyWith(duration: v),
                  ),
                ],
                IconButton(
                  key: Key('rx-homeo-remove-$i'),
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.enabled ? () => widget.onRemove(i) : null,
                ),
              ],
            ),
          ),
        if (compact)
          for (var i = 0; i < widget.lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  field(
                    i,
                    'dosage',
                    'Dosage (row ${i + 1})',
                    widget.lines[i].dosage,
                    (v) => widget.lines[i].copyWith(dosage: v),
                    flex: 3,
                  ),
                  field(
                    i,
                    'duration',
                    'Duration',
                    widget.lines[i].duration,
                    (v) => widget.lines[i].copyWith(duration: v),
                  ),
                ],
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('rx-homeo-add'),
            onPressed: widget.enabled ? widget.onAdd : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add medicine'),
          ),
        ),
      ],
    );
  }
}

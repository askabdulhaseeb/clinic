import 'package:flutter/material.dart';

import '../../domain/entities/department.dart';

/// Department picker for forms. Lists active departments plus the current
/// value when it is inactive, so an edit never loses its department.
class DepartmentDropdown extends StatelessWidget {
  const DepartmentDropdown({
    super.key,
    required this.departments,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<Department> departments;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final options = departments
        .where((d) => d.active || d.id == value)
        .toList(growable: false);
    final current = options.any((d) => d.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      key: const Key('department-dropdown'),
      initialValue: current,
      decoration: const InputDecoration(labelText: 'Department'),
      items: [
        for (final d in options)
          DropdownMenuItem(
            value: d.id,
            child: Text(d.active ? d.name : '${d.name} (inactive)'),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: (v) => v == null ? 'Pick a department' : null,
    );
  }
}

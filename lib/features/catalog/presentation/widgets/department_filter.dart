import 'package:flutter/material.dart';

import '../../domain/entities/department.dart';

/// "All" plus one segment per department. Inactive departments are listed
/// too so their records stay reachable.
class DepartmentFilter extends StatelessWidget {
  const DepartmentFilter({
    super.key,
    required this.departments,
    required this.selected,
    required this.onChanged,
    this.allowAll = true,
  });

  final List<Department> departments;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool allowAll;

  @override
  Widget build(BuildContext context) {
    if (departments.isEmpty) return const SizedBox.shrink();
    return SegmentedButton<String?>(
      key: const Key('department-filter'),
      segments: [
        if (allowAll) const ButtonSegment(value: null, label: Text('All')),
        for (final d in departments)
          ButtonSegment(
            value: d.id,
            label: Text(d.active ? d.name : '${d.name} (inactive)'),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../auth/domain/entities/user_role.dart';

/// Small chips listing a user's roles.
class RoleChips extends StatelessWidget {
  const RoleChips({super.key, required this.roles});

  final List<UserRole> roles;

  @override
  Widget build(BuildContext context) {
    final sorted = [...roles]..sort((a, b) => a.index.compareTo(b.index));
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final role in sorted)
          Chip(
            label: Text(role.label),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }
}

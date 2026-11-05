import 'package:flutter/material.dart';

import '../../../settings/domain/entities/clinic_settings.dart';

/// `−  2  +` for the receipt copy count, 1 to 5 (FEATURES §5.7).
class CopiesStepper extends StatelessWidget {
  const CopiesStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'visit-copies',
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String keyPrefix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('$keyPrefix-minus'),
          tooltip: 'Fewer copies',
          icon: const Icon(Icons.remove),
          onPressed: enabled && value > ClinicSettings.minReceiptCopies
              ? () => onChanged(value - 1)
              : null,
        ),
        Text(
          '$value',
          key: Key(keyPrefix),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          key: Key('$keyPrefix-plus'),
          tooltip: 'More copies',
          icon: const Icon(Icons.add),
          onPressed: enabled && value < ClinicSettings.maxReceiptCopies
              ? () => onChanged(value + 1)
              : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/utils/phone.dart';
import '../../domain/entities/patient.dart';

/// Name, age, gender, patient number and phone (UI_DESIGN §5 components).
/// Shared by patient detail now, visit and consultation later.
class PatientHeader extends StatelessWidget {
  const PatientHeader({
    super.key,
    required this.patient,
    required this.today,
    this.familyPhone,
    this.dense = false,
  });

  final Patient patient;

  /// `YYYY-MM-DD` used to compute the age.
  final String today;
  final String? familyPhone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final age = patient.ageLabel(today);
    final details = [
      if (age.isNotEmpty) age,
      patient.gender.label,
      if (familyPhone != null) Phone.display(familyPhone!),
      if (patient.personalPhone case final p?) 'Personal ${Phone.display(p)}',
    ].join(' · ');
    return Row(
      children: [
        CircleAvatar(
          radius: dense ? 18 : 24,
          child: Icon(switch (patient.gender) {
            Gender.male => Icons.man,
            Gender.female => Icons.woman,
            Gender.other => Icons.person,
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient.name,
                style: dense ? text.titleMedium : text.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                details,
                style: text.bodyMedium?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PatientNoChip(patient: patient),
      ],
    );
  }
}

/// `26-00341`, or the temp number with a "pending" look until synced.
class PatientNoChip extends StatelessWidget {
  const PatientNoChip({super.key, required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = !patient.isSynced;
    return Tooltip(
      message: pending
          ? 'Temporary number until the record syncs'
          : 'Patient number',
      child: Chip(
        avatar: Icon(
          pending ? Icons.cloud_upload_outlined : Icons.badge_outlined,
          size: 18,
        ),
        label: Text(
          patient.displayNo,
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: pending ? scheme.onSurfaceVariant : null,
          ),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

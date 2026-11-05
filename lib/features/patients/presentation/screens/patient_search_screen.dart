import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patients_repository.dart';
import '../viewmodels/patient_search_vm.dart';
import '../widgets/new_patient_phone_dialog.dart';
import '../widgets/patient_header.dart';

/// `/reception/patients` and `/admin/patients` (UI_DESIGN §4.2).
class PatientSearchScreen extends StatelessWidget {
  const PatientSearchScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PatientSearchViewModel(
        repository: context.read<PatientsRepository>(),
      ),
      child: PatientSearchView(role: role),
    );
  }
}

/// Body; expects a [PatientSearchViewModel] above it.
class PatientSearchView extends StatefulWidget {
  const PatientSearchView({super.key, required this.role, this.clock});

  final UserRole role;
  final DateTime Function()? clock;

  @override
  State<PatientSearchView> createState() => _PatientSearchViewState();
}

class _PatientSearchViewState extends State<PatientSearchView> {
  static const _debounce = Duration(milliseconds: 300);
  final _search = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _run(text));
  }

  void _run(String text) {
    _timer?.cancel();
    unawaited(context.read<PatientSearchViewModel>().search(text));
  }

  Future<void> _newPatient({String initialPhone = ''}) async {
    final vm = context.read<PatientSearchViewModel>();
    final choice = await showNewPatientPhoneDialog(
      context,
      lookup: vm.lookupFamily,
      initialPhone: initialPhone,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case NewPatientNewFamily(:final phone):
        context.go(AppRoutes.patientNewFor(widget.role, phone: phone));
      case NewPatientAddToFamily(:final family):
        context.go(AppRoutes.patientNewFor(widget.role, familyId: family.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PatientSearchViewModel>();
    final today = KarachiDate.today(widget.clock?.call());
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('patient-search'),
                    controller: _search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Phone, patient ID or name',
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('patient-search-clear'),
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                _run('');
                              },
                            ),
                    ),
                    onChanged: _onChanged,
                    onSubmitted: _run,
                  ),
                ),
                // Doctors search read-only (UI_DESIGN §4.6a).
                if (widget.role != UserRole.doctor) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const Key('patient-new'),
                    onPressed: _newPatient,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('New patient'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _Body(
              vm: vm,
              role: widget.role,
              today: today,
              onRegisterPhone: (phone) => context.go(
                AppRoutes.patientNewFor(widget.role, phone: phone),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.vm,
    required this.role,
    required this.today,
    required this.onRegisterPhone,
  });

  final PatientSearchViewModel vm;
  final UserRole role;
  final String today;
  final void Function(String phone) onRegisterPhone;

  @override
  Widget build(BuildContext context) {
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Search failed',
        message: vm.error,
      );
    }
    switch (vm.mode) {
      case SearchMode.empty:
        return const EmptyState(
          icon: Icons.search,
          title: 'Search by phone, patient ID or name',
          message: 'Results are grouped by family.',
        );
      case SearchMode.tooShort:
        return const EmptyState(
          icon: Icons.keyboard,
          title: 'Keep typing',
          message: 'At least two letters, or a full mobile number.',
        );
      case SearchMode.phone:
      case SearchMode.patientNo:
      case SearchMode.name:
        if (vm.groups.isEmpty) {
          final phone = vm.mode == SearchMode.phone
              ? Phone.normalize(vm.query)
              : null;
          return EmptyState(
            icon: Icons.person_search,
            title: 'No patient found',
            message: phone == null
                ? 'Check the spelling, or register the patient.'
                : 'No family has ${Phone.display(phone)} yet.',
            action: phone == null
                ? null
                : FilledButton.icon(
                    key: const Key('register-phone'),
                    onPressed: () => onRegisterPhone(phone),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Register new family'),
                  ),
          );
        }
        // Cached matches cost nothing; the server is one tap away when the
        // patient is not among them (FIREBASE_ARCHITECTURE §9).
        final fromCache = vm.origin == ResultOrigin.cache;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: vm.groups.length + (fromCache ? 1 : 0),
          itemBuilder: (context, i) {
            if (fromCache && i == vm.groups.length) {
              return _SearchOnlineRow(onPressed: vm.searchOnline);
            }
            return FamilyGroupCard(
              group: vm.groups[i],
              role: role,
              today: today,
            );
          },
        );
    }
  }
}

/// Footer under results that came from this device's cache.
class _SearchOnlineRow extends StatelessWidget {
  const _SearchOnlineRow({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Matches saved on this device.',
              style: TextStyle(color: scheme.outline),
            ),
          ),
          TextButton.icon(
            key: const Key('search-online'),
            onPressed: () => unawaited(onPressed()),
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: const Text('Not here? Search online'),
          ),
        ],
      ),
    );
  }
}

/// One family header with its patient rows (UI_DESIGN §4.2).
class FamilyGroupCard extends StatelessWidget {
  const FamilyGroupCard({
    super.key,
    required this.group,
    required this.role,
    required this.today,
  });

  final FamilyGroup group;
  final UserRole role;
  final String today;

  @override
  Widget build(BuildContext context) {
    final family = group.family;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Icon(Icons.family_restroom, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.headName.isEmpty ? 'Family' : family.headName,
                        style: text.titleMedium,
                      ),
                      Text(
                        [
                          Phone.display(family.phone),
                          if (family.address.isNotEmpty) family.address,
                        ].join(' · '),
                        style: text.bodySmall?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                if (family.duplicatePhone) const _DuplicateChip(),
                if (role != UserRole.doctor)
                  TextButton.icon(
                    key: Key('family-add-${family.id}'),
                    onPressed: () => context.go(
                      AppRoutes.patientNewFor(role, familyId: family.id),
                    ),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add patient'),
                  ),
              ],
            ),
          ),
          if (group.patients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No patients registered under this family yet.'),
            ),
          for (final p in group.patients)
            PatientRow(patient: p, role: role, today: today),
        ],
      ),
    );
  }
}

class _DuplicateChip extends StatelessWidget {
  const _DuplicateChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message:
            'Another family was registered with this number. '
            'Admin can merge them.',
        child: Chip(
          avatar: Icon(Icons.warning_amber, size: 18, color: scheme.error),
          label: const Text('Duplicate phone'),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// One patient row: name, age, gender, number, last visit, actions.
class PatientRow extends StatelessWidget {
  const PatientRow({
    super.key,
    required this.patient,
    required this.role,
    required this.today,
  });

  final Patient patient;
  final UserRole role;
  final String today;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final scheme = Theme.of(context).colorScheme;
    final age = patient.ageLabel(today);
    final lastVisit = patient.lastVisitAt == null
        ? 'No visits yet'
        : 'Last visit ${KarachiDate.format(KarachiDate.now(patient.lastVisitAt))}';
    void open() => context.go(AppRoutes.patientFor(role, patient.id));
    return ListTile(
      key: Key('patient-row-${patient.id}'),
      onTap: open,
      title: Text(patient.name),
      subtitle: Text(
        [if (age.isNotEmpty) age, patient.gender.label, lastVisit].join(' · '),
        style: TextStyle(color: scheme.outline),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PatientNoChip(patient: patient),
          if (!compact && role != UserRole.doctor) ...[
            const SizedBox(width: 8),
            TextButton(
              key: Key('patient-new-visit-${patient.id}'),
              onPressed: () => context.go(
                AppRoutes.visitNewFor(role, patientId: patient.id),
              ),
              child: const Text('New visit'),
            ),
            TextButton(
              key: Key('patient-book-${patient.id}'),
              onPressed: () => context.go(
                AppRoutes.appointmentNewFor(role, patientId: patient.id),
              ),
              child: const Text('Book'),
            ),
          ],
          IconButton(
            key: Key('patient-open-${patient.id}'),
            tooltip: 'Open',
            icon: const Icon(Icons.chevron_right),
            onPressed: open,
          ),
        ],
      ),
    );
  }
}

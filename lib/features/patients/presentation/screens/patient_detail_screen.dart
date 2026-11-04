import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../settings/presentation/viewmodels/settings_controller.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patients_repository.dart';
import '../viewmodels/patient_detail_vm.dart';
import '../widgets/family_dialogs.dart';
import '../widgets/patient_header.dart';

/// `/<role>/patients/:id` (UI_DESIGN §3.2): family members, visits,
/// reports, appointments, WhatsApp button.
class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({
    super.key,
    required this.role,
    required this.patientId,
  });

  final UserRole role;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController?>();
    return ChangeNotifierProvider(
      key: ValueKey(patientId),
      create: (context) => PatientDetailViewModel(
        repository: context.read<PatientsRepository>(),
        patientId: patientId,
      ),
      child: PatientDetailView(
        role: role,
        clinicName: settings?.clinicName ?? SettingsController.fallbackName,
        whatsAppTemplate:
            settings?.settings?.whatsappTemplates.adhoc ??
            WhatsappTemplates.defaults.adhoc,
      ),
    );
  }
}

/// Body; expects a [PatientDetailViewModel] above it.
class PatientDetailView extends StatelessWidget {
  const PatientDetailView({
    super.key,
    required this.role,
    required this.clinicName,
    required this.whatsAppTemplate,
    this.openUrl,
  });

  final UserRole role;
  final String clinicName;
  final String whatsAppTemplate;

  /// Opens the WhatsApp link; defaults to url_launcher in a new tab.
  final Future<void> Function(Uri uri)? openUrl;

  Future<void> _open(Uri uri) =>
      (openUrl ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(
        uri,
      );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PatientDetailViewModel>();
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    void backToSearch() => context.go(AppRoutes.patientsFor(role));

    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Patient not found',
        action: OutlinedButton(
          onPressed: backToSearch,
          child: const Text('Back to patients'),
        ),
      );
    }
    final patient = vm.patient;
    if (vm.loading || patient == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final link = vm.whatsAppLink(
      template: whatsAppTemplate,
      clinicName: clinicName,
    );
    final wide = Breakpoints.isExpanded(context);

    final family = _FamilyCard(vm: vm, role: role, patient: patient);
    final tabs = _PlaceholderTabs(patient: patient);

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: patient.name,
            onBack: backToSearch,
            actions: [
              IconButton(
                key: const Key('patient-whatsapp'),
                tooltip: link == null ? 'No phone' : 'Send WhatsApp',
                icon: const Icon(Icons.chat_outlined),
                onPressed: link == null ? null : () => unawaited(_open(link)),
              ),
              FilledButton.tonalIcon(
                key: const Key('patient-edit'),
                onPressed: () =>
                    context.go(AppRoutes.patientEditFor(role, patient.id)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PatientHeader(
                            patient: patient,
                            today: vm.today,
                            familyPhone: vm.family?.phone,
                          ),
                          if (patient.address.isNotEmpty ||
                              patient.notes.isNotEmpty) ...[
                            const Divider(height: 24),
                            if (patient.address.isNotEmpty)
                              _Line(
                                icon: Icons.home_outlined,
                                text: patient.address,
                              ),
                            if (patient.notes.isNotEmpty)
                              _Line(
                                icon: Icons.notes_outlined,
                                text: patient.notes,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: family),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: tabs),
                      ],
                    )
                  else ...[
                    family,
                    const SizedBox(height: 12),
                    tabs,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.vm,
    required this.role,
    required this.patient,
  });

  final PatientDetailViewModel vm;
  final UserRole role;
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final family = vm.family;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.family_restroom, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Family', style: text.titleMedium)),
                if (family?.duplicatePhone ?? false)
                  Tooltip(
                    message:
                        'Another family was registered with this number. '
                        'Admin can merge them.',
                    child: Icon(Icons.warning_amber, color: scheme.error),
                  ),
                IconButton(
                  key: const Key('family-edit'),
                  tooltip: 'Edit head of family',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: family == null || vm.busy
                      ? null
                      : () => showEditFamilyDialog(
                          context,
                          family: family,
                          onSave: vm.updateFamily,
                        ),
                ),
              ],
            ),
            if (family != null) ...[
              const SizedBox(height: 4),
              Text(family.headName, style: text.bodyLarge),
              Text(
                [
                  Phone.display(family.phone),
                  if (family.address.isNotEmpty) family.address,
                ].join(' · '),
                style: text.bodyMedium?.copyWith(color: scheme.outline),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: const Key('family-add-member'),
                  onPressed: family == null
                      ? null
                      : () => context.go(
                          AppRoutes.patientNewFor(role, familyId: family.id),
                        ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add member'),
                ),
                TextButton.icon(
                  key: const Key('family-change-phone'),
                  onPressed: family == null || vm.busy
                      ? null
                      : () => showChangeFamilyPhoneDialog(
                          context,
                          family: family,
                          onSave: vm.changeFamilyPhone,
                        ),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Change phone'),
                ),
                TextButton.icon(
                  key: const Key('patient-move'),
                  onPressed: vm.busy
                      ? null
                      : () => showMovePatientDialog(
                          context,
                          patientName: patient.name,
                          find: vm.findFamily,
                          onMove: vm.moveTo,
                        ),
                  icon: const Icon(Icons.drive_file_move_outline, size: 18),
                  label: const Text('Move to another family'),
                ),
              ],
            ),
            const Divider(),
            Text(
              'Other members',
              style: text.labelLarge?.copyWith(color: scheme.outline),
            ),
            if (vm.otherMembers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No other members yet.'),
              ),
            for (final m in vm.otherMembers)
              ListTile(
                key: Key('patient-open-${m.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(m.name),
                subtitle: Text(
                  [
                    if (m.ageLabel(vm.today).isNotEmpty) m.ageLabel(vm.today),
                    m.gender.label,
                  ].join(' · '),
                ),
                trailing: PatientNoChip(patient: m),
                onTap: () => context.go(AppRoutes.patientFor(role, m.id)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Visits, Reports and Appointments arrive in Phases 4–6; the tabs are in
/// place so the layout is reviewed now.
class _PlaceholderTabs extends StatelessWidget {
  const _PlaceholderTabs({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(text: 'Visits'),
                Tab(text: 'Reports'),
                Tab(text: 'Appointments'),
              ],
              labelColor: scheme.primary,
            ),
            const SizedBox(
              height: 220,
              child: TabBarView(
                children: [
                  _ComingSoon(
                    icon: Icons.receipt_long_outlined,
                    text: 'Visits — coming in Phase 4',
                  ),
                  _ComingSoon(
                    icon: Icons.description_outlined,
                    text: 'Reports — coming in Phase 5',
                  ),
                  _ComingSoon(
                    icon: Icons.event_outlined,
                    text: 'Appointments — coming in Phase 6',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => EmptyState(icon: icon, title: text);
}

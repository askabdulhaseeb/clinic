import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../appointments/presentation/widgets/patient_appointments_tab.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../prescriptions/domain/repositories/prescriptions_repository.dart';
import '../../../prescriptions/presentation/widgets/visit_history_list.dart';
import '../../../reports/presentation/report_picker.dart';
import '../../../reports/presentation/widgets/reports_tab.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../settings/presentation/viewmodels/settings_controller.dart';
import '../../../visits/domain/repositories/visits_repository.dart';
import '../../../visits/presentation/screens/visits_screen.dart';
import '../../../visits/presentation/viewmodels/patient_history_vm.dart';
import '../../../visits/presentation/widgets/patient_history_loader.dart';
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
    return MultiProvider(
      key: ValueKey(patientId),
      providers: [
        ChangeNotifierProvider(
          create: (context) => PatientDetailViewModel(
            repository: context.read<PatientsRepository>(),
            patientId: patientId,
          ),
        ),
        // Visits tab: 3 at a time, read when the tab opens (§11).
        ChangeNotifierProvider(
          create: (context) => PatientHistoryViewModel(
            visitsRepository: context.read<VisitsRepository>(),
            prescriptionsRepository: context.read<PrescriptionsRepository>(),
            patientId: patientId,
          ),
        ),
      ],
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
    final tabs = _Tabs(
      history: context.watch<PatientHistoryViewModel>(),
      role: role,
      patient: patient,
      openUrl: _open,
    );

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
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const Key('patient-sell'),
                onPressed: () => context.go(
                  AppRoutes.saleNewFor(role, patientId: patient.id),
                ),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                label: const Text('Sell'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('patient-new-visit'),
                onPressed: () => context.go(
                  AppRoutes.visitNewFor(role, patientId: patient.id),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New visit'),
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

/// Visits (Phase 4; newest first, 3 per page, row opens the visit for a
/// reprint), Reports (Phase 5B) and Appointments (Phase 6A).
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.history,
    required this.role,
    required this.patient,
    required this.openUrl,
  });

  final PatientHistoryViewModel history;
  final UserRole role;
  final Patient patient;
  final Future<void> Function(Uri uri) openUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = patient.visitCount;
    return DefaultTabController(
      length: 3,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: count == 0 ? 'Visits' : 'Visits ($count)'),
                const Tab(text: 'Reports'),
                const Tab(text: 'Appointments'),
              ],
              labelColor: scheme.primary,
            ),
            SizedBox(
              height: 320,
              child: TabBarView(
                children: [
                  PatientHistoryLoader(
                    history: history,
                    builder: (context, h) =>
                        _VisitsList(history: h, role: role),
                  ),
                  PatientHistoryLoader(
                    history: history,
                    builder: (context, h) => ReportsTab(
                      patient: patient,
                      visits: h.visits,
                      canManage: true,
                      cameraPicker: kIsWeb ? null : pickReportWithCamera,
                      openUrl: openUrl,
                    ),
                  ),
                  PatientAppointmentsTab(patient: patient, role: role),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitsList extends StatelessWidget {
  const _VisitsList({required this.history, required this.role});

  final PatientHistoryViewModel history;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final visits = history.visits;
    if (history.loading && visits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visits.isEmpty) {
      return EmptyState(
        icon: history.error == null
            ? Icons.receipt_long_outlined
            : Icons.error_outline,
        title: history.error == null ? 'No visits yet' : 'Could not load',
        message: history.error,
      );
    }
    final footer = history.hasMore || history.error != null;
    return ListView.separated(
      itemCount: visits.length + (footer ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        if (i == visits.length) {
          return LoadMoreRow(
            keyName: 'visits-load-more',
            loading: history.loadingMore,
            error: history.error,
            onPressed: history.loadMore,
          );
        }
        return VisitRow(
          visit: visits[i],
          showDate: true,
          onTap: () => context.go(AppRoutes.visitFor(role, visits[i].id)),
        );
      },
    );
  }
}

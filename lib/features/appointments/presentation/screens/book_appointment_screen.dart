import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../patients/domain/repositories/patients_repository.dart';
import '../../../patients/presentation/widgets/patient_header.dart';
import '../../domain/appointment_rules.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../viewmodels/book_appointment_vm.dart';
import '../widgets/appointment_dialogs.dart';

/// `/<role>/appointments/new?patientId=` (UI_DESIGN §4.13).
class BookAppointmentScreen extends StatelessWidget {
  const BookAppointmentScreen({
    super.key,
    required this.role,
    required this.patientId,
  });

  final UserRole role;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(patientId),
      create: (context) => BookAppointmentViewModel(
        patientsRepository: context.read<PatientsRepository>(),
        appointmentsRepository: context.read<AppointmentsRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
        patientId: patientId,
      ),
      child: BookAppointmentView(role: role),
    );
  }
}

/// Body; expects a [BookAppointmentViewModel] above it.
class BookAppointmentView extends StatefulWidget {
  const BookAppointmentView({super.key, required this.role});

  final UserRole role;

  @override
  State<BookAppointmentView> createState() => _BookAppointmentViewState();
}

class _BookAppointmentViewState extends State<BookAppointmentView> {
  final _time = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _time.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _back(BookAppointmentViewModel vm) {
    final p = vm.patient;
    context.go(
      p == null
          ? AppRoutes.patientsFor(widget.role)
          : AppRoutes.patientFor(widget.role, p.id),
    );
  }

  Future<void> _pickDate(BookAppointmentViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(vm.date),
      firstDate: KarachiDate.parse(vm.today),
      lastDate: KarachiDate.parse(vm.today).add(const Duration(days: 365)),
    );
    if (picked != null) vm.setDate(KarachiDate.format(picked));
  }

  Future<void> _save() async {
    final vm = context.read<BookAppointmentViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await vm.save();
    if (saved == null) {
      final error = vm.saveError;
      if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Appointment booked for ${formatAppointmentDate(saved.date)}',
        ),
      ),
    );
    if (!mounted) return;
    context.go(AppRoutes.patientFor(widget.role, saved.patientId));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookAppointmentViewModel>();
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
          onPressed: () => _back(vm),
          child: const Text('Back to patients'),
        ),
      );
    }
    final patient = vm.patient;
    if (vm.loading || patient == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final error = vm.validationError;
    return Scaffold(
      body: Column(
        children: [
          PageHeader(title: 'Book appointment', onBack: () => _back(vm)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: PatientHeader(
                        patient: patient,
                        today: vm.today,
                        familyPhone: patient.phones.firstOrNull,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Field(
                            label: 'Department',
                            child: SegmentedButton<String>(
                              emptySelectionAllowed: true,
                              showSelectedIcon: false,
                              segments: [
                                for (final d in vm.activeDepartments)
                                  ButtonSegment(
                                    value: d.id,
                                    label: Text(
                                      d.name,
                                      key: Key('book-dept-${d.id}'),
                                    ),
                                  ),
                              ],
                              selected: {?vm.departmentId},
                              onSelectionChanged: (s) {
                                if (s.isNotEmpty) vm.selectDepartment(s.first);
                              },
                            ),
                          ),
                          _Field(
                            label: 'Doctor',
                            child: DropdownButtonFormField<String>(
                              key: const Key('book-doctor'),
                              initialValue: vm.doctorId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              hint: Text(
                                vm.departmentId == null
                                    ? 'Choose a department first'
                                    : 'Choose a doctor',
                                overflow: TextOverflow.ellipsis,
                              ),
                              items: [
                                for (final d in vm.doctorsForDepartment)
                                  DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name),
                                  ),
                              ],
                              onChanged: vm.departmentId == null
                                  ? null
                                  : (id) {
                                      if (id != null) vm.selectDoctor(id);
                                    },
                            ),
                          ),
                          _Field(
                            label: 'Date',
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                key: const Key('book-date'),
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: Text(formatAppointmentDate(vm.date)),
                                onPressed: () => unawaited(_pickDate(vm)),
                              ),
                            ),
                          ),
                          _Field(
                            label: 'Time',
                            child: TextField(
                              key: const Key('book-time'),
                              controller: _time,
                              maxLength: AppointmentRules.maxTimeLength,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Optional, e.g. 10:30',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                              onChanged: vm.setTime,
                            ),
                          ),
                          _Field(
                            label: 'Notes',
                            child: TextField(
                              key: const Key('book-notes'),
                              controller: _notes,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Optional',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: vm.setNotes,
                            ),
                          ),
                          if (error != null && vm.departmentId != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                error,
                                style: text.bodySmall?.copyWith(
                                  color: scheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    key: const Key('book-save'),
                    icon: vm.saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_available),
                    label: const Text('Book'),
                    onPressed: vm.canSave ? () => unawaited(_save()) : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: text.labelLarge),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../viewmodels/doctor_form_vm.dart';
import '../widgets/department_dropdown.dart';

/// Admin → Catalog → Doctors → new or `:id` (FEATURES §7.3).
class DoctorFormScreen extends StatelessWidget {
  const DoctorFormScreen({super.key, this.doctorId});

  final String? doctorId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(doctorId),
      create: (context) => DoctorFormViewModel(
        repository: context.read<CatalogRepository>(),
        doctorId: doctorId,
      ),
      child: const DoctorFormView(),
    );
  }
}

/// Body; expects a [DoctorFormViewModel] above it.
class DoctorFormView extends StatefulWidget {
  const DoctorFormView({super.key, this.onSaved});

  /// Called after a successful save; defaults to going back to the list.
  final VoidCallback? onSaved;

  @override
  State<DoctorFormView> createState() => _DoctorFormViewState();
}

class _DoctorFormViewState extends State<DoctorFormView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _specialisation = TextEditingController();
  final _salary = TextEditingController();
  final _share = TextEditingController();
  final _feeControllers = <String, TextEditingController>{};
  bool _filled = false;

  @override
  void dispose() {
    _name.dispose();
    _specialisation.dispose();
    _salary.dispose();
    _share.dispose();
    for (final c in _feeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillFrom(Doctor d) {
    _name.text = d.name;
    _specialisation.text = d.specialisation;
    _salary.text = d.salary == 0 ? '' : '${d.salary}';
    _share.text = d.sharePercent == 0
        ? ''
        : (d.sharePercent == d.sharePercent.roundToDouble()
              ? '${d.sharePercent.toInt()}'
              : '${d.sharePercent}');
  }

  TextEditingController _feeController(String visitTypeId, int fee) =>
      _feeControllers.putIfAbsent(
        visitTypeId,
        () => TextEditingController(text: fee == 0 ? '' : '$fee'),
      );

  void _back() => context.go(AppRoutes.adminCatalogDoctors);

  Future<void> _submit() async {
    final vm = context.read<DoctorFormViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    for (final e in _feeControllers.entries) {
      vm.setFee(e.key, e.value.text);
    }
    final ok = await vm.submit(
      name: _name.text,
      specialisation: _specialisation.text,
      salary: _salary.text,
      sharePercent: _share.text,
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(vm.isEdit ? 'Doctor saved' : 'Doctor added')),
    );
    final onSaved = widget.onSaved;
    if (onSaved != null) {
      onSaved();
    } else {
      _back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DoctorFormViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final wide = Breakpoints.isExpanded(context);
    final title = vm.isEdit ? 'Edit doctor' : 'New doctor';

    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    }
    if (vm.isEdit && vm.existing == null) {
      if (vm.notFound) {
        return EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Doctor not found',
          action: OutlinedButton(
            onPressed: _back,
            child: const Text('Back to doctors'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.isEdit && !_filled) {
      _filled = true;
      _fillFrom(vm.existing!);
    }

    return Scaffold(
      body: Column(
        children: [
          PageHeader(title: title, onBack: _back),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Card(
                          title: 'Doctor',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Pair(
                                wide: wide,
                                left: TextFormField(
                                  key: const Key('doctor-name'),
                                  controller: _name,
                                  autofocus: !vm.isEdit,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                  ),
                                  validator: DoctorFormViewModel.validateName,
                                ),
                                right: DepartmentDropdown(
                                  departments: vm.departments,
                                  value: vm.departmentId,
                                  onChanged: vm.setDepartment,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('doctor-specialisation'),
                                controller: _specialisation,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Specialisation',
                                ),
                              ),
                              const SizedBox(height: 4),
                              SwitchListTile(
                                key: const Key('doctor-active'),
                                title: const Text('Active'),
                                subtitle: const Text(
                                  'Inactive doctors are hidden when creating '
                                  'visits',
                                ),
                                value: vm.active,
                                onChanged: vm.setActive,
                                contentPadding: EdgeInsets.zero,
                              ),
                              if (vm.isEdit)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        vm.existing!.hasLogin
                                            ? Icons.link
                                            : Icons.link_off,
                                        size: 18,
                                        color: scheme.outline,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          vm.existing!.hasLogin
                                              ? 'Linked to a login. Change '
                                                    'the link under Users.'
                                              : 'No login yet. Create one '
                                                    'under Users and pick this '
                                                    'doctor.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: scheme.outline),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Card(
                          title: 'Pay',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Pair(
                                wide: wide,
                                left: TextFormField(
                                  key: const Key('doctor-salary'),
                                  controller: _salary,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Monthly salary',
                                    prefixText: 'Rs ',
                                  ),
                                  validator: DoctorFormViewModel.validateSalary,
                                ),
                                right: TextFormField(
                                  key: const Key('doctor-share'),
                                  controller: _share,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Revenue share',
                                    suffixText: '%',
                                  ),
                                  validator:
                                      DoctorFormViewModel.validateSharePercent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Share applies to',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 6),
                              SegmentedButton<ShareBasis>(
                                key: const Key('doctor-share-basis'),
                                segments: [
                                  for (final b in ShareBasis.values)
                                    ButtonSegment(
                                      value: b,
                                      label: Text(b.label),
                                    ),
                                ],
                                selected: {vm.shareBasis},
                                onSelectionChanged: (s) =>
                                    vm.setShareBasis(s.first),
                                showSelectedIcon: false,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Card(
                          title: 'Fees',
                          subtitle: vm.departmentId == null
                              ? 'Pick a department to set fees'
                              : 'Per visit type of '
                                    '${vm.departmentName(vm.departmentId!)}. '
                                    'Leave empty for no fee.',
                          child: vm.feeVisitTypes.isEmpty
                              ? Text(
                                  'This department has no active visit types.',
                                  style: TextStyle(color: scheme.outline),
                                )
                              : Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    for (final t in vm.feeVisitTypes)
                                      SizedBox(
                                        width: 200,
                                        child: TextFormField(
                                          key: Key('doctor-fee-${t.id}'),
                                          controller: _feeController(
                                            t.id,
                                            vm.fees[t.id] ?? 0,
                                          ),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: t.name,
                                            prefixText: 'Rs ',
                                          ),
                                          validator:
                                              DoctorFormViewModel.validateFee,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        if (vm.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            vm.error!,
                            key: const Key('doctor-form-error'),
                            style: TextStyle(color: scheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('doctor-save'),
        onPressed: vm.submitting ? null : _submit,
        icon: vm.submitting
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(vm.isEdit ? 'Save' : 'Add doctor'),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: text.titleMedium),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.wide, required this.left, required this.right});

  final bool wide;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../viewmodels/visit_type_form_vm.dart';
import '../widgets/department_dropdown.dart';

/// Admin → Catalog → Visit types → new or `:id` (FEATURES §7.3, §6.4).
class VisitTypeFormScreen extends StatelessWidget {
  const VisitTypeFormScreen({
    super.key,
    this.visitTypeId,
    this.initialDepartmentId,
  });

  final String? visitTypeId;
  final String? initialDepartmentId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(visitTypeId),
      create: (context) => VisitTypeFormViewModel(
        repository: context.read<CatalogRepository>(),
        visitTypeId: visitTypeId,
        initialDepartmentId: initialDepartmentId,
      ),
      child: const VisitTypeFormView(),
    );
  }
}

/// Body; expects a [VisitTypeFormViewModel] above it.
class VisitTypeFormView extends StatefulWidget {
  const VisitTypeFormView({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<VisitTypeFormView> createState() => _VisitTypeFormViewState();
}

class _VisitTypeFormViewState extends State<VisitTypeFormView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _checklistItem = TextEditingController();
  final _postOpDay = TextEditingController();
  String? _checklistError;
  String? _postOpError;
  bool _filled = false;

  @override
  void dispose() {
    _name.dispose();
    _checklistItem.dispose();
    _postOpDay.dispose();
    super.dispose();
  }

  void _back() => context.go(AppRoutes.adminCatalogVisitTypes);

  void _addChecklistItem() {
    final error = context.read<VisitTypeFormViewModel>().addChecklistItem(
      _checklistItem.text,
    );
    setState(() => _checklistError = error);
    if (error == null) _checklistItem.clear();
  }

  void _addPostOpDay() {
    final error = context.read<VisitTypeFormViewModel>().addPostOpDay(
      _postOpDay.text,
    );
    setState(() => _postOpError = error);
    if (error == null) _postOpDay.clear();
  }

  Future<void> _submit() async {
    final vm = context.read<VisitTypeFormViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await vm.submit(name: _name.text);
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(vm.isEdit ? 'Visit type saved' : 'Visit type added'),
      ),
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
    final vm = context.watch<VisitTypeFormViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
          icon: Icons.search_off,
          title: 'Visit type not found',
          action: OutlinedButton(
            onPressed: _back,
            child: const Text('Back to visit types'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.isEdit && !_filled) {
      _filled = true;
      _name.text = vm.existing!.name;
    }

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: vm.isEdit ? 'Edit visit type' : 'New visit type',
            onBack: _back,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  key: const Key('visit-type-name'),
                                  controller: _name,
                                  autofocus: !vm.isEdit,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                  ),
                                  validator:
                                      VisitTypeFormViewModel.validateName,
                                ),
                                const SizedBox(height: 12),
                                DepartmentDropdown(
                                  departments: vm.departments,
                                  value: vm.departmentId,
                                  onChanged: vm.setDepartment,
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile(
                                  key: const Key('visit-type-follow-up'),
                                  title: const Text('Follow-up type'),
                                  subtitle: const Text(
                                    'Uses the doctor\'s reduced follow-up fee',
                                  ),
                                  value: vm.isFollowUp,
                                  onChanged: vm.setFollowUp,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                SwitchListTile(
                                  key: const Key('visit-type-operation'),
                                  title: const Text('Operation'),
                                  subtitle: const Text(
                                    'Has a pre-op checklist and post-op '
                                    'follow-ups',
                                  ),
                                  value: vm.isOperation,
                                  onChanged: vm.setOperation,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                SwitchListTile(
                                  key: const Key('visit-type-active'),
                                  title: const Text('Active'),
                                  value: vm.active,
                                  onChanged: vm.setActive,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (vm.isOperation) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Default pre-op checklist',
                                    style: text.titleMedium,
                                  ),
                                  Text(
                                    'Copied onto every operation of this type. '
                                    'Doctors can add patient-specific items.',
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final item in vm.checklist)
                                    ListTile(
                                      key: Key('checklist-${item.id}'),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.check_box_outline_blank,
                                      ),
                                      title: Text(item.label),
                                      trailing: IconButton(
                                        tooltip: 'Remove',
                                        icon: const Icon(Icons.close),
                                        onPressed: () =>
                                            vm.removeChecklistItem(item.id),
                                      ),
                                    ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          key: const Key('checklist-input'),
                                          controller: _checklistItem,
                                          decoration: InputDecoration(
                                            labelText: 'Add item',
                                            errorText: _checklistError,
                                          ),
                                          onSubmitted: (_) =>
                                              _addChecklistItem(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: OutlinedButton(
                                          key: const Key('checklist-add'),
                                          onPressed: _addChecklistItem,
                                          child: const Text('Add'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Default post-op follow-ups',
                                    style: text.titleMedium,
                                  ),
                                  Text(
                                    'Days after surgery. Changeable per '
                                    'patient.',
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final day in vm.postOpDays)
                                        InputChip(
                                          key: Key('post-op-day-$day'),
                                          label: Text('Day $day'),
                                          onDeleted: () =>
                                              vm.removePostOpDay(day),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 160,
                                        child: TextField(
                                          key: const Key('post-op-input'),
                                          controller: _postOpDay,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Add day',
                                            errorText: _postOpError,
                                          ),
                                          onSubmitted: (_) => _addPostOpDay(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: OutlinedButton(
                                          key: const Key('post-op-add'),
                                          onPressed: _addPostOpDay,
                                          child: const Text('Add'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (vm.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            vm.error!,
                            key: const Key('visit-type-form-error'),
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
        key: const Key('visit-type-save'),
        onPressed: vm.submitting ? null : _submit,
        icon: vm.submitting
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(vm.isEdit ? 'Save' : 'Add visit type'),
      ),
    );
  }
}

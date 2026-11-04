import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patients_repository.dart';
import '../viewmodels/patient_form_vm.dart';

/// `/<role>/patients/new?phone=|familyId=` and `/<role>/patients/:id/edit`
/// (UI_DESIGN §3.2).
class PatientFormScreen extends StatelessWidget {
  const PatientFormScreen({
    super.key,
    required this.role,
    this.familyId,
    this.patientId,
    this.initialPhone,
  });

  final UserRole role;
  final String? familyId;
  final String? patientId;
  final String? initialPhone;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey('$familyId/$patientId'),
      create: (context) => PatientFormViewModel(
        repository: context.read<PatientsRepository>(),
        familyId: familyId,
        patientId: patientId,
        initialPhone: initialPhone,
      ),
      child: PatientFormView(role: role),
    );
  }
}

/// Body; expects a [PatientFormViewModel] above it.
class PatientFormView extends StatefulWidget {
  const PatientFormView({super.key, required this.role});

  final UserRole role;

  @override
  State<PatientFormView> createState() => _PatientFormViewState();
}

class _PatientFormViewState extends State<PatientFormView> {
  final _formKey = GlobalKey<FormState>();
  final _familyPhone = TextEditingController();
  final _familyHead = TextEditingController();
  final _familyAddress = TextEditingController();
  final _name = TextEditingController();
  final _dob = TextEditingController();
  final _age = TextEditingController();
  final _personalPhone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  Gender _gender = Gender.male;
  AgeMode _ageMode = AgeMode.age;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<PatientFormViewModel>();
    final phone = vm.initialPhone;
    if (phone != null) _familyPhone.text = Phone.display(phone);
  }

  @override
  void dispose() {
    for (final c in [
      _familyPhone,
      _familyHead,
      _familyAddress,
      _name,
      _dob,
      _age,
      _personalPhone,
      _address,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillFrom(PatientFormViewModel vm, Patient p) {
    _name.text = p.name;
    _gender = p.gender;
    _ageMode = vm.initialAgeMode;
    _age.text = vm.initialAge;
    _dob.text = vm.initialDob;
    _personalPhone.text = p.personalPhone == null
        ? ''
        : Phone.display(p.personalPhone!);
    _address.text = p.address;
    _notes.text = p.notes;
  }

  void _back() {
    final vm = context.read<PatientFormViewModel>();
    final id = vm.patientId;
    context.go(
      id == null
          ? AppRoutes.patientsFor(widget.role)
          : AppRoutes.patientFor(widget.role, id),
    );
  }

  Future<void> _pickDob(PatientFormViewModel vm) async {
    final today = KarachiDate.parse(vm.today);
    final current = KarachiDate.isValid(_dob.text.trim())
        ? KarachiDate.parse(_dob.text.trim())
        : DateTime.utc(today.year - 30, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime.utc(today.year - PatientFormViewModel.maxAge),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() => _dob.text = KarachiDate.format(picked));
  }

  Future<void> _submit() async {
    final vm = context.read<PatientFormViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final id = await vm.submit(
      family: vm.isNewFamily
          ? FamilyFields(
              phone: _familyPhone.text,
              headName: _familyHead.text,
              address: _familyAddress.text,
            )
          : null,
      patient: PatientFields(
        name: _name.text,
        gender: _gender,
        ageMode: _ageMode,
        dob: _dob.text,
        age: _age.text,
        personalPhone: _personalPhone.text,
        address: _address.text,
        notes: _notes.text,
      ),
    );
    if (id == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(vm.isEdit ? 'Patient saved' : 'Patient registered'),
      ),
    );
    context.go(AppRoutes.patientFor(widget.role, id));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PatientFormViewModel>();
    final wide = Breakpoints.isExpanded(context);

    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.person_off_outlined,
        title: vm.isEdit ? 'Patient not found' : 'Family not found',
        action: OutlinedButton(
          onPressed: () => context.go(AppRoutes.patientsFor(widget.role)),
          child: const Text('Back to patients'),
        ),
      );
    }
    if (vm.isEdit && !_filled && vm.patient != null) {
      _filled = true;
      _fillFrom(vm, vm.patient!);
    }
    final title = vm.isEdit
        ? 'Edit patient'
        : vm.isNewFamily
        ? 'New family'
        : 'New patient';

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
                        if (vm.isNewFamily)
                          _FormCard(
                            title: 'Family',
                            subtitle:
                                'One phone number groups the whole family.',
                            child: _familyFields(wide),
                          )
                        else if (vm.family case final f?)
                          _FamilySummary(family: f),
                        const SizedBox(height: 16),
                        _FormCard(
                          title: 'Patient',
                          child: _patientFields(vm, wide),
                        ),
                        if (vm.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            vm.error!,
                            key: const Key('patient-form-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: vm.submitting ? null : _back,
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              key: const Key('patient-save'),
                              onPressed: vm.submitting ? null : _submit,
                              child: Text(
                                vm.isEdit ? 'Save' : 'Register patient',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyFields(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Pair(
        wide: wide,
        left: TextFormField(
          key: const Key('family-phone'),
          controller: _familyPhone,
          autofocus: _familyPhone.text.isEmpty,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Family phone',
            hintText: '0300 1234567',
          ),
          validator: PatientFormViewModel.validatePhone,
        ),
        right: TextFormField(
          key: const Key('family-head'),
          controller: _familyHead,
          autofocus: _familyPhone.text.isNotEmpty,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Head of family'),
          validator: PatientFormViewModel.validateHeadName,
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const Key('family-address'),
        controller: _familyAddress,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Address'),
      ),
    ],
  );

  Widget _patientFields(PatientFormViewModel vm, bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Pair(
        wide: wide,
        left: TextFormField(
          key: const Key('patient-name'),
          controller: _name,
          autofocus: !vm.isNewFamily && !vm.isEdit,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
          validator: PatientFormViewModel.validateName,
        ),
        right: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Gender',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          child: SegmentedButton<Gender>(
            key: const Key('patient-gender'),
            segments: [
              for (final g in Gender.values)
                ButtonSegment(
                  value: g,
                  label: Text(g.label, key: Key('patient-gender-${g.key}')),
                ),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _Pair(
        wide: wide,
        left: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Age is known as',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          child: SegmentedButton<AgeMode>(
            segments: const [
              ButtonSegment(
                value: AgeMode.age,
                label: Text('Age in years', key: Key('age-mode-age')),
              ),
              ButtonSegment(
                value: AgeMode.dob,
                label: Text('Date of birth', key: Key('age-mode-dob')),
              ),
            ],
            selected: {_ageMode},
            onSelectionChanged: (s) => setState(() => _ageMode = s.first),
          ),
        ),
        right: _ageMode == AgeMode.age
            ? TextFormField(
                key: const Key('patient-age'),
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  suffixText: 'years',
                  helperText: 'Stored as an approximate date of birth',
                ),
                validator: PatientFormViewModel.validateAge,
              )
            : TextFormField(
                key: const Key('patient-dob'),
                controller: _dob,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: IconButton(
                    key: const Key('patient-dob-pick'),
                    tooltip: 'Pick a date',
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDob(vm),
                  ),
                ),
                validator: vm.validateDob,
              ),
      ),
      const SizedBox(height: 12),
      _Pair(
        wide: wide,
        left: TextFormField(
          key: const Key('patient-personal-phone'),
          controller: _personalPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Personal phone (optional)',
            hintText: '0300 1234567',
          ),
          validator: PatientFormViewModel.validateOptionalPhone,
        ),
        right: TextFormField(
          key: const Key('patient-address'),
          controller: _address,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Address (if different from the family)',
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const Key('patient-notes'),
        controller: _notes,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Notes',
          alignLabelWithHint: true,
        ),
      ),
    ],
  );
}

class _FamilySummary extends StatelessWidget {
  const _FamilySummary({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.family_restroom),
        title: Text('Family of ${family.headName}'),
        subtitle: Text(
          [
            Phone.display(family.phone),
            if (family.address.isNotEmpty) family.address,
            '${family.patientCount} patient${family.patientCount == 1 ? '' : 's'}',
          ].join(' · '),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, this.subtitle, required this.child});

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
              Text(
                subtitle!,
                style: text.bodySmall?.copyWith(color: scheme.outline),
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
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

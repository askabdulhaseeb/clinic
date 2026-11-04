import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../catalog/domain/seed_catalog.dart';
import '../../domain/repositories/settings_repository.dart';
import '../viewmodels/initial_setup_vm.dart';

/// Admin → first-run setup (FIREBASE_ARCHITECTURE §10). Creates the branch,
/// settings and seed catalog, then goes to the dashboard.
class InitialSetupScreen extends StatelessWidget {
  const InitialSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          InitialSetupViewModel(repository: context.read<SettingsRepository>()),
      child: const InitialSetupView(),
    );
  }
}

/// Body; expects an [InitialSetupViewModel] above it.
class InitialSetupView extends StatefulWidget {
  const InitialSetupView({super.key, this.onDone});

  /// Called after a successful run; defaults to going to the dashboard.
  final VoidCallback? onDone;

  @override
  State<InitialSetupView> createState() => _InitialSetupViewState();
}

class _InitialSetupViewState extends State<InitialSetupView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await context.read<InitialSetupViewModel>().run(
      clinicName: _name.text,
      address: _address.text,
      phone: _phone.text,
    );
    if (!ok || !mounted) return;
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
    } else {
      context.go(AppRoutes.adminDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InitialSetupViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Initial setup', style: text.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Runs once for a new clinic. You can change everything '
                      'later under Settings and Catalog.',
                      style: text.bodyMedium?.copyWith(color: scheme.outline),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('setup-clinic-name'),
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Clinic name',
                        helperText: 'Shown on receipts and in the app header',
                      ),
                      validator: InitialSetupViewModel.validateClinicName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(
                        labelText: 'Address (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('This will create', style: text.titleSmall),
                    const SizedBox(height: 8),
                    const _SeedLine(
                      icon: Icons.settings_outlined,
                      label:
                          'Clinic settings with default receipt and '
                          'WhatsApp templates',
                    ),
                    _SeedLine(
                      icon: Icons.category_outlined,
                      label:
                          'Departments: ${SeedCatalog.departments.map((d) => '${d.name} (${d.code})').join(', ')}',
                    ),
                    _SeedLine(
                      icon: Icons.list_alt_outlined,
                      label: 'Visit types: ${_visitTypeSummary()}',
                    ),
                    if (vm.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        vm.error!,
                        key: const Key('setup-error'),
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('setup-run'),
                      onPressed: vm.running ? null : _run,
                      icon: vm.running
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.rocket_launch_outlined),
                      label: const Text('Run setup'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _visitTypeSummary() {
    final parts = <String>[];
    for (final d in SeedCatalog.departments) {
      final names = SeedCatalog.visitTypes
          .where((v) => v.departmentId == d.id)
          .map((v) => v.name)
          .join(', ');
      parts.add('${d.name}: $names');
    }
    return parts.join('; ');
  }
}

class _SeedLine extends StatelessWidget {
  const _SeedLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

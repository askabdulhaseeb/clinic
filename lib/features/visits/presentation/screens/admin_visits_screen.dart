import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/repositories/visits_repository.dart';
import '../viewmodels/admin_visits_vm.dart';
import 'visits_screen.dart';

/// `/admin/visits`: any day's visits with a text filter (UI_DESIGN §4.18).
class AdminVisitsScreen extends StatelessWidget {
  const AdminVisitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          AdminVisitsViewModel(repository: context.read<VisitsRepository>()),
      child: const AdminVisitsView(),
    );
  }
}

/// Body; expects an [AdminVisitsViewModel] above it.
class AdminVisitsView extends StatelessWidget {
  const AdminVisitsView({super.key});

  Future<void> _pickDate(BuildContext context, AdminVisitsViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(vm.date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) vm.setDate(KarachiDate.format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminVisitsViewModel>();
    final compact = Breakpoints.isCompact(context);
    final visits = vm.visits;

    final strip = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          IconButton(
            key: const Key('visits-prev-day'),
            tooltip: 'Previous day',
            onPressed: vm.previousDay,
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton.icon(
            key: const Key('visits-date'),
            onPressed: () => _pickDate(context, vm),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(KarachiDate.display(vm.date)),
          ),
          IconButton(
            key: const Key('visits-next-day'),
            tooltip: 'Next day',
            onPressed: vm.nextDay,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            key: const Key('visits-refresh'),
            tooltip: 'Refresh',
            onPressed: vm.loading ? null : vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
          SizedBox(
            width: compact ? 220 : 320,
            child: TextField(
              key: const Key('visits-filter'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Name, number, phone or token',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: vm.setFilter,
            ),
          ),
          FilledButton.icon(
            key: const Key('visits-new'),
            onPressed: () => context.go(AppRoutes.patientsFor(UserRole.admin)),
            icon: const Icon(Icons.add),
            label: Text(compact ? 'New' : 'New visit'),
          ),
        ],
      ),
    );

    final Widget body;
    if (vm.loading && vm.all.isEmpty && vm.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load visits',
        message: vm.error,
        action: OutlinedButton(
          onPressed: vm.refresh,
          child: const Text('Try again'),
        ),
      );
    } else if (vm.all.isEmpty) {
      body = const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No visits on this day',
      );
    } else if (visits.isEmpty) {
      body = const EmptyState(
        icon: Icons.search_off,
        title: 'No visit matches the filter',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: visits.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => VisitRow(
          visit: visits[i],
          onTap: () =>
              context.go(AppRoutes.visitFor(UserRole.admin, visits[i].id)),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          strip,
          const SizedBox(height: 8),
          Expanded(child: body),
        ],
      ),
    );
  }
}

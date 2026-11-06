import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import 'expenses_screen.dart';
import 'payouts_screen.dart';

/// Admin → Finance sections (UI_DESIGN §4.17); each tab is a route.
enum FinanceTab {
  expenses('Expenses', AppRoutes.adminFinanceExpenses),
  payouts('Payouts', AppRoutes.adminFinancePayouts);

  const FinanceTab(this.label, this.path);

  final String label;
  final String path;
}

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key, required this.tab});

  final FinanceTab tab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(tab),
      length: FinanceTab.values.length,
      initialIndex: tab.index,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (i) => context.go(FinanceTab.values[i].path),
              tabs: [
                for (final t in FinanceTab.values)
                  Tab(key: Key('fin-tab-${t.name}'), text: t.label),
              ],
            ),
          ),
          Expanded(
            child: switch (tab) {
              FinanceTab.expenses => const ExpensesScreen(),
              FinanceTab.payouts => const PayoutsScreen(),
            },
          ),
        ],
      ),
    );
  }
}

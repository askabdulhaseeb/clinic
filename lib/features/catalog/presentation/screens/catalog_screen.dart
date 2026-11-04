import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import 'departments_screen.dart';
import 'doctors_screen.dart';
import 'fee_grid_screen.dart';
import 'visit_types_screen.dart';

/// The four catalog sections (UI_DESIGN §3.4).
enum CatalogTab {
  departments('Departments', AppRoutes.adminCatalogDepartments),
  doctors('Doctors', AppRoutes.adminCatalogDoctors),
  visitTypes('Visit types', AppRoutes.adminCatalogVisitTypes),
  fees('Fees', AppRoutes.adminCatalogFees);

  const CatalogTab(this.label, this.path);

  final String label;
  final String path;
}

/// Admin → Catalog. Tab strip whose tabs are routes, so each section has
/// its own URL and the browser back button works.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.tab});

  final CatalogTab tab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(tab),
      length: CatalogTab.values.length,
      initialIndex: tab.index,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (i) => context.go(CatalogTab.values[i].path),
              tabs: [
                for (final t in CatalogTab.values)
                  Tab(key: Key('catalog-tab-${t.name}'), text: t.label),
              ],
            ),
          ),
          Expanded(
            child: switch (tab) {
              CatalogTab.departments => const DepartmentsScreen(),
              CatalogTab.doctors => const DoctorsScreen(),
              CatalogTab.visitTypes => const VisitTypesScreen(),
              CatalogTab.fees => const FeeGridScreen(),
            },
          ),
        ],
      ),
    );
  }
}

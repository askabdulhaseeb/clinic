import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../domain/entities/inventory_item.dart';
import 'inventory_items_screen.dart';
import 'lens_grid_screen.dart';
import 'purchases_screen.dart';
import 'suppliers_screen.dart';

/// The six inventory sections (UI_DESIGN §4.15); each tab is a route.
enum InventoryTab {
  medicine('Medicines', '/admin/inventory/medicine'),
  frame('Frames', '/admin/inventory/frame'),
  lens('Lenses', AppRoutes.adminInventoryLens),
  consumable('Consumables', '/admin/inventory/consumable'),
  suppliers('Suppliers', AppRoutes.adminInventorySuppliers),
  purchases('Purchases', AppRoutes.adminInventoryPurchases);

  const InventoryTab(this.label, this.path);

  final String label;
  final String path;

  /// The item category a tab lists, or null for suppliers and purchases.
  ItemCategory? get category => switch (this) {
    InventoryTab.medicine => ItemCategory.medicine,
    InventoryTab.frame => ItemCategory.frame,
    InventoryTab.lens => ItemCategory.lens,
    InventoryTab.consumable => ItemCategory.consumable,
    InventoryTab.suppliers || InventoryTab.purchases => null,
  };
}

/// Admin → Inventory. Tab strip whose tabs are routes, like Catalog.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key, required this.tab});

  final InventoryTab tab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(tab),
      length: InventoryTab.values.length,
      initialIndex: tab.index,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (i) => context.go(InventoryTab.values[i].path),
              tabs: [
                for (final t in InventoryTab.values)
                  Tab(key: Key('inv-tab-${t.name}'), text: t.label),
              ],
            ),
          ),
          Expanded(
            child: switch (tab) {
              InventoryTab.lens => const LensGridScreen(),
              InventoryTab.suppliers => const SuppliersScreen(),
              InventoryTab.purchases => const PurchasesScreen(),
              _ => InventoryItemsScreen(category: tab.category!),
            },
          ),
        ],
      ),
    );
  }
}

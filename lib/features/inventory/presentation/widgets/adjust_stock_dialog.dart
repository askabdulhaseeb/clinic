import 'package:flutter/material.dart';

import '../../domain/entities/inventory_item.dart';

/// Adjust-stock dialog (UI_DESIGN §4.15): signed quantity and reason.
/// Returns them, or null when dismissed.
Future<({int qty, String reason})?> showAdjustStockDialog(
  BuildContext context, {
  required InventoryItem item,
}) {
  final qty = TextEditingController();
  final reason = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<({int qty, String reason})>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Adjust stock'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${item.name} · ${item.stock} ${item.unit} on hand',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('inv-adjust-qty'),
              controller: qty,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: '+5 to add, -3 to remove',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim().replaceFirst('+', ''));
                if (n == null) return 'Whole number';
                if (n == 0) return 'Enter a quantity other than 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('inv-adjust-reason'),
              controller: reason,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Stock count, breakage, expired',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Enter the reason' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('inv-adjust-save'),
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop((
              qty: int.parse(qty.text.trim().replaceFirst('+', '')),
              reason: reason.text.trim(),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../../domain/entities/supplier.dart';

/// Add or edit a supplier (UI_DESIGN §4.15). Returns the supplier to save
/// (ID empty for a new one), or null when dismissed.
Future<Supplier?> showSupplierFormDialog(
  BuildContext context, {
  Supplier? existing,
}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '');
  final address = TextEditingController(text: existing?.address ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  final formKey = GlobalKey<FormState>();
  return showDialog<Supplier>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(existing == null ? 'New supplier' : 'Edit supplier'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('supplier-name'),
                controller: name,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? 'Enter the supplier name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('supplier-phone'),
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('supplier-address'),
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('supplier-notes'),
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('supplier-save'),
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(
              Supplier(
                id: existing?.id ?? '',
                name: name.text.trim(),
                phone: phone.text.trim(),
                address: address.text.trim(),
                notes: notes.text.trim(),
                active: existing?.active ?? true,
                createdAt: existing?.createdAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

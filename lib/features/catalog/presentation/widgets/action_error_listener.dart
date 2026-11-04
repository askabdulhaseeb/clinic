import 'package:flutter/material.dart';

/// Shows [error] in a snackbar once and calls [onShown]. Used by list
/// screens whose row actions report failures through the view model.
void showActionError(
  BuildContext context, {
  required String? error,
  required VoidCallback onShown,
}) {
  if (error == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    onShown();
  });
}

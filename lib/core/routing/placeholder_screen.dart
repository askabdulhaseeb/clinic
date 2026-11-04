import 'package:flutter/material.dart';

/// Temporary screen used until a feature's real screen exists.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.embedded = false,
  });

  final String title;

  /// True when shown inside an [AppShell], which already has a title bar.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: Text(
        '$title — coming soon',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

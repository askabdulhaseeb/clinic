import 'package:flutter/material.dart';

/// Title row for a detail or form page shown inside the role shell: back
/// button, title, optional trailing actions. The shell keeps its own bar.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              key: const Key('page-back'),
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

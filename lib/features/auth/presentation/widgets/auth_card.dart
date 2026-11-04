import 'package:flutter/material.dart';

/// Centered card used by the login and change-password screens.
class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_hospital_outlined,
                      size: 40,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: text.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: text.bodyMedium?.copyWith(color: scheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

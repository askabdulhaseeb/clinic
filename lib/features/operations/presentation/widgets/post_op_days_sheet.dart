import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/repositories/operations_repository.dart';
import '../viewmodels/post_op_days_vm.dart';

/// Reception's "Change post-op days" sheet (UI_DESIGN §4.11a). Resolves
/// true when the days were saved.
Future<bool> showPostOpDaysSheet(
  BuildContext context, {
  required String operationId,
}) async {
  final repo = context.read<OperationsRepository>();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => PostOpDaysViewModel(
        operationsRepository: repo,
        operationId: operationId,
      ),
      child: const PostOpDaysSheet(),
    ),
  );
  return saved ?? false;
}

/// Body; expects a [PostOpDaysViewModel] above it.
class PostOpDaysSheet extends StatefulWidget {
  const PostOpDaysSheet({super.key});

  @override
  State<PostOpDaysSheet> createState() => _PostOpDaysSheetState();
}

class _PostOpDaysSheetState extends State<PostOpDaysSheet> {
  final _newDay = TextEditingController();

  @override
  void dispose() {
    _newDay.dispose();
    super.dispose();
  }

  void _add(PostOpDaysViewModel vm) {
    final problem = vm.addDay(_newDay.text);
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    _newDay.clear();
  }

  Future<void> _save(PostOpDaysViewModel vm) async {
    final days = vm.days;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change the post-op follow-ups?'),
        content: Text(
          days.isEmpty
              ? 'All post-op appointments will be cancelled.'
              : 'Appointments will be re-booked for day '
                    '${days.join(', ')} after surgery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            key: const Key('postop-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final saved = await vm.save();
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else if (vm.error case final error?) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PostOpDaysViewModel>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final op = vm.operation;
    final Widget body;
    if (vm.loadError != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    } else if (vm.loading || op == null) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final enabled = vm.canEdit && !vm.saving;
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(op.visitTypeName, style: text.titleMedium),
          Text(
            '${op.patientName} · surgery '
            '${KarachiDate.display(op.scheduledDate)}'
            '${vm.canEdit ? '' : ' · ${op.status.label}'}',
            style: text.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 12),
          Text(
            'Days after surgery; each one is an appointment.',
            style: text.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in vm.days)
                InputChip(
                  key: Key('postop-day-$d'),
                  label: Text('Day $d'),
                  onDeleted: enabled ? () => vm.removeDay(d) : null,
                ),
              if (vm.days.isEmpty)
                Text(
                  'No post-op follow-ups',
                  style: text.bodyMedium?.copyWith(color: scheme.outline),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  key: const Key('postop-day-input'),
                  controller: _newDay,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Add day',
                  ),
                  onSubmitted: (_) => _add(vm),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('postop-day-add'),
                onPressed: enabled ? () => _add(vm) : null,
                child: const Text('Add'),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('postop-save'),
                onPressed: enabled && vm.dirty
                    ? () => unawaited(_save(vm))
                    : null,
                child: Text(vm.saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Post-op follow-ups', style: text.titleLarge),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

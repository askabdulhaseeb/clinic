import 'package:flutter/material.dart';

import '../viewmodels/patient_history_vm.dart';

/// Starts the first history page when it is first built, which is when
/// the tab holding it becomes visible, then rebuilds with the view model.
class PatientHistoryLoader extends StatefulWidget {
  const PatientHistoryLoader({
    super.key,
    required this.history,
    required this.builder,
  });

  final PatientHistoryViewModel history;
  final Widget Function(BuildContext context, PatientHistoryViewModel history)
  builder;

  @override
  State<PatientHistoryLoader> createState() => _PatientHistoryLoaderState();
}

class _PatientHistoryLoaderState extends State<PatientHistoryLoader> {
  @override
  void initState() {
    super.initState();
    // After this build: load() notifies at once and listeners may be
    // mid-build.
    Future<void>.microtask(widget.history.load);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.history,
    builder: (context, _) => widget.builder(context, widget.history),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_color.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/clinic_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../viewmodels/settings_controller.dart';
import '../viewmodels/settings_form_vm.dart';
import '../widgets/logo_picker.dart';

/// Admin → Settings (FEATURES §7.8). Waits for the app-level settings, then
/// shows the form.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.logoPicker = pickLogoWithFilePicker});

  final LogoPicker logoPicker;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    switch (controller.status) {
      case SettingsStatus.unknown:
        if (controller.error != null) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load settings',
            message: controller.error,
          );
        }
        return const Center(child: CircularProgressIndicator());
      case SettingsStatus.missing:
        return const EmptyState(
          icon: Icons.settings_suggest_outlined,
          title: 'Clinic not set up yet',
          message: 'Run the initial setup from the banner above first.',
        );
      case SettingsStatus.ready:
        final initial = controller.settings!;
        // Created once: a save echoes back through the listener and must
        // not reset the form (or drop edits in progress).
        return ChangeNotifierProvider(
          create: (context) => SettingsFormViewModel(
            repository: context.read<SettingsRepository>(),
            initial: initial,
          ),
          child: SettingsView(logoPicker: logoPicker),
        );
    }
  }
}

/// The form; expects a [SettingsFormViewModel] above it.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, this.logoPicker = pickLogoWithFilePicker});

  final LogoPicker logoPicker;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _footer;
  late final TextEditingController _copies;
  late final TextEditingController _reminderDays;
  late final TextEditingController _tplAppointment;
  late final TextEditingController _tplFollowUp;
  late final TextEditingController _tplPostOp;
  late final TextEditingController _tplAdhoc;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsFormViewModel>().initial;
    _name = TextEditingController(text: s.clinicName);
    _address = TextEditingController(text: s.address);
    _phone = TextEditingController(text: s.phone);
    _footer = TextEditingController(text: s.receiptFooter);
    _copies = TextEditingController(text: '${s.defaultReceiptCopies}');
    _reminderDays = TextEditingController(text: '${s.followUpReminderDays}');
    _tplAppointment = TextEditingController(
      text: s.whatsappTemplates.appointment,
    );
    _tplFollowUp = TextEditingController(text: s.whatsappTemplates.followUp);
    _tplPostOp = TextEditingController(text: s.whatsappTemplates.postOp);
    _tplAdhoc = TextEditingController(text: s.whatsappTemplates.adhoc);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _phone,
      _footer,
      _copies,
      _reminderDays,
      _tplAppointment,
      _tplFollowUp,
      _tplPostOp,
      _tplAdhoc,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<SettingsFormViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await vm.save(
      clinicName: _name.text,
      address: _address.text,
      phone: _phone.text,
      receiptFooter: _footer.text,
      defaultReceiptCopies: int.parse(_copies.text.trim()),
      followUpReminderDays: int.parse(_reminderDays.text.trim()),
      templates: WhatsappTemplates(
        appointment: _tplAppointment.text.trim(),
        followUp: _tplFollowUp.text.trim(),
        postOp: _tplPostOp.text.trim(),
        adhoc: _tplAdhoc.text.trim(),
      ),
    );
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  Future<void> _pickLogo() async {
    final picked = await widget.logoPicker();
    if (picked == null || !mounted) return;
    final ok = await context.read<SettingsFormViewModel>().uploadLogo(
      bytes: picked.bytes,
      contentType: picked.contentType,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Logo uploaded')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsFormViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final wide = Breakpoints.isExpanded(context);
    return Scaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'Clinic',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TwoColumn(
                          wide: wide,
                          left: TextFormField(
                            key: const Key('settings-clinic-name'),
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Clinic name',
                            ),
                            validator: SettingsFormViewModel.validateClinicName,
                          ),
                          right: TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _address,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _LogoRow(
                          logoUrl: vm.logoUrl,
                          uploading: vm.uploadingLogo,
                          onPick: vm.busy ? null : _pickLogo,
                        ),
                        const SizedBox(height: 16),
                        _ThemeColourRow(
                          selected: vm.themeColor,
                          onSelect: vm.busy ? null : vm.setThemeColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Receipts',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _footer,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Receipt footer',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            key: const Key('settings-copies'),
                            controller: _copies,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Default receipt copies',
                            ),
                            validator: SettingsFormViewModel.validateCopies,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'WhatsApp reminders',
                    subtitle:
                        'Placeholders: ${WhatsappTemplates.placeholders.join(' ')}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 260,
                          child: TextFormField(
                            key: const Key('settings-reminder-days'),
                            controller: _reminderDays,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Follow-up reminder days',
                              helperText:
                                  'Days before a follow-up that it is due',
                            ),
                            validator:
                                SettingsFormViewModel.validateReminderDays,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          key: const Key('reminder-appointment'),
                          title: const Text('Appointment reminders'),
                          value: vm.reminders.appointment,
                          onChanged: (v) => vm.setReminder(appointment: v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        TextFormField(
                          controller: _tplAppointment,
                          maxLines: 2,
                          enabled: vm.reminders.appointment,
                          decoration: const InputDecoration(
                            labelText: 'Appointment message',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          key: const Key('reminder-follow-up'),
                          title: const Text('Follow-up reminders'),
                          value: vm.reminders.followUp,
                          onChanged: (v) => vm.setReminder(followUp: v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        TextFormField(
                          controller: _tplFollowUp,
                          maxLines: 2,
                          enabled: vm.reminders.followUp,
                          decoration: const InputDecoration(
                            labelText: 'Follow-up message',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          key: const Key('reminder-post-op'),
                          title: const Text('Post-op reminders'),
                          value: vm.reminders.postOp,
                          onChanged: (v) => vm.setReminder(postOp: v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        TextFormField(
                          controller: _tplPostOp,
                          maxLines: 2,
                          enabled: vm.reminders.postOp,
                          decoration: const InputDecoration(
                            labelText: 'Post-op message',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tplAdhoc,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Ad-hoc message',
                            helperText:
                                'Used by the Send WhatsApp button on a patient',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (vm.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      vm.error!,
                      key: const Key('settings-error'),
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('settings-save'),
        onPressed: vm.busy ? null : _save,
        icon: vm.saving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('Save'),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: text.titleMedium),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({
    required this.wide,
    required this.left,
    required this.right,
  });

  final bool wide;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

/// Eight swatches (UI_DESIGN §4.9b, Phase 10); the chosen one is ringed and
/// carries a check. Keys `settings-colour-<key>` and
/// `settings-colour-<key>-selected` on the chosen one.
class _ThemeColourRow extends StatelessWidget {
  const _ThemeColourRow({required this.selected, required this.onSelect});

  final ThemeColor selected;
  final ValueChanged<ThemeColor>? onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme colour', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in ThemeColor.values)
              Tooltip(
                message: c.label,
                child: InkWell(
                  key: Key('settings-colour-${c.key}'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: onSelect == null ? null : () => onSelect!(c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.seed,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == selected
                            ? scheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: c == selected
                        ? Icon(
                            Icons.check,
                            key: Key('settings-colour-${c.key}-selected'),
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LogoRow extends StatelessWidget {
  const _LogoRow({
    required this.logoUrl,
    required this.uploading,
    required this.onPick,
  });

  final String? logoUrl;
  final bool uploading;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = logoUrl;
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: url == null || url.isEmpty
              ? Icon(Icons.image_outlined, color: scheme.outline)
              : Image.network(
                  url,
                  key: const Key('settings-logo-image'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.broken_image_outlined, color: scheme.outline),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Logo'),
              Text(
                'PNG or JPG, up to 2 MB. Printed on receipts.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          key: const Key('settings-pick-logo'),
          onPressed: uploading ? null : onPick,
          icon: uploading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_outlined),
          label: Text(url == null || url.isEmpty ? 'Upload' : 'Replace'),
        ),
      ],
    );
  }
}

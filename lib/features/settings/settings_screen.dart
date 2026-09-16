import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/status_badge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _logout() async {
    await context.read<AppStore>().logout();
  }

  Future<void> _reset() async {
    final ok = await confirmDialog(
      context,
      title: 'Clear operational data?',
      message: 'This deletes tasks, workers, payments, collections, handovers, zones, and history. Your account and work types remain.',
      confirmLabel: 'Clear data',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await context.read<AppStore>().clearOperationalData();
      if (mounted) {
        showSuccess(context, 'Operational data cleared.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final boss = store.getCurrentUser();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: scheme.primary.withValues(alpha: 0.12), child: Icon(Icons.verified_user, color: scheme.primary)),
                title: Text(boss?.displayName ?? 'Boss'),
                subtitle: Text('${boss?.username ?? 'boss'} · ${boss?.role.name.toUpperCase() ?? 'BOSS'}'),
                trailing: Text(AppConstants.appVersion, style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'WORK TYPES'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => showAppSheet(context, const _AddWorkTypeForm(), title: 'Add Work Type'),
                icon: const Icon(Icons.add),
                label: const Text('Add Work Type'),
              ),
            ),
            const SizedBox(height: 8),
            for (final wt in store.workTypes)
              Card(
                child: ListTile(
                  leading: Icon(
                    wt.code == 'Kupalilia' ? Icons.eco : Icons.agriculture,
                    color: const Color(0xFF2E7D32),
                  ),
                  title: Text(wt.name),
                  subtitle: Text(wt.description ?? ''),
                  trailing: const Icon(Icons.auto_fix_high, size: 18, color: Color(0xFF6A1B9A)),
                ),
              ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'DATA'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.refresh, color: Color(0xFFEF6C00)),
                    title: const Text('Clear operational data'),
                    subtitle: const Text('Remove farm records while keeping accounts and work types.'),
                    trailing: _busy
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _reset,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.storage, color: Color(0xFF0277BD)),
                    title: const Text('Backend'),
                    subtitle: Text(store.isConnected ? 'Local persistent database — live updates enabled' : 'OFFLINE'),
                    trailing: StatusBadge(store.isConnected ? BadgeKind.live : BadgeKind.offline, pulse: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'APPEARANCE'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.brightness_6, color: Color(0xFFEF6C00)),
                    title: const Text('Theme'),
                    subtitle: const Text('Choose light, dark, or system default.'),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonFormField<ThemeMode>(
                      initialValue: store.themeMode,
                      decoration: const InputDecoration(
                        labelText: 'Theme mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('System default')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                      ],
                      onChanged: (mode) async {
                        if (mode != null) {
                          await store.setThemeMode(mode);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'ACCOUNT'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      filled: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Farm FMS — Work Measurement → Expectation → Allocation → Payment → Collection → Handover → Live Management',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWorkTypeForm extends StatefulWidget {
  const _AddWorkTypeForm();

  @override
  State<_AddWorkTypeForm> createState() => _AddWorkTypeFormState();
}

class _AddWorkTypeFormState extends State<_AddWorkTypeForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _calculationMode = 'area';

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            validator: Validators.required,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Work type name', prefixIcon: Icon(Icons.work_outline)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description (optional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _calculationMode,
            decoration: const InputDecoration(labelText: 'Calculation rule', prefixIcon: Icon(Icons.calculate_outlined)),
            items: const [
              DropdownMenuItem(value: 'area', child: Text('Area × rate (Length × Width)')),
              DropdownMenuItem(value: 'quantity', child: Text('Quantity × rate')),
            ],
            onChanged: (value) => setState(() => _calculationMode = value ?? 'area'),
          ),
          const SizedBox(height: 8),
          Text(_calculationMode == 'area'
              ? 'Example: 30 × 30 = 900 m², then apply the full work expected cost per m².'
              : 'Enter the work quantity and the expected cost per unit.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              try {
                context.read<AppStore>().addWorkType(
                      name: _name.text,
                      description: _description.text,
                      calculationMode: _calculationMode,
                    );
                Navigator.pop(context);
                showSuccess(context, 'Work type added.');
              } catch (e) {
                showError(context, e);
              }
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Work Type'),
          ),
        ],
      ),
    );
  }
}
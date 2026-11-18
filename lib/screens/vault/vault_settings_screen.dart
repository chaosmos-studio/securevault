import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/vault_service.dart';
import '../../ui/disguise_icon.dart';
import '../../ui/settings_rows.dart';
import '../../ui/text_prompt.dart';
import '../../ui/vault_theme.dart';
import '../setup/setup_flow.dart';
import 'backup_screen.dart';
import 'pin_screens.dart';
import 'vaults_screen.dart';

class VaultSettingsScreen extends StatelessWidget {
  const VaultSettingsScreen({super.key});

  static const _lockChoices = <int, String>{
    0: 'Right away',
    30: 'After 30 seconds',
    60: 'After 1 minute',
    300: 'After 5 minutes',
  };

  String _lockLabel(int seconds) =>
      _lockChoices[seconds] ??
      (seconds < 60 ? 'After $seconds seconds' : 'After ${seconds ~/ 60} minutes');

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _pickDisguise(BuildContext context) async {
    final state = context.read<AppState>();
    final picked = await showModalBottomSheet<DisguiseType>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DisguiseSheet(current: state.currentDisguise),
    );
    if (picked == null || picked == state.currentDisguise) return;
    await state.changeDisguise(picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('SecureVault becomes ${picked.displayName} when you leave'),
      ));
    }
  }

  Future<void> _pickLock(BuildContext context) async {
    final state = context.read<AppState>();
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<int>(
          groupValue: state.autoLockSeconds,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in _lockChoices.entries)
                RadioListTile<int>(value: entry.key, title: Text(entry.value)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await state.setAutoLockSeconds(picked);
  }

  Future<void> _rename(BuildContext context) async {
    final state = context.read<AppState>();
    final info = state.currentVaultInfo;
    if (info == null) return;
    final name = await askText(context,
        title: 'Vault name', initial: info.name, confirm: 'Save', maxLength: 30, sentences: true);
    if (name == null || name.trim().isEmpty) return;
    await VaultService.renameVault(info.id, name.trim());
    await state.refreshVaultInfo();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.vault;
    final themeLabel = switch (state.themeMode) {
      ThemeMode.system => 'Phone setting',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SettingsGroup(children: [
            SettingsRow(
              leading: DisguiseIcon(disguise: state.currentDisguise, size: 40),
              title: state.currentDisguise.displayName,
              subtitle: 'Disguise',
              onTap: () => _pickDisguise(context),
            ),
          ]),
          SettingsGroup(title: 'This vault', children: [
            SettingsRow(
              icon: Icons.edit_outlined,
              title: 'Name',
              value: state.currentVaultInfo?.name ?? '',
              onTap: () => _rename(context),
            ),
            SettingsRow(
              icon: Icons.pin_outlined,
              title: 'Change PIN',
              onTap: () => _push(context, const ChangePinScreen()),
            ),
            SettingsRow(
              icon: Icons.save_alt_rounded,
              title: 'Back up and restore',
              onTap: () => _push(context, const BackupScreen()),
            ),
          ]),
          SettingsGroup(title: 'Security', children: [
            SettingsRow(
              icon: Icons.lock_clock_outlined,
              title: 'Lock',
              value: _lockLabel(state.autoLockSeconds),
              onTap: () => _pickLock(context),
            ),
            SettingsRow(
              icon: Icons.layers_outlined,
              title: 'Vaults',
              subtitle: 'Each vault opens with its own PIN',
              onTap: () => _push(context, const VaultsScreen()),
            ),
          ]),
          SettingsGroup(title: 'Look', children: [
            SettingsRow(
              icon: Icons.contrast_rounded,
              title: 'Theme',
              value: themeLabel,
              onTap: () async {
                final next = switch (state.themeMode) {
                  ThemeMode.system => ThemeMode.light,
                  ThemeMode.light => ThemeMode.dark,
                  ThemeMode.dark => ThemeMode.system,
                };
                await state.setThemeMode(next);
              },
            ),
          ]),
          SettingsGroup(title: 'About', children: [
            SettingsRow(
              icon: Icons.mail_outline_rounded,
              title: 'Contact',
              value: 'hello@chaosmos.studio',
              onTap: () => launchUrl(Uri.parse('mailto:hello@chaosmos.studio')),
            ),
            SettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              onTap: () => launchUrl(Uri.parse('https://shravangoswami.com/SecureVault/privacy/'),
                  mode: LaunchMode.externalApplication),
            ),
            SettingsRow(
              icon: Icons.favorite_outline_rounded,
              title: 'Made by',
              value: 'Shravan Goswami, Jash Ambaliya',
              onTap: () => launchUrl(Uri.parse('https://shravangoswami.com/SecureVault/developers/'),
                  mode: LaunchMode.externalApplication),
            ),
          ]),
          const SizedBox(height: 12),
          Center(
            child: Text('SecureVault ${AppConstants.version}',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: c.muted)),
          ),
        ],
      ),
    );
  }
}

class _DisguiseSheet extends StatefulWidget {
  const _DisguiseSheet({required this.current});

  final DisguiseType current;

  @override
  State<_DisguiseSheet> createState() => _DisguiseSheetState();
}

class _DisguiseSheetState extends State<_DisguiseSheet> {
  late DisguiseType _picked = widget.current;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Disguise', style: text.headlineSmall),
            const SizedBox(height: 6),
            Text('The new icon appears when you leave the app.',
                style: text.bodyMedium!.copyWith(color: c.muted)),
            const SizedBox(height: 20),
            SizedBox(
              height: 340,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final d in DisguiseType.values)
                    DisguiseChoice(
                      disguise: d,
                      selected: d == _picked,
                      onTap: () => setState(() => _picked = d),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, _picked),
              child: Text(_picked == widget.current ? 'Keep ${_picked.displayName}' : 'Use ${_picked.displayName}'),
            ),
          ],
        ),
      ),
    );
  }
}

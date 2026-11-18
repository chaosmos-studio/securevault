import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/vault_service.dart';
import '../../ui/settings_rows.dart';
import '../../ui/vault_theme.dart';
import 'pin_screens.dart';

/// The vaults this vault may see. Each one opens with its own PIN, so a vault
/// made to show other people never reveals the others.
class VaultsScreen extends StatefulWidget {
  const VaultsScreen({super.key});

  @override
  State<VaultsScreen> createState() => _VaultsScreenState();
}

class _VaultsScreenState extends State<VaultsScreen> {
  late Future<List<Map<String, dynamic>>> _vaults = _load();

  Future<List<Map<String, dynamic>>> _load() {
    final id = context.read<AppState>().currentVault?.id;
    return id == null ? Future.value(const []) : VaultService.getVisibleVaults(id);
  }

  Future<void> _new() async {
    final made = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const NewVaultScreen()));
    if (made == true && mounted) {
      setState(() => _vaults = _load());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vault made. Open it with its PIN.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    return Scaffold(
      appBar: AppBar(title: const Text('Vaults')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _vaults,
        builder: (context, snap) {
          final vaults = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Text(
                  'Make a second vault with harmless things in it. If someone makes you '
                  'open SecureVault, type that PIN instead.',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.muted),
                ),
              ),
              SettingsGroup(children: [
                for (final v in vaults)
                  SettingsRow(
                    icon: v['isCurrent'] == true ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    title: v['name'] as String? ?? 'Vault',
                    value: v['isCurrent'] == true ? 'Open now' : null,
                  ),
              ]),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: const Text('New vault'),
      ),
    );
  }
}

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/downloads.dart';
import '../../ui/text_prompt.dart';
import '../../ui/vault_theme.dart';

/// Saves this vault to one file, and brings a saved vault's items back in.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  SavedCopy? _saved;

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _backUp() async {
    final state = context.read<AppState>();
    final vault = state.currentVault;
    final password = state.currentPassword;
    if (vault == null || password == null) return;
    setState(() => _busy = true);
    final SavedCopy copy;
    try {
      copy = await BackupService.backUp(
        vault: vault,
        vaultName: state.currentVaultInfo?.name ?? 'Vault',
        password: password,
      );
    } catch (_) {
      _say('Could not save the backup');
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = copy;
    });
    if (!copy.inDownloads) await _share();
  }

  Future<void> _share() async {
    final saved = _saved;
    if (saved == null) return;
    await context.read<AppState>().whileOutside(() => Share.shareXFiles([XFile(saved.file.path)]));
  }

  Future<void> _restore() async {
    final state = context.read<AppState>();
    final picked = await state.whileOutside(() => FilePicker.platform.pickFiles());
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final pin = await _askPin();
    if (pin == null || !mounted) return;
    final vault = state.currentVault;
    final password = state.currentPassword;
    if (vault == null || password == null) return;

    setState(() => _busy = true);
    try {
      final added = await BackupService.restore(
        backup: File(path),
        backupPassword: pin,
        vault: vault,
        password: password,
        key: state.currentKey,
      );
      await state.refreshVault();
      _say(added == 0
          ? 'Everything in that backup is already here'
          : 'Brought back $added ${added == 1 ? 'item' : 'items'}');
    } on BackupException catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Could not read that backup');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPin() async {
    final pin = await askText(context,
        title: 'PIN of the backed-up vault', confirm: 'Open', obscure: true);
    return pin == null || pin.isEmpty ? null : pin;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final text = Theme.of(context).textTheme;
    final saved = _saved;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Back up and restore')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Your vault lives only on this phone. Uninstalling the app deletes it. '
              'Keep a backup somewhere safe, like your computer or cloud drive.',
              style: text.bodyLarge!.copyWith(color: c.muted),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _busy ? null : _backUp,
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Back up this vault'),
            ),
            if (saved != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: c.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          saved.inDownloads
                              ? 'Saved to Downloads as ${saved.file.uri.pathSegments.last}'
                              : 'Ready to send as ${saved.file.uri.pathSegments.last}',
                          style: text.bodyMedium),
                    ),
                    TextButton(onPressed: _share, child: const Text('Send')),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restore,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore from a backup'),
            ),
            const SizedBox(height: 16),
            Text(
              'Restoring adds the photos, videos and notes from a backup into this vault. '
              'It needs the PIN that vault had.',
              style: text.bodyMedium!.copyWith(color: c.muted),
            ),
            if (_busy) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

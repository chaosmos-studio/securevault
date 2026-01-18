import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/disguise_service.dart';
import '../../core/services/vault_service.dart';

class VaultSettingsScreen extends StatefulWidget {
  const VaultSettingsScreen({super.key});

  @override
  State<VaultSettingsScreen> createState() => _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends State<VaultSettingsScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isCreatingDecoy = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showChangeDisguiseDialog() {
    final appState = context.read<AppState>();
    DisguiseType selectedDisguise = appState.currentDisguise;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Disguise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: DisguiseType.values.map((disguise) {
              final isSelected = disguise == selectedDisguise;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
                title: Row(
                  children: [
                    Icon(disguise.icon),
                    const SizedBox(width: 12),
                    Text(disguise.displayName),
                  ],
                ),
                onTap: () {
                  setDialogState(() => selectedDisguise = disguise);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _applyDisguise(selectedDisguise);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyDisguise(DisguiseType disguise) async {
    final appState = context.read<AppState>();
    await appState.setDisguise(disguise);
    await DisguiseService.setDisguise(disguise);

    if (Platform.isAndroid && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Apply Changes'),
          content: const Text(
            'The app will briefly close to apply the new icon and name. '
            'This is normal and only happens when changing the disguise.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (Platform.isIOS && mounted) {
      _showIOSNameChangeTutorial();
    }
  }

  void _showIOSNameChangeTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change App Name on iOS'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'The app icon has been changed. To also change the app name on your home screen, follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1. Open the Shortcuts app'),
              SizedBox(height: 8),
              Text('2. Tap + to create a new shortcut'),
              SizedBox(height: 8),
              Text('3. Tap "Add Action" → "Open App"'),
              SizedBox(height: 8),
              Text('4. Select this app'),
              SizedBox(height: 8),
              Text('5. Tap the name at the top → "Rename"'),
              SizedBox(height: 8),
              Text('6. Enter your desired name (e.g., "Calculator")'),
              SizedBox(height: 8),
              Text('7. Tap "Add to Home Screen"'),
              SizedBox(height: 8),
              Text('8. Choose an icon and tap "Add"'),
              SizedBox(height: 16),
              Text(
                'Now you can use the shortcut instead of the original app icon!',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showCreateDecoyVaultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Decoy Vault'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create a separate vault with its own password. '
              'This vault will be indistinguishable from your main vault.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Decoy Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isCreatingDecoy ? null : _createDecoyVault,
            child: _isCreatingDecoy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createDecoyVault() async {
    if (_newPasswordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 4 characters')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isCreatingDecoy = true);

    try {
      await VaultService.createVault(_newPasswordController.text);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Decoy vault created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating vault: $e')),
        );
      }
    } finally {
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _isCreatingDecoy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'APPEARANCE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: Icon(appState.currentDisguise.icon),
            title: const Text('Current Disguise'),
            subtitle: Text(appState.currentDisguise.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangeDisguiseDialog,
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'SECURITY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('Create Decoy Vault'),
            subtitle: const Text('Add another vault with different password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showCreateDecoyVaultDialog,
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Auto-Lock'),
            subtitle: Text('After ${AppConstants.autoLockSeconds} seconds of inactivity'),
          ),
          if (Platform.isIOS) ...[
            const Divider(),
            const ListTile(
              title: Text(
                'iOS TIPS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Change App Name'),
              subtitle: const Text('Learn how to change the app name on iOS'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showIOSNameChangeTutorial,
            ),
          ],
          const Divider(),
          const ListTile(
            title: Text(
              'ABOUT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text(AppConstants.version),
          ),
        ],
      ),
    );
  }
}

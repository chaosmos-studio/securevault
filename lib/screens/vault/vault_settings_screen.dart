import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/disguise_service.dart';
import '../../core/services/vault_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/app_dialogs_service.dart';

class VaultSettingsScreen extends StatefulWidget {
  const VaultSettingsScreen({super.key});

  @override
  State<VaultSettingsScreen> createState() => _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends State<VaultSettingsScreen> {
  final _vaultNameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  bool _isCreatingDecoy = false;
  int _autoLockSeconds = AppConstants.autoLockSeconds;

  static const List<int> _autoLockOptions = [15, 30, 60, 120, 300, 600];

  @override
  void initState() {
    super.initState();
    _loadAutoLockSetting();
  }

  Future<void> _loadAutoLockSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoLockSeconds =
          prefs.getInt('auto_lock_seconds') ?? AppConstants.autoLockSeconds;
    });
  }

  Future<void> _saveAutoLockSetting(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_lock_seconds', seconds);
    setState(() {
      _autoLockSeconds = seconds;
    });
  }

  String _formatAutoLockTime(int seconds) {
    if (seconds < 60) return '$seconds seconds';
    return '${seconds ~/ 60} minute${seconds >= 120 ? 's' : ''}';
  }

  @override
  void dispose() {
    _vaultNameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  Future<void> _showThemePicker(BuildContext context) async {
    final appState = context.read<AppState>();
    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose Theme'),
        children: [
          ListTile(
            leading: Icon(
              appState.themeMode == ThemeMode.system
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: appState.themeMode == ThemeMode.system
                  ? Theme.of(context).primaryColor
                  : null,
            ),
            title: const Text('System Default'),
            onTap: () {
              appState.setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              appState.themeMode == ThemeMode.light
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: appState.themeMode == ThemeMode.light
                  ? Theme.of(context).primaryColor
                  : null,
            ),
            title: const Text('Light'),
            onTap: () {
              appState.setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              appState.themeMode == ThemeMode.dark
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: appState.themeMode == ThemeMode.dark
                  ? Theme.of(context).primaryColor
                  : null,
            ),
            title: const Text('Dark'),
            onTap: () {
              appState.setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
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
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
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
                // Show instructions BEFORE applying disguise to avoid app restart
                _showDisguiseInstructions(selectedDisguise);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performDisguiseChange(DisguiseType disguise) async {
    final appState = context.read<AppState>();
    await appState.setDisguise(disguise);
    await DisguiseService.setDisguise(disguise);

    if (mounted) {
      if (Platform.isAndroid) {
        _showAndroidIconChangeDialog();
      } else if (Platform.isIOS) {
        _showIOSNameChangeTutorial();
      }
    }
  }

  void _showDisguiseInstructions(DisguiseType disguise) {
    String title;
    List<String> instructions;

    switch (disguise) {
      case DisguiseType.calculator:
        title = 'Calculator Mode';
        instructions = [
          'Enter password as numbers, press = to unlock',
          'Use ⌫ (backspace) to delete numbers',
          'Or use "Request a Feature" menu for any password',
        ];
        break;
      case DisguiseType.clock:
        title = 'Clock Mode';
        instructions = [
          'Tap time digits to enter password',
          'Add alarm - enter time and label (both try unlock)',
          'Tap existing alarm to edit time and label',
          'Or use "Request a Feature" menu for any password',
        ];
        break;
      case DisguiseType.moodspace:
        title = 'MoodSpace Mode';
        instructions = [
          'Tap the mood emoji area to enter password',
          'Or type password in the mood input field',
          'The app tracks moods as cover functionality',
        ];
        break;
      case DisguiseType.notes:
        title = 'Notes Mode';
        instructions = [
          'Type your password in the notes area',
          'The vault unlocks automatically when password is typed',
          'Notes are saved as cover functionality',
        ];
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(disguise.icon),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to open your vault:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...instructions.map(
              (instruction) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(instruction)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Apply disguise AFTER user reads instructions
              await _performDisguiseChange(disguise);
            },
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showAndroidIconChangeDialog() {
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
    bool isAdminVault = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Vault'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create a separate vault with its own password. '
                  'All vaults are completely independent.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _vaultNameController,
                  decoration: const InputDecoration(
                    labelText: 'Vault Name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Work, Family, Private',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
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
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Admin Vault'),
                  subtitle: const Text(
                    'Can see and manage all other vaults',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: isAdminVault,
                  onChanged: (value) =>
                      setDialogState(() => isAdminVault = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _vaultNameController.clear();
                _newPasswordController.clear();
                _confirmPasswordController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isCreatingDecoy
                  ? null
                  : () => _createDecoyVault(isAdminVault),
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
      ),
    );
  }

  Future<void> _createDecoyVault(bool isAdmin) async {
    if (_vaultNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vault name')),
      );
      return;
    }

    if (_newPasswordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 4 characters')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    final currentVaultId = context.read<AppState>().currentVault?.id;
    setState(() => _isCreatingDecoy = true);

    try {
      final isTaken = await VaultService.isPasswordTaken(
        _newPasswordController.text,
      );
      if (isTaken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A vault with this password already exists'),
            ),
          );
        }
        return;
      }

      await VaultService.createVault(
        _newPasswordController.text,
        name: _vaultNameController.text.trim(),
        isMaster: isAdmin,
        createdByVaultId: currentVaultId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      _vaultNameController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _isCreatingDecoy = false);
    }
  }

  void _showChangePasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _changePassword,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final currentPassword = appState.currentPassword;

    if (vault == null || currentPassword == null) return;

    if (_currentPasswordController.text != currentPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password is incorrect')),
      );
      return;
    }

    if (_newPasswordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 4 characters'),
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    navigator.pop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Changing password...'),
          ],
        ),
      ),
    );

    try {
      final success = await VaultService.changePassword(
        vault,
        currentPassword,
        _newPasswordController.text,
      );

      if (mounted) navigator.pop();

      if (success) {
        appState.lock();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Password changed. Please log in with your new password.',
            ),
          ),
        );
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to change password')),
        );
      }
    } catch (e) {
      if (mounted) navigator.pop();
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }
  }

  void _showVaultPasswords() {
    final appState = context.read<AppState>();
    final currentVaultId = appState.currentVault?.id;

    if (currentVaultId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Vaults'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: VaultService.getVisibleVaults(currentVaultId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final vaults = snapshot.data!;
            if (vaults.isEmpty) {
              return const Text('No vaults found.');
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appState.isMasterVault
                        ? 'All vaults (admin access):'
                        : 'Vaults visible to you:',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ...vaults.map((vault) {
                    final isCurrentVault = vault['isCurrent'] == true;
                    final isAdmin = vault['isMaster'] == true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            isAdmin
                                ? Icons.admin_panel_settings
                                : Icons.folder_outlined,
                            size: 20,
                            color: isCurrentVault
                                ? Colors.blue
                                : (isAdmin ? Colors.amber : Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${vault['name']}${isCurrentVault ? ' (current)' : ''}',
                              style: TextStyle(
                                fontWeight: isCurrentVault
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Text(
                    'Each vault has its own password. Use the password to access the corresponding vault.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('App Theme'),
            subtitle: Text(_getThemeModeName(appState.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context),
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
            title: const Text('Create New Vault'),
            subtitle: const Text('Add another vault with its own password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showCreateDecoyVaultDialog,
          ),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('Change Password'),
            subtitle: const Text('Change your vault password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangePasswordDialog,
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('View Vaults'),
            subtitle: const Text('See all your vaults'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showVaultPasswords,
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Auto-Lock'),
            subtitle: Text(
              'After ${_formatAutoLockTime(_autoLockSeconds)} of inactivity',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAutoLockDialog,
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'BACKUP & RESTORE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Create Backup'),
            subtitle: const Text('Export encrypted backup to Downloads'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _createBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore from Backup'),
            subtitle: const Text('Import data from backup file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _restoreBackup,
          ),
          const ListTile(
            leading: Icon(Icons.warning_amber_outlined, color: Colors.orange),
            title: Text('Important'),
            subtitle: Text(
              'Back up your data regularly. If you uninstall this app, all data will be permanently deleted.',
              style: TextStyle(fontSize: 12),
            ),
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
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Version'),
            subtitle: const Text(AppConstants.version),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangelog,
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('About Us'),
            subtitle: const Text('Meet the developers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutDialog,
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact Us'),
            subtitle: const Text('Get in touch with support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppDialogsService.showContactUs(context),
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('Request a Feature'),
            subtitle: const Text('Suggest improvements'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppDialogsService.showRequestFeature(context),
          ),
        ],
      ),
    );
  }

  void _showAutoLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Lock Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _autoLockOptions.map((seconds) {
            final isSelected = seconds == _autoLockSeconds;
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(_formatAutoLockTime(seconds)),
              onTap: () {
                Navigator.pop(context);
                _saveAutoLockSetting(seconds);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    final appState = context.read<AppState>();
    final password = appState.currentPassword;

    if (password == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to create backup')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Creating backup...'),
          ],
        ),
      ),
    );

    try {
      final backupFile = await BackupService.createLocalBackup(password);

      if (mounted) Navigator.pop(context);

      if (backupFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup saved to: ${BackupService.getBackupFileName(backupFile)}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create backup')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    if (!file.path.endsWith('.svb')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid backup file (.svb)'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the vault password that was active when this backup was created. This may be different from your current vault password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Original Vault Password',
                hintText: 'Password used when backup was created',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will replace ALL your current data with the backup data!',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || passwordController.text.isEmpty) return;

    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Restoring backup...'),
          ],
        ),
      ),
    );

    try {
      final success = await BackupService.restoreFromBackup(
        file,
        passwordController.text,
      );

      if (mounted) navigator.pop();

      if (success && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Backup restored successfully! Please restart the app.',
            ),
          ),
        );
      } else if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to restore backup. Check your password.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) navigator.pop();
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAboutDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutScreen()),
    );
  }

  void _showChangelog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangelogScreen()),
    );
  }
}

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  Future<String> _loadChangelog() async {
    return await rootBundle.loadString('Changelog.md');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Changelog')),
      body: FutureBuilder<String>(
        future: _loadChangelog(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.hasError
                          ? 'Error loading changelog: ${snapshot.error}'
                          : 'Changelog not available',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: _parseChangelog(snapshot.data!, context),
          );
        },
      ),
    );
  }

  List<Widget> _parseChangelog(String content, BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    String currentVersion = '';
    String currentDate = '';
    List<String> currentChanges = [];

    for (final line in lines) {
      if (line.startsWith('## [')) {
        if (currentVersion.isNotEmpty && currentChanges.isNotEmpty) {
          widgets.add(
            _ChangelogEntry(
              version: currentVersion,
              date: currentDate,
              changes: List.from(currentChanges),
            ),
          );
          widgets.add(const SizedBox(height: 16));
        }
        final match = RegExp(r'\[([^\]]+)\]\s*-\s*(.+)').firstMatch(line);
        if (match != null) {
          currentVersion = match.group(1) ?? '';
          currentDate = match.group(2) ?? '';
        }
        currentChanges = [];
      } else if (line.startsWith('- ')) {
        currentChanges.add(line.substring(2).replaceAll('**', ''));
      }
    }

    if (currentVersion.isNotEmpty && currentChanges.isNotEmpty) {
      widgets.add(
        _ChangelogEntry(
          version: currentVersion,
          date: currentDate,
          changes: currentChanges,
        ),
      );
    }

    return widgets;
  }
}

class _ChangelogEntry extends StatelessWidget {
  final String version;
  final String date;
  final List<String> changes;

  const _ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'v$version',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(date, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            ...changes.map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: Text(change)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Icon(Icons.security, size: 64, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'SecureVault',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const Center(
            child: Text(
              'Version ${AppConstants.version}',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Your private vault, hidden in plain sight.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'DEVELOPERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          _buildDeveloperCard(
            context,
            name: 'Shravan Goswami',
            role: 'Lead Developer',
            links: [
              _DeveloperLink(
                _SocialIcon.github,
                'GitHub',
                'https://github.com/shravangoswami',
              ),
              _DeveloperLink(
                _SocialIcon.linkedin,
                'LinkedIn',
                'https://linkedin.com/in/shravangoswami',
              ),
              _DeveloperLink(
                _SocialIcon.website,
                'Website',
                'https://shravangoswami.com',
              ),
              _DeveloperLink(
                _SocialIcon.email,
                'Email',
                'mailto:hello@chaosmos.studio',
              ),
              _DeveloperLink(
                _SocialIcon.sponsor,
                'Sponsor',
                'https://github.com/sponsors/shravangoswami',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDeveloperCard(
            context,
            name: 'Jash Ambaliya',
            role: 'Co-Developer',
            links: [
              _DeveloperLink(
                _SocialIcon.github,
                'GitHub',
                'https://github.com/AJ0070',
              ),
              _DeveloperLink(
                _SocialIcon.linkedin,
                'LinkedIn',
                'https://www.linkedin.com/in/jash0070/',
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '❤️ Made with Flutter',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '© ${DateTime.now().year} SecureVault. All rights reserved.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard(
    BuildContext context, {
    required String name,
    required String role,
    required List<_DeveloperLink> links,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    name[0],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(role, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: links.map((link) {
                return ActionChip(
                  avatar: link.icon.widget,
                  label: Text(link.label),
                  onPressed: () => _launchUrl(link.url),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SocialIcon {
  github,
  linkedin,
  website,
  email,
  sponsor;

  Widget get widget {
    switch (this) {
      case _SocialIcon.github:
        return const _GitHubIcon();
      case _SocialIcon.linkedin:
        return const _LinkedInIcon();
      case _SocialIcon.website:
        return const Icon(Icons.language, size: 18);
      case _SocialIcon.email:
        return const Icon(Icons.email_outlined, size: 18);
      case _SocialIcon.sponsor:
        return const Icon(Icons.favorite, size: 18, color: Colors.pink);
    }
  }
}

class _GitHubIcon extends StatelessWidget {
  const _GitHubIcon();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GitHubSVGPainter(isDark: isDark)),
    );
  }
}

class _GitHubSVGPainter extends CustomPainter {
  final bool isDark;
  _GitHubSVGPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..style = PaintingStyle.fill;

    final path = Path();
    // GitHub SVG path scaled to 18x18
    path.moveTo(9, 0);
    path.cubicTo(13.97, 0, 18, 4.03, 18, 9.0);
    path.cubicTo(18, 12.97, 15.64, 16.35, 12.27, 17.5);
    path.cubicTo(11.82, 17.59, 11.66, 17.3, 11.66, 17.05);
    path.cubicTo(11.66, 16.74, 11.67, 15.75, 11.67, 14.52);
    path.cubicTo(11.67, 13.66, 11.39, 13.1, 11.07, 12.82);
    path.cubicTo(13.03, 12.59, 15.09, 11.81, 15.09, 8.36);
    path.cubicTo(15.09, 7.35, 14.74, 6.53, 14.16, 5.89);
    path.cubicTo(14.25, 5.65, 14.56, 4.74, 14.08, 3.49);
    path.cubicTo(14.08, 3.49, 13.32, 3.24, 11.68, 4.4);
    path.cubicTo(10.96, 4.19, 10.19, 4.09, 9.43, 4.09);
    path.cubicTo(8.67, 4.09, 7.9, 4.19, 7.18, 4.4);
    path.cubicTo(5.54, 3.24, 4.77, 3.49, 4.77, 3.49);
    path.cubicTo(4.29, 4.74, 4.6, 5.65, 4.69, 5.89);
    path.cubicTo(4.12, 6.53, 3.76, 7.35, 3.76, 8.36);
    path.cubicTo(3.76, 11.8, 5.81, 12.59, 7.76, 12.83);
    path.cubicTo(7.51, 13.06, 7.29, 13.48, 7.21, 14.07);
    path.cubicTo(6.71, 14.31, 5.42, 14.72, 4.62, 13.33);
    path.cubicTo(4.62, 13.33, 4.15, 12.46, 3.26, 12.39);
    path.cubicTo(3.26, 12.39, 2.39, 12.38, 3.21, 12.95);
    path.cubicTo(3.21, 12.95, 3.79, 13.23, 4.19, 14.28);
    path.cubicTo(4.19, 14.28, 4.72, 15.88, 7.18, 15.33);
    path.cubicTo(7.18, 16.09, 7.19, 16.8, 7.19, 17.05);
    path.cubicTo(7.19, 17.3, 7.03, 17.6, 6.58, 17.5);
    path.cubicTo(3.21, 16.36, 0.84, 12.97, 0.84, 9.0);
    path.cubicTo(0.84, 4.03, 4.87, 0, 9.84, 0);
    path.close();

    canvas.translate(-0.84, 0); // Adjust for viewBox offset
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinkedInIcon extends StatelessWidget {
  const _LinkedInIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _LinkedInSVGPainter()),
    );
  }
}

class _LinkedInSVGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A66C2)
      ..style = PaintingStyle.fill;

    final path = Path();
    // LinkedIn SVG path scaled to 18x18
    path.moveTo(13.75, 13.75);
    path.lineTo(11.75, 13.75);
    path.lineTo(11.75, 10.62);
    path.cubicTo(11.75, 9.87, 11.74, 8.92, 10.71, 8.92);
    path.cubicTo(9.67, 8.92, 9.51, 9.73, 9.51, 10.57);
    path.lineTo(9.51, 13.75);
    path.lineTo(7.51, 13.75);
    path.lineTo(7.51, 7.31);
    path.lineTo(9.43, 7.31);
    path.lineTo(9.43, 8.19);
    path.lineTo(9.46, 8.19);
    path.cubicTo(9.85, 7.52, 10.58, 7.13, 11.36, 7.16);
    path.cubicTo(13.38, 7.16, 13.75, 8.56, 13.75, 10.31);
    path.lineTo(13.75, 13.75);
    path.close();

    path.moveTo(5.25, 6.43);
    path.cubicTo(4.42, 6.43, 3.94, 5.8, 3.94, 5.06);
    path.cubicTo(3.94, 4.32, 4.42, 3.69, 5.25, 3.69);
    path.cubicTo(6.08, 3.69, 6.56, 4.32, 6.56, 5.06);
    path.cubicTo(6.56, 5.8, 6.08, 6.43, 5.25, 6.43);
    path.close();

    path.moveTo(6.25, 13.75);
    path.lineTo(4.25, 13.75);
    path.lineTo(4.25, 7.31);
    path.lineTo(6.25, 7.31);
    path.lineTo(6.25, 13.75);
    path.close();

    path.moveTo(14.75, 2.25);
    path.lineTo(3.24, 2.25);
    path.cubicTo(2.56, 2.25, 2.25, 2.52, 2.25, 3.22);
    path.lineTo(2.25, 14.78);
    path.cubicTo(2.25, 15.48, 2.56, 15.75, 3.24, 15.75);
    path.lineTo(14.75, 15.75);
    path.cubicTo(15.44, 15.75, 15.75, 15.48, 15.75, 14.78);
    path.lineTo(15.75, 3.22);
    path.cubicTo(15.75, 2.52, 15.44, 2.25, 14.75, 2.25);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DeveloperLink {
  final _SocialIcon icon;
  final String label;
  final String url;

  const _DeveloperLink(this.icon, this.label, this.url);
}

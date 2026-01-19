import 'dart:io';
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
      _autoLockSeconds = prefs.getInt('auto_lock_seconds') ?? AppConstants.autoLockSeconds;
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
                  onChanged: (value) => setDialogState(() => isAdminVault = value),
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
              onPressed: _isCreatingDecoy ? null : () => _createDecoyVault(isAdminVault),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final currentVaultId = context.read<AppState>().currentVault?.id;
    setState(() => _isCreatingDecoy = true);

    try {
      final isTaken = await VaultService.isPasswordTaken(_newPasswordController.text);
      if (isTaken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A vault with this password already exists')),
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
          SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
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
        const SnackBar(content: Text('New password must be at least 4 characters')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
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
          const SnackBar(content: Text('Password changed. Please log in with your new password.')),
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
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
                            isAdmin ? Icons.admin_panel_settings : Icons.folder_outlined,
                            size: 20,
                            color: isCurrentVault ? Colors.blue : (isAdmin ? Colors.amber : Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${vault['name']}${isCurrentVault ? ' (current)' : ''}',
                              style: TextStyle(
                                fontWeight: isCurrentVault ? FontWeight.bold : FontWeight.normal,
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
            subtitle: Text('After ${_formatAutoLockTime(_autoLockSeconds)} of inactivity'),
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
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text(AppConstants.version),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('About Us'),
            subtitle: const Text('Meet the developers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutDialog,
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
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create backup')),
      );
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
            content: Text('Backup saved to: ${BackupService.getBackupFileName(backupFile)}'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        const SnackBar(content: Text('Please select a valid backup file (.svb)')),
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
      final success = await BackupService.restoreFromBackup(file, passwordController.text);
      
      if (mounted) navigator.pop();
      
      if (success && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Backup restored successfully! Please restart the app.')),
        );
      } else if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to restore backup. Check your password.')),
        );
      }
    } catch (e) {
      if (mounted) navigator.pop();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAboutDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutScreen()),
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
      appBar: AppBar(
        title: const Text('About Us'),
      ),
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _buildDeveloperCard(
            context,
            name: 'Shravan Goswami',
            role: 'Lead Developer',
            links: [
              _DeveloperLink(Icons.code, 'GitHub', 'https://github.com/shravangoswami'),
              _DeveloperLink(Icons.language, 'Website', 'https://shravangoswami.com'),
              _DeveloperLink(Icons.work_outline, 'LinkedIn', 'https://linkedin.com/in/shravangoswami'),
              _DeveloperLink(Icons.email_outlined, 'Email', 'mailto:hello@chaosmos.studio'),
              _DeveloperLink(Icons.favorite, 'Sponsor', 'https://github.com/sponsors/shravangoswami'),
            ],
          ),
          const SizedBox(height: 16),
          _buildDeveloperCard(
            context,
            name: 'Jash Ambaliya',
            role: 'Co-Developer',
            links: [
              _DeveloperLink(Icons.favorite, 'Sponsor', 'https://github.com/sponsors/jashambaliya'),
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
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  avatar: Icon(link.icon, size: 18),
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

class _DeveloperLink {
  final IconData icon;
  final String label;
  final String url;

  const _DeveloperLink(this.icon, this.label, this.url);
}

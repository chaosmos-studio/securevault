import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/vault_service.dart';
import '../../core/services/disguise_service.dart';
import '../../core/services/app_dialogs_service.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DisguiseType _selectedDisguise = DisguiseType.calculator;
  final _vaultNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isMasterVault = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _vaultNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeSetup() async {
    if (_vaultNameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a vault name');
      return;
    }
    if (_passwordController.text.length < 4) {
      setState(() => _error = 'Password must be at least 4 characters');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final appState = context.read<AppState>();

    try {
      await VaultService.createVault(
        _passwordController.text,
        name: _vaultNameController.text.trim(),
        isMaster: _isMasterVault,
      );

      // Save disguise preference (safe — isSetupComplete is still false,
      // so AppRouter still shows SetupWizard even after notifyListeners)
      await appState.setDisguise(_selectedDisguise);

      if (mounted) {
        // Show first-time instructions while SetupWizard is still active
        await AppDialogsService.showFirstTimeInstructions(context);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('first_time_instructions', false);

        // Apply native icon change while SetupWizard is still active
        await DisguiseService.setDisguise(_selectedDisguise);

        if (Platform.isAndroid) {
          // Persist setup complete directly to SharedPreferences WITHOUT
          // calling appState.completeSetup() which triggers notifyListeners()
          // and causes AppRouter to replace SetupWizard before we can
          // show the restart dialog and force-stop the app.
          await prefs.setBool('is_setup_complete', true);

          // Show dialog, then kill the app so launcher picks up the new icon.
          // When the app restarts, AppState.initialize() reads is_setup_complete
          // from SharedPreferences and routes to the disguise screen.
          _showRestartDialog();
        } else {
          // On non-Android platforms, complete setup normally
          await appState.completeSetup();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Setup failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Apply Disguise'),
        content: const Text(
          'The app will now close to apply the new icon and name. '
          'Please reopen the app from your home screen.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await DisguiseService.forceStopApp();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildDisguisePage(),
                  _buildPasswordPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight - 48, // Subtract vertical padding
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.security, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to SecureVault',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your private vault disguised as everyday apps. '
                    'Keep your photos, videos, and notes completely private.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisguisePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Disguise',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select how the app appears on your home screen. '
            'You can change this later in settings.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: DisguiseType.values.map((disguise) {
                final isSelected = _selectedDisguise == disguise;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDisguise = disguise),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? Colors.blue.withValues(alpha: 0.1)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          disguise.icon,
                          size: 48,
                          color: isSelected ? Colors.blue : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          disguise.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.blue : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Row(
            children: [
              TextButton(onPressed: _previousPage, child: const Text('Back')),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextPage,
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight - 48, // Subtract vertical padding
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Your Vault',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Give your vault a name and set a password. '
                    'You can create more vaults later with different passwords.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _vaultNameController,
                    decoration: const InputDecoration(
                      labelText: 'Vault Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.folder),
                      hintText: 'e.g., Personal, Work, Private',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Admin Vault'),
                    subtitle: const Text(
                      'Can see and manage all other vaults',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isMasterVault,
                    onChanged: (value) =>
                        setState(() => _isMasterVault = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const Spacer(),
                  const SizedBox(height: 24), // Bottom spacing
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : _previousPage,
                        child: const Text('Back'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _completeSetup,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Complete Setup'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

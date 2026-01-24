import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/vault_service.dart';
import '../services/encryption_service.dart';
import '../services/security_service.dart';

class AppState extends ChangeNotifier {
  DisguiseType _currentDisguise = DisguiseType.calculator;
  bool _isSetupComplete = false;
  bool _isUnlocked = false;
  Vault? _currentVault;
  String? _currentPassword;
  String? _currentKey; // Cache the derived key for performance
  DateTime? _lastActivityTime;
  VaultInfo? _currentVaultInfo;

  DisguiseType get currentDisguise => _currentDisguise;
  bool get isSetupComplete => _isSetupComplete;
  bool get isUnlocked => _isUnlocked;
  Vault? get currentVault => _currentVault;
  String? get currentPassword => _currentPassword;
  String? get currentKey => _currentKey;
  VaultInfo? get currentVaultInfo => _currentVaultInfo;
  bool get isMasterVault => _currentVaultInfo?.isMaster ?? false;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isSetupComplete = prefs.getBool('is_setup_complete') ?? false;
    final disguiseId =
        prefs.getString('current_disguise') ?? DisguiseType.calculator.id;
    _currentDisguise = DisguiseType.values.firstWhere(
      (d) => d.id == disguiseId,
      orElse: () => DisguiseType.calculator,
    );

    final themeModeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex];

    notifyListeners();
    // Ensure screenshots are allowed in disguise mode
    await SecurityService.allowScreenshots();
  }

  Future<void> setDisguise(DisguiseType disguise) async {
    _currentDisguise = disguise;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_disguise', disguise.id);
    notifyListeners();
  }

  Future<void> completeSetup() async {
    _isSetupComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_setup_complete', true);
    notifyListeners();
  }

  Future<bool> unlock(String password) async {
    final vault = await VaultService.unlockVault(password);
    if (vault != null) {
      _isUnlocked = true;
      _currentVault = vault;
      _currentPassword = password;
      // Derive and cache key once
      _currentKey = await EncryptionService.deriveKeyFromPassword(password);
      _lastActivityTime = DateTime.now();
      _currentVaultInfo = await VaultService.getVaultInfo(vault.id);

      // Prevent screenshots when vault is unlocked
      await SecurityService.preventScreenshots();

      notifyListeners();
      return true;
    }
    return false;
  }

  void lock() {
    _isUnlocked = false;
    _currentVault = null;
    _currentPassword = null;
    _currentKey = null;
    _lastActivityTime = null;
    _currentVaultInfo = null;
    notifyListeners();

    // Allow screenshots again when locked (disguise mode)
    SecurityService.allowScreenshots();
  }

  void updateActivity() {
    _lastActivityTime = DateTime.now();
  }

  bool shouldAutoLock() {
    if (_lastActivityTime == null) return false;
    final elapsed = DateTime.now().difference(_lastActivityTime!);
    return elapsed.inSeconds > AppConstants.autoLockSeconds;
  }

  Future<void> refreshVault() async {
    if (_currentPassword != null) {
      _currentVault = await VaultService.unlockVault(_currentPassword!);
      notifyListeners();
    }
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }
}

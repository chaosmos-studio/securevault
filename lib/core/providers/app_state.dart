import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/disguise_service.dart';
import '../services/vault_service.dart';
import '../services/encryption_service.dart';
import '../services/security_service.dart';
import '../services/temp_files.dart';

class AppState extends ChangeNotifier {
  static const _autoLockKey = 'auto_lock_seconds';
  static const _coachKey = 'coach_pending';
  static const _welcomeKey = 'welcome_pending';

  DisguiseType _currentDisguise = DisguiseType.calculator;
  bool _isSetupComplete = false;
  bool _isUnlocked = false;
  Vault? _currentVault;
  String? _currentPassword;
  String? _currentKey;
  VaultInfo? _currentVaultInfo;
  int _autoLockSeconds = AppConstants.autoLockSeconds;
  bool _coachPending = false;
  bool _welcomePending = false;
  String? _practicePin;
  DateTime? _leftAt;
  int _outsideTasks = 0;

  DisguiseType get currentDisguise => _currentDisguise;
  bool get isSetupComplete => _isSetupComplete;
  bool get isUnlocked => _isUnlocked;
  Vault? get currentVault => _currentVault;
  String? get currentPassword => _currentPassword;
  String? get currentKey => _currentKey;
  VaultInfo? get currentVaultInfo => _currentVaultInfo;
  bool get isMasterVault => _currentVaultInfo?.isMaster ?? false;
  int get autoLockSeconds => _autoLockSeconds;

  /// The disguise shows how to open the vault until the first unlock.
  bool get coachPending => _coachPending;

  /// The PIN chosen a moment ago in setup, shown once while practising.
  /// Only ever held in memory.
  String? get practicePin => _practicePin;

  /// The vault explains the new launcher icon once, after the first unlock.
  bool get welcomePending => _welcomePending;

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
    _autoLockSeconds =
        prefs.getInt(_autoLockKey) ?? AppConstants.autoLockSeconds;
    _coachPending = prefs.getBool(_coachKey) ?? false;
    _welcomePending = prefs.getBool(_welcomeKey) ?? false;

    notifyListeners();
    await SecurityService.allowScreenshots();
    await TempFiles.clear();
    if (_isSetupComplete) {
      await DisguiseService.repairIcon(_currentDisguise);
    }
  }

  Future<void> setDisguise(DisguiseType disguise) async {
    _currentDisguise = disguise;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_disguise', disguise.id);
    notifyListeners();
  }

  /// Turns the launcher icon into [disguise] the next time the app is left.
  Future<void> changeDisguise(DisguiseType disguise) async {
    await setDisguise(disguise);
    await DisguiseService.requestIcon(disguise);
  }

  /// Ends setup: the vault exists and the disguise is chosen. The disguise
  /// then teaches its secret entry until the vault is opened once.
  Future<void> finishSetup(DisguiseType disguise, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_disguise', disguise.id);
    await prefs.setInt(_autoLockKey, 0);
    await prefs.setBool(_coachKey, true);
    await prefs.setBool(_welcomeKey, true);
    await prefs.setBool('is_setup_complete', true);
    await DisguiseService.requestIcon(disguise);
    _currentDisguise = disguise;
    _autoLockSeconds = 0;
    _coachPending = true;
    _welcomePending = true;
    _practicePin = pin;
    _isSetupComplete = true;
    notifyListeners();
  }

  Future<bool> unlock(String password) async {
    if (password.isEmpty) return false;
    final vault = await VaultService.unlockVault(password);
    if (vault == null) return false;

    _isUnlocked = true;
    _currentVault = vault;
    _currentPassword = password;
    _currentKey = await EncryptionService.deriveKeyFromPassword(password);
    _currentVaultInfo = await VaultService.getVaultInfo(vault.id);
    _leftAt = null;
    if (_coachPending) {
      _coachPending = false;
      _practicePin = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_coachKey, false);
    }

    await SecurityService.preventScreenshots();
    notifyListeners();
    return true;
  }

  void lock() {
    if (!_isUnlocked) return;
    _isUnlocked = false;
    _currentVault = null;
    _currentPassword = null;
    _currentKey = null;
    _currentVaultInfo = null;
    _leftAt = null;
    notifyListeners();
    SecurityService.allowScreenshots();
    TempFiles.clear();
  }

  Future<void> dismissWelcome() async {
    _welcomePending = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey, false);
    notifyListeners();
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockKey, seconds);
    notifyListeners();
  }

  /// Runs a picker, camera or share sheet without locking the vault behind it.
  Future<T> whileOutside<T>(Future<T> Function() task) async {
    _outsideTasks++;
    try {
      return await task();
    } finally {
      _outsideTasks--;
      _leftAt = null;
    }
  }

  /// The app went to the background.
  Future<void> onLeft() async {
    if (_isUnlocked && _outsideTasks == 0) {
      if (_autoLockSeconds == 0) {
        lock();
      } else {
        _leftAt = DateTime.now();
      }
    }
    if (!_isUnlocked) {
      await DisguiseService.applyPendingIcon();
    }
  }

  /// The app came back to the front.
  void onReturned() {
    final leftAt = _leftAt;
    _leftAt = null;
    if (_isUnlocked &&
        leftAt != null &&
        DateTime.now().difference(leftAt).inSeconds >= _autoLockSeconds) {
      lock();
    }
  }

  Future<void> refreshVault() async {
    if (_currentPassword != null) {
      _currentVault = await VaultService.unlockVault(_currentPassword!);
      notifyListeners();
    }
  }

  Future<void> refreshVaultInfo() async {
    final vault = _currentVault;
    if (vault == null) return;
    _currentVaultInfo = await VaultService.getVaultInfo(vault.id);
    notifyListeners();
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

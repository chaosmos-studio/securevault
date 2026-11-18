import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Swaps the launcher icon and name between SecureVault and its disguises.
///
/// Android drops the old icon from the home screen when the swap happens, and
/// a swap while the app is on screen can close it. So a swap is only requested
/// here, and made when the app goes to the background with the vault locked.
class DisguiseService {
  static const _pendingKey = 'pending_icon';
  static const _methodChannel = MethodChannel('com.securevault/disguise');

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> requestIcon(DisguiseType disguise) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, disguise.id);
  }

  static Future<void> applyPendingIcon() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_pendingKey);
    if (pending == null || !_android) return;
    try {
      await _methodChannel.invokeMethod('setDisguise', {'disguiseId': pending});
      await prefs.remove(_pendingKey);
    } catch (_) {
      // Left pending, to be tried again next time.
    }
  }

  /// Requests a swap if the launcher shows something other than [disguise],
  /// for phones where an earlier swap never happened.
  static Future<void> repairIcon(DisguiseType disguise) async {
    final shown = await currentIcon();
    if (shown != null && shown != disguise.id) {
      await requestIcon(disguise);
    }
  }

  /// The disguise id the launcher shows, "default" for SecureVault itself,
  /// or null where icons cannot change.
  static Future<String?> currentIcon() async {
    if (!_android) return null;
    try {
      return await _methodChannel.invokeMethod<String>('getCurrentDisguise');
    } catch (_) {
      return null;
    }
  }
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class DisguiseService {
  static const _currentDisguiseKey = 'current_disguise';
  static const _isSetupCompleteKey = 'is_setup_complete';
  static const _methodChannel = MethodChannel('com.securevault/disguise');

  static Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isSetupCompleteKey) ?? false;
  }

  static Future<void> setSetupComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isSetupCompleteKey, complete);
  }

  static Future<DisguiseType> getCurrentDisguise() async {
    final prefs = await SharedPreferences.getInstance();
    final disguiseId =
        prefs.getString(_currentDisguiseKey) ?? DisguiseType.calculator.id;
    return DisguiseType.values.firstWhere(
      (d) => d.id == disguiseId,
      orElse: () => DisguiseType.calculator,
    );
  }

  static Future<void> setDisguise(DisguiseType disguise) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentDisguiseKey, disguise.id);

    // Change App Icon via native method channel
    if (Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod('setDisguise', {'disguiseId': disguise.id});
      } catch (e) {
        // Ignore errors - icon change may cause app restart
      }
    }
  }

  // Deprecated methods removed as we use IconService now

  static Future<bool> supportsIconChange() async {
    if (Platform.isAndroid) {
      return true;
    } else if (Platform.isIOS) {
      try {
        final result = await _methodChannel.invokeMethod<bool>(
          'supportsAlternateIcons',
        );
        return result ?? false;
      } catch (e) {
        return false;
      }
    }
    return false;
  }
}

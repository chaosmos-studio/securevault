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
    final disguiseId = prefs.getString(_currentDisguiseKey) ?? DisguiseType.calculator.id;
    return DisguiseType.values.firstWhere(
      (d) => d.id == disguiseId,
      orElse: () => DisguiseType.calculator,
    );
  }

  static Future<void> setDisguise(DisguiseType disguise) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentDisguiseKey, disguise.id);
    
    if (Platform.isAndroid) {
      await _setAndroidDisguise(disguise);
    } else if (Platform.isIOS) {
      await _setIOSDisguise(disguise);
    }
  }

  static Future<void> _setAndroidDisguise(DisguiseType disguise) async {
    try {
      await _methodChannel.invokeMethod('setDisguise', {
        'disguiseId': disguise.id,
      });
    } catch (e) {
      // Method channel not implemented yet - will be added with native code
    }
  }

  static Future<void> _setIOSDisguise(DisguiseType disguise) async {
    try {
      await _methodChannel.invokeMethod('setAlternateIcon', {
        'iconName': disguise.id,
      });
    } catch (e) {
      // Method channel not implemented yet
    }
  }

  static Future<bool> supportsIconChange() async {
    if (Platform.isAndroid) {
      return true;
    } else if (Platform.isIOS) {
      try {
        final result = await _methodChannel.invokeMethod<bool>('supportsAlternateIcons');
        return result ?? false;
      } catch (e) {
        return false;
      }
    }
    return false;
  }
}

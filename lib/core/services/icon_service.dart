import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

class IconService {
  // Map Display Name -> Internal Key (We'll handle platform differences in methods)
  static final Map<String, String> _icons = {
    'Default': 'Default',
    'Shield': 'Default', // Shield uses Default icon
    'Calculator': 'Calculator',
    'Weather': 'Weather',
    'Notes': 'Notes',
    'Clock': 'Clock',
  };

  static final Map<String, String> _iconAssets = {
    'Default': 'assets/icons/shield_icon.png',
    'Calculator': 'assets/icons/calculator_icon.png',
    'Weather': 'assets/icons/weather_icon.png',
    'Notes': 'assets/icons/notes_icon.png',
    'Clock': 'assets/icons/clock_icon.png',
  };

  /// Returns a map of Display Name -> Asset Path
  static Map<String, String> get availableIcons {
    final map = <String, String>{};
    _icons.forEach((key, value) {
      map[key] = _iconAssets[key]!;
    });
    return map;
  }

  /// Helper to get platform-specific icon name
  static String? _getPlatformIconName(String key) {
    if (key == 'Default') return null; // Default is usually null for the plugin

    if (Platform.isAndroid) {
      // Android uses the Activity Alias name declared in Manifest
      // Based on AndroidManifest.xml: .CalculatorAlias, .NotesAlias, etc.
      // The plugin might expect just "CalculatorAlias" or ".CalculatorAlias"
      // Looking at common usage, it often wants the full class name or relative.
      // Let's assume the aliases are named as Key + 'Alias'
      return '${key}Alias';
    } else if (Platform.isIOS) {
      // iOS uses the key in Info.plist (CFBundleAlternateIcons)
      // Our Info.plist has lowercase keys: calculator, notes, clock, weather
      return key.toLowerCase();
    }
    return key;
  }

  /// Changes the app icon.
  static Future<void> changeIcon(String iconDisplayName) async {
    try {
      final String? internalKey = _icons[iconDisplayName];
      if (internalKey == null) return;

      final String? platformName = _getPlatformIconName(internalKey);

      await FlutterDynamicIconPlus.setAlternateIconName(iconName: platformName);
      debugPrint("Icon changed to $iconDisplayName ($platformName)");
    } on PlatformException catch (e) {
      debugPrint("Failed to change icon: ${e.message}");
    } catch (e) {
      debugPrint("Error changing icon: $e");
    }
  }

  static Future<String> getCurrentIcon() async {
    try {
      final String? iconName = await FlutterDynamicIconPlus.alternateIconName;
      // If null, it's the default icon
      if (iconName == null) return 'Default';

      // We need to map back from platform specific name to Display Name
      // This is a bit tricky if we don't know the exact string returned.
      // But we can try to match against our expected platform names.

      for (var entry in _icons.entries) {
        if (entry.key == 'Default') continue;
        final platformName = _getPlatformIconName(entry.key);
        if (iconName == platformName) return entry.key;
        // iOS might return 'calculator' while we expect 'calculator' -> Match
        // Android might return 'com.example...CalculatorAlias' -> We might need to check contains
        if (Platform.isAndroid && iconName.endsWith(platformName!)) {
          return entry.key;
        }
      }
      return 'Default';
    } catch (e) {
      return 'Default';
    }
  }
}

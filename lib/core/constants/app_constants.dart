import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'SecureVault';
  static const String version = '1.1.0';

  static const int maxFailedAttempts = 5;
  static const int lockoutDurationMinutes = 5;
  static const int autoLockSeconds = 60;

  static const int pbkdf2Iterations = 100000;
  static const int saltLength = 32;
  static const int keyLength = 32;
}

enum DisguiseType {
  calculator('calculator', 'Calculator', Icons.calculate),
  notes('notes', 'Notes', Icons.note_alt),
  clock('clock', 'Clock', Icons.access_time),
  moodspace('moodspace', 'MoodSpace', Icons.emoji_emotions);

  final String id;
  final String displayName;
  final IconData icon;

  const DisguiseType(this.id, this.displayName, this.icon);
}

enum VaultItemType { photo, video, note }

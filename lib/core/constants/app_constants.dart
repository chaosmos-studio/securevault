import 'package:flutter/material.dart';

class AppConstants {
  static const String version = '1.1.0';
  static const String contactEmail = 'hello@chaosmos.studio';
  static const String privacyUrl = 'https://chaosmos.studio/apps/securevault/privacy/';
  static const String sourceUrl = 'https://github.com/chaosmos-studio/securevault';
  static const int autoLockSeconds = 60;
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

import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// The launcher icon a disguise uses, or SecureVault's own when [disguise] is null.
class DisguiseIcon extends StatelessWidget {
  const DisguiseIcon({super.key, required this.disguise, this.size = 56});

  final DisguiseType? disguise;
  final double size;

  static String assetFor(DisguiseType? d) => switch (d) {
        null => 'assets/icons/shield_icon.png',
        DisguiseType.calculator => 'assets/icons/calculator_icon.png',
        DisguiseType.notes => 'assets/icons/notes_icon.png',
        DisguiseType.clock => 'assets/icons/clock_icon.png',
        DisguiseType.moodspace => 'assets/icons/mood_icon.png',
      };

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetFor(disguise),
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: disguise?.displayName ?? 'SecureVault',
    );
  }
}

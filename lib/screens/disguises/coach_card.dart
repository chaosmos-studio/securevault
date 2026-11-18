import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../ui/vault_theme.dart';

/// Shows, on top of the disguise, the one move that opens the vault.
class CoachCard extends StatelessWidget {
  const CoachCard({super.key, required this.disguise, this.pin});

  final DisguiseType disguise;

  /// The PIN chosen a moment ago, or null after a restart.
  final String? pin;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final code = pin ?? 'your PIN';
    final (before, after) = switch (disguise) {
      DisguiseType.calculator => ('Type', 'then  ='),
      DisguiseType.notes => ('Search for', ''),
      DisguiseType.clock => ('Type', 'then Start'),
      DisguiseType.moodspace => ('Write', 'then Save'),
    };
    final base = TextStyle(
      fontFamily: kVaultFont,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: c.ground,
      height: 1.3,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * -12), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Material(
          color: c.ink,
          elevation: 6,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Icon(Icons.lock_open_rounded, color: c.accentSoft, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: base,
                          children: [
                            TextSpan(text: '$before '),
                            TextSpan(
                              text: code,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                letterSpacing: pin == null ? 0 : 2,
                                color: c.accentSoft,
                              ),
                            ),
                            if (after.isNotEmpty) TextSpan(text: ' $after'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This opens your vault',
                        style: base.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: c.ground.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

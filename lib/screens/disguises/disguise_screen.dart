import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import 'calculator_disguise.dart';
import 'clock_disguise.dart';
import 'coach_card.dart';
import 'moodspace_disguise.dart';
import 'notes_disguise.dart';

/// The everyday app the vault hides behind. Until the vault has been opened
/// once, a card on top shows how to open it.
class DisguiseScreen extends StatelessWidget {
  const DisguiseScreen({super.key, required this.disguise});

  final DisguiseType disguise;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final coach = state.coachPending;
    final app = switch (disguise) {
      DisguiseType.calculator => CalculatorDisguise(coach: coach),
      DisguiseType.notes => NotesDisguise(coach: coach),
      DisguiseType.clock => ClockDisguise(coach: coach),
      DisguiseType.moodspace => MoodSpaceDisguise(coach: coach),
    };
    if (!coach) return app;

    return Stack(
      children: [
        app,
        Positioned(
          left: 0,
          right: 0,
          top: disguise == DisguiseType.notes ? null : 0,
          bottom: disguise == DisguiseType.notes ? 0 : null,
          child: SafeArea(
            child: CoachCard(disguise: disguise, pin: state.practicePin),
          ),
        ),
      ],
    );
  }
}

/// Tries [code] as a vault password. The app switches to the vault on success.
/// Older versions allowed 4-character passwords, and kept spaces as typed.
Future<bool> tryVaultCode(BuildContext context, String code) async {
  final state = context.read<AppState>();
  if (code.length >= 4 && await state.unlock(code)) return true;
  final trimmed = code.trim();
  return trimmed != code && trimmed.length >= 4 && await state.unlock(trimmed);
}

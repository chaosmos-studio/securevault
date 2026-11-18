import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/vault_service.dart';
import '../../ui/disguise_icon.dart';
import '../../ui/pin_pad.dart';
import '../../ui/vault_theme.dart';

/// First run: what this is, which app it hides behind, and a PIN. Practising
/// the secret entry on the disguise itself is the last step (see the coach card).
class SetupFlow extends StatefulWidget {
  const SetupFlow({super.key});

  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

enum _Step { intro, disguise, pin, confirm }

class _SetupFlowState extends State<SetupFlow> {
  _Step _step = _Step.intro;
  DisguiseType _disguise = DisguiseType.calculator;
  String _pin = '';
  String? _error;
  int _errors = 0;
  bool _busy = false;

  void _go(_Step step) => setState(() {
        _step = step;
        _error = null;
      });

  bool _back() {
    switch (_step) {
      case _Step.intro:
        return true;
      case _Step.disguise:
        _go(_Step.intro);
      case _Step.pin:
        _go(_Step.disguise);
      case _Step.confirm:
        _go(_Step.pin);
    }
    return false;
  }

  Future<void> _confirm(String pin) async {
    if (pin != _pin) {
      setState(() {
        _error = "Those PINs don't match";
        _errors++;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      if (!await VaultService.isPasswordTaken(pin)) {
        await VaultService.createVault(pin, name: 'My vault', isMaster: true);
      }
      if (!mounted) return;
      await context.read<AppState>().finishSetup(_disguise, pin);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not create the vault. Try again.';
          _errors++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final Widget body = switch (_step) {
      _Step.intro => _Intro(onStart: () => _go(_Step.disguise)),
      _Step.disguise => _DisguisePicker(
          selected: _disguise,
          onSelect: (d) => setState(() => _disguise = d),
          onNext: () => _go(_Step.pin),
        ),
      _Step.pin => PinStep(
          key: const ValueKey('pin'),
          title: 'Choose a PIN',
          subtitle: '${_whereToType(_disguise)}. 6 to 12 digits.',
          onDone: (pin) {
            _pin = pin;
            _go(_Step.confirm);
          },
        ),
      _Step.confirm => PinStep(
          key: const ValueKey('confirm'),
          title: 'Type it again',
          autoSubmitLength: _pin.length,
          error: _error,
          errorCount: _errors,
          busy: _busy,
          onDone: _confirm,
        ),
    };

    return PopScope(
      canPop: _step == _Step.intro,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.ground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      if (_step != _Step.intro)
                        IconButton(
                          tooltip: 'Back',
                          onPressed: _busy ? null : _back,
                          icon: const Icon(Icons.arrow_back),
                          style: IconButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      const Spacer(),
                      _StepDots(step: _step.index, count: _Step.values.length),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(key: ValueKey(_step), child: body),
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

String _whereToType(DisguiseType d) => switch (d) {
      DisguiseType.calculator => 'You type it into the Calculator',
      DisguiseType.notes => 'You type it into Search in Notes',
      DisguiseType.clock => 'You type it into the Timer',
      DisguiseType.moodspace => 'You write it as a note in MoodSpace',
    };

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(left: 6),
            width: i == step ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= step ? c.ink : c.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _Intro extends StatefulWidget {
  const _Intro({required this.onStart});

  final VoidCallback onStart;

  @override
  State<_Intro> createState() => _IntroState();
}

class _IntroState extends State<_Intro> {
  static const _cycle = [null, ...DisguiseType.values];
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) setState(() => _shown = (_shown + 1) % _cycle.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final text = Theme.of(context).textTheme;
    final disguise = _cycle[_shown];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: child),
            ),
            child: Column(
              key: ValueKey(_shown),
              children: [
                DisguiseIcon(disguise: disguise, size: 132),
                const SizedBox(height: 14),
                Text(disguise?.displayName ?? 'SecureVault',
                    style: text.titleMedium!.copyWith(color: c.muted)),
              ],
            ),
          ),
        ),
        const Spacer(),
        Text('A private vault that looks like an everyday app', style: text.displaySmall),
        const SizedBox(height: 12),
        Text('Photos, videos and notes, locked behind a PIN only you know.',
            style: text.bodyLarge!.copyWith(color: c.muted)),
        const SizedBox(height: 32),
        FilledButton(onPressed: widget.onStart, child: const Text('Get started')),
      ],
    );
  }
}

class _DisguisePicker extends StatelessWidget {
  const _DisguisePicker({
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  final DisguiseType selected;
  final ValueChanged<DisguiseType> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pick a disguise', style: text.displaySmall),
        const SizedBox(height: 10),
        Text('SecureVault takes this name and icon on your phone.',
            style: text.bodyLarge!.copyWith(color: c.muted)),
        const SizedBox(height: 28),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final d in DisguiseType.values)
                DisguiseChoice(
                  disguise: d,
                  selected: d == selected,
                  onTap: () => onSelect(d),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onNext, child: Text('Use ${selected.displayName}')),
      ],
    );
  }
}

/// A disguise's icon and name, as a choice that can be selected.
class DisguiseChoice extends StatelessWidget {
  const DisguiseChoice({
    super.key,
    required this.disguise,
    required this.selected,
    required this.onTap,
  });

  final DisguiseType disguise;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accentSoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: selected ? c.accent : c.surface, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DisguiseIcon(disguise: disguise, size: 72),
                    const SizedBox(height: 12),
                    Text(disguise.displayName,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(Icons.check_circle, color: c.accent, size: 24),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

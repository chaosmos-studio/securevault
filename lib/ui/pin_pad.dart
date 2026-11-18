import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vault_theme.dart';

const int kMinPin = 6;
const int kMaxPin = 12;

/// A dot for each digit typed, with hollow dots up to the shortest PIN.
/// Shakes when [shakeKey] changes.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.shakeKey = 0});

  final int length;
  final int shakeKey;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final count = math.max(kMinPin, length);
    return TweenAnimationBuilder<double>(
      key: ValueKey(shakeKey),
      tween: Tween(begin: shakeKey == 0 ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 6) * (1 - t) * 14, 0),
        child: child,
      ),
      child: SizedBox(
        height: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 7),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < length ? c.ink : Colors.transparent,
                  border: Border.all(color: i < length ? c.ink : c.line, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Digits 0 to 9 and a backspace, sized to the space it is given.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    return LayoutBuilder(builder: (context, box) {
      final size = math.min(76.0, math.min(box.maxWidth / 3.6, box.maxHeight / 4.6));
      Widget key(String label) {
        if (label.isEmpty) return SizedBox(width: size, height: size);
        final isBack = label == '<';
        return Semantics(
          button: true,
          label: isBack ? 'Delete' : label,
          child: SizedBox(
            width: size,
            height: size,
            child: Material(
              color: isBack ? Colors.transparent : c.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  isBack ? onBackspace() : onDigit(label);
                },
                child: Center(
                  child: isBack
                      ? Icon(Icons.backspace_outlined, color: c.ink, size: 26)
                      : Text(label,
                          style: TextStyle(
                            fontFamily: kVaultFont,
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            color: c.ink,
                          )),
                ),
              ),
            ),
          ),
        );
      }

      Widget row(List<String> keys) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final k in keys) key(k)],
          );

      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          row(['1', '2', '3']),
          row(['4', '5', '6']),
          row(['7', '8', '9']),
          row(['', '0', '<']),
        ],
      );
    });
  }
}

/// A full-screen step that asks for a PIN: a title, the dots, a message and
/// the keypad. [onDone] runs when the PIN is long enough and Next is pressed,
/// or as soon as [autoSubmitLength] digits are typed.
class PinStep extends StatefulWidget {
  const PinStep({
    super.key,
    required this.title,
    this.subtitle,
    required this.onDone,
    this.autoSubmitLength,
    this.error,
    this.errorCount = 0,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final ValueChanged<String> onDone;
  final int? autoSubmitLength;
  final String? error;
  final int errorCount;
  final bool busy;

  @override
  State<PinStep> createState() => _PinStepState();
}

class _PinStepState extends State<PinStep> {
  String _pin = '';

  @override
  void didUpdateWidget(PinStep old) {
    super.didUpdateWidget(old);
    if (widget.errorCount != old.errorCount) _pin = '';
  }

  void _digit(String d) {
    if (widget.busy || _pin.length >= kMaxPin) return;
    setState(() => _pin += d);
    if (widget.autoSubmitLength == _pin.length) widget.onDone(_pin);
  }

  void _back() {
    if (_pin.isEmpty || widget.busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final text = Theme.of(context).textTheme;
    final ready = _pin.length >= kMinPin && widget.autoSubmitLength == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: text.displaySmall),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 10),
          Text(widget.subtitle!, style: text.bodyLarge!.copyWith(color: c.muted)),
        ],
        const Spacer(flex: 2),
        PinDots(length: _pin.length, shakeKey: widget.errorCount),
        const SizedBox(height: 16),
        SizedBox(
          height: 22,
          child: Text(
            widget.error ?? '',
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: c.danger),
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 9,
          child: PinPad(onDigit: _digit, onBackspace: _back),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: widget.autoSubmitLength != null
              ? null
              : FilledButton(
                  onPressed: ready && !widget.busy ? () => widget.onDone(_pin) : null,
                  child: widget.busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onAccent),
                        )
                      : const Text('Next'),
                ),
        ),
      ],
    );
  }
}

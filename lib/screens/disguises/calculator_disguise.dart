import 'package:flutter/material.dart';
import '../../core/logic/calculator_engine.dart';
import '../../core/widgets/disguise_menu.dart';
import 'disguise_screen.dart';
import 'pulse.dart';

class _CalcColors {
  const _CalcColors({
    required this.ground,
    required this.ink,
    required this.muted,
    required this.digit,
    required this.function,
    required this.operator,
    required this.onOperator,
    required this.equals,
    required this.onEquals,
  });

  final Color ground, ink, muted, digit, function, operator, onOperator, equals, onEquals;

  static const light = _CalcColors(
    ground: Color(0xFFF9FAFC),
    ink: Color(0xFF1A1C20),
    muted: Color(0xFF6B7079),
    digit: Color(0xFFECEFF4),
    function: Color(0xFFDDE2EA),
    operator: Color(0xFFD7E3FA),
    onOperator: Color(0xFF16345F),
    equals: Color(0xFF2F5BB0),
    onEquals: Color(0xFFFFFFFF),
  );

  static const dark = _CalcColors(
    ground: Color(0xFF111215),
    ink: Color(0xFFE7E8EC),
    muted: Color(0xFF969AA3),
    digit: Color(0xFF25272C),
    function: Color(0xFF353941),
    operator: Color(0xFF29395A),
    onOperator: Color(0xFFD7E3FA),
    equals: Color(0xFFA8C4FA),
    onEquals: Color(0xFF0E2A57),
  );
}

enum _Kind { digit, function, operator, equals }

/// A working calculator. Digits typed and then "=" open the vault when they
/// are a vault PIN.
class CalculatorDisguise extends StatefulWidget {
  const CalculatorDisguise({super.key, this.coach = false});

  final bool coach;

  @override
  State<CalculatorDisguise> createState() => _CalculatorDisguiseState();
}

class _CalculatorDisguiseState extends State<CalculatorDisguise> {
  final _engine = CalculatorEngine();

  /// Every digit typed since the last clear or "=", operators skipped.
  String _secret = '';

  Future<void> _press(String key) async {
    switch (key) {
      case 'AC':
        _secret = '';
        setState(_engine.clear);
      case '±':
        setState(_engine.toggleSign);
      case '%':
        if (await _tryOpen()) return;
        setState(_engine.percent);
      case '⌫':
        if (_secret.isNotEmpty) _secret = _secret.substring(0, _secret.length - 1);
        setState(_engine.backspace);
      case '=':
        if (await _tryOpen()) return;
        _secret = '';
        setState(_engine.equals);
      case CalculatorEngine.plus ||
            CalculatorEngine.minus ||
            CalculatorEngine.times ||
            CalculatorEngine.divide:
        setState(() => _engine.operator(key));
      default:
        if (key != '.') _secret += key;
        setState(() => _engine.digit(key));
    }
  }

  Future<bool> _tryOpen() async {
    final code = _secret;
    if (code.isEmpty) return false;
    final opened = await tryVaultCode(context, code);
    if (opened) _secret = '';
    return opened;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = dark ? _CalcColors.dark : _CalcColors.light;
    final display = _engine.display;
    final preview = _engine.preview;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: c.equals,
        fontFamily: 'Roboto',
      ),
      child: Scaffold(
        backgroundColor: c.ground,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4, top: 4),
                  child: DisguiseMenu(iconColor: c.muted),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          display,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: display == CalculatorEngine.divideByZero ? 40 : 72,
                            fontWeight: FontWeight.w300,
                            color: c.ink,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 40,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            preview,
                            style: TextStyle(fontSize: 32, color: c.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Column(
                    children: [
                      _row(c, const [('AC', _Kind.function), ('±', _Kind.function), ('%', _Kind.function), (CalculatorEngine.divide, _Kind.operator)]),
                      _row(c, const [('7', _Kind.digit), ('8', _Kind.digit), ('9', _Kind.digit), (CalculatorEngine.times, _Kind.operator)]),
                      _row(c, const [('4', _Kind.digit), ('5', _Kind.digit), ('6', _Kind.digit), (CalculatorEngine.minus, _Kind.operator)]),
                      _row(c, const [('1', _Kind.digit), ('2', _Kind.digit), ('3', _Kind.digit), (CalculatorEngine.plus, _Kind.operator)]),
                      _row(c, const [('0', _Kind.digit), ('.', _Kind.digit), ('⌫', _Kind.digit), ('=', _Kind.equals)]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(_CalcColors c, List<(String, _Kind)> keys) {
    return Expanded(
      child: Row(
        children: [
          for (final (label, kind) in keys)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: _key(c, label, kind),
              ),
            ),
        ],
      ),
    );
  }

  Widget _key(_CalcColors c, String label, _Kind kind) {
    final (bg, fg) = switch (kind) {
      _Kind.digit => (c.digit, c.ink),
      _Kind.function => (c.function, c.ink),
      _Kind.operator => (c.operator, c.onOperator),
      _Kind.equals => (c.equals, c.onEquals),
    };
    final Widget face = label == '⌫'
        ? Icon(Icons.backspace_outlined, color: fg, size: 26)
        : Text(
            label,
            style: TextStyle(
              fontSize: label == 'AC' ? 26 : 32,
              fontWeight: FontWeight.w400,
              color: fg,
            ),
          );
    final key = Material(
      color: bg,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _press(label),
        child: Center(child: face),
      ),
    );
    final semantic = Semantics(
      button: true,
      label: switch (label) { '⌫' => 'Backspace', '±' => 'Plus or minus', _ => label },
      child: key,
    );
    return label == '=' && widget.coach ? Pulse(child: semantic) : semantic;
  }
}

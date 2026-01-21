import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/widgets/disguise_menu.dart';

class CalculatorDisguise extends StatefulWidget {
  const CalculatorDisguise({super.key});

  @override
  State<CalculatorDisguise> createState() => _CalculatorDisguiseState();
}

class _CalculatorDisguiseState extends State<CalculatorDisguise> {
  String _display = '0';
  String _currentInput = '';
  String _operator = '';
  double _firstOperand = 0;
  bool _shouldResetDisplay = false;
  String _secretCode = '';

  void _onDigitPress(String digit) {
    setState(() {
      _secretCode += digit;

      if (_shouldResetDisplay) {
        _display = digit;
        _currentInput = digit;
        _shouldResetDisplay = false;
      } else if (_display == '0' && digit != '.') {
        _display = digit;
        _currentInput = digit;
      } else {
        _display += digit;
        _currentInput += digit;
      }
    });
  }

  void _onOperatorPress(String op) {
    setState(() {
      if (_currentInput.isNotEmpty) {
        _firstOperand = double.tryParse(_currentInput) ?? 0;
      }
      _operator = op;
      _shouldResetDisplay = true;
      _currentInput = '';
    });
  }

  void _onEqualsPress() async {
    if (_secretCode.isNotEmpty) {
      final appState = context.read<AppState>();
      final unlocked = await appState.unlock(_secretCode);
      if (unlocked && mounted) {
        Navigator.of(context).pushReplacementNamed('/vault');
        return;
      }
    }

    setState(() {
      if (_operator.isNotEmpty && _currentInput.isNotEmpty) {
        double secondOperand = double.tryParse(_currentInput) ?? 0;
        double result = 0;

        switch (_operator) {
          case '+':
            result = _firstOperand + secondOperand;
            break;
          case '-':
            result = _firstOperand - secondOperand;
            break;
          case '×':
            result = _firstOperand * secondOperand;
            break;
          case '÷':
            result = secondOperand != 0 ? _firstOperand / secondOperand : 0;
            break;
        }

        _display = _formatResult(result);
        _currentInput = _display;
        _operator = '';
        _shouldResetDisplay = true;
      }
      _secretCode = '';
    });
  }

  String _formatResult(double result) {
    if (result == result.toInt()) {
      return result.toInt().toString();
    }
    return result
        .toStringAsFixed(8)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  void _onBackspacePress() {
    setState(() {
      if (_secretCode.isNotEmpty) {
        _secretCode = _secretCode.substring(0, _secretCode.length - 1);
      }

      if (_display.isNotEmpty && _display != '0') {
        if (_display.length == 1) {
          _display = '0';
          _currentInput = '';
        } else {
          _display = _display.substring(0, _display.length - 1);
          _currentInput = _display;
        }
      }
    });
  }

  void _onClearPress() {
    setState(() {
      _display = '0';
      _currentInput = '';
      _operator = '';
      _firstOperand = 0;
      _shouldResetDisplay = false;
      _secretCode = '';
    });
  }

  void _onPercentPress() async {
    if (_secretCode.isNotEmpty) {
      final appState = context.read<AppState>();
      final unlocked = await appState.unlock(_secretCode);
      if (unlocked && mounted) {
        Navigator.of(context).pushReplacementNamed('/vault');
        return;
      }
    }

    setState(() {
      double value = double.tryParse(_currentInput) ?? 0;
      double result = value / 100;
      _display = _formatResult(result);
      _currentInput = _display;
      _secretCode = '';
    });
  }

  void _onSignChangePress() {
    setState(() {
      if (_currentInput.isNotEmpty && _currentInput != '0') {
        if (_currentInput.startsWith('-')) {
          _currentInput = _currentInput.substring(1);
        } else {
          _currentInput = '-$_currentInput';
        }
        _display = _currentInput;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? Colors.black
            : Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          DisguiseMenu(iconColor: isDark ? Colors.white70 : Colors.black87),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_operator.isNotEmpty)
                      Text(
                        '${_formatResult(_firstOperand)} $_operator',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 24,
                        ),
                      ),
                    Text(
                      _display,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: _display.length > 8
                            ? 56
                            : (_display.length > 6 ? 72 : 88),
                        fontWeight: FontWeight.w200,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _buildIOSRow(['C', '±', '%', '÷']),
                    _buildIOSRow(['7', '8', '9', '×']),
                    _buildIOSRow(['4', '5', '6', '-']),
                    _buildIOSRow(['1', '2', '3', '+']),
                    _buildIOSBottomRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSRow(List<String> buttons) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: buttons.map((btn) {
            final isOperator = ['÷', '×', '-', '+', '='].contains(btn);
            final isFunction = ['C', '±', '%'].contains(btn);

            final isDark = Theme.of(context).brightness == Brightness.dark;

            Color bgColor;
            Color textColor;

            if (isOperator) {
              bgColor = const Color(0xFFFF9F0A);
              textColor = Colors.white;
            } else if (isFunction) {
              bgColor = isDark
                  ? const Color(0xFFA5A5A5)
                  : const Color(0xFFD6D6D6);
              textColor = Colors.black;
            } else {
              bgColor = isDark
                  ? const Color(0xFF333333)
                  : const Color(0xFFE0E0E0);
              textColor = isDark ? Colors.white : Colors.black;
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Material(
                    color: bgColor,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _handleButtonPress(btn),
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Text(
                          btn,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIOSBottomRow() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // 0 button - wider
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Material(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF333333)
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(40),
                  child: InkWell(
                    onTap: () => _handleButtonPress('0'),
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 28),
                      child: Text(
                        '0',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Backspace button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Material(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE0E0E0),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _handleButtonPress('⌫'),
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Text(
                          '⌫',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w400,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // = button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Material(
                    color: const Color(0xFFFF9F0A),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _handleButtonPress('='),
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: Text(
                          '=',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleButtonPress(String btn) {
    switch (btn) {
      case 'C':
        _onClearPress();
        break;
      case '±':
        _onSignChangePress();
        break;
      case '%':
        _onPercentPress();
        break;
      case '⌫':
        _onBackspacePress();
        break;
      case '=':
        _onEqualsPress();
        break;
      case '+':
      case '-':
      case '×':
      case '÷':
        _onOperatorPress(btn);
        break;
      default:
        _onDigitPress(btn);
    }
  }
}

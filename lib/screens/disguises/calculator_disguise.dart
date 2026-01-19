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
    return result.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
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
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        actions: [
          DisguiseMenu(iconColor: isDark ? Colors.white : Colors.black),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_operator.isNotEmpty)
                      Text(
                        '${_formatResult(_firstOperand)} $_operator',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 24,
                        ),
                      ),
                    Text(
                      _display,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: _display.length > 10 ? 48 : 64,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 1,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    _buildAndroidRow(['C', '⌫', '%', '÷'], isDark),
                    _buildAndroidRow(['7', '8', '9', '×'], isDark),
                    _buildAndroidRow(['4', '5', '6', '-'], isDark),
                    _buildAndroidRow(['1', '2', '3', '+'], isDark),
                    _buildAndroidRow(['±', '0', '.', '='], isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidRow(List<String> buttons, bool isDark) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons.map((btn) {
          final isOperator = ['÷', '×', '-', '+'].contains(btn);
          final isEquals = btn == '=';
          final isFunction = ['C', '⌫', '%', '±'].contains(btn);

          Color bgColor;
          Color textColor;
          
          if (isEquals) {
            bgColor = const Color(0xFF4285F4);
            textColor = Colors.white;
          } else if (isOperator) {
            bgColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E8E8);
            textColor = const Color(0xFF4285F4);
          } else if (isFunction) {
            bgColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E8E8);
            textColor = isDark ? Colors.white : Colors.black87;
          } else {
            bgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5);
            textColor = isDark ? Colors.white : Colors.black87;
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () => _handleButtonPress(btn),
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: Text(
                      btn,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: isOperator || isEquals ? FontWeight.w500 : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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

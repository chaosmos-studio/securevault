import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(24),
                child: Text(
                  _display,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildRow(['C', '±', '%', '÷']),
                  _buildRow(['7', '8', '9', '×']),
                  _buildRow(['4', '5', '6', '-']),
                  _buildRow(['1', '2', '3', '+']),
                  _buildRow(['0', '.', '=']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> buttons) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons.map((btn) {
          final isOperator = ['÷', '×', '-', '+', '='].contains(btn);
          final isFunction = ['C', '±', '%'].contains(btn);
          final isZero = btn == '0';

          return Expanded(
            flex: isZero ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                onPressed: () => _handleButtonPress(btn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOperator
                      ? Colors.orange
                      : isFunction
                          ? Colors.grey[400]
                          : Colors.grey[850],
                  foregroundColor: isFunction ? Colors.black : Colors.white,
                  shape: isZero
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        )
                      : const CircleBorder(),
                ),
                child: Text(
                  btn,
                  style: const TextStyle(fontSize: 28),
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

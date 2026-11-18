import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/logic/calculator_engine.dart';

String run(List<String> keys) {
  final e = CalculatorEngine();
  for (final k in keys) {
    switch (k) {
      case '=':
        e.equals();
      case 'AC':
        e.clear();
      case '%':
        e.percent();
      case '±':
        e.toggleSign();
      case '<':
        e.backspace();
      case CalculatorEngine.plus ||
            CalculatorEngine.minus ||
            CalculatorEngine.times ||
            CalculatorEngine.divide:
        e.operator(k);
      default:
        e.digit(k);
    }
  }
  return e.display;
}

void main() {
  const plus = CalculatorEngine.plus;
  const minus = CalculatorEngine.minus;
  const times = CalculatorEngine.times;
  const divide = CalculatorEngine.divide;

  test('multiplies and divides before adding and subtracting', () {
    expect(run(['2', plus, '3', times, '4', '=']), '14');
    expect(run(['2', '0', minus, '6', divide, '3', '=']), '18');
  });

  test('shows decimals without trailing zeros', () {
    expect(run(['1', '0', divide, '4', '=']), '2.5');
    expect(run(['1', divide, '3', '=']), '0.333333333333');
    expect(run(['0', '.', '1', plus, '0', '.', '2', '=']), '0.3');
  });

  test('says so when dividing by zero', () {
    expect(run(['8', divide, '0', '=']), CalculatorEngine.divideByZero);
    expect(run(['8', divide, '0', '=', '5']), '5');
  });

  test('previews the result while typing', () {
    final e = CalculatorEngine()
      ..digit('1')
      ..digit('2')
      ..operator(times)
      ..digit('4');
    expect(e.display, '12${times}4');
    expect(e.preview, '48');
  });

  test('handles percent, sign, backspace and a fresh start after a result', () {
    expect(run(['5', '0', '%']), '0.5');
    expect(run(['7', '±']), '-7');
    expect(run(['7', '±', '±']), '7');
    expect(run(['1', '2', '3', '<']), '12');
    expect(run(['2', plus, '2', '=', '9']), '9');
    expect(run(['2', plus, '2', '=', times, '3', '=']), '12');
  });

  test('replaces an operator typed twice and ignores a second point', () {
    expect(run(['6', plus, times, '2', '=']), '12');
    expect(run(['1', '.', '.', '5', '=']), '1.5');
  });
}

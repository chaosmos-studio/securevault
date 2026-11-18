/// The arithmetic behind the Calculator disguise: an expression typed key by
/// key, multiplication and division before addition and subtraction.
class CalculatorEngine {
  static const plus = '+';
  static const minus = '−';
  static const times = '×';
  static const divide = '÷';
  static const operators = [plus, minus, times, divide];
  static const divideByZero = "Can't divide by 0";

  String _expression = '';
  bool _showingResult = false;
  String? _error;

  /// What the display shows: the expression, a result, or an error.
  String get display => _error ?? (_expression.isEmpty ? '0' : _expression);

  /// The result so far, shown under the expression, or empty when it would
  /// only repeat the display.
  String get preview {
    if (_error != null || _showingResult) return '';
    if (!operators.any(_expression.contains)) return '';
    final value = _evaluate(_trimmedExpression);
    return value == null ? '' : format(value);
  }

  String get _trimmedExpression {
    var e = _expression;
    while (e.isNotEmpty && (operators.contains(e[e.length - 1]) || e.endsWith('.'))) {
      e = e.substring(0, e.length - 1);
    }
    return e;
  }

  String get _lastNumber {
    final match = RegExp(r'-?[0-9.]*$').firstMatch(_expression);
    return match?.group(0) ?? '';
  }

  void digit(String d) {
    if (_error != null || _showingResult) {
      _expression = '';
      _error = null;
      _showingResult = false;
    }
    final last = _lastNumber;
    if (d == '.') {
      if (last.contains('.')) return;
      _expression += last.isEmpty || last == '-' ? '0.' : '.';
      return;
    }
    if (last == '0' || last == '-0') {
      _expression = _expression.substring(0, _expression.length - 1) + d;
      return;
    }
    if (last.replaceAll(RegExp(r'[-.]'), '').length >= 15) return;
    _expression += d;
  }

  void operator(String op) {
    _error = null;
    _showingResult = false;
    if (_expression.isEmpty || _expression == '-') {
      if (op == minus) _expression = '-';
      return;
    }
    final lastChar = _expression[_expression.length - 1];
    if (operators.contains(lastChar)) {
      _expression = _expression.substring(0, _expression.length - 1) + op;
    } else if (lastChar != '-') {
      _expression += op;
    }
  }

  void clear() {
    _expression = '';
    _error = null;
    _showingResult = false;
  }

  void backspace() {
    if (_error != null || _showingResult) {
      clear();
      return;
    }
    if (_expression.isNotEmpty) {
      _expression = _expression.substring(0, _expression.length - 1);
    }
  }

  void toggleSign() {
    if (_error != null) return;
    _showingResult = false;
    final last = _lastNumber;
    final start = _expression.length - last.length;
    if (last.startsWith('-')) {
      _expression = _expression.substring(0, start) + last.substring(1);
    } else {
      _expression = '${_expression.substring(0, start)}-$last';
    }
  }

  void percent() {
    if (_error != null) return;
    final last = _lastNumber;
    final value = double.tryParse(last);
    if (value == null) return;
    _showingResult = false;
    _expression =
        _expression.substring(0, _expression.length - last.length) + format(value / 100);
  }

  void equals() {
    if (_error != null || _expression.isEmpty) return;
    final value = _evaluate(_trimmedExpression);
    if (value == null) return;
    if (value.isInfinite || value.isNaN) {
      _error = divideByZero;
      _expression = '';
      return;
    }
    _expression = format(value);
    _showingResult = true;
  }

  static double? _evaluate(String expression) {
    if (expression.isEmpty || expression == '-') return null;
    final numbers = <double>[];
    final ops = <String>[];
    final pattern = RegExp('(-?[0-9.]+)|([${operators.join()}])');
    for (final m in pattern.allMatches(expression)) {
      if (m.group(1) != null) {
        final n = double.tryParse(m.group(1)!);
        if (n == null) return null;
        numbers.add(n);
      } else {
        ops.add(m.group(2)!);
      }
    }
    if (numbers.length != ops.length + 1) return null;

    // Multiplication and division first, then left to right.
    final sums = <double>[numbers.first];
    final sumOps = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final n = numbers[i + 1];
      switch (ops[i]) {
        case times:
          sums[sums.length - 1] *= n;
        case divide:
          sums[sums.length - 1] /= n;
        default:
          sums.add(n);
          sumOps.add(ops[i]);
      }
    }
    var total = sums.first;
    for (var i = 0; i < sumOps.length; i++) {
      total = sumOps[i] == plus ? total + sums[i + 1] : total - sums[i + 1];
    }
    return total;
  }

  static String format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    if (value.abs() >= 1e15 || value.abs() < 1e-9) {
      return value.toStringAsExponential(8).replaceAll(RegExp(r'\.?0+e'), 'e');
    }
    var text = value.toStringAsPrecision(12);
    if (text.contains('.') && !text.contains('e')) {
      text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return text;
  }
}

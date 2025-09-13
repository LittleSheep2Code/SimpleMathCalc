import 'dart:math';
import 'package:rational/rational.dart';
import 'models/calculation_step.dart';
import 'calculator.dart';
import 'parser.dart';

/// 帮助解析一元一次方程 ax+b=cx+d 的辅助类
class LinearEquationParts {
  final double a, b, c, d;
  LinearEquationParts(this.a, this.b, this.c, this.d);
}

class SolverService {
  /// 主入口方法，识别并分发任务
  CalculationResult solve(String input) {
    // 预处理输入字符串
    final cleanInput = input.replaceAll(' ', '').toLowerCase();

    // 对包含x的方程进行预处理，展开表达式
    String processedInput = cleanInput;
    if (processedInput.contains('x') && processedInput.contains('(')) {
      processedInput = _expandExpressions(processedInput);
    }

    // 1. 检查是否为二元一次方程组 (格式: ...;...)
    if (processedInput.contains(';') &&
        processedInput.contains('x') &&
        processedInput.contains('y')) {
      return _solveSystemOfLinearEquations(processedInput);
    }

    // 2. 检查是否为一元二次方程 (包含 x^2 或 x²)
    if (processedInput.contains('x^2') || processedInput.contains('x²')) {
      return _solveQuadraticEquation(processedInput.replaceAll('x²', 'x^2'));
    }

    // 3. 检查是否为一元一次方程 (包含 x 但不包含 y 或 x^2)
    if (processedInput.contains('x') && !processedInput.contains('y')) {
      return _solveLinearEquation(processedInput);
    }

    // 4. 如果都不是，则作为简单表达式计算
    try {
      return _solveSimpleExpression(input); // 使用原始输入以保留运算符
    } catch (e) {
      throw Exception('无法识别的格式。请检查您的方程或表达式。');
    }
  }

  /// ---- 求解器实现 ----

  /// 1. 求解简单表达式
  CalculationResult _solveSimpleExpression(String input) {
    final steps = <CalculationStep>[];
    steps.add(
      CalculationStep(
        stepNumber: 1,
        title: '表达式求值',
        explanation: '这是一个标准的数学表达式，我们将直接计算其结果。',
        formula: '\$\$$input\$\$',
      ),
    );

    // 检查是否为特殊三角函数值，可以返回精确结果
    final exactTrigResult = _getExactTrigResult(input);
    if (exactTrigResult != null) {
      return CalculationResult(
        steps: steps,
        finalAnswer: '\$\$$exactTrigResult\$\$',
      );
    }

    // 预处理输入，将三角函数的参数从度转换为弧度
    String processedInput = _convertTrigToRadians(input);

    try {
      // 使用自定义解析器解析表达式
      final parser = Parser(processedInput);
      final expr = parser.parse();

      // 对表达式进行求值
      final evaluatedExpr = expr.evaluate();

      // 获取数值结果 - 需要正确进行类型转换
      double result;
      if (evaluatedExpr is IntExpr) {
        result = evaluatedExpr.value.toDouble();
      } else if (evaluatedExpr is DoubleExpr) {
        result = evaluatedExpr.value;
      } else if (evaluatedExpr is FractionExpr) {
        result = evaluatedExpr.numerator / evaluatedExpr.denominator;
      } else {
        // 如果无法完全求值为数值，尝试简化并转换为字符串
        final simplified = evaluatedExpr.simplify();
        return CalculationResult(
          steps: steps,
          finalAnswer: '\$\$${simplified.toString()}\$\$',
        );
      }

      // 尝试将结果格式化为几倍根号的形式
      final formattedResult = _formatSqrtResult(result);

      return CalculationResult(
        steps: steps,
        finalAnswer: '\$\$$formattedResult\$\$',
      );
    } catch (e) {
      throw Exception('无法解析表达式: $input');
    }
  }

  /// 2. 求解一元一次方程
  CalculationResult _solveLinearEquation(String input) {
    final steps = <CalculationStep>[];
    steps.add(
      CalculationStep(
        stepNumber: 0,
        title: '原方程',
        explanation: '这是一元一次方程。',
        formula: '\$\$$input\$\$',
      ),
    );

    final parts = _parseLinearEquation(input);
    final a = parts.a, b = parts.b, c = parts.c, d = parts.d;

    final newA = _rationalFromDouble(a) - _rationalFromDouble(c);
    final newD = _rationalFromDouble(d) - _rationalFromDouble(b);

    steps.add(
      CalculationStep(
        stepNumber: 1,
        title: '移项',
        explanation: '将所有含 x 的项移到等式左边，常数项移到右边。',
        formula:
            '\$\$${a}x ${c >= 0 ? '-' : '+'} ${c.abs()}x = $d ${b >= 0 ? '-' : '+'} ${b.abs()}\$\$',
      ),
    );

    steps.add(
      CalculationStep(
        stepNumber: 2,
        title: '合并同类项',
        explanation: '合并等式两边的项。',
        formula:
            '\$\$${newA.toDouble().toStringAsFixed(4)}x = ${newD.toDouble().toStringAsFixed(4)}\$\$',
      ),
    );

    if (newA == Rational.zero) {
      return CalculationResult(
        steps: steps,
        finalAnswer: newD == Rational.zero ? '有无穷多解' : '无解',
      );
    }

    final x = newD / newA;
    steps.add(
      CalculationStep(
        stepNumber: 3,
        title: '求解 x',
        explanation: '两边同时除以 x 的系数 ($newA)。',
        formula: '\$\$x = \\frac{$newD}{$newA}\$\$',
      ),
    );

    return CalculationResult(steps: steps, finalAnswer: '\$\$x = $x\$\$');
  }

  /// 3. 求解一元二次方程 (升级版)
  CalculationResult _solveQuadraticEquation(String input) {
    final steps = <CalculationStep>[];

    final eqParts = input.split('=');
    if (eqParts.length != 2) throw Exception("方程格式错误，应包含一个 '='。");

    // Keep original equation for display
    final originalEquation = _formatOriginalEquation(input);

    // Parse coefficients symbolically
    final leftCoeffsSymbolic = _parsePolynomialSymbolic(eqParts[0]);
    final rightCoeffsSymbolic = _parsePolynomialSymbolic(eqParts[1]);

    final aSymbolic = _subtractCoefficients(
      leftCoeffsSymbolic[2] ?? '0',
      rightCoeffsSymbolic[2] ?? '0',
    );
    final bSymbolic = _subtractCoefficients(
      leftCoeffsSymbolic[1] ?? '0',
      rightCoeffsSymbolic[1] ?? '0',
    );
    final cSymbolic = _subtractCoefficients(
      leftCoeffsSymbolic[0] ?? '0',
      rightCoeffsSymbolic[0] ?? '0',
    );

    // Also get numeric values for calculations
    final leftCoeffs = _parsePolynomial(eqParts[0]);
    final rightCoeffs = _parsePolynomial(eqParts[1]);
    final a = (leftCoeffs[2] ?? 0) - (rightCoeffs[2] ?? 0);
    final b = (leftCoeffs[1] ?? 0) - (rightCoeffs[1] ?? 0);
    final c = (leftCoeffs[0] ?? 0) - (rightCoeffs[0] ?? 0);

    if (a == 0) {
      return _solveLinearEquation('${b}x+$c=0');
    }

    steps.add(
      CalculationStep(
        stepNumber: 1,
        title: '整理方程',
        explanation: r'将方程整理成标准形式 $ax^2+bx+c=0$。',
        formula: originalEquation,
      ),
    );

    if (a == a.round() && b == b.round() && c == c.round()) {
      final factors = _tryFactorization(a.toInt(), b.toInt(), c.toInt());
      if (factors != null) {
        steps.add(
          CalculationStep(
            stepNumber: 2,
            title: '因式分解法 (十字相乘)',
            explanation: '我们发现可以将方程分解为两个一次因式的乘积。',
            formula: factors.formula,
          ),
        );
        steps.add(
          CalculationStep(
            stepNumber: 3,
            title: '求解',
            explanation: '分别令每个因式等于 0，解出 x。',
            formula: factors.solution,
          ),
        );
        steps.add(
          CalculationStep(
            stepNumber: 4,
            title: '化简结果',
            explanation: '将分数化简到最简形式，并将负号写在分数外面。',
            formula: factors.solution,
          ),
        );
        return CalculationResult(steps: steps, finalAnswer: factors.solution);
      }
    }

    steps.add(
      CalculationStep(
        stepNumber: 2,
        title: '选择解法',
        explanation: '无法进行因式分解，我们选择使用求根公式法。',
        formula: '\$\$\\Delta = b^2 - 4ac\$\$',
      ),
    );

    // Calculate delta symbolically
    final deltaSymbolic = _calculateDeltaSymbolic(
      aSymbolic,
      bSymbolic,
      cSymbolic,
    );
    final delta =
        _rationalFromDouble(b).pow(2) -
        Rational.fromInt(4) * _rationalFromDouble(a) * _rationalFromDouble(c);

    steps.add(
      CalculationStep(
        stepNumber: 3,
        title: '计算判别式 (Delta)',
        explanation: '\$\$\\Delta = b^2 - 4ac = $deltaSymbolic\$\$',
        formula:
            '\$\$\\Delta = $deltaSymbolic = ${delta.toDouble().toStringAsFixed(4)}\$\$',
      ),
    );

    final deltaDouble = delta.toDouble();
    if (deltaDouble > 0) {
      // Pass delta directly to maintain precision
      final x1Expr = _formatQuadraticRoot(-b, delta, 2 * a, true);
      final x2Expr = _formatQuadraticRoot(-b, delta, 2 * a, false);

      steps.add(
        CalculationStep(
          stepNumber: 4,
          title: '应用求根公式',
          explanation:
              r'因为 $\Delta > 0$，方程有两个不相等的实数根。公式: $x = \frac{-b \pm \sqrt{\Delta}}{2a}$。',
          formula: '\$\$x_1 = $x1Expr, \\quad x_2 = $x2Expr\$\$',
        ),
      );
      return CalculationResult(
        steps: steps,
        finalAnswer: '\$\$x_1 = $x1Expr, \\quad x_2 = $x2Expr\$\$',
      );
    } else if (deltaDouble == 0) {
      final x = -b / (2 * a);
      steps.add(
        CalculationStep(
          stepNumber: 4,
          title: '应用求根公式',
          explanation: r'因为 $\Delta = 0$，方程有两个相等的实数根。',
          formula: '\$\$x_1 = x_2 = ${x.toStringAsFixed(4)}\$\$',
        ),
      );
      return CalculationResult(
        steps: steps,
        finalAnswer: '\$\$x_1 = x_2 = ${x.toStringAsFixed(4)}\$\$',
      );
    } else {
      steps.add(
        CalculationStep(
          stepNumber: 4,
          title: '判断解',
          explanation: r'因为 $\Delta < 0$，该方程在实数范围内无解，但有虚数解。',
          formula: '无实数解，有虚数解',
        ),
      );

      // For complex roots, we need to handle -delta
      final negDelta = -delta;
      final sqrtNegDeltaStr = _formatSqrtFromRational(negDelta);
      final realPart = -b / (2 * a);
      final imagPartExpr = _formatImaginaryPart(sqrtNegDeltaStr, 2 * a);

      steps.add(
        CalculationStep(
          stepNumber: 5,
          title: '计算虚数根',
          explanation: '使用求根公式计算虚数根。',
          formula: r'$$x = \frac{-b \pm \sqrt{-\Delta} i}{2a}$$',
        ),
      );

      return CalculationResult(
        steps: steps,
        finalAnswer:
            '\$\$x_1 = ${realPart.toStringAsFixed(4)} + $imagPartExpr, \\quad x_2 = ${realPart.toStringAsFixed(4)} - $imagPartExpr\$\$',
      );
    }
  }

  /// 4. 求解二元一次方程组
  CalculationResult _solveSystemOfLinearEquations(String input) {
    final steps = <CalculationStep>[];
    final equations = input.split(';');
    if (equations.length != 2) throw Exception("格式错误, 请用 ';' 分隔两个方程。");

    final p1 = _parseTwoVariableLinear(equations[0]);
    final p2 = _parseTwoVariableLinear(equations[1]);

    double a1 = p1[0], b1 = p1[1], c1 = p1[2];
    double a2 = p2[0], b2 = p2[1], c2 = p2[2];

    steps.add(
      CalculationStep(
        stepNumber: 0,
        title: '原始方程组',
        explanation: '这是一个二元一次方程组，我们将使用加减消元法求解。',
        formula:
            '''
\$\$
\\begin{cases}
${a1}x ${b1 >= 0 ? '+' : ''} ${b1}y = $c1 & (1) \\\\
${a2}x ${b2 >= 0 ? '+' : ''} ${b2}y = $c2 & (2)
\\end{cases}
\$\$
''',
      ),
    );

    final det =
        _rationalFromDouble(a1) * _rationalFromDouble(b2) -
        _rationalFromDouble(a2) * _rationalFromDouble(b1);
    if (det == Rational.zero) {
      final infiniteCheck =
          _rationalFromDouble(a1) * _rationalFromDouble(c2) -
          _rationalFromDouble(a2) * _rationalFromDouble(c1);
      return CalculationResult(
        steps: steps,
        finalAnswer: infiniteCheck == Rational.zero ? '有无穷多解' : '无解',
      );
    }

    final newA1 = _rationalFromDouble(a1) * _rationalFromDouble(b2);
    final newC1 = _rationalFromDouble(c1) * _rationalFromDouble(b2);
    final newA2 = _rationalFromDouble(a2) * _rationalFromDouble(b1);
    final newC2 = _rationalFromDouble(c2) * _rationalFromDouble(b1);

    steps.add(
      CalculationStep(
        stepNumber: 1,
        title: '消元',
        explanation: '为了消去变量 y，将方程(1)两边乘以 $b2，方程(2)两边乘以 $b1。',
        formula:
            '''
\$\$
\\begin{cases}
${newA1.toDouble().toStringAsFixed(2)}x ${b1 * b2 >= 0 ? '+' : ''} ${(b1 * b2).toStringAsFixed(2)}y = ${newC1.toDouble().toStringAsFixed(2)} & (3) \\\\
${newA2.toDouble().toStringAsFixed(2)}x ${b1 * b2 >= 0 ? '+' : ''} ${(b1 * b2).toStringAsFixed(2)}y = ${newC2.toDouble().toStringAsFixed(2)} & (4)
\\end{cases}
\$\$
''',
      ),
    );

    final xCoeff = newA1 - newA2;
    final constCoeff = newC1 - newC2;

    steps.add(
      CalculationStep(
        stepNumber: 2,
        title: '相减',
        explanation: '将方程(3)减去方程(4)，得到一个只含 x 的方程。',
        formula:
            '\$\$(${newA1.toDouble().toStringAsFixed(2)} - ${newA2.toDouble().toStringAsFixed(2)})x = ${newC1.toDouble().toStringAsFixed(2)} - ${newC2.toDouble().toStringAsFixed(2)} \\Rightarrow ${xCoeff.toDouble().toStringAsFixed(2)}x = ${constCoeff.toDouble().toStringAsFixed(2)}\$\$',
      ),
    );

    final x = constCoeff / xCoeff;
    steps.add(
      CalculationStep(
        stepNumber: 3,
        title: '解出 x',
        explanation: '求解上述方程得到 x 的值。',
        formula: '\$\$x = $x\$\$',
      ),
    );

    if (b1.abs() < 1e-9) {
      final yCoeff = b2;
      final yConst = c2 - a2 * x.toDouble();
      final y = yConst / yCoeff;
      steps.add(
        CalculationStep(
          stepNumber: 4,
          title: '回代求解 y',
          explanation: '将 x = ${x.toDouble().toStringAsFixed(4)} 代入原方程(2)中。',
          formula:
              '''
\$\$
\\begin{aligned}
$a2(${x.toDouble().toStringAsFixed(4)}) + ${b2}y &= $c2 \\\\
${a2 * x.toDouble()} + ${b2}y &= $c2 \\\\
${b2}y &= $c2 - ${a2 * x.toDouble()} \\\\
${b2}y &= ${c2 - a2 * x.toDouble()}
\\end{aligned}
\$\$
''',
        ),
      );
      steps.add(
        CalculationStep(
          stepNumber: 5,
          title: '解出 y',
          explanation: '求解得到 y 的值。',
          formula: '\$\$y = ${y.toStringAsFixed(4)}\$\$',
        ),
      );
      return CalculationResult(
        steps: steps,
        finalAnswer:
            '\$\$x = ${x.toDouble().toStringAsFixed(4)}, \\quad y = ${y.toStringAsFixed(4)}\$\$',
      );
    } else {
      final yCoeff = b1;
      final yConst = c1 - a1 * x.toDouble();
      final y = yConst / yCoeff;
      steps.add(
        CalculationStep(
          stepNumber: 4,
          title: '回代求解 y',
          explanation: '将 x = ${x.toDouble().toStringAsFixed(4)} 代入原方程(1)中。',
          formula:
              '''
\$\$
\\begin{aligned}
$a1(${x.toDouble().toStringAsFixed(4)}) + ${b1}y &= $c1 \\\\
${a1 * x.toDouble()} + ${b1}y &= $c1 \\\\
${b1}y &= $c1 - ${a1 * x.toDouble()} \\\\
${b1}y &= ${c1 - a1 * x.toDouble()}
\\end{aligned}
\$\$
''',
        ),
      );
      steps.add(
        CalculationStep(
          stepNumber: 5,
          title: '解出 y',
          explanation: '求解得到 y 的值。',
          formula: '\$\$y = ${y.toStringAsFixed(4)}\$\$',
        ),
      );
      return CalculationResult(
        steps: steps,
        finalAnswer:
            '\$\$x = ${x.toDouble().toStringAsFixed(4)}, \\quad y = ${y.toStringAsFixed(4)}\$\$',
      );
    }
  }

  /// ---- 辅助函数 ----

  /// 获取精确三角函数结果
  String? _getExactTrigResult(String input) {
    final cleanInput = input.replaceAll(' ', '').toLowerCase();

    // 匹配 sin(角度) 模式
    final sinMatch = RegExp(r'^sin\((\d+(?:\+\d+)*)\)$').firstMatch(cleanInput);
    if (sinMatch != null) {
      final angleExpr = sinMatch.group(1)!;
      final angle = _evaluateAngleExpression(angleExpr);
      if (angle != null) {
        return _getSinExactValue(angle);
      }
    }

    // 匹配 cos(角度) 模式
    final cosMatch = RegExp(r'^cos\((\d+(?:\+\d+)*)\)$').firstMatch(cleanInput);
    if (cosMatch != null) {
      final angleExpr = cosMatch.group(1)!;
      final angle = _evaluateAngleExpression(angleExpr);
      if (angle != null) {
        return _getCosExactValue(angle);
      }
    }

    // 匹配 tan(角度) 模式
    final tanMatch = RegExp(r'^tan\((\d+(?:\+\d+)*)\)$').firstMatch(cleanInput);
    if (tanMatch != null) {
      final angleExpr = tanMatch.group(1)!;
      final angle = _evaluateAngleExpression(angleExpr);
      if (angle != null) {
        return _getTanExactValue(angle);
      }
    }

    return null;
  }

  /// 计算角度表达式（如 30+45 = 75）
  int? _evaluateAngleExpression(String expr) {
    final parts = expr.split('+');
    int sum = 0;
    for (final part in parts) {
      final num = int.tryParse(part.trim());
      if (num == null) return null;
      sum += num;
    }
    return sum;
  }

  /// 获取 sin 的精确值
  String? _getSinExactValue(int angle) {
    // 标准化角度到 0-360 度
    final normalizedAngle = angle % 360;

    switch (normalizedAngle) {
      case 0:
      case 360:
        return '0';
      case 30:
        return '\\frac{1}{2}';
      case 45:
        return '\\frac{\\sqrt{2}}{2}';
      case 60:
        return '\\frac{\\sqrt{3}}{2}';
      case 75:
        return '1 + \\frac{\\sqrt{2}}{2}';
      case 90:
        return '1';
      case 120:
        return '\\frac{\\sqrt{3}}{2}';
      case 135:
        return '\\frac{\\sqrt{2}}{2}';
      case 150:
        return '\\frac{1}{2}';
      case 180:
        return '0';
      case 210:
        return '-\\frac{1}{2}';
      case 225:
        return '-\\frac{\\sqrt{2}}{2}';
      case 240:
        return '-\\frac{\\sqrt{3}}{2}';
      case 270:
        return '-1';
      case 300:
        return '-\\frac{\\sqrt{3}}{2}';
      case 315:
        return '-\\frac{\\sqrt{2}}{2}';
      case 330:
        return '-\\frac{1}{2}';
      default:
        return null;
    }
  }

  /// 获取 cos 的精确值
  String? _getCosExactValue(int angle) {
    // cos(angle) = sin(90 - angle)
    final complementaryAngle = 90 - angle;
    return _getSinExactValue(complementaryAngle.abs());
  }

  /// 获取 tan 的精确值
  String? _getTanExactValue(int angle) {
    // tan(angle) = sin(angle) / cos(angle)
    final sinValue = _getSinExactValue(angle);
    final cosValue = _getCosExactValue(angle);

    if (sinValue != null && cosValue != null) {
      if (cosValue == '0') return null; // 未定义
      return '\\frac{$sinValue}{$cosValue}';
    }

    return null;
  }

  /// 将三角函数的参数从度转换为弧度
  String _convertTrigToRadians(String input) {
    String result = input;

    // 正则表达式匹配三角函数调用，如 sin(30), cos(45), tan(60)
    final trigPattern = RegExp(
      r'(sin|cos|tan|asin|acos|atan)\s*\(\s*([^)]+)\s*\)',
      caseSensitive: false,
    );

    result = result.replaceAllMapped(trigPattern, (match) {
      final func = match.group(1)!;
      final arg = match.group(2)!;

      // 如果参数已经是弧度相关的表达式（包含 pi 或 π），则不转换
      if (arg.contains('pi') || arg.contains('π') || arg.contains('rad')) {
        return '$func($arg)';
      }

      // 将度数转换为弧度：度 * π / 180
      return '$func(($arg)*($pi/180))';
    });

    return result;
  }

  /// 将数值结果格式化为几倍根号的形式
  String _formatSqrtResult(double result) {
    // 处理负数
    if (result < 0) {
      return '-${_formatSqrtResult(-result)}';
    }

    // 处理零
    if (result == 0) return '0';

    // 检查是否接近整数
    final rounded = result.round();
    if ((result - rounded).abs() < 1e-10) {
      return rounded.toString();
    }

    // 计算 result 的平方，看它是否接近整数
    final squared = result * result;
    final squaredRounded = squared.round();

    // 如果 squared 接近整数，说明 result 是某个数的平方根
    if ((squared - squaredRounded).abs() < 1e-6) {
      // 寻找最大的完全平方数因子
      int maxSquareFactor = 1;
      for (int i = 2; i * i <= squaredRounded; i++) {
        if (squaredRounded % (i * i) == 0) {
          maxSquareFactor = i * i;
        }
      }

      final coefficient = sqrt(maxSquareFactor).round();
      final remaining = squaredRounded ~/ maxSquareFactor;

      if (remaining == 1) {
        // 完全平方数，直接返回系数
        return coefficient.toString();
      } else if (coefficient == 1) {
        return '\\sqrt{$remaining}';
      } else {
        return '$coefficient\\sqrt{$remaining}';
      }
    }

    // 如果不是平方根的结果，返回原始数值（保留几位小数）
    return result
        .toStringAsFixed(6)
        .replaceAll(RegExp(r'\.0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _expandExpressions(String input) {
    String result = input;
    int maxIterations = 10; // Prevent infinite loops
    int iterationCount = 0;

    while (iterationCount < maxIterations) {
      String oldResult = result;

      final powerMatch = RegExp(
        r'(-?\d*\.?\d*)?\(([^)]+)\)\^2',
      ).firstMatch(result);
      if (powerMatch != null) {
        final kStr = powerMatch.group(1);
        double k = 1.0;
        if (kStr != null && kStr.isNotEmpty) {
          k = kStr == '-' ? -1.0 : double.parse(kStr);
        }

        final factor = powerMatch.group(2)!;
        final coeffs = _parsePolynomial(factor);
        final a = coeffs[1] ?? 0;
        final b = coeffs[0] ?? 0;

        final newA = k * a * a;
        final newB = k * 2 * a * b;
        final newC = k * b * b;

        final expanded =
            '${newA}x^2${newB >= 0 ? '+' : ''}${newB}x${newC >= 0 ? '+' : ''}$newC';
        result = result.replaceFirst(powerMatch.group(0)!, '($expanded)');
        iterationCount++;
        continue;
      }

      final factorMulMatch = RegExp(
        r'\(([^)]+)\)\(([^)]+)\)',
      ).firstMatch(result);
      if (factorMulMatch != null) {
        final factor1 = factorMulMatch.group(1)!;
        final factor2 = factorMulMatch.group(2)!;
        print('Expanding: ($factor1) * ($factor2)');

        final coeffs1 = _parsePolynomial(factor1);
        final coeffs2 = _parsePolynomial(factor2);
        print('Coeffs1: $coeffs1, Coeffs2: $coeffs2');

        final a = coeffs1[1] ?? 0;
        final b = coeffs1[0] ?? 0;
        final c = coeffs2[1] ?? 0;
        final d = coeffs2[0] ?? 0;
        print('a=$a, b=$b, c=$c, d=$d');

        final newA = a * c;
        final newB = a * d + b * c;
        final newC = b * d;
        print('newA=$newA, newB=$newB, newC=$newC');

        final expanded =
            '${newA}x^2${newB >= 0 ? '+' : ''}${newB}x${newC >= 0 ? '+' : ''}$newC';
        print('Expanded result: $expanded');

        result = result.replaceFirst(factorMulMatch.group(0)!, expanded);
        iterationCount++;
        continue;
      }

      // Handle expressions like x(expr) or (expr)x or coeff(expr)
      final termFactorMatch = RegExp(
        r'([+-]?(?:\d*\.?\d*)?x?)\(([^)]+)\)',
      ).firstMatch(result);
      if (termFactorMatch != null) {
        final termStr = termFactorMatch.group(1)!;
        final factorStr = termFactorMatch.group(2)!;

        // Skip if the term is just a sign or empty
        if (termStr == '+' || termStr == '-' || termStr.isEmpty) {
          break;
        }

        // Parse the term (coefficient and x power)
        final termCoeffs = _parsePolynomial(termStr);
        final factorCoeffs = _parsePolynomial(factorStr);

        final termA = termCoeffs[1] ?? 0; // x coefficient
        final termB = termCoeffs[0] ?? 0; // constant term

        final factorA = factorCoeffs[1] ?? 0; // x coefficient
        final factorB = factorCoeffs[0] ?? 0; // constant term

        // Multiply: (termA*x + termB) * (factorA*x + factorB)
        final newA = termA * factorA;
        final newB = termA * factorB + termB * factorA;
        final newC = termB * factorB;

        final expanded =
            '${newA == 1
                ? ''
                : newA == -1
                ? '-'
                : newA}x^2${newB >= 0 ? '+' : ''}${newB}x${newC >= 0 ? '+' : ''}$newC';
        result = result.replaceFirst(termFactorMatch.group(0)!, '($expanded)');
        iterationCount++;
        continue;
      }

      if (result == oldResult) break;
      iterationCount++;
    }

    if (iterationCount >= maxIterations) {
      throw Exception('表达式展开过于复杂，请简化输入。');
    }

    // 检查是否为方程（包含等号），如果是的话，将右边的常数项移到左边
    if (result.contains('=')) {
      final parts = result.split('=');
      if (parts.length == 2) {
        final leftSide = parts[0];
        final rightSide = parts[1];

        // 解析左边的多项式
        final leftCoeffs = _parsePolynomial(leftSide);
        final rightCoeffs = _parsePolynomial(rightSide);

        // 计算标准形式 ax^2 + bx + c = 0 的系数
        // A = B 转换为 A - B = 0，所以右边的系数要取相反数
        final a = (leftCoeffs[2] ?? 0) - (rightCoeffs[2] ?? 0);
        final b = (leftCoeffs[1] ?? 0) - (rightCoeffs[1] ?? 0);
        final c = (leftCoeffs[0] ?? 0) - (rightCoeffs[0] ?? 0);

        // 构建标准形式的方程
        String standardForm = '';
        if (a != 0) {
          standardForm +=
              '${a == 1
                  ? ''
                  : a == -1
                  ? '-'
                  : a}x^2';
        }
        if (b != 0) {
          standardForm += b > 0 ? '+${b}x' : '${b}x';
        }
        if (c != 0) {
          standardForm += c > 0 ? '+$c' : '$c';
        }

        // 移除开头的加号
        if (standardForm.startsWith('+')) {
          standardForm = standardForm.substring(1);
        }

        // 如果所有系数都为0，则方程恒成立
        if (standardForm.isEmpty) {
          standardForm = '0';
        }

        result = '$standardForm=0';
      }
    }

    return result;
  }

  LinearEquationParts _parseLinearEquation(String input) {
    final parts = input.split('=');
    if (parts.length != 2) throw Exception("方程格式错误，应包含一个'='。");

    final leftCoeffs = _parsePolynomial(parts[0]);
    final rightCoeffs = _parsePolynomial(parts[1]);

    return LinearEquationParts(
      (leftCoeffs[1] ?? 0.0),
      (leftCoeffs[0] ?? 0.0),
      (rightCoeffs[1] ?? 0.0),
      (rightCoeffs[0] ?? 0.0),
    );
  }

  Map<int, double> _parsePolynomial(String side) {
    final coeffs = <int, double>{};

    // 如果输入包含括号，去掉括号
    var cleanSide = side;
    if (cleanSide.startsWith('(') && cleanSide.endsWith(')')) {
      cleanSide = cleanSide.substring(1, cleanSide.length - 1);
    }

    // 扩展模式以支持 sqrt 函数
    final pattern = RegExp(
      r'([+-]?(?:\d*\.?\d*|sqrt\(\d+\)))x(?:\^(\d+))?|([+-]?(?:\d*\.?\d*|sqrt\(\d+\)))',
    );
    var s = cleanSide.startsWith('+') || cleanSide.startsWith('-')
        ? cleanSide
        : '+$cleanSide';

    for (final match in pattern.allMatches(s)) {
      if (match.group(0)!.isEmpty) continue; // Skip empty matches

      if (match.group(3) != null) {
        // 常数项
        final constStr = match.group(3)!;
        final constValue = _parseCoefficientWithSqrt(constStr);
        coeffs[0] = (coeffs[0] ?? 0) + constValue;
      } else {
        // x 的幂次项
        int power = match.group(2) != null ? int.parse(match.group(2)!) : 1;
        String coeffStr = match.group(1) ?? '+';
        final coeff = _parseCoefficientWithSqrt(coeffStr);
        coeffs[power] = (coeffs[power] ?? 0) + coeff;
      }
    }
    return coeffs;
  }

  /// 解析包含 sqrt 函数的系数
  double _parseCoefficientWithSqrt(String coeffStr) {
    if (coeffStr.isEmpty || coeffStr == '+') return 1.0;
    if (coeffStr == '-') return -1.0;

    // 检查是否包含 sqrt 函数
    final sqrtMatch = RegExp(r'sqrt\((\d+)\)').firstMatch(coeffStr);
    if (sqrtMatch != null) {
      final innerValue = int.parse(sqrtMatch.group(1)!);

      // 对于完全平方数，直接返回整数结果
      final sqrtValue = sqrt(innerValue.toDouble());
      final rounded = sqrtValue.round();
      if ((sqrtValue - rounded).abs() < 1e-10) {
        // 检查是否有系数
        final coeffPart = coeffStr.replaceFirst(sqrtMatch.group(0)!, '');
        if (coeffPart.isEmpty) return rounded.toDouble();
        if (coeffPart == '-') return -rounded.toDouble();

        final coeff = double.parse(coeffPart);
        return coeff * rounded;
      }

      // 对于非完全平方数，计算数值但保持高精度
      final nonPerfectSqrtValue = sqrt(innerValue.toDouble());

      // 检查是否有系数
      final coeffPart = coeffStr.replaceFirst(sqrtMatch.group(0)!, '');
      if (coeffPart.isEmpty) return nonPerfectSqrtValue;
      if (coeffPart == '-') return -nonPerfectSqrtValue;

      final coeff = double.parse(coeffPart);
      return coeff * nonPerfectSqrtValue;
    }

    // 普通数值
    return double.parse(coeffStr);
  }

  List<double> _parseTwoVariableLinear(String equation) {
    final parts = equation.split('=');
    if (parts.length != 2) throw Exception("方程 $equation 格式错误");
    final c = double.tryParse(parts[1]) ?? 0.0;

    double a = 0, b = 0;
    final xMatch = RegExp(r'([+-]?\d*\.?\d*)x').firstMatch(parts[0]);
    if (xMatch != null) {
      final coeff = xMatch.group(1);
      if (coeff == null || coeff.isEmpty || coeff == '+') {
        a = 1.0;
      } else if (coeff == '-') {
        a = -1.0;
      } else {
        a = double.tryParse(coeff) ?? 0.0;
      }
    }
    final yMatch = RegExp(r'([+-]?\d*\.?\d*)y').firstMatch(parts[0]);
    if (yMatch != null) {
      final coeff = yMatch.group(1);
      if (coeff == null || coeff.isEmpty || coeff == '+') {
        b = 1.0;
      } else if (coeff == '-') {
        b = -1.0;
      } else {
        b = double.tryParse(coeff) ?? 0.0;
      }
    }
    return [a, b, c];
  }

  ({String formula, String solution})? _tryFactorization(int a, int b, int c) {
    if (a == 0) return null;
    int ac = a * c;
    int absAc = ac.abs();

    // Try all divisors of abs(ac) and consider both positive and negative factors
    for (int d = 1; d <= sqrt(absAc).toInt(); d++) {
      if (absAc % d == 0) {
        int d1 = d;
        int d2 = absAc ~/ d;

        // Try all sign combinations for the factors
        // We need m * n = ac and m + n = b
        List<int> signCombinations = [1, -1];

        for (int sign1 in signCombinations) {
          for (int sign2 in signCombinations) {
            int m = sign1 * d1;
            int n = sign2 * d2;
            if (m + n == b && m * n == ac) {
              return formatFactor(m, n, a);
            }

            // Also try the swapped version
            m = sign1 * d2;
            n = sign2 * d1;
            if (m + n == b && m * n == ac) {
              return formatFactor(m, n, a);
            }
          }
        }
      }
    }
    return null;
  }

  bool check(int m, int n, int b) => m + n == b;

  ({String formula, String solution}) formatFactor(int m, int n, int a) {
    // Roots are -m/a and -n/a
    int g1 = gcd(m.abs(), a.abs());
    int root1Num = -m ~/ g1;
    int root1Den = a ~/ g1;

    int g2 = gcd(n.abs(), a.abs());
    int root2Num = -n ~/ g2;
    int root2Den = a ~/ g2;

    String sol1 = _formatFraction(root1Num, root1Den);
    String sol2 = _formatFraction(root2Num, root2Den);

    // For formula, show (a x + m)(x + n/a) or simplified
    String f1 = a == 1 ? 'x' : '${a}x';
    f1 = m == 0 ? f1 : '$f1 ${m >= 0 ? '+' : ''} $m';

    String f2;
    if (n % a == 0) {
      int coeff = n ~/ a;
      f2 = 'x ${coeff >= 0 ? '+' : ''} $coeff';
      if (coeff == 0) f2 = 'x';
    } else {
      f2 = 'x ${n >= 0 ? '+' : ''} \\frac{$n}{$a}';
    }

    String formula = '\$\$($f1)($f2) = 0\$\$';

    String solution;
    if (root1Num * root2Den == root2Num * root1Den) {
      solution = '\$\$x_1 = x_2 = $sol1\$\$';
    } else {
      solution = '\$\$x_1 = $sol1, \\quad x_2 = $sol2\$\$';
    }

    return (formula: formula, solution: solution);
  }

  String _formatFraction(int num, int den) {
    if (den == 0) return 'undefined';

    // Handle sign: make numerator positive, put sign outside
    bool isNegative = (num < 0) != (den < 0);
    int absNum = num.abs();
    int absDen = den.abs();

    // Simplify fraction
    int g = gcd(absNum, absDen);
    absNum ~/= g;
    absDen ~/= g;

    if (absDen == 1) {
      return isNegative ? '-$absNum' : '$absNum';
    } else {
      String fraction = '\\frac{$absNum}{$absDen}';
      return isNegative ? '-$fraction' : fraction;
    }
  }

  int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);

  /// 格式化 Rational 值的平方根表达式，保持符号形式
  String _formatSqrtFromRational(Rational value) {
    if (value == Rational.zero) return '0';

    // 处理负数（用于复数根）
    if (value < Rational.zero) {
      return '\\sqrt{${(-value).toBigInt()}}';
    }

    // 尝试将 Rational 转换为完全平方数的形式
    // 例如: 4/9 -> 2/3, 9/4 -> 3/2, 25/16 -> 5/4 等

    // 首先简化分数
    final simplified = value;

    // 检查分子和分母是否都是完全平方数
    final numerator = simplified.numerator;
    final denominator = simplified.denominator;

    // 寻找分子和分母的平方根因子
    BigInt sqrtNumerator = _findSquareRootFactor(numerator);
    BigInt sqrtDenominator = _findSquareRootFactor(denominator);

    // 计算剩余的分子和分母
    final remainingNumerator = numerator ~/ (sqrtNumerator * sqrtNumerator);
    final remainingDenominator =
        denominator ~/ (sqrtDenominator * sqrtDenominator);

    // 构建结果
    String result = '';

    // 处理系数部分
    if (sqrtNumerator > BigInt.one || sqrtDenominator > BigInt.one) {
      if (sqrtNumerator > sqrtDenominator) {
        final coeff = sqrtNumerator ~/ sqrtDenominator;
        if (coeff > BigInt.one) {
          result += '$coeff';
        }
      } else if (sqrtDenominator > sqrtNumerator) {
        // 这会导致分母，需要用分数表示
        final coeffNum = sqrtNumerator;
        final coeffDen = sqrtDenominator;
        if (coeffNum == BigInt.one) {
          result += '\\frac{1}{$coeffDen}';
        } else {
          result += '\\frac{$coeffNum}{$coeffDen}';
        }
      }
    }

    // 处理根号部分
    if (remainingNumerator == BigInt.one &&
        remainingDenominator == BigInt.one) {
      // 没有根号部分
      if (result.isEmpty) {
        return '1';
      }
    } else if (remainingNumerator == remainingDenominator) {
      // 根号部分约分后为1
      if (result.isEmpty) {
        return '1';
      }
    } else {
      // 需要根号
      String sqrtContent = '';
      if (remainingDenominator == BigInt.one) {
        sqrtContent = '$remainingNumerator';
      } else {
        sqrtContent = '\\frac{$remainingNumerator}{$remainingDenominator}';
      }

      if (result.isEmpty) {
        result = '\\sqrt{$sqrtContent}';
      } else {
        result += '\\sqrt{$sqrtContent}';
      }
    }

    return result.isEmpty ? '1' : result;
  }

  /// 寻找一个大整数的平方根因子
  BigInt _findSquareRootFactor(BigInt n) {
    if (n <= BigInt.one) return BigInt.one;

    BigInt factor = BigInt.one;
    BigInt i = BigInt.two;

    while (i * i <= n) {
      BigInt count = BigInt.zero;
      while (n % (i * i) == BigInt.zero) {
        n = n ~/ (i * i);
        count += BigInt.one;
      }
      if (count > BigInt.zero) {
        factor = factor * i;
      }
      i += BigInt.one;
    }

    return factor;
  }

  /// 格式化二次方程的根：(-b ± sqrt(delta)) / (2a)
  String _formatQuadraticRoot(
    double b,
    Rational delta,
    double denominator,
    bool isPlus,
  ) {
    final sign = isPlus ? '+' : '-';
    final bStr = b == 0
        ? ''
        : b > 0
        ? '${b.toInt()}'
        : '(${b.toInt()})';
    final denomStr = denominator == 2 ? '2' : denominator.toString();

    // Format sqrt(delta) symbolically using the Rational value
    final sqrtExpr = _formatSqrtFromRational(delta);

    if (b == 0) {
      // 简化为 ±sqrt(delta)/denominator
      if (denominator == 2) {
        return isPlus ? '\\frac{$sqrtExpr}{2}' : '-\\frac{$sqrtExpr}{2}';
      } else {
        return isPlus
            ? '\\frac{$sqrtExpr}{$denomStr}'
            : '-\\frac{$sqrtExpr}{$denomStr}';
      }
    } else {
      // 完整的表达式：(-b ± sqrt(delta))/denominator
      final numerator = b > 0
          ? '-$bStr $sign $sqrtExpr'
          : '(${b.toInt()}) $sign $sqrtExpr';

      if (denominator == 2) {
        return '\\frac{$numerator}{2}';
      } else {
        return '\\frac{$numerator}{$denomStr}';
      }
    }
  }

  /// 格式化复数根的虚部：sqrt(-delta)/(2a)
  String _formatImaginaryPart(String sqrtExpr, double denominator) {
    final denomStr = denominator == 2 ? '2' : denominator.toString();

    if (denominator == 2) {
      return '\\frac{\\sqrt{${sqrtExpr.replaceAll('\\sqrt{', '').replaceAll('}', '')}}}{2}i';
    } else {
      return '\\frac{\\sqrt{${sqrtExpr.replaceAll('\\sqrt{', '').replaceAll('}', '')}}}{$denomStr}i';
    }
  }

  /// 格式化原始方程，保持符号形式
  String _formatOriginalEquation(String input) {
    // Simply return the original equation with proper LaTeX formatting
    // This avoids complex parsing issues and preserves the original symbolic form
    String result = input.replaceAll(' ', '');

    // 确保方程格式正确
    if (!result.contains('=')) {
      result = '$result=0';
    }

    // Replace sqrt with LaTeX format
    result = result.replaceAll('sqrt(', '\\sqrt{');
    result = result.replaceAll(')', '}');

    return '\$\$$result\$\$';
  }

  /// 解析多项式，保持符号形式
  Map<int, String> _parsePolynomialSymbolic(String side) {
    final coeffs = <int, String>{};

    // Use a simpler approach: split by terms and parse each term individually
    var s = side.replaceAll(' ', ''); // Remove spaces
    if (!s.startsWith('+') && !s.startsWith('-')) {
      s = '+$s';
    }

    // Split by + and - but be more careful about parentheses and functions
    final terms = <String>[];
    int start = 0;
    int parenDepth = 0;

    for (int i = 0; i < s.length; i++) {
      final char = s[i];

      if (char == '(') {
        parenDepth++;
      } else if (char == ')') {
        parenDepth--;
      }

      // Only split on + or - when not inside parentheses
      if (parenDepth == 0 && (char == '+' || char == '-') && i > start) {
        terms.add(s.substring(start, i));
        start = i;
      }
    }
    terms.add(s.substring(start));

    for (final term in terms) {
      if (term.isEmpty) continue;

      // Parse each term
      final termPattern = RegExp(r'^([+-]?)(.*?)x(?:\^(\d+))?$|^([+-]?)(.*?)$');
      final match = termPattern.firstMatch(term);

      if (match != null) {
        if (match.group(5) != null) {
          // Constant term
          final sign = match.group(4) ?? '+';
          final value = match.group(5)!;
          final coeffStr = sign == '+' && value.isNotEmpty
              ? value
              : '$sign$value';
          coeffs[0] = _combineCoefficients(coeffs[0], coeffStr);
        } else {
          // x term
          final sign = match.group(1) ?? '+';
          final coeffPart = match.group(2) ?? '';
          final power = match.group(3) != null ? int.parse(match.group(3)!) : 1;

          String coeffStr;
          if (coeffPart.isEmpty) {
            coeffStr = sign == '+' ? '1' : '-1';
          } else {
            coeffStr = sign == '+' ? coeffPart : '$sign$coeffPart';
          }

          coeffs[power] = _combineCoefficients(coeffs[power], coeffStr);
        }
      }
    }

    return coeffs;
  }

  /// 合并系数，保持符号形式
  String _combineCoefficients(String? existing, String newCoeff) {
    if (existing == null || existing == '0') return newCoeff;
    if (newCoeff == '0') return existing;

    // 简化逻辑：如果都是数字，可以相加；否则保持原样
    final existingNum = double.tryParse(existing);
    final newNum = double.tryParse(newCoeff);

    if (existingNum != null && newNum != null) {
      final sum = existingNum + newNum;
      return sum.toString();
    }

    // 如果包含符号表达式，直接连接
    return '$existing+$newCoeff'.replaceAll('+-', '-');
  }

  /// 减去系数
  String _subtractCoefficients(String a, String b) {
    if (a == '0') return b.startsWith('-') ? b.substring(1) : '-$b';
    if (b == '0') return a;

    final aNum = double.tryParse(a);
    final bNum = double.tryParse(b);

    if (aNum != null && bNum != null) {
      final result = aNum - bNum;
      return result.toString();
    }

    // 符号表达式相减
    return '$a-${b.startsWith('-') ? b.substring(1) : b}';
  }

  /// 计算判别式，保持符号形式
  String _calculateDeltaSymbolic(String a, String b, String c) {
    // Delta = b^2 - 4ac

    // 计算 b^2
    String bSquared;
    if (b == '0') {
      bSquared = '0';
    } else if (b == '1') {
      bSquared = '1';
    } else if (b == '-1') {
      bSquared = '1';
    } else if (b.startsWith('-')) {
      final absB = b.substring(1);
      bSquared = '$absB^2';
    } else {
      bSquared = '$b^2';
    }

    // 计算 4ac
    String fourAC;
    if (a == '0' || c == '0') {
      fourAC = '0';
    } else {
      // 处理符号
      String aCoeff = a;
      String cCoeff = c;

      // 如果 a 或 c 是负数，需要处理符号
      bool aNegative = a.startsWith('-');
      bool cNegative = c.startsWith('-');

      if (aNegative) aCoeff = a.substring(1);
      if (cNegative) cCoeff = c.substring(1);

      String acProduct;
      if (aCoeff == '1' && cCoeff == '1') {
        acProduct = '1';
      } else if (aCoeff == '1') {
        acProduct = cCoeff;
      } else if (cCoeff == '1') {
        acProduct = aCoeff;
      } else {
        acProduct = '$aCoeff \\cdot $cCoeff';
      }

      // 确定 4ac 的符号
      bool productNegative = aNegative != cNegative;
      String fourACValue = '4 \\cdot $acProduct';

      if (productNegative) {
        fourAC = '-$fourACValue';
      } else {
        fourAC = fourACValue;
      }
    }

    // 计算 Delta = b^2 - 4ac
    if (bSquared == '0' && fourAC == '0') {
      return '0';
    } else if (bSquared == '0') {
      return fourAC.startsWith('-') ? fourAC.substring(1) : '-$fourAC';
    } else if (fourAC == '0') {
      return bSquared;
    } else {
      String sign = fourAC.startsWith('-') ? '+' : '-';
      String absFourAC = fourAC.startsWith('-') ? fourAC.substring(1) : fourAC;
      return '$bSquared $sign $absFourAC';
    }
  }

  Rational _rationalFromDouble(double value, {int maxPrecision = 12}) {
    // 限制小数精度，避免无限循环小数
    final str = value.toStringAsFixed(maxPrecision);

    if (!str.contains('.')) {
      return Rational.parse(str);
    }

    final parts = str.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts[1];

    final numerator = BigInt.parse(integerPart + fractionalPart);
    final denominator = BigInt.from(10).pow(fractionalPart.length);

    return Rational(numerator, denominator);
  }
}

import 'dart:math';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:math_expressions/math_expressions.dart';
import 'models/calculation_step.dart';

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
      if (kDebugMode) {
        print(e);
      }
      throw Exception('无法识别的格式。请检查您的方程或表达式。');
    }
  }

  /// ---- 求解器实现 ----

  /// 1. 求解简单表达式
  CalculationResult _solveSimpleExpression(String input) {
    final steps = <CalculationStep>[];
    steps.add(
      CalculationStep(
        title: "第一步：表达式求值",
        explanation: "这是一个标准的数学表达式，我们将直接计算其结果。",
        formula: input,
      ),
    );

    // **FIXED**: Correct usage of the math_expressions library
    Parser p = Parser();
    Expression exp = p.parse(input);
    ContextModel cm = ContextModel();
    final result = exp.evaluate(EvaluationType.REAL, cm);

    return CalculationResult(steps: steps, finalAnswer: result.toString());
  }

  /// 2. 求解一元一次方程
  CalculationResult _solveLinearEquation(String input) {
    final steps = <CalculationStep>[];
    steps.add(
      CalculationStep(title: "原方程", explanation: "这是一元一次方程。", formula: input),
    );

    // 解析方程: ax+b=cx+d
    final parts = _parseLinearEquation(input);
    final a = parts.a, b = parts.b, c = parts.c, d = parts.d;

    // 移项合并
    final newA = a - c;
    final newD = d - b;

    steps.add(
      CalculationStep(
        title: "第一步：移项",
        explanation: "将所有含 x 的项移到等式左边，常数项移到右边。",
        formula:
            "${a}x ${c >= 0 ? '-' : '+'} ${c.abs()}x = $d ${b >= 0 ? '-' : '+'} ${b.abs()}",
      ),
    );

    steps.add(
      CalculationStep(
        title: "第二步：合并同类项",
        explanation: "合并等式两边的项。",
        formula: "${newA}x = $newD",
      ),
    );

    // 求解x
    if (newA == 0) {
      if (newD == 0) {
        return CalculationResult(steps: steps, finalAnswer: "有无穷多解");
      } else {
        return CalculationResult(steps: steps, finalAnswer: "无解");
      }
    }

    final x = newD / newA;
    steps.add(
      CalculationStep(
        title: "第三步：求解 x",
        explanation: "两边同时除以 x 的系数 ($newA)。",
        formula: "x = $newD / $newA",
      ),
    );

    return CalculationResult(steps: steps, finalAnswer: "x = $x");
  }

  /// 3. 求解一元二次方程 (升级版)
  CalculationResult _solveQuadraticEquation(String input) {
    final steps = <CalculationStep>[];

    // 整理成 ax^2+bx+c=0 的形式并提取系数
    final eqParts = input.split('=');
    if (eqParts.length != 2) throw Exception("方程格式错误，应包含一个 '='。");

    final leftCoeffs = _parsePolynomial(eqParts[0]);
    final rightCoeffs = _parsePolynomial(eqParts[1]);

    // 移项合并
    final a = (leftCoeffs[2] ?? 0) - (rightCoeffs[2] ?? 0);
    final b = (leftCoeffs[1] ?? 0) - (rightCoeffs[1] ?? 0);
    final c = (leftCoeffs[0] ?? 0) - (rightCoeffs[0] ?? 0);

    if (a == 0) {
      // 如果 a=0, 这实际上是一个一元一次方程
      return _solveLinearEquation("${b}x+${c}=0");
    }

    // **FIXED**: Corrected typo 'ax' to 'a'
    steps.add(
      CalculationStep(
        title: "第一步：整理方程",
        explanation: "将方程整理成标准形式 ax^2+bx+c=0。",
        formula:
            "${a}x^2 ${b >= 0 ? '+' : ''} ${b}x ${c >= 0 ? '+' : ''} $c = 0",
      ),
    );

    // 尝试因式分解 (十字相乘法)
    if (a == a.round() && b == b.round() && c == c.round()) {
      final factors = _tryFactorization(a.toInt(), b.toInt(), c.toInt());
      if (factors != null) {
        steps.add(
          CalculationStep(
            title: "第二步：因式分解法 (十字相乘)",
            explanation: "我们发现可以将方程分解为两个一次因式的乘积。",
            formula: factors.formula,
          ),
        );

        steps.add(
          CalculationStep(
            title: "第三步：求解",
            explanation: "分别令每个因式等于 0，解出 x。",
            formula: "解得 ${factors.solution}",
          ),
        );

        return CalculationResult(steps: steps, finalAnswer: factors.solution);
      } else {
        steps.add(
          CalculationStep(
            title: "第二步：选择解法",
            explanation: "尝试因式分解失败，我们选择使用求根公式法。",
            formula: "\$\\Delta = b^2 - 4ac\$",
          ),
        );
      }
    } else {
      steps.add(
        CalculationStep(
          title: "第二步：选择解法",
          explanation: "系数包含小数，我们使用求根公式法。",
          formula: "\$\\Delta = b^2 - 4ac\$",
        ),
      );
    }

    // 使用求根公式法
    final delta = b * b - 4 * a * c;
    steps.add(
      CalculationStep(
        title: "第三步：计算判别式 (Delta)",
        explanation: "\$\\Delta = ($b)^2 - 4 \\cdot ($a) \\cdot ($c) = $delta",
        // **FIXED**: Removed unnecessary braces for linter warning
        formula: "\$\\Delta = $delta",
      ),
    );

    if (delta > 0) {
      final x1 = (-b + sqrt(delta)) / (2 * a);
      final x2 = (-b - sqrt(delta)) / (2 * a);
      steps.add(
        CalculationStep(
          title: "第四步：应用求根公式",
          explanation:
              "因为 \$\\Delta > 0\$，方程有两个不相等的实数根。公式: \$x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a}\$",
          formula:
              "x₁ = ${x1.toStringAsFixed(4)}, x₂ = ${x2.toStringAsFixed(4)}",
        ),
      );
      return CalculationResult(
        steps: steps,
        finalAnswer:
            "x₁ = ${x1.toStringAsFixed(4)}, x₂ = ${x2.toStringAsFixed(4)}",
      );
    } else if (delta == 0) {
      final x = -b / (2 * a);
      steps.add(
        CalculationStep(
          title: "第四步：应用求根公式",
          explanation: "因为 \$\Delta = 0\$，方程有两个相等的实数根。",
          formula: "x₁ = x₂ = ${x.toStringAsFixed(4)}",
        ),
      );
      return CalculationResult(
        steps: steps,
        finalAnswer: "x₁ = x₂ = ${x.toStringAsFixed(4)}",
      );
    } else {
      steps.add(
        CalculationStep(
          title: "第四步：判断解",
          explanation: "因为 \$\Delta < 0\$，该方程在实数范围内无解。",
          formula: "无实数解",
        ),
      );
      return CalculationResult(steps: steps, finalAnswer: "无实数解");
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
        title: "原始方程组",
        explanation: "这是一个二元一次方程组，我们将使用加减消元法求解。",
        formula:
            "${a1}x ${b1 >= 0 ? '+' : ''} ${b1}y = $c1  ---(1)\n${a2}x ${b2 >= 0 ? '+' : ''} ${b2}y = $c2  ---(2)",
      ),
    );

    final det = a1 * b2 - a2 * b1;
    if (det == 0) {
      if (a1 * c2 - a2 * c1 == 0) {
        return CalculationResult(steps: steps, finalAnswer: "有无穷多解");
      } else {
        return CalculationResult(steps: steps, finalAnswer: "无解");
      }
    }

    final newA1 = a1 * b2, newC1 = c1 * b2;
    final newA2 = a2 * b1, newC2 = c2 * b1;

    // **FIXED**: Wrapped calculations in braces {} for string interpolation
    steps.add(
      CalculationStep(
        title: "第一步：消元",
        explanation: "为了消去变量 y，将方程(1)两边乘以 $b2\$，方程(2)两边乘以 $b1\$。",
        formula:
            "${newA1}x ${b1 * b2 >= 0 ? '+' : ''} ${b1 * b2}y = $newC1  ---(3)\n${newA2}x ${b1 * b2 >= 0 ? '+' : ''} ${b1 * b2}y = $newC2  ---(4)",
      ),
    );

    final xCoeff = newA1 - newA2;
    final constCoeff = newC1 - newC2;

    steps.add(
      CalculationStep(
        title: "第二步：相减",
        explanation: "将方程(3)减去方程(4)，得到一个只含 x 的方程。",
        formula:
            "($newA1 - $newA2)x = $newC1 - $newC2 \n=> ${xCoeff}x = $constCoeff",
      ),
    );

    final x = constCoeff / xCoeff;
    steps.add(
      CalculationStep(
        title: "第三步：解出 x",
        explanation: "求解上述方程得到 x 的值。",
        formula: "x = $x",
      ),
    );

    // **FIXED**: Added a check for b1 to avoid division by zero if we substitute into an equation without y.
    if (b1.abs() < 1e-9) {
      // If b1 is very close to 0, use the second equation
      final yCoeff = b2;
      final yConst = c2 - a2 * x;
      final y = yConst / yCoeff;
      steps.add(
        CalculationStep(
          title: "第四步：回代求解 y",
          explanation: "将 x = $x 代入原方程(2)中。",
          // **FIXED**: Corrected string interpolation for calculations and substitutions
          formula:
              "${a2}(${x}) + ${b2}y = $c2 \n=> ${a2 * x} + ${b2}y = $c2 \n=> ${b2}y = $c2 - ${a2 * x} \n=> ${b2}y = ${c2 - a2 * x}",
        ),
      );
      steps.add(
        CalculationStep(
          title: "第五步：解出 y",
          explanation: "求解得到 y 的值。",
          formula: "y = $y",
        ),
      );
      return CalculationResult(steps: steps, finalAnswer: "x = $x, y = $y");
    } else {
      // Default case, substitute into the first equation
      final yCoeff = b1;
      final yConst = c1 - a1 * x;
      final y = yConst / yCoeff;
      steps.add(
        CalculationStep(
          title: "第四步：回代求解 y",
          explanation: "将 x = $x 代入原方程(1)中。",
          formula:
              "${a1}(${x}) + ${b1}y = $c1 \n=> ${a1 * x} + ${b1}y = $c1 \n=> ${b1}y = $c1 - ${a1 * x} \n=> ${b1}y = ${c1 - a1 * x}",
        ),
      );
      steps.add(
        CalculationStep(
          title: "第五步：解出 y",
          explanation: "求解得到 y 的值。",
          formula: "y = $y",
        ),
      );
      return CalculationResult(steps: steps, finalAnswer: "x = $x, y = $y");
    }
  }

  /// ---- 辅助函数 ----

  /// 展开表达式，例如 (x-1)(x+2) -> x^2+x-2
  String _expandExpressions(String input) {
    String result = input;
    // 循环直到没有更多的表达式可以展开
    while (true) {
      String oldResult = result;

      // 模式1: k*(ax+b)^2, 例如 4(x-1)^2 or (x-1)^2
      final powerMatch = RegExp(
        r'(-?\d*\.?\d*)?\(([^)]+)\)\^2',
      ).firstMatch(result);
      if (powerMatch != null) {
        final kStr = powerMatch.group(1);
        double k = 1.0;
        if (kStr != null && kStr.isNotEmpty) {
          if (kStr == '-') {
            k = -1.0;
          } else {
            k = double.parse(kStr);
          }
        }

        final factor = powerMatch.group(2)!;
        final coeffs = _parsePolynomial(factor);
        final a = coeffs[1] ?? 0;
        final b = coeffs[0] ?? 0;

        // (ax+b)^2 = a^2*x^2 + 2ab*x + b^2
        final newA = k * a * a;
        final newB = k * 2 * a * b;
        final newC = k * b * b;

        final expanded =
            "${newA}x^2${newB >= 0 ? '+' : ''}${newB}x${newC >= 0 ? '+' : ''}${newC}";
        result = result.replaceFirst(powerMatch.group(0)!, "($expanded)");
        continue; // 重新开始循环以处理嵌套表达式
      }

      // 模式2: (ax+b)(cx+d), 例如 (x-3)(x+2)
      final factorMulMatch = RegExp(
        r'\(([^)]+)\)\(([^)]+)\)',
      ).firstMatch(result);
      if (factorMulMatch != null) {
        final factor1 = factorMulMatch.group(1)!;
        final factor2 = factorMulMatch.group(2)!;
        final coeffs1 = _parsePolynomial(factor1);
        final coeffs2 = _parsePolynomial(factor2);

        final a = coeffs1[1] ?? 0;
        final b = coeffs1[0] ?? 0;
        final c = coeffs2[1] ?? 0;
        final d = coeffs2[0] ?? 0;

        // (ax+b)(cx+d) = ac*x^2 + (ad+bc)*x + bd
        final newA = a * c;
        final newB = a * d + b * c;
        final newC = b * d;

        final expanded =
            "${newA}x^2${newB >= 0 ? '+' : ''}${newB}x${newC >= 0 ? '+' : ''}${newC}";
        result = result.replaceFirst(factorMulMatch.group(0)!, "($expanded)");
        continue; // 重新开始循环
      }

      // 如果在这次迭代中没有改变，则跳出循环
      if (result == oldResult) {
        break;
      }
    }
    return result;
  }

  LinearEquationParts _parseLinearEquation(String input) {
    final parts = input.split('=');
    if (parts.length != 2) throw Exception("方程格式错误，应包含一个'='。");

    final leftCoeffs = _parsePolynomial(parts[0]);
    final rightCoeffs = _parsePolynomial(parts[1]);

    final a = leftCoeffs[1] ?? 0.0;
    final b = leftCoeffs[0] ?? 0.0;
    final c = rightCoeffs[1] ?? 0.0;
    final d = rightCoeffs[0] ?? 0.0;

    return LinearEquationParts(a, b, c, d);
  }

  Map<int, double> _parsePolynomial(String side) {
    final coeffs = <int, double>{};
    final pattern = RegExp(
      r'([+-]?(?:\d*\.?\d*))?x(?:\^(\d+))?|([+-]?\d*\.?\d+)',
    );
    var s = side.startsWith('+') || side.startsWith('-') ? side : '+$side';

    for (final match in pattern.allMatches(s)) {
      if (match.group(3) != null) {
        coeffs[0] = (coeffs[0] ?? 0) + double.parse(match.group(3)!);
      } else {
        int power = match.group(2) != null ? int.parse(match.group(2)!) : 1;
        String coeffStr = match.group(1) ?? '+';
        double coeff = 1.0;
        if (coeffStr.isNotEmpty && coeffStr != '+') {
          if (coeffStr == '-') {
            coeff = -1.0;
          } else {
            coeff = double.parse(coeffStr);
          }
        } else if (coeffStr == '-') {
          coeff = -1.0;
        }
        coeffs[power] = (coeffs[power] ?? 0) + coeff;
      }
    }
    return coeffs;
  }

  List<double> _parseTwoVariableLinear(String equation) {
    final parts = equation.split('=');
    if (parts.length != 2) throw Exception("方程 $equation 格式错误");
    final c = double.tryParse(parts[1]) ?? 0.0;

    double a = 0, b = 0;
    final xMatch = RegExp(r'([+-]?\d*\.?\d*)x').firstMatch(parts[0]);
    if (xMatch != null) {
      final coeff = xMatch.group(1);
      if (coeff == null || coeff == '+') {
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
      if (coeff == null || coeff == '+') {
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
    for (int i = 1; i <= sqrt(ac.abs()); i++) {
      if (ac % i == 0) {
        int j = ac ~/ i;
        if (check(i, j, b)) return formatFactor(i, j, a);
        if (check(-i, -j, b)) return formatFactor(-i, -j, a);
        if (check(i, -j, b)) return formatFactor(i, -j, a);
        if (check(-i, j, b)) return formatFactor(-i, j, a);
      }
    }
    return null;
  }

  // **FIXED**: Simplified check method
  bool check(int m, int n, int b) {
    return m + n == b;
  }

  ({String formula, String solution}) formatFactor(int m, int n, int a) {
    int common = gcd(n.abs(), a.abs());
    int num = n ~/ common;
    int den = a ~/ common;

    final a1 = den;
    final c1 = num;
    final a2 = a ~/ den;
    final c2 = m ~/ a2;

    // **FIXED**: Correctly handle coefficients of 1
    final f1Part1 = a1 == 1 ? 'x' : '${a1}x';
    final f1 = c1 == 0 ? f1Part1 : "$f1Part1 ${c1 >= 0 ? '+' : ''} $c1";

    final f2Part1 = a2 == 1 ? 'x' : '${a2}x';
    final f2 = c2 == 0 ? f2Part1 : "$f2Part1 ${c2 >= 0 ? '+' : ''} $c2";

    // **FIXED**: Renamed variables to lowerCamelCase
    final int x1Num = -c1, x1Den = a1;
    final int x2Num = -c2, x2Den = a2;

    final sol1 = x1Den == 1 ? "$x1Num" : "$x1Num/$x1Den";
    final sol2 = x2Den == 1 ? "$x2Num" : "$x2Num/$x2Den";

    final solution = x1Num * x2Den == x2Num * x1Den
        ? "x₁ = x₂ = $sol1"
        : "x₁ = $sol1, x₂ = $sol2";

    return (formula: "(${f1})(${f2}) = 0", solution: solution);
  }

  int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
}

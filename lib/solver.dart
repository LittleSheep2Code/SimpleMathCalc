import 'dart:developer' show log;
import 'dart:math' hide log;
import 'package:rational/rational.dart';
import 'package:simple_math_calc/calculator.dart';
import 'package:simple_math_calc/parser.dart';
import 'models/calculation_step.dart';

/// 帮助解析一元一次方程 ax+b=cx+d 的辅助类
class LinearEquationParts {
  final double a, b, c, d;
  LinearEquationParts(this.a, this.b, this.c, this.d);
}

class SolverService {
  /// 格式化数字，移除不必要的尾随零
  String _formatNumber(double value, {int precision = 4}) {
    String formatted = value.toStringAsFixed(precision);
    // 移除尾随的零和小数点
    formatted = formatted.replaceAll(RegExp(r'\.0+$'), '');
    // 如果最后是小数点，也移除
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  /// 尝试对二次方程进行因式分解
  String? _tryFactorQuadratic(double a, double b, double c) {
    if (a != a.round() || b != b.round() || c != c.round()) return null;
    int aa = a.round(), bb = b.round(), cc = c.round();
    if (aa == 0) return null; // 不是二次方程

    // 简单情况：如果 a=1，尝试简单的因式分解
    if (aa == 1) {
      // 寻找两个因式 (x + m)(x + n) = x^2 + (m+n)x + mn
      // 需要满足 m+n = -b, mn = c
      for (int m = -100; m <= 100; m++) {
        for (int n = -100; n <= 100; n++) {
          if (m + n == -bb && m * n == cc) {
            String factor1 = _formatFactorTerm(1, -m, 'x');
            String factor2 = _formatFactorTerm(1, -n, 'x');
            return '($factor1)($factor2)';
          }
        }
      }
    }

    // 简单情况：如果 a=-1，尝试简单的因式分解
    if (aa == -1) {
      // 寻找两个因式 -(x + m)(x + n) = -x^2 - (m+n)x - mn
      // 需要满足 m+n = b, mn = -c
      for (int m = -100; m <= 100; m++) {
        for (int n = -100; n <= 100; n++) {
          if (m + n == bb && m * n == -cc) {
            String factor1 = _formatFactorTerm(1, m);
            String factor2 = _formatFactorTerm(1, n);
            return '-($factor1)($factor2)';
          }
        }
      }
    }

    // 对于更复杂的情况，暂时不进行因式分解
    return null;
  }

  /// 格式化因式中的项
  String _formatFactorTerm(int coeff, int constTerm, [String variable = 'x']) {
    String result = '';
    if (coeff != 0) {
      if (coeff == 1)
        result += variable;
      else if (coeff == -1)
        result += '-$variable';
      else
        result += '${coeff}$variable';
    }
    if (constTerm != 0) {
      if (result.isNotEmpty) {
        if (constTerm > 0)
          result += ' + $constTerm';
        else
          result += ' - ${-constTerm}';
      } else {
        result += constTerm.toString();
      }
    }
    if (result.isEmpty) result = '0';
    return result;
  }

  /// 检测方程中的变量
  Set<String> _detectVariables(String input) {
    final variablePattern = RegExp(r'([a-zA-Z])');
    final matches = variablePattern.allMatches(input);
    return matches.map((match) => match.group(1)!).toSet();
  }

  /// 主入口方法，识别并分发任务
  CalculationResult solve(String input) {
    // 预处理输入字符串
    final cleanInput = input.replaceAll(' ', '').toLowerCase();

    // 检测方程中的变量
    final variables = _detectVariables(cleanInput);
    if (!cleanInput.contains('=') || variables.isEmpty) {
      // 如果没有等号或没有变量，当作简单表达式处理
      try {
        return _solveSimpleExpression(input);
      } catch (e) {
        throw Exception('无法识别的格式。请检查您的方程或表达式。');
      }
    }

    // 获取主变量（第一个检测到的变量）
    final mainVariable = variables.first;

    // 对包含变量的方程进行预处理，展开表达式
    String processedInput = cleanInput;
    if (processedInput.contains(mainVariable) && processedInput.contains('(')) {
      processedInput = _expandExpressions(processedInput, mainVariable);
    }

    // 0. 检查是否是 (expr)^n = constant 的形式（任意次幂）
    final powerEqMatch = RegExp(
      r'^\(([^)]+)\)\^(\d+)\s*=\s*(.+)$',
    ).firstMatch(cleanInput);
    if (powerEqMatch != null) {
      final exprStr = powerEqMatch.group(1)!;
      final powerStr = powerEqMatch.group(2)!;
      final rightStr = powerEqMatch.group(3)!;

      final n = int.parse(powerStr);
      final rightValue = double.tryParse(rightStr);

      if (rightValue != null) {
        return _solveGeneralPowerEquation(
          exprStr,
          n,
          rightValue,
          cleanInput,
          mainVariable,
        );
      }
    }

    // 0.5. 检查是否是 a(expr)^2 = b 的形式（向后兼容）
    final squareEqMatch = RegExp(
      r'^(\d*\.?\d*)?\(([^)]+)\)\^2\s*=\s*(.+)$',
    ).firstMatch(cleanInput);
    if (squareEqMatch != null) {
      final coeffStr = squareEqMatch.group(1)!;
      final exprStr = squareEqMatch.group(2)!;
      final rightStr = squareEqMatch.group(3)!;

      // 解析系数
      double coeff = coeffStr.isEmpty ? 1.0 : double.parse(coeffStr);

      // 解析右边
      double right = double.parse(rightStr);

      // 解析 expr 为 variable ± h
      final exprMatch = RegExp(
        r'$mainVariable\s*([+-]\s*\d*\.?\d*)?',
      ).firstMatch(exprStr);
      if (exprMatch != null) {
        final hStr = exprMatch.group(1) ?? '';
        double constant = hStr.isEmpty
            ? 0.0
            : double.parse(hStr.replaceAll(' ', ''));
        double h = -constant; // For (var - h)^2, h is the center

        // 使用有理数计算
        final coeffRat = _rationalFromDouble(coeff);
        final rightRat = _rationalFromDouble(right);
        final hRat = _rationalFromDouble(h);
        final innerRat = rightRat / coeffRat;
        final sqrtInnerRat = sqrtRational(innerRat);
        if (sqrtInnerRat != null) {
          final x1Rat = hRat + sqrtInnerRat;
          final x2Rat = hRat - sqrtInnerRat;
          final x1Str = _formatRational(x1Rat);
          final x2Str = _formatRational(x2Rat);

          return CalculationResult(
            steps: [
              CalculationStep(
                stepNumber: 1,
                title: '整理方程',
                explanation: '这是一个平方形式的方程。',
                formula: '\$\$$cleanInput\$\$',
              ),
              CalculationStep(
                stepNumber: 2,
                title: '移项',
                explanation: '将常数项移到等式右边。',
                formula:
                    '\$\$($exprStr)^2 = \\frac{${rightRat.numerator}}{${rightRat.denominator}} \\div \\frac{${coeffRat.numerator}}{${coeffRat.denominator}}\$\$',
              ),
              CalculationStep(
                stepNumber: 3,
                title: '开方',
                explanation: '对方程两边同时开平方。',
                formula:
                    '\$\$${mainVariable} ${h >= 0 ? '+' : ''}$h = \\pm \\sqrt{\\frac{${innerRat.numerator}}{${innerRat.denominator}}}\$\$',
              ),
              CalculationStep(
                stepNumber: 4,
                title: '解出 ${mainVariable}',
                explanation: '分别取正负号，解出 ${mainVariable} 的值。',
                formula:
                    '\$\$${mainVariable}_1 = $x1Str, \\quad ${mainVariable}_2 = $x2Str\$\$',
              ),
            ],
            finalAnswer:
                '\$\$${mainVariable}_1 = $x1Str, \\quad ${mainVariable}_2 = $x2Str\$\$',
          );
        }
      }
    }

    // 1. 检查是否为多元一次方程组 (格式: ...;...)
    if (processedInput.contains(';') && variables.length > 1) {
      return _solveSystemOfLinearEquations(processedInput, variables);
    }

    // 2. 检查是否为一元二次方程 (包含 variable^2 或 variable²)
    if (processedInput.contains('${mainVariable}^2') ||
        processedInput.contains('${mainVariable}²')) {
      return _solveQuadraticEquation(
        processedInput.replaceAll('${mainVariable}²', '${mainVariable}^2'),
        mainVariable,
      );
    }

    // 3. 检查是否为幂次方程 (variable^n = a 的形式)
    if (processedInput.contains('${mainVariable}^') &&
        processedInput.contains('=')) {
      return _solvePowerEquation(processedInput, mainVariable);
    }

    // 4. 检查是否为一元一次方程 (包含主变量)
    if (processedInput.contains(mainVariable)) {
      return _solveLinearEquation(processedInput, mainVariable);
    }

    // 如果都不是，则作为简单表达式计算
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
    // Parse the input to get LaTeX-formatted version
    final parser = Parser(input);
    final parsedExpr = parser.parse();
    final latexInput = parsedExpr.toString().replaceAll('*', '\\cdot');

    steps.add(
      CalculationStep(
        stepNumber: 1,
        title: '表达式求值',
        explanation: '这是一个标准的数学表达式，我们将直接计算其结果。',
        formula: '\$\$$latexInput\$\$',
      ),
    );

    // 检查是否为特殊三角函数值，可以返回精确结果
    final exactTrigResult = getExactTrigResult(input);
    if (exactTrigResult != null) {
      return CalculationResult(
        steps: steps,
        finalAnswer: '\$\$$exactTrigResult\$\$',
      );
    }

    // 预处理输入，将三角函数的参数从度转换为弧度
    String processedInput = convertTrigToRadians(input);

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
      final formattedResult = formatSqrtResult(result);

      return CalculationResult(
        steps: steps,
        finalAnswer: '\$\$$formattedResult\$\$',
      );
    } catch (e) {
      throw Exception('无法解析表达式: $input');
    }
  }

  /// 2. 求解一元一次方程
  CalculationResult _solveLinearEquation(
    String input, [
    String variable = 'x',
  ]) {
    final steps = <CalculationStep>[];
    // Parse the input to get LaTeX-formatted version
    final parser = Parser(input);
    final parsedExpr = parser.parse();
    final latexInput = parsedExpr.toString().replaceAll('*', '\\cdot');

    steps.add(
      CalculationStep(
        stepNumber: 0,
        title: '原方程',
        explanation: '这是一元一次方程。',
        formula: '\$\$$latexInput\$\$',
      ),
    );

    final parts = _parseLinearEquation(input, variable);
    final a = parts.a, b = parts.b, c = parts.c, d = parts.d;

    final newA = _rationalFromDouble(a) - _rationalFromDouble(c);
    final newD = _rationalFromDouble(d) - _rationalFromDouble(b);

    steps.add(
      CalculationStep(
        stepNumber: 1,
        title: '移项',
        explanation: '将所有含 ${variable} 的项移到等式左边，常数项移到右边。',
        formula:
            '\$\$${a}${variable} ${c >= 0 ? '-' : '+'} ${c.abs()}${variable} = $d ${b >= 0 ? '-' : '+'} ${b.abs()}\$\$',
      ),
    );

    steps.add(
      CalculationStep(
        stepNumber: 2,
        title: '合并同类项',
        explanation: '合并等式两边的项。',
        formula:
            '\$\$${_formatNumber(newA.toDouble())}${variable} = ${_formatNumber(newD.toDouble())}\$\$',
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
        title: '求解 ${variable}',
        explanation: '两边同时除以 ${variable} 的系数 ($newA)。',
        formula: '\$\$${variable} = \\frac{$newD}{$newA}\$\$',
      ),
    );

    return CalculationResult(
      steps: steps,
      finalAnswer: '\$\$${variable} = $x\$\$',
    );
  }

  /// 3. 求解一元二次方程 (升级版)
  CalculationResult _solveQuadraticEquation(
    String input, [
    String variable = 'x',
  ]) {
    final steps = <CalculationStep>[];

    final eqParts = input.split('=');
    if (eqParts.length != 2) throw Exception("方程格式错误，应包含一个 '='。");

    // Keep original equation for display
    final originalEquation = _formatOriginalEquation(input);

    // Parse coefficients symbolically (kept for potential future use)
    // final leftCoeffsSymbolic = _parsePolynomialSymbolic(eqParts[0]);
    // final rightCoeffsSymbolic = _parsePolynomialSymbolic(eqParts[1]);
    // final aSymbolic = _subtractCoefficients(
    //   leftCoeffsSymbolic[2] ?? '0',
    //   rightCoeffsSymbolic[2] ?? '0',
    // );
    // final bSymbolic = _subtractCoefficients(
    //   leftCoeffsSymbolic[1] ?? '0',
    //   rightCoeffsSymbolic[1] ?? '0',
    // );
    // final cSymbolic = _subtractCoefficients(
    //   leftCoeffsSymbolic[0] ?? '0',
    //   rightCoeffsSymbolic[0] ?? '0',
    // );

    // Also get numeric values for calculations
    final leftCoeffs = _parsePolynomial(eqParts[0], variable);
    final rightCoeffs = _parsePolynomial(eqParts[1], variable);
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

    final factored = _tryFactorQuadratic(a, b, c);
    if (factored != null) {
      steps.add(
        CalculationStep(
          stepNumber: 2,
          title: '选择解法',
          explanation: '我们选择使用因式分解法。',
          formula: '\$\$ax^2 + bx + c = 0\$\$',
        ),
      );
      steps.add(
        CalculationStep(
          stepNumber: 3,
          title: '因式分解',
          explanation: '将二次方程分解为两个一次因式的乘积。',
          formula: '\$\$$factored = 0\$\$',
        ),
      );

      // Parse the factored form to find the roots
      final roots = _calculateRootsFromFactoredForm(factored);
      steps.add(
        CalculationStep(
          stepNumber: 4,
          title: '解出 x',
          explanation: '分别令每个因式为零，解出 x 的值。',
          formula: roots.formula,
        ),
      );
      return CalculationResult(steps: steps, finalAnswer: roots.finalAnswer);
    } else {
      // 检查系数是否都是整数
      bool allIntegers = a == a.round() && b == b.round() && c == c.round();

      if (!allIntegers) {
        // 使用公式法
        steps.add(
          CalculationStep(
            stepNumber: 2,
            title: '选择解法',
            explanation: '系数包含非整数，我们选择使用公式法。',
            formula: r'公式法：$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$',
          ),
        );
        return _solveQuadraticByFormula(a, b, c, steps);
      } else {
        // 使用配方法
        steps.add(
          CalculationStep(
            stepNumber: 2,
            title: '选择解法',
            explanation: '我们选择使用配方法。',
            formula: r'配方法：$x^2 + \frac{b}{a}x + \frac{c}{a} = 0$',
          ),
        );
      }
    }

    // Step 1: Divide by a if a ≠ 1
    String currentEquation;
    if (a == 1) {
      currentEquation =
          'x^2 ${b >= 0 ? "+" : ""}${b}x ${c >= 0 ? "+" : ""}$c = 0';
    } else {
      final aStr = a == -1 ? '-' : a.toString();
      currentEquation =
          '\\frac{1}{$aStr}(x^2 ${b >= 0 ? "+" : ""}${b}x ${c >= 0 ? "+" : ""}$c) = 0';
    }

    steps.add(
      CalculationStep(
        stepNumber: 3,
        title: '方程变形',
        explanation: a == 1 ? '方程已经是标准形式。' : '将方程两边同时除以 $a。',
        formula: '\$\$$currentEquation\$\$',
      ),
    );

    // Step 2: Move constant term to the other side
    final constantTerm = c / a;

    steps.add(
      CalculationStep(
        stepNumber: 4,
        title: '移项',
        explanation: '将常数项移到方程右边。',
        formula: '\$\$x^2 ${b >= 0 ? "+" : ""}${b}x = ${-constantTerm}\$\$',
      ),
    );

    // Step 3: Complete the square
    final halfCoeff = b / (2 * a);
    final completeSquareTerm = halfCoeff * halfCoeff;
    final completeStr = completeSquareTerm >= 0
        ? '+$completeSquareTerm'
        : completeSquareTerm.toString();

    final xTerm = halfCoeff >= 0 ? "+$halfCoeff" : halfCoeff.toString();
    final rightSide = "${-constantTerm} $completeStr";

    steps.add(
      CalculationStep(
        stepNumber: 5,
        title: '配方',
        explanation:
            '在方程两边同时加上 \$(\\frac{b}{2a})^2 = $completeSquareTerm\$ 以配成完全平方。',
        formula: '\$\$(x $xTerm)^2 = $rightSide\$\$',
      ),
    );

    // Step 4: Simplify right side
    final rightSideValue = -constantTerm + completeSquareTerm;
    final rightSideStrValue = rightSideValue >= 0
        ? rightSideValue.toString()
        : '($rightSideValue)';

    steps.add(
      CalculationStep(
        stepNumber: 6,
        title: '化简',
        explanation: '合并右边的常数项。',
        formula:
            '\$\$(x ${halfCoeff >= 0 ? "+" : ""}$halfCoeff)^2 = $rightSideStrValue\$\$',
      ),
    );

    // Step 5: Take square root - check for symbolic representation
    final symbolicSqrt = _getSymbolicSquareRoot(rightSideValue);
    final sqrtStr = rightSideValue >= 0
        ? (symbolicSqrt ?? sqrt(rightSideValue.abs()).toString())
        : '${sqrt(rightSideValue.abs()).toString()}i';

    steps.add(
      CalculationStep(
        stepNumber: 7,
        title: '开方',
        explanation: '对方程两边同时开平方。',
        formula:
            '\$\$x ${halfCoeff >= 0 ? "+" : ""}$halfCoeff = \\pm $sqrtStr\$\$',
      ),
    );

    // Step 6: Solve for x - use symbolic forms when possible
    final discriminant = b * b - 4 * a * c;
    if (rightSideValue >= 0) {
      final roots = _calculateSymbolicRoots(a, b, discriminant, symbolicSqrt);

      steps.add(
        CalculationStep(
          stepNumber: 8,
          title: '解出 x',
          explanation: '分别取正负号，解出 x 的值。',
          formula: roots.formula,
        ),
      );

      return CalculationResult(steps: steps, finalAnswer: roots.finalAnswer);
    } else {
      // Complex roots
      final imagPart = sqrt(-discriminant) / (2 * a);
      steps.add(
        CalculationStep(
          stepNumber: 8,
          title: '解出 x',
          explanation: '方程在实数范围内无解，但有虚数解。',
          formula:
              '\$\$x_1 = ${-halfCoeff} + ${imagPart}i, \\quad x_2 = ${-halfCoeff} - ${imagPart}i\$\$',
        ),
      );

      return CalculationResult(
        steps: steps,
        finalAnswer:
            '\$\$x_1 = ${-halfCoeff} + ${imagPart}i, \\quad x_2 = ${-halfCoeff} - ${imagPart}i\$\$',
      );
    }
  }

  /// 3.5. 求解通用幂次方程 ((expression)^n = constant 的形式)
  CalculationResult _solveGeneralPowerEquation(
    String exprStr,
    int n,
    double rightValue,
    String originalInput,
    String variable,
  ) {
    final steps = <CalculationStep>[];

    steps.add(
      CalculationStep(
        stepNumber: 1,
        title: '原方程',
        explanation: '这是一个幂次方程。',
        formula: '\$\$$originalInput\$\$',
      ),
    );

    steps.add(
      CalculationStep(
        stepNumber: 2,
        title: '对方程两边同时开 $n 次方',
        explanation: '对方程两边同时开 $n 次方以解出表达式。',
        formula: '\$\$($exprStr) = \\sqrt[$n]{$rightValue}\$\$',
      ),
    );

    // 计算右边的 n 次方根
    final rootValue = pow(rightValue, 1.0 / n);

    // 尝试格式化根的值
    String rootStr;
    if (rootValue.round() == rootValue) {
      // 是整数
      rootStr = rootValue.round().toString();
    } else {
      // 检查是否可以表示为根号形式
      final rootExpr = SqrtExpr(IntExpr(rightValue.toInt()), n);
      final simplified = rootExpr.simplify();
      if (simplified is IntExpr) {
        rootStr = simplified.value.toString();
      } else {
        rootStr = _formatNumber(rootValue.toDouble(), precision: 6);
      }
    }

    steps.add(
      CalculationStep(
        stepNumber: 3,
        title: '计算 $n 次方根',
        explanation: '计算右边的 $n 次方根。',
        formula: '\$\$\\sqrt[$n]{$rightValue} = $rootStr\$\$',
      ),
    );

    // 现在我们需要求解 expression = rootValue 的方程
    final newEquation = '$exprStr=$rootStr';

    steps.add(
      CalculationStep(
        stepNumber: 4,
        title: '化简为新方程',
        explanation: '现在我们需要解方程 $exprStr = $rootStr。',
        formula: '\$\$($exprStr) = $rootStr\$\$',
      ),
    );

    // 递归调用求解器来处理新的方程
    try {
      final result = solve(newEquation);

      // 添加后续步骤
      for (int i = 0; i < result.steps.length; i++) {
        steps.add(
          CalculationStep(
            stepNumber: 5 + i,
            title: result.steps[i].title,
            explanation: result.steps[i].explanation,
            formula: result.steps[i].formula,
          ),
        );
      }

      return CalculationResult(steps: steps, finalAnswer: result.finalAnswer);
    } catch (e) {
      // 如果递归求解失败，返回当前步骤
      return CalculationResult(
        steps: steps,
        finalAnswer: '\$\$($exprStr) = $rootStr\$\$',
      );
    }
  }

  /// 3.6. 求解幂次方程 (variable^n = a 的形式)
  CalculationResult _solvePowerEquation(String input, [String variable = 'x']) {
    final steps = <CalculationStep>[];

    // 解析方程
    final parts = input.split('=');
    if (parts.length != 2) throw Exception("方程格式错误，应包含一个 '='。");

    final leftSide = parts[0].trim();
    final rightSide = parts[1].trim();

    // 检查左边是否为 variable^n 的形式
    final powerMatch = RegExp(
      r'^${RegExp.escape(variable)}\^(\d+)$',
    ).firstMatch(leftSide);
    if (powerMatch == null) {
      throw Exception("不支持的幂次方程格式。当前支持 ${variable}^n = a 的形式。");
    }

    final n = int.parse(powerMatch.group(1)!);
    final a = double.tryParse(rightSide);

    if (a == null) {
      throw Exception("方程右边必须是数字。");
    }

    if (n <= 0) {
      throw Exception("幂次必须是正整数。");
    }

    if (a < 0 && n % 2 == 0) {
      throw Exception("当幂次为偶数时，右边不能为负数（在实数范围内无解）。");
    }

    steps.add(
      CalculationStep(
        stepNumber: 1,
        title: '原方程',
        explanation: '这是一个幂次方程。',
        formula: '\$\$$input\$\$',
      ),
    );

    steps.add(
      CalculationStep(
        stepNumber: 2,
        title: '对方程两边同时开 $n 次方',
        explanation: '对方程两边同时开 $n 次方以解出 ${variable}。',
        formula: '\$\$${variable} = \\sqrt[$n]{$a}\$\$',
      ),
    );

    // 计算结果
    final result = pow(a, 1.0 / n);

    // 尝试格式化为精确形式
    String resultStr;
    if (result.round() == result) {
      // 是整数
      resultStr = result.round().toString();
    } else {
      // 检查是否可以表示为根号形式
      final rootExpr = SqrtExpr(IntExpr(a.toInt()), n);
      final simplified = rootExpr.simplify();
      if (simplified is IntExpr) {
        resultStr = simplified.value.toString();
      } else {
        resultStr = _formatNumber(result.toDouble(), precision: 6);
      }
    }

    steps.add(
      CalculationStep(
        stepNumber: 3,
        title: '计算结果',
        explanation: '计算开 $n 次方的结果。',
        formula: '\$\$${variable} = $resultStr\$\$',
      ),
    );

    return CalculationResult(
      steps: steps,
      finalAnswer: '\$\$${variable} = $resultStr\$\$',
    );
  }

  /// 4. 求解二元一次方程组
  CalculationResult _solveSystemOfLinearEquations(
    String input, [
    Set<String> variables = const {'x', 'y'},
  ]) {
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
${_formatNumber(newA1.toDouble(), precision: 2)}x ${b1 * b2 >= 0 ? '+' : ''} ${_formatNumber((b1 * b2), precision: 2)}y = ${_formatNumber(newC1.toDouble(), precision: 2)} & (3) \\\\
${_formatNumber(newA2.toDouble(), precision: 2)}x ${b1 * b2 >= 0 ? '+' : ''} ${_formatNumber((b1 * b2), precision: 2)}y = ${_formatNumber(newC2.toDouble(), precision: 2)} & (4)
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
            '\$\$(${_formatNumber(newA1.toDouble(), precision: 2)} - ${_formatNumber(newA2.toDouble(), precision: 2)})x = ${_formatNumber(newC1.toDouble(), precision: 2)} - ${_formatNumber(newC2.toDouble(), precision: 2)} \\Rightarrow ${_formatNumber(xCoeff.toDouble(), precision: 2)}x = ${_formatNumber(constCoeff.toDouble(), precision: 2)}\$\$',
      ),
    );

    final x = constCoeff / xCoeff;
    steps.add(
      CalculationStep(
        stepNumber: 3,
        title: '解出 x',
        explanation: '求解上述方程得到 x 的值。',
        formula: '\$\$x = ${_formatNumber(x.toDouble())}\$\$',
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
          explanation: '将 x = ${_formatNumber(x.toDouble())} 代入原方程(2)中。',
          formula:
              '''
\$\$
\\begin{aligned}
$a2(${_formatNumber(x.toDouble())}) + ${b2}y &= $c2 \\\\
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
          formula: '\$\$y = ${_formatNumber(y.toDouble())}\$\$',
        ),
      );
      return CalculationResult(
        steps: steps,
        finalAnswer:
            '\$\$x = ${_formatNumber(x.toDouble())}, \\quad y = ${_formatNumber(y.toDouble())}\$\$',
      );
    } else {
      final yCoeff = b1;
      final yConst = c1 - a1 * x.toDouble();
      final y = yConst / yCoeff;
      steps.add(
        CalculationStep(
          stepNumber: 4,
          title: '回代求解 y',
          explanation: '将 x = ${_formatNumber(x.toDouble())} 代入原方程(1)中。',
          formula:
              '''
\$\$
\\begin{aligned}
$a1(${_formatNumber(x.toDouble())}) + ${b1}y &= $c1 \\\\
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
          formula: '\$\$y = ${_formatNumber(y.toDouble())}\$\$',
        ),
      );
      return CalculationResult(
        steps: steps,
        finalAnswer:
            '\$\$x = ${_formatNumber(x.toDouble())}, \\quad y = ${_formatNumber(y.toDouble())}\$\$',
      );
    }
  }

  /// 检查表达式是否可绘制（包含变量x且可以被求值）
  bool isGraphableExpression(String expression) {
    try {
      // 移除空格并转换为小写
      String cleanExpr = expression.replaceAll(' ', '').toLowerCase();

      // 如果以 y= 开头，去掉前缀
      if (cleanExpr.startsWith('y=')) {
        cleanExpr = cleanExpr.substring(2);
      }

      // 不能包含等号（方程而不是函数表达式）
      if (cleanExpr.contains('=')) {
        return false;
      }

      // 必须包含变量x
      if (!cleanExpr.contains('x')) {
        return false;
      }

      // 尝试展开表达式（如果包含括号）
      String processedExpr = cleanExpr;
      if (processedExpr.contains('(')) {
        processedExpr = _expandExpressions(processedExpr);
      }

      // 尝试解析表达式
      final parser = Parser(processedExpr);
      final expr = parser.parse();

      // 测试在几个点上是否可以求值
      final testPoints = [-1.0, 0.0, 1.0];
      for (final x in testPoints) {
        try {
          final substituted = expr.substitute('x', DoubleExpr(x));
          final evaluated = substituted.evaluate();
          if (evaluated is DoubleExpr &&
              evaluated.value.isFinite &&
              !evaluated.value.isNaN) {
            // 至少有一个点可以求值就算成功
            return true;
          }
        } catch (e) {
          // 继续测试其他点
          continue;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 准备函数表达式用于绘图（展开因式形式）
  String prepareFunctionForGraphing(String expression) {
    // 移除空格并转换为小写
    String cleanExpr = expression.replaceAll(' ', '').toLowerCase();

    // 如果以 y= 开头，去掉前缀
    if (cleanExpr.startsWith('y=')) {
      cleanExpr = cleanExpr.substring(2);
    }

    // 如果表达式包含括号，进行展开
    if (cleanExpr.contains('(')) {
      cleanExpr = _expandExpressions(cleanExpr);
    }

    // 清理格式：移除不必要的.0后缀和简化格式
    cleanExpr = cleanExpr
        .replaceAll('.0', '') // 移除所有.0
        .replaceAll('+0', '') // 移除+0
        .replaceAll('-0', '') // 移除-0
        .replaceAll('1x^2', 'x^2') // 1x^2 -> x^2
        .replaceAll('1x', 'x'); // 1x -> x

    // 移除开头的+号
    if (cleanExpr.startsWith('+')) {
      cleanExpr = cleanExpr.substring(1);
    }

    return cleanExpr;
  }

  /// ---- 辅助函数 ----

  String _expandExpressions(String input, [String variable = 'x']) {
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
        final coeffs = _parsePolynomial(factor, variable);
        final a = coeffs[1] ?? 0;
        final b = coeffs[0] ?? 0;

        final newA = k * a * a;
        final newB = k * 2 * a * b;
        final newC = k * b * b;

        final expanded =
            '${newA}x^2${newB >= 0 ? '+' : ''}${newB}x${newC >= 0 ? '+' : ''}$newC';
        result = result.replaceFirst(powerMatch.group(0)!, expanded);
        iterationCount++;
        continue;
      }

      final factorMulMatch = RegExp(
        r'\(([^)]+)\)\(([^)]+)\)',
      ).firstMatch(result);
      if (factorMulMatch != null) {
        final factor1 = factorMulMatch.group(1)!;
        final factor2 = factorMulMatch.group(2)!;
        log('Expanding: ($factor1) * ($factor2)');

        final coeffs1 = _parsePolynomial(factor1, variable);
        final coeffs2 = _parsePolynomial(factor2, variable);
        log('Coeffs1: $coeffs1, Coeffs2: $coeffs2');

        final a = coeffs1[1] ?? 0;
        final b = coeffs1[0] ?? 0;
        final c = coeffs2[1] ?? 0;
        final d = coeffs2[0] ?? 0;
        log('a=$a, b=$b, c=$c, d=$d');

        final newA = a * c;
        final newB = a * d + b * c;
        final newC = b * d;
        log('newA=$newA, newB=$newB, newC=$newC');

        final expanded =
            '${newA}x^2${newB >= 0 ? '+' : ''}${newB}x${newC >= 0 ? '+' : ''}$newC';
        log('Expanded result: $expanded');

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
        final termCoeffs = _parsePolynomial(termStr, variable);
        final factorCoeffs = _parsePolynomial(factorStr, variable);

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
        result = result.replaceFirst(termFactorMatch.group(0)!, expanded);
        iterationCount++;
        continue;
      }

      if (result == oldResult) break;
      iterationCount++;
    }

    if (iterationCount >= maxIterations) {
      throw Exception('表达式展开过于复杂，请简化输入。');
    }

    // 清理展开后的表达式格式
    result = _cleanExpandedExpression(result);

    // 检查是否为方程（包含等号），如果是的话，将右边的常数项移到左边
    if (result.contains('=')) {
      final parts = result.split('=');
      if (parts.length == 2) {
        final leftSide = parts[0];
        final rightSide = parts[1];

        // 解析左边的多项式
        final leftCoeffs = _parsePolynomial(leftSide, variable);
        final rightCoeffs = _parsePolynomial(rightSide, variable);

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

  LinearEquationParts _parseLinearEquation(
    String input, [
    String variable = 'x',
  ]) {
    final parts = input.split('=');
    if (parts.length != 2) throw Exception("方程格式错误，应包含一个'='。");

    final leftCoeffs = _parsePolynomial(parts[0], variable);
    final rightCoeffs = _parsePolynomial(parts[1], variable);

    return LinearEquationParts(
      (leftCoeffs[1] ?? 0.0),
      (leftCoeffs[0] ?? 0.0),
      (rightCoeffs[1] ?? 0.0),
      (rightCoeffs[0] ?? 0.0),
    );
  }

  Map<int, double> _parsePolynomial(String side, [String variable = 'x']) {
    final coeffs = <int, double>{};

    // 如果输入包含括号，去掉括号
    var cleanSide = side;
    if (cleanSide.startsWith('(') && cleanSide.endsWith(')')) {
      cleanSide = cleanSide.substring(1, cleanSide.length - 1);
    }

    // 扩展模式以支持 sqrt 函数，使用动态变量
    final escapedVar = RegExp.escape(variable);
    final pattern = RegExp(
      r'([+-]?(?:\d*\.?\d*|sqrt\(\d+\)))' +
          escapedVar +
          r'(?:\^(\d+))?|([+-]?(?:\d*\.?\d*|sqrt\(\d+\)))',
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
        // 变量的幂次项
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

  /// 格式化原始方程，保持符号形式
  String _formatOriginalEquation(String input) {
    // Parse the equation and convert to LaTeX
    String result = input.replaceAll(' ', '');

    // 确保方程格式正确
    if (!result.contains('=')) {
      result = '$result=0';
    }

    final parts = result.split('=');
    if (parts.length == 2) {
      // Check if the equation is already in standard polynomial form
      // If it doesn't contain parentheses and looks like a standard polynomial,
      // return it as-is to avoid unnecessary parsing
      final leftSide = parts[0];
      final rightSide = parts[1];

      // If left side is a standard polynomial (no parentheses, only x^2, x, and constants)
      // and right side is 0, return the original
      if (_isStandardPolynomial(leftSide) &&
          (rightSide == '0' || rightSide.isEmpty)) {
        result = '$leftSide=0';
        return '\$\$$result\$\$';
      }

      try {
        final leftParser = Parser(parts[0]);
        final leftExpr = leftParser.parse();
        final rightParser = Parser(parts[1]);
        final rightExpr = rightParser.parse();

        // Get the string representation and clean it up
        String leftStr = leftExpr.toString().replaceAll('*', '\\cdot');
        String rightStr = rightExpr.toString().replaceAll('*', '\\cdot');

        // Clean up unnecessary parentheses
        leftStr = _cleanParentheses(leftStr);
        rightStr = _cleanParentheses(rightStr);

        result = '$leftStr=$rightStr';
      } catch (e) {
        // Fallback to original if parsing fails
        result = result.replaceAll('sqrt(', '\\sqrt{');
        result = result.replaceAll(')', '}');
      }
    } else {
      try {
        final parser = Parser(result.split('=')[0]);
        final expr = parser.parse();

        // Get the string representation and clean it up
        String exprStr = expr.toString().replaceAll('*', '\\cdot');
        exprStr = _cleanParentheses(exprStr);

        result = '$exprStr=0';
      } catch (e) {
        // Fallback
        result = result.replaceAll('sqrt(', '\\sqrt{');
        result = result.replaceAll(')', '}');
      }
    }

    return '\$\$$result\$\$';
  }

  /// 检查字符串是否为标准多项式形式（不含括号，只有x^2、x和常数项）
  bool _isStandardPolynomial(String expr) {
    // Remove spaces
    final cleanExpr = expr.replaceAll(' ', '');

    // If it contains parentheses, it's not standard
    if (cleanExpr.contains('(') || cleanExpr.contains(')')) {
      return false;
    }

    // Check if it matches the pattern of a standard polynomial
    // Should only contain: digits, x, ^, +, -, and spaces (already removed)
    final validChars = RegExp(r'^[0-9x\^\+\-\.]*$');
    if (!validChars.hasMatch(cleanExpr)) {
      return false;
    }

    // Should not have complex expressions like x*x or 2x*3
    if (cleanExpr.contains('*') || cleanExpr.contains('/')) {
      return false;
    }

    // Should have proper x^2 format (not xx or x2)
    if (cleanExpr.contains('x^2') ||
        cleanExpr.contains('x^3') ||
        cleanExpr.contains('x^4')) {
      // This is likely a polynomial
      return true;
    }

    // Check for simple terms like x, 2x, x+1, etc.
    final termPattern = RegExp(
      r'^[+-]?(?:\d*\.?\d*)?x?(?:\^\d+)?(?:[+-][+-]?(?:\d*\.?\d*)?x?(?:\^\d+)?)*$',
    );
    return termPattern.hasMatch(cleanExpr);
  }

  /// 清理不必要的括号
  String _cleanParentheses(String expr) {
    // 移除最外层的括号，如果它们不影响运算顺序
    if (expr.startsWith('(') && expr.endsWith(')')) {
      String inner = expr.substring(1, expr.length - 1);

      // 检查移除括号是否会改变含义
      // 简单检查：如果内部没有运算符，或者只有加减号，可以移除
      if (!inner.contains('+') &&
          !inner.contains('-') &&
          !inner.contains('*') &&
          !inner.contains('/')) {
        return inner;
      }

      // 如果内部表达式是简单的，可以移除括号
      // 例如：(x+1) 可以变成 x+1, 但 (x+1)*(x-1) 不能移除
      final operators = RegExp(r'[+\-*/]');
      final matches = operators.allMatches(inner).toList();

      // 如果只有一个运算符且是加减号，可以移除
      if (matches.length == 1 && (inner.contains('+') || inner.contains('-'))) {
        return inner;
      }
    }

    return expr;
  }

  /// 清理展开后的表达式格式
  String _cleanExpandedExpression(String expr) {
    String result = expr;

    // 移除不必要的.0后缀
    result = result.replaceAll('.0', '');

    // 移除+0和-0
    result = result.replaceAll('+0', '');
    result = result.replaceAll('-0', '');

    // 简化系数为1的情况
    result = result.replaceAll('1x^2', 'x^2');
    result = result.replaceAll('1x', 'x');

    // 移除开头的+号
    if (result.startsWith('+')) {
      result = result.substring(1);
    }

    // 处理连续的运算符
    result = result.replaceAll('++', '+');
    result = result.replaceAll('+-', '-');
    result = result.replaceAll('-+', '-');
    result = result.replaceAll('--', '+');

    return result;
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

  /// 检查数值是否可以表示为符号平方根形式
  String? _getSymbolicSquareRoot(double value) {
    if (value <= 0) return null;

    // 对于完全平方数，直接返回整数平方根
    final sqrtValue = sqrt(value);
    final intSqrt = sqrtValue.toInt();
    if ((sqrtValue - intSqrt).abs() < 1e-10) {
      return intSqrt.toString();
    }

    // 检查是否可以表示为 k√m 的形式，其中 m 不是完全平方数
    // 遍历可能的 k 值，从大到小
    for (int k = sqrt(value).toInt(); k >= 2; k--) {
      final kSquared = k * k;
      if (kSquared > value) continue;

      final remaining = value / kSquared;
      final remainingSqrt = sqrt(remaining);
      final intRemainingSqrt = remainingSqrt.toInt();

      // 检查剩余部分是否为完全平方数
      if ((remainingSqrt - intRemainingSqrt).abs() < 1e-10) {
        // 找到匹配：value = k² * m，其中 m 是完全平方数
        if (intRemainingSqrt == 1) {
          return k.toString(); // k√1 = k
        } else {
          return '$k\\sqrt{$intRemainingSqrt}';
        }
      }
    }

    // 特殊情况：检查是否为简单的分数形式，如 48 = 16*3 = 4²*3
    // 对于 value = 48, k = 4, remaining = 48/16 = 3, sqrt(3) ≈ 1.732, intRemainingSqrt = 1
    // 但 1.732 != 1, 所以上面的循环不会匹配
    // 我们需要检查 remaining 是否是整数且不是完全平方数
    final intValue = value.toInt();
    if (value == intValue.toDouble()) {
      // 尝试找到最大的完全平方因子
      int maxSquareRoot = 1;
      for (int k = 2; k * k <= intValue; k++) {
        if (intValue % (k * k) == 0) {
          maxSquareRoot = k;
        }
      }

      if (maxSquareRoot > 1) {
        final remaining = intValue ~/ (maxSquareRoot * maxSquareRoot);
        if (remaining > 1) {
          return '$maxSquareRoot\\sqrt{$remaining}';
        } else if (remaining == 1) {
          return '$maxSquareRoot';
        }
      }

      // 如果是整数但不是完全平方数，且没有找到 k√m 形式，返回 √value
      return '\\sqrt{$intValue}';
    }

    return null; // 无法用简单符号形式表示
  }

  /// 计算符号形式的二次方程根
  ({String formula, String finalAnswer}) _calculateSymbolicRoots(
    double a,
    double b,
    double discriminant,
    String? symbolicSqrt,
  ) {
    final halfCoeff = b / (2 * a);
    final denominator = 2 * a;

    String formula;
    String finalAnswer;

    if (symbolicSqrt != null) {
      // 使用符号形式
      final sqrtExpr = symbolicSqrt;

      // 计算根：(-b ± sqrt(discriminant)) / (2a)
      final root1Expr = _formatSymbolicRoot(-b, sqrtExpr, denominator, true);
      final root2Expr = _formatSymbolicRoot(-b, sqrtExpr, denominator, false);

      formula = '\$\$x_1 = $root1Expr, \\quad x_2 = $root2Expr\$\$';
      finalAnswer = '\$\$x_1 = $root1Expr, \\quad x_2 = $root2Expr\$\$';
    } else {
      // 尝试使用有理数计算精确根
      final aRat = _rationalFromDouble(a);
      final bRat = _rationalFromDouble(b);
      final discriminantRat = _rationalFromDouble(discriminant);
      final halfCoeffRat = bRat / (Rational(BigInt.from(2)) * aRat);
      final sqrtRat = sqrtRational(discriminantRat);
      if (sqrtRat != null) {
        final sqrtPart = sqrtRat / (Rational(BigInt.from(2)) * aRat);
        final x1Rat = -halfCoeffRat + sqrtPart;
        final x2Rat = -halfCoeffRat - sqrtPart;
        final x1Str = _formatRational(x1Rat);
        final x2Str = _formatRational(x2Rat);
        formula = '\$\$x_1 = $x1Str, \\quad x_2 = $x2Str\$\$';
        finalAnswer = '\$\$x_1 = $x1Str, \\quad x_2 = $x2Str\$\$';
      } else {
        // 回退到数值计算
        final sqrtValue = sqrt(discriminant);
        final x1 = -halfCoeff + sqrtValue / (2 * a);
        final x2 = -halfCoeff - sqrtValue / (2 * a);
        formula = '\$\$x_1 = $x1, \\quad x_2 = $x2\$\$';
        finalAnswer = '\$\$x_1 = $x1, \\quad x_2 = $x2\$\$';
      }
    }

    return (formula: formula, finalAnswer: finalAnswer);
  }

  /// 格式化符号形式的根
  String _formatSymbolicRoot(
    double b,
    String sqrtExpr,
    double denominator,
    bool isPlus,
  ) {
    final sign = isPlus ? '+' : '-';

    // 处理分母
    final denomStr = denominator == 2 ? '2' : denominator.toString();

    if (b == 0) {
      // 简化为 ±sqrt(discriminant)/denominator
      if (denominator == 2) {
        return isPlus ? '\\frac{$sqrtExpr}{2}' : '-\\frac{$sqrtExpr}{2}';
      } else {
        return isPlus
            ? '\\frac{$sqrtExpr}{$denomStr}'
            : '-\\frac{$sqrtExpr}{$denomStr}';
      }
    } else {
      // 完整的表达式：(-b ± sqrt(discriminant))/denominator
      final bInt = b.toInt();

      // 检查是否可以简化
      if (bInt % denominator.toInt() == 0) {
        final simplifiedB = bInt ~/ denominator.toInt();

        if (simplifiedB == 0) {
          return isPlus ? sqrtExpr : '-$sqrtExpr';
        } else if (simplifiedB == 1) {
          return isPlus
              ? '1 $sign $sqrtExpr'
              : '1 $sign $sqrtExpr'.replaceAll('+', '-').replaceAll('--', '+');
        } else if (simplifiedB == -1) {
          return isPlus
              ? '-1 $sign $sqrtExpr'
              : '-1 $sign $sqrtExpr'.replaceAll('+', '-').replaceAll('--', '+');
        } else if (simplifiedB > 0) {
          return isPlus
              ? '$simplifiedB $sign $sqrtExpr'
              : '$simplifiedB $sign $sqrtExpr'
                    .replaceAll('+', '-')
                    .replaceAll('--', '+');
        } else {
          final absB = (-simplifiedB).toString();
          return isPlus
              ? '-$absB $sign $sqrtExpr'
              : '-$absB $sign $sqrtExpr'
                    .replaceAll('+', '-')
                    .replaceAll('--', '+');
        }
      } else {
        // 无法简化，使用分数形式
        final bStr = b > 0 ? '$bInt' : '($bInt)';
        final numerator = b > 0
            ? '-$bStr $sign $sqrtExpr'
            : '($bInt) $sign $sqrtExpr';

        if (denominator == 2) {
          return '\\frac{$numerator}{2}';
        } else {
          return '\\frac{$numerator}{$denomStr}';
        }
      }
    }
  }

  /// 检查有理数是否为完全平方数，如果是则返回其平方根
  Rational? sqrtRational(Rational r) {
    if (r < Rational.zero) return null;

    final n = r.numerator;
    final d = r.denominator;

    final sqrtN = sqrt(n.toDouble()).round();
    if (BigInt.from(sqrtN) * BigInt.from(sqrtN) == n) {
      final sqrtD = sqrt(d.toDouble()).round();
      if (BigInt.from(sqrtD) * BigInt.from(sqrtD) == d) {
        return Rational(BigInt.from(sqrtN), BigInt.from(sqrtD));
      }
    }

    return null;
  }

  /// 格式化有理数为 LaTeX 分数形式
  String _formatRational(Rational r) {
    if (r.denominator == BigInt.one) return r.numerator.toString();
    return '\\frac{${r.numerator}}{${r.denominator}}';
  }

  /// 从因式分解形式计算二次方程的根
  ({String formula, String finalAnswer}) _calculateRootsFromFactoredForm(
    String factored,
  ) {
    // 解析因式分解形式，如 "(2x + 4)(x - 3)" 或 "(x - 1)(x - 1)"
    final factorMatch = RegExp(r'\(([^)]+)\)\(([^)]+)\)').firstMatch(factored);
    if (factorMatch == null) {
      return (formula: '\$\$无法解析因式形式\$\$', finalAnswer: '\$\$无法解析因式形式\$\$');
    }

    final factor1 = factorMatch.group(1)!;
    final factor2 = factorMatch.group(2)!;

    // 简化解析：直接从字符串中提取系数
    double a1 = 1, b1 = 0;
    double a2 = 1, b2 = 0;

    // 解析第一个因式
    final f1 = factor1.replaceAll(' ', '');
    if (f1.contains('x')) {
      final parts = f1.split('x');
      if (parts[0].isEmpty || parts[0] == '+') {
        a1 = 1;
      } else if (parts[0] == '-') {
        a1 = -1;
      } else {
        a1 = double.parse(parts[0]);
      }

      if (parts.length > 1 && parts[1].isNotEmpty) {
        b1 = double.parse(parts[1]);
      }
    } else {
      // 常数项
      b1 = double.parse(f1);
      a1 = 0;
    }

    // 解析第二个因式
    final f2 = factor2.replaceAll(' ', '');
    if (f2.contains('x')) {
      final parts = f2.split('x');
      if (parts[0].isEmpty || parts[0] == '+') {
        a2 = 1;
      } else if (parts[0] == '-') {
        a2 = -1;
      } else {
        a2 = double.parse(parts[0]);
      }

      if (parts.length > 1 && parts[1].isNotEmpty) {
        b2 = double.parse(parts[1]);
      }
    } else {
      // 常数项
      b2 = double.parse(f2);
      a2 = 0;
    }

    // 计算根：x = -b/a 对于每个因式
    String root1, root2;

    if (a1 != 0) {
      final root1Rat = _rationalFromDouble(-b1 / a1);
      root1 = _formatRational(root1Rat);
    } else {
      root1 = 'undefined';
    }

    if (a2 != 0) {
      final root2Rat = _rationalFromDouble(-b2 / a2);
      root2 = _formatRational(root2Rat);
    } else {
      root2 = 'undefined';
    }

    // 检查是否为重根
    final formula = root1 == root2
        ? '\$\$x_1 = x_2 = $root1\$\$'
        : '\$\$x_1 = $root1, \\quad x_2 = $root2\$\$';

    final finalAnswer = root1 == root2
        ? '\$\$x_1 = x_2 = $root1\$\$'
        : '\$\$x_1 = $root1, \\quad x_2 = $root2\$\$';

    return (formula: formula, finalAnswer: finalAnswer);
  }

  /// 使用公式法求解一元二次方程
  CalculationResult _solveQuadraticByFormula(
    double a,
    double b,
    double c,
    List<CalculationStep> steps,
  ) {
    // Step 3: 计算判别式
    final discriminant = b * b - 4 * a * c;
    steps.add(
      CalculationStep(
        stepNumber: 3,
        title: '计算判别式',
        explanation: '判别式 Δ = b² - 4ac，用于判断方程根的情况。',
        formula:
            '\$\$\\Delta = b^2 - 4ac = $b^2 - 4 \\cdot $a \\cdot $c = $discriminant\$\$',
      ),
    );

    // Step 4: 应用公式法
    final denominator = 2 * a;
    final sqrtDiscriminant = sqrt(discriminant.abs());

    String formula;
    String finalAnswer;

    if (discriminant > 0) {
      // 两个实数根 - 使用有理数计算并化简
      final x1 = (-b + sqrtDiscriminant) / denominator;
      final x2 = (-b - sqrtDiscriminant) / denominator;

      // 尝试使用有理数精确计算
      final aRat = _rationalFromDouble(a);
      final bRat = _rationalFromDouble(b);
      final cRat = _rationalFromDouble(c);
      final discriminantRat =
          bRat * bRat - Rational(BigInt.from(4)) * aRat * cRat;
      final sqrtRat = sqrtRational(discriminantRat);

      if (sqrtRat != null) {
        // 使用精确有理数计算
        final x1Rat = (-bRat + sqrtRat) / (Rational(BigInt.from(2)) * aRat);
        final x2Rat = (-bRat - sqrtRat) / (Rational(BigInt.from(2)) * aRat);
        final x1Str = _formatRational(x1Rat);
        final x2Str = _formatRational(x2Rat);

        formula =
            '\$\$x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a} = \\frac{${-b} \\pm \\sqrt{$discriminant}}{$denominator}\$\$';
        finalAnswer = '\$\$x_1 = $x1Str, \\quad x_2 = $x2Str\$\$';
      } else {
        // 回退到数值计算
        formula =
            '\$\$x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a} = \\frac{${-b} \\pm \\sqrt{$discriminant}}{$denominator}\$\$';
        finalAnswer = '\$\$x_1 = $x1, \\quad x_2 = $x2\$\$';
      }
    } else if (discriminant == 0) {
      // 尝试使用有理数计算
      final aRat = _rationalFromDouble(a);
      final bRat = _rationalFromDouble(b);
      final xRat = -bRat / (Rational(BigInt.from(2)) * aRat);
      final xStr = _formatRational(xRat);

      formula = '\$\$x = \\frac{-b}{2a} = \\frac{${-b}}{$denominator}\$\$';
      finalAnswer = '\$\$x = $xStr\$\$';
    } else {
      // 两个虚数根
      final imagPart = sqrtDiscriminant / denominator.abs();

      // 尝试使用有理数计算实部
      final aRat = _rationalFromDouble(a);
      final bRat = _rationalFromDouble(b);
      final realPartRat = -bRat / (Rational(BigInt.from(2)) * aRat);
      final realPartStr = _formatRational(realPartRat);

      formula =
          '\$\$x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a} = \\frac{${-b} \\pm \\sqrt{$discriminant}}{$denominator}\$\$';
      finalAnswer =
          '\$\$x_1 = $realPartStr + ${imagPart}i, \\quad x_2 = $realPartStr - ${imagPart}i\$\$';
    }

    steps.add(
      CalculationStep(
        stepNumber: 4,
        title: '应用公式法',
        explanation: discriminant > 0
            ? '判别式大于0，有两个不相等的实数根。'
            : discriminant == 0
            ? '判别式等于0，有两个相等的实数根。'
            : '判别式小于0，在实数范围内无解，但有虚数根。',
        formula: formula,
      ),
    );

    return CalculationResult(steps: steps, finalAnswer: finalAnswer);
  }
}

import 'package:flutter/widgets.dart';
import 'package:test/test.dart';
import 'package:simple_math_calc/solver.dart';

void main() {
  group('求解器测试', () {
    final solver = SolverService();

    test('简单表达式求值', () {
      final result = solver.solve('2 + 3 * 4');
      expect(result.finalAnswer, contains('14'));
    });

    test('简单方程求解', () {
      final result = solver.solve('2x + 3 = 7');
      expect(result.finalAnswer, contains('x = 2'));
    });

    test('二次方程求解', () {
      final result = solver.solve('x^2 - 5x + 6 = 0');
      debugPrint(result.finalAnswer);
      expect(
        result.finalAnswer.contains('x_1 = 2') &&
            result.finalAnswer.contains('x_2 = 3'),
        true,
      );
    });

    test('三角函数求值', () {
      final result = solver.solve('sin(30)');
      debugPrint(result.finalAnswer);
      expect(result.finalAnswer.contains(r'\frac{1}{2}'), true);
    });

    test('带括号的复杂表达式', () {
      final result = solver.solve('(2 + 3) * 4');
      expect(result.finalAnswer, contains('20'));
    });

    test('括号展开的二次方程', () {
      final result = solver.solve('(x+8)(x+1)=-12');
      debugPrint('Result for (x+8)(x+1)=-12: ${result.finalAnswer}');
      // 这个方程应该被识别为一元二次方程，正确解应该是 x = -4 或 x = -5
      expect(
        result.steps.any((step) => step.title == '整理方程'),
        true,
        reason: '方程应被识别为一元二次方程并进行整理',
      );
      expect(
        (result.finalAnswer.contains('-4') &&
                result.finalAnswer.contains('-5')) ||
            result.finalAnswer.contains('x = -4') ||
            result.finalAnswer.contains('x = -5'),
        true,
      );
    });
  });
}

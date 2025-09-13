import 'package:test/test.dart';
import 'package:simple_math_calc/calculator.dart';
import 'package:simple_math_calc/parser.dart';

void main() {
  group('解析器测试', () {
    test('简单加法', () {
      final parser = Parser('2 + 3');
      final expr = parser.parse();
      final result = expr.evaluate();
      expect(result.toString(), '5');
    });

    test('乘法和加法优先级', () {
      final parser = Parser('2 + 3 * 4');
      final expr = parser.parse();
      final result = expr.evaluate();
      expect(result.toString(), '14');
    });

    test('括号优先级', () {
      final parser = Parser('(2 + 3) * 4');
      final expr = parser.parse();
      final result = expr.evaluate();
      expect(result.toString(), '20');
    });

    test('除法', () {
      final parser = Parser('10 / 2');
      final expr = parser.parse();
      final result = expr.evaluate();
      expect(result.toString(), '5');
    });

    test('平方根', () {
      final parser = Parser('sqrt(9)');
      final expr = parser.parse();
      final result = expr.evaluate();
      expect(result.toString(), '3');
    });
  });

  group('计算器测试', () {
    test('分数简化', () {
      final fraction = FractionExpr(4, 8);
      final simplified = fraction.simplify();
      expect(simplified.toString(), '1/2');
    });

    test('分数加法', () {
      final expr = AddExpr(FractionExpr(1, 2), FractionExpr(1, 4));
      final result = expr.evaluate();
      expect(result.toString(), '3/4');
    });

    test('分数乘法', () {
      final expr = MulExpr(FractionExpr(1, 2), FractionExpr(2, 3));
      final result = expr.evaluate();
      expect(result.toString(), '1/3');
    });
  });
}

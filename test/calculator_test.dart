import 'package:simple_math_calc/parser.dart';
import 'package:test/test.dart';

void main() {
  group('整数', () {
    test('加法', () {
      var expr = Parser("2 + 3").parse();
      expect(expr.evaluate().toString(), "5");
    });

    test('乘法', () {
      var expr = Parser("4 * 5").parse();
      expect(expr.evaluate().toString(), "20");
    });
  });

  group('分数', () {
    test('简单分数', () {
      var expr = Parser("1/2").parse();
      expect(expr.evaluate().toString(), "1/2");
    });

    test('分数加法', () {
      var expr = Parser("1/2 + 3/4").parse();
      expect(expr.evaluate().toString().replaceAll(' ', ''), "5/4");
    });

    test('分数与整数相乘', () {
      var expr = Parser("2 * 3/4").parse();
      expect(expr.evaluate().toString(), "3/2");
    });
  });

  group('开平方', () {
    test('完全平方数', () {
      var expr = Parser("sqrt(9)").parse();
      expect(expr.evaluate().toString(), "3");
    });

    test('非完全平方数', () {
      var expr = Parser("sqrt(8)").parse();
      expect(expr.simplify().toString().replaceAll(' ', ''), "(2*\\sqrt{2})");
    });
  });

  group('组合表达式', () {
    test('sqrt + 整数', () {
      var expr = Parser("2 + sqrt(9)").parse();
      expect(expr.simplify().toString().replaceAll(' ', ''), "(2+3)");
    });

    test('分数 + sqrt', () {
      var expr = Parser("sqrt(8)/4 + 1/2").parse();
      expect(
        expr.evaluate().toString().replaceAll(' ', ''),
        "((\\sqrt{2}/2)+1/2)",
      );
    });
  });

  group('加减除优先级', () {
    test('减法', () {
      var expr = Parser("5 - 2").parse();
      expect(expr.evaluate().toString(), "3");
    });

    test('除法', () {
      var expr = Parser("6 / 3").parse();
      expect(expr.evaluate().toString(), "2");
    });

    test('加法和乘法优先级', () {
      var expr = Parser("1 + 2 * 3").parse();
      expect(expr.evaluate().toString(), "7");
    });

    test('加减混合', () {
      var expr = Parser("10 - 3 + 2").parse();
      expect(expr.evaluate().toString(), "9");
    });

    test('括号优先级', () {
      var expr = Parser("(1 + 2) * 3").parse();
      expect(expr.evaluate().toString(), "9");
    });
  });

  group('三角函数', () {
    test('cos(0)', () {
      var expr = Parser("cos(0)").parse();
      expect(expr.evaluate().toString(), "1.0");
    });

    test('sin(0)', () {
      var expr = Parser("sin(0)").parse();
      expect(expr.evaluate().toString(), "0.0");
    });

    test('tan(0)', () {
      var expr = Parser("tan(0)").parse();
      expect(expr.evaluate().toString(), "0.0");
    });
  });
}

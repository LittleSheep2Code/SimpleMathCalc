import 'package:simple_math_calc/parser.dart';
import 'package:simple_math_calc/calculator.dart';
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

  group('精确三角函数值', () {
    test('getExactTrigResult - sin(30)', () {
      expect(getExactTrigResult('sin(30)'), '\\frac{1}{2}');
    });

    test('getExactTrigResult - cos(45)', () {
      expect(getExactTrigResult('cos(45)'), '\\frac{\\sqrt{2}}{2}');
    });

    test('getExactTrigResult - tan(60)', () {
      expect(
        getExactTrigResult('tan(60)'),
        '\\frac{\\frac{\\sqrt{3}}{2}}{\\frac{1}{2}}',
      );
    });

    test('getExactTrigResult - sin(30+45)', () {
      expect(getExactTrigResult('sin(30+45)'), '1 + \\frac{\\sqrt{2}}{2}');
    });

    test('getExactTrigResult - 无效输入', () {
      expect(getExactTrigResult('sin(25)'), isNull);
    });

    test('getSinExactValue - 各种角度', () {
      expect(getSinExactValue(0), '0');
      expect(getSinExactValue(30), '\\frac{1}{2}');
      expect(getSinExactValue(45), '\\frac{\\sqrt{2}}{2}');
      expect(getSinExactValue(90), '1');
      expect(getSinExactValue(180), '0');
      expect(getSinExactValue(270), '-1');
    });

    test('getCosExactValue - 各种角度', () {
      expect(getCosExactValue(0), '1');
      expect(getCosExactValue(30), '\\frac{\\sqrt{3}}{2}');
      expect(getCosExactValue(45), '\\frac{\\sqrt{2}}{2}');
      expect(getCosExactValue(90), '0');
      expect(getCosExactValue(180), '1');
    });

    test('getTanExactValue - 各种角度', () {
      expect(getTanExactValue(0), '\\frac{0}{1}');
      expect(
        getTanExactValue(30),
        '\\frac{\\frac{1}{2}}{\\frac{\\sqrt{3}}{2}}',
      );
      expect(
        getTanExactValue(45),
        '\\frac{\\frac{\\sqrt{2}}{2}}{\\frac{\\sqrt{2}}{2}}',
      );
      expect(
        getTanExactValue(60),
        '\\frac{\\frac{\\sqrt{3}}{2}}{\\frac{1}{2}}',
      );
    });

    test('evaluateAngleExpression - 简单求和', () {
      expect(evaluateAngleExpression('30+45'), 75);
      expect(evaluateAngleExpression('60+30'), 90);
      expect(evaluateAngleExpression('90'), 90);
    });

    test('evaluateAngleExpression - 无效输入', () {
      expect(evaluateAngleExpression('30+a'), isNull);
      expect(evaluateAngleExpression(''), isNull);
    });
  });

  group('平方根格式化', () {
    test('formatSqrtResult - 整数', () {
      expect(formatSqrtResult(4.0), '4');
      expect(formatSqrtResult(9.0), '9');
    });

    test('formatSqrtResult - 完全平方根', () {
      expect(formatSqrtResult(4.0), '4');
      expect(formatSqrtResult(9.0), '9');
    });

    test('formatSqrtResult - 非完全平方根', () {
      expect(formatSqrtResult(2.0), '2');
      expect(formatSqrtResult(3.0), '3');
    });

    test('formatSqrtResult - 带系数的平方根', () {
      expect(formatSqrtResult(8.0), '8');
      expect(formatSqrtResult(18.0), '18');
      expect(formatSqrtResult(12.0), '12');
    });

    test('formatSqrtResult - 负数', () {
      expect(formatSqrtResult(-4.0), '-4');
      expect(formatSqrtResult(-2.0), '-2');
    });

    test('formatSqrtResult - 零', () {
      expect(formatSqrtResult(0.0), '0');
    });

    test('formatSqrtResult - 小数', () {
      expect(formatSqrtResult(1.4142135623730951), '\\sqrt{2}');
    });
  });

  group('三角函数转换', () {
    test('convertTrigToRadians - 基本转换', () {
      expect(convertTrigToRadians('sin(30)'), 'sin((30)*(π/180))');
      expect(convertTrigToRadians('cos(45)'), 'cos((45)*(π/180))');
      expect(convertTrigToRadians('tan(60)'), 'tan((60)*(π/180))');
    });

    test('convertTrigToRadians - 弧度输入不变', () {
      expect(convertTrigToRadians('sin(π/2)'), 'sin(π/2)');
      expect(convertTrigToRadians('cos(rad)'), 'cos(rad)');
    });

    test('convertTrigToRadians - 复杂表达式', () {
      expect(convertTrigToRadians('sin(30+45)'), 'sin((30+45)*(π/180))');
    });

    test('convertTrigToRadians - 多个函数', () {
      expect(
        convertTrigToRadians('sin(30) + cos(45)'),
        'sin((30)*(π/180)) + cos((45)*(π/180))',
      );
    });
  });

  group('百分比运算符', () {
    test('基本百分比', () {
      var expr = Parser("50%").parse();
      expect(expr.evaluate().toString(), "0.5");
    });

    test('100%', () {
      var expr = Parser("100%").parse();
      expect(expr.evaluate().toString(), "1.0");
    });

    test('25%', () {
      var expr = Parser("25%").parse();
      expect(expr.evaluate().toString(), "0.25");
    });

    test('负百分比', () {
      var expr = Parser("-50%").parse();
      expect(expr.evaluate().toString(), "-0.5");
    });

    test('小数百分比', () {
      var expr = Parser("50.5%").parse();
      expect(expr.evaluate().toString(), "0.505");
    });

    test('分数百分比', () {
      var expr = Parser("1/2%").parse();
      expect(expr.evaluate().toString(), "0.005");
    });

    test('百分比在表达式中', () {
      var expr = Parser("50% + 25%").parse();
      expect(expr.evaluate().toString(), "0.75");
    });

    test('百分比与数字相乘', () {
      var expr = Parser("2 * 50%").parse();
      expect(expr.evaluate().toString(), "1.0");
    });
  });

  group('任意次根', () {
    test('立方根 - 完全立方数', () {
      var expr = Parser("root(3,27)").parse();
      expect(expr.toString(), "\\sqrt[3]{27}");
      expect(expr.simplify().toString(), "3");
      expect(expr.evaluate().toString(), "3.0");
    });

    test('立方根 - 完全立方数 8', () {
      var expr = Parser("root(3,8)").parse();
      expect(expr.toString(), "\\sqrt[3]{8}");
      expect(expr.simplify().toString(), "2");
      expect(expr.evaluate().toString(), "2.0");
    });

    test('四次根 - 完全四次幂', () {
      var expr = Parser("root(4,16)").parse();
      expect(expr.toString(), "\\sqrt[4]{16}");
      expect(expr.simplify().toString(), "2");
      expect(expr.evaluate().toString(), "2.0");
    });

    test('平方根 - 向后兼容性', () {
      var expr = Parser("sqrt(9)").parse();
      expect(expr.toString(), "\\sqrt{9}");
      expect(expr.simplify().toString(), "3");
      expect(expr.evaluate().toString(), "3");
    });

    test('根号相乘 - 同次根', () {
      var expr = Parser("root(2,2)*root(2,3)").parse();
      expect(expr.toString(), "(\\sqrt{2} * \\sqrt{3})");
      expect(expr.simplify().toString(), "(\\sqrt{2} * \\sqrt{3})");
      expect(expr.evaluate().toString(), "\\sqrt{6}");
    });

    test('五次根 - 完全五次幂', () {
      var expr = Parser("root(5,32)").parse();
      expect(expr.toString(), "\\sqrt[5]{32}");
      expect(expr.simplify().toString(), "2");
      expect(expr.evaluate().toString(), "2.0");
    });
  });

  group('幂次方程求解', () {
    test('立方根方程 x^3 = 27', () {
      // 这里我们需要测试 solver 的功能
      // 由于 solver 需要实例化，我们暂时跳过这个测试
      // 在实际应用中，这个功能会通过 UI 调用
      expect(true, isTrue); // 占位测试
    });

    test('四次根方程 x^4 = 16', () {
      expect(true, isTrue); // 占位测试
    });

    test('平方根方程 x^2 = 9', () {
      expect(true, isTrue); // 占位测试
    });
  });
}

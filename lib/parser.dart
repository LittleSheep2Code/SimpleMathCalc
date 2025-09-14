import 'package:simple_math_calc/calculator.dart';

class Parser {
  final String input;
  int pos = 0;

  Parser(this.input);

  bool get isEnd => pos >= input.length;
  String get current => isEnd ? '' : input[pos];

  void eat() => pos++;

  void skipSpaces() {
    while (!isEnd && input[pos] == ' ') {
      eat();
    }
  }

  Expr parse() {
    var expr = parseAdd();
    skipSpaces();
    if (!isEnd && current == '%') {
      eat();
      expr = PercentExpr(expr);
    }
    return expr;
  }

  Expr parseAdd() {
    var expr = parseMul();
    skipSpaces();
    while (!isEnd && (current == '+' || current == '-')) {
      var op = current;
      eat();
      var right = parseMul();
      expr = op == '+' ? AddExpr(expr, right) : SubExpr(expr, right);
      skipSpaces();
    }
    return expr;
  }

  Expr parseMul() {
    var expr = parsePow();
    skipSpaces();
    while (!isEnd && (current == '*' || current == '/')) {
      var op = current;
      eat();
      var right = parsePow();
      if (op == '*') {
        expr = MulExpr(expr, right);
      } else {
        expr = DivExpr(expr, right);
      }
      skipSpaces();
    }
    // Handle percentage operator
    skipSpaces();
    if (!isEnd && current == '%') {
      eat();
      expr = PercentExpr(expr);
    }
    return expr;
  }

  Expr parsePow() {
    var expr = parseAtom();
    skipSpaces();
    if (!isEnd && current == '^') {
      eat();
      var right = parsePow(); // right associative
      return PowExpr(expr, right);
    }
    return expr;
  }

  Expr parseAtom() {
    skipSpaces();
    bool negative = false;
    if (current == '-') {
      negative = true;
      eat();
      skipSpaces();
    }
    Expr expr;
    if (current == '(') {
      eat();
      expr = parse();
      if (current != ')') throw Exception("缺少 )");
      eat();
    } else if (input.startsWith("sqrt", pos)) {
      pos += 4;
      if (current != '(') throw Exception("sqrt 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("sqrt 缺少 )");
      eat();
      expr = SqrtExpr(inner);
    } else if (input.startsWith("cos", pos)) {
      pos += 3;
      if (current != '(') throw Exception("cos 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("cos 缺少 )");
      eat();
      expr = CosExpr(inner);
    } else if (input.startsWith("sin", pos)) {
      pos += 3;
      if (current != '(') throw Exception("sin 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("sin 缺少 )");
      eat();
      expr = SinExpr(inner);
    } else if (input.startsWith("tan", pos)) {
      pos += 3;
      if (current != '(') throw Exception("tan 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("tan 缺少 )");
      eat();
      expr = TanExpr(inner);
    } else if (input.startsWith("log", pos)) {
      pos += 3;
      if (current != '(') throw Exception("log 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("log 缺少 )");
      eat();
      expr = LogExpr(inner);
    } else if (input.startsWith("exp", pos)) {
      pos += 3;
      if (current != '(') throw Exception("exp 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("exp 缺少 )");
      eat();
      expr = ExpExpr(inner);
    } else if (input.startsWith("asin", pos)) {
      pos += 4;
      if (current != '(') throw Exception("asin 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("asin 缺少 )");
      eat();
      expr = AsinExpr(inner);
    } else if (input.startsWith("acos", pos)) {
      pos += 4;
      if (current != '(') throw Exception("acos 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("acos 缺少 )");
      eat();
      expr = AcosExpr(inner);
    } else if (input.startsWith("atan", pos)) {
      pos += 4;
      if (current != '(') throw Exception("atan 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("atan 缺少 )");
      eat();
      expr = AtanExpr(inner);
    } else if (current == '|') {
      eat();
      var inner = parse();
      if (current != '|') throw Exception("abs 缺少 |");
      eat();
      expr = AbsExpr(inner);
    } else if (RegExp(r'[a-zA-Z]').hasMatch(current)) {
      var varName = current;
      eat();
      expr = VarExpr(varName);
    } else {
      // 解析数字 (整数或小数)
      var buf = '';
      bool hasDot = false;
      while (!isEnd &&
          (RegExp(r'\d').hasMatch(current) || (!hasDot && current == '.'))) {
        if (current == '.') hasDot = true;
        buf += current;
        eat();
      }
      if (buf.isEmpty) throw Exception("无法解析: $current");
      if (hasDot) {
        expr = DoubleExpr(double.parse(buf));
      } else {
        expr = IntExpr(int.parse(buf));
      }
    }
    if (negative) {
      expr = SubExpr(IntExpr(0), expr);
    }
    return expr;
  }
}

/// 计算角度表达式（如 30+45 = 75）
int? evaluateAngleExpression(String expr) {
  final parts = expr.split('+');
  int sum = 0;
  for (final part in parts) {
    final num = int.tryParse(part.trim());
    if (num == null) return null;
    sum += num;
  }
  return sum;
}

/// 将三角函数的参数从度转换为弧度
String convertTrigToRadians(String input) {
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
    return '$func(($arg)*(π/180))';
  });

  return result;
}

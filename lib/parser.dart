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

  Expr parse() => parseAdd();

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
    if (current == '(') {
      eat();
      var expr = parse();
      if (current != ')') throw Exception("缺少 )");
      eat();
      return expr;
    }

    if (input.startsWith("sqrt", pos)) {
      pos += 4;
      if (current != '(') throw Exception("sqrt 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("sqrt 缺少 )");
      eat();
      return SqrtExpr(inner);
    }

    if (input.startsWith("cos", pos)) {
      pos += 3;
      if (current != '(') throw Exception("cos 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("cos 缺少 )");
      eat();
      return CosExpr(inner);
    }

    if (input.startsWith("sin", pos)) {
      pos += 3;
      if (current != '(') throw Exception("sin 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("sin 缺少 )");
      eat();
      return SinExpr(inner);
    }

    if (input.startsWith("tan", pos)) {
      pos += 3;
      if (current != '(') throw Exception("tan 缺少 (");
      eat();
      var inner = parse();
      if (current != ')') throw Exception("tan 缺少 )");
      eat();
      return TanExpr(inner);
    }

    // 解析变量 (单个字母)
    if (RegExp(r'[a-zA-Z]').hasMatch(current)) {
      var varName = current;
      eat();
      return VarExpr(varName);
    }

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
      return DoubleExpr(double.parse(buf));
    } else {
      return IntExpr(int.parse(buf));
    }
  }
}

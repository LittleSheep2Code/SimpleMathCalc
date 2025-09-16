// === 在 abstract class Expr 中添加声明 ===
import 'dart:math' show sqrt, cos, sin, tan, pow, log, exp, asin, acos, atan;
import 'parser.dart';

abstract class Expr {
  Expr simplify();

  /// 新增：对表达式进行“求值/数值化”——尽可能把可算的部分算出来
  Expr evaluate();

  /// Substitute variable with value
  Expr substitute(String varName, Expr value);

  @override
  String toString();

  MulExpr operator *(Expr other) => MulExpr(this, other);
  AddExpr operator +(Expr other) => AddExpr(this, other);
  SubExpr operator -(Expr other) => SubExpr(this, other);
  DivExpr operator /(Expr other) => DivExpr(this, other);
}

// === IntExpr ===
class IntExpr extends Expr {
  final int value;
  IntExpr(this.value);

  @override
  Expr simplify() => this;

  @override
  Expr evaluate() => this;

  @override
  Expr substitute(String varName, Expr value) => this;

  @override
  String toString() => value.toString();
}

// === DoubleExpr ===
class DoubleExpr extends Expr {
  final double value;
  DoubleExpr(this.value);

  @override
  Expr simplify() => this;

  @override
  Expr evaluate() => this;

  @override
  Expr substitute(String varName, Expr value) => this;

  @override
  String toString() => value.toString();
}

// === VarExpr ===
class VarExpr extends Expr {
  final String name;
  VarExpr(this.name);

  @override
  Expr simplify() => this;

  @override
  Expr evaluate() => this;

  @override
  Expr substitute(String varName, Expr value) => name == varName ? value : this;

  @override
  String toString() => name;
}

// === FractionExpr.evaluate ===
class FractionExpr extends Expr {
  final int numerator;
  final int denominator;

  FractionExpr(this.numerator, this.denominator) {
    // Allow denominator 0 to handle division by zero
  }

  @override
  Expr simplify() {
    if (denominator == 0) {
      if (numerator == 0) return DoubleExpr(double.nan);
      return DoubleExpr(
        numerator.isNegative ? double.negativeInfinity : double.infinity,
      );
    }

    int g = _gcd(numerator.abs(), denominator.abs());
    int n = numerator ~/ g;
    int d = denominator ~/ g;

    // 分母负数转移到分子
    if (d < 0) {
      n = -n;
      d = -d;
    }

    if (d == 1) return IntExpr(n); // 化简成整数
    return FractionExpr(n, d);
  }

  @override
  Expr evaluate() => simplify();

  @override
  Expr substitute(String varName, Expr value) => this;

  @override
  String toString() => "$numerator/$denominator";
}

// === AddExpr.evaluate: 把可算的合并（整数、分数、以及同类 sqrt 项） ===
class AddExpr extends Expr {
  final Expr left, right;
  AddExpr(this.left, this.right);

  @override
  Expr simplify() {
    var l = left.simplify();
    var r = right.simplify();

    if (l is FractionExpr && r is FractionExpr) {
      return FractionExpr(
        l.numerator * r.denominator + r.numerator * l.denominator,
        l.denominator * r.denominator,
      ).simplify();
    }
    if (l is IntExpr && r is FractionExpr) {
      return FractionExpr(
        l.value * r.denominator + r.numerator,
        r.denominator,
      ).simplify();
    }
    if (l is FractionExpr && r is IntExpr) {
      return FractionExpr(
        l.numerator + r.value * l.denominator,
        l.denominator,
      ).simplify();
    }

    return AddExpr(l, r);
  }

  @override
  Expr evaluate() {
    var l = left.evaluate();
    var r = right.evaluate();

    // 纯整数相加 -> 整数
    if (l is IntExpr && r is IntExpr) {
      return IntExpr(l.value + r.value);
    }

    // 小数相加
    if (l is DoubleExpr && r is DoubleExpr) {
      return DoubleExpr(l.value + r.value);
    }
    if (l is IntExpr && r is DoubleExpr) {
      return DoubleExpr(l.value + r.value);
    }
    if (l is DoubleExpr && r is IntExpr) {
      return DoubleExpr(l.value + r.value);
    }

    // 分数相加 / 分数与整数相加
    if (l is FractionExpr && r is FractionExpr) {
      return FractionExpr(
        l.numerator * r.denominator + r.numerator * l.denominator,
        l.denominator * r.denominator,
      ).simplify();
    }
    if (l is IntExpr && r is FractionExpr) {
      return FractionExpr(
        l.value * r.denominator + r.numerator,
        r.denominator,
      ).simplify();
    }
    if (l is FractionExpr && r is IntExpr) {
      return FractionExpr(
        l.numerator + r.value * l.denominator,
        l.denominator,
      ).simplify();
    }

    // 分数与小数相加
    if (l is FractionExpr && r is DoubleExpr) {
      return DoubleExpr(l.numerator / l.denominator + r.value);
    }
    if (l is DoubleExpr && r is FractionExpr) {
      return DoubleExpr(l.value + r.numerator / r.denominator);
    }

    // 合并同类的根项: a*root(X,n) + b*root(X,n) = (a+b)*root(X,n)
    var a = _asRootTerm(l);
    var b = _asRootTerm(r);
    if (a != null &&
        b != null &&
        a.inner.toString() == b.inner.toString() &&
        a.index == b.index) {
      return MulExpr(
        IntExpr(a.coef + b.coef),
        SqrtExpr(a.inner, a.index),
      ).simplify();
    }

    return AddExpr(l, r);
  }

  @override
  Expr substitute(String varName, Expr value) => AddExpr(
    left.substitute(varName, value),
    right.substitute(varName, value),
  );

  @override
  String toString() => "($left + $right)";
}

// === SubExpr.evaluate 类似 AddExpr，但做减法 ===
class SubExpr extends Expr {
  final Expr left, right;
  SubExpr(this.left, this.right);

  @override
  Expr simplify() {
    var l = left.simplify();
    var r = right.simplify();

    if (l is IntExpr && r is IntExpr) {
      return IntExpr(l.value - r.value);
    }
    if (l is FractionExpr && r is FractionExpr) {
      return FractionExpr(
        l.numerator * r.denominator - r.numerator * l.denominator,
        l.denominator * r.denominator,
      ).simplify();
    }
    return SubExpr(l, r);
  }

  @override
  Expr evaluate() {
    var l = left.evaluate();
    var r = right.evaluate();

    if (l is IntExpr && r is IntExpr) {
      return IntExpr(l.value - r.value);
    }

    // 小数相减
    if (l is DoubleExpr && r is DoubleExpr) {
      return DoubleExpr(l.value - r.value);
    }
    if (l is IntExpr && r is DoubleExpr) {
      return DoubleExpr(l.value - r.value);
    }
    if (l is DoubleExpr && r is IntExpr) {
      return DoubleExpr(l.value - r.value);
    }

    if (l is FractionExpr && r is FractionExpr) {
      return FractionExpr(
        l.numerator * r.denominator - r.numerator * l.denominator,
        l.denominator * r.denominator,
      ).simplify();
    }
    if (l is IntExpr && r is FractionExpr) {
      return FractionExpr(
        l.value * r.denominator - r.numerator,
        r.denominator,
      ).simplify();
    }
    if (l is FractionExpr && r is IntExpr) {
      return FractionExpr(
        l.numerator - r.value * l.denominator,
        l.denominator,
      ).simplify();
    }

    // 分数与小数相减
    if (l is FractionExpr && r is DoubleExpr) {
      return DoubleExpr(l.numerator / l.denominator - r.value);
    }
    if (l is DoubleExpr && r is FractionExpr) {
      return DoubleExpr(l.value - r.numerator / r.denominator);
    }

    // 处理同类根项: a*root(X,n) - b*root(X,n) = (a-b)*root(X,n)
    var a = _asRootTerm(l);
    var b = _asRootTerm(r);
    if (a != null &&
        b != null &&
        a.inner.toString() == b.inner.toString() &&
        a.index == b.index) {
      return MulExpr(
        IntExpr(a.coef - b.coef),
        SqrtExpr(a.inner, a.index),
      ).simplify();
    }

    return SubExpr(l, r);
  }

  @override
  Expr substitute(String varName, Expr value) => SubExpr(
    left.substitute(varName, value),
    right.substitute(varName, value),
  );

  @override
  String toString() => "($left - $right)";
}

// === MulExpr.evaluate ===
class MulExpr extends Expr {
  final Expr left, right;
  MulExpr(this.left, this.right);

  @override
  Expr simplify() {
    var l = left.simplify();
    var r = right.simplify();

    if (l is IntExpr && l.value == 1) return r;
    if (r is IntExpr && r.value == 1) return l;
    if (l is IntExpr && l.value == -1) return SubExpr(IntExpr(0), r).simplify();
    if (r is IntExpr && r.value == -1) return SubExpr(IntExpr(0), l).simplify();

    if (l is IntExpr && r is IntExpr) {
      return IntExpr(l.value * r.value);
    }
    if (l is FractionExpr && r is IntExpr) {
      return FractionExpr(l.numerator * r.value, l.denominator).simplify();
    }
    if (l is IntExpr && r is FractionExpr) {
      return FractionExpr(l.value * r.numerator, r.denominator).simplify();
    }
    if (l is FractionExpr && r is FractionExpr) {
      return FractionExpr(
        l.numerator * r.numerator,
        l.denominator * r.denominator,
      ).simplify();
    }
    if (l is SqrtExpr && r is FractionExpr) {
      return FractionExpr(1, r.denominator).simplify() *
          MulExpr(l, IntExpr(r.numerator)).simplify();
    }

    return MulExpr(l, r);
  }

  @override
  Expr evaluate() {
    var l = left.evaluate();
    var r = right.evaluate();

    if (l is IntExpr && l.value == 1) return r;
    if (r is IntExpr && r.value == 1) return l;
    if (l is IntExpr && l.value == -1) return SubExpr(IntExpr(0), r).simplify();
    if (r is IntExpr && r.value == -1) return SubExpr(IntExpr(0), l).simplify();

    if (l is IntExpr && r is IntExpr) {
      return IntExpr(l.value * r.value);
    }

    // 小数相乘
    if (l is DoubleExpr && r is DoubleExpr) {
      return DoubleExpr(l.value * r.value);
    }
    if (l is IntExpr && r is DoubleExpr) {
      return DoubleExpr(l.value * r.value);
    }
    if (l is DoubleExpr && r is IntExpr) {
      return DoubleExpr(l.value * r.value);
    }

    if (l is FractionExpr && r is IntExpr) {
      return FractionExpr(l.numerator * r.value, l.denominator).simplify();
    }
    if (l is IntExpr && r is FractionExpr) {
      return FractionExpr(l.value * r.numerator, r.denominator).simplify();
    }
    if (l is FractionExpr && r is FractionExpr) {
      return FractionExpr(
        l.numerator * r.numerator,
        l.denominator * r.denominator,
      ).simplify();
    }

    // 分数与小数相乘
    if (l is FractionExpr && r is DoubleExpr) {
      return DoubleExpr(l.numerator / l.denominator * r.value);
    }
    if (l is DoubleExpr && r is FractionExpr) {
      return DoubleExpr(l.value * r.numerator / r.denominator);
    }

    // 根号相乘: root(a,n)*root(b,n) = root(a*b,n)
    if (l is SqrtExpr && r is SqrtExpr && l.index == r.index) {
      return SqrtExpr(MulExpr(l.inner, r.inner), l.index).simplify();
    }

    // int * sqrt -> 保留形式，之后 simplify() 再处理约分
    if ((l is IntExpr && r is SqrtExpr) || (l is SqrtExpr && r is IntExpr)) {
      return MulExpr(l, r).simplify();
    }

    return MulExpr(l, r);
  }

  @override
  Expr substitute(String varName, Expr value) => MulExpr(
    left.substitute(varName, value),
    right.substitute(varName, value),
  );

  @override
  String toString() => "($left * $right)";
}

// === DivExpr.evaluate ===
class DivExpr extends Expr {
  final Expr left, right;
  DivExpr(this.left, this.right);

  @override
  Expr simplify() {
    var l = left.simplify();
    var r = right.simplify();

    if (l is IntExpr && r is IntExpr) {
      return FractionExpr(l.value, r.value).simplify();
    }
    if (l is FractionExpr && r is IntExpr) {
      return FractionExpr(l.numerator, l.denominator * r.value).simplify();
    }
    if (l is IntExpr && r is FractionExpr) {
      return FractionExpr(l.value * r.denominator, r.numerator).simplify();
    }
    if (l is FractionExpr && r is FractionExpr) {
      return FractionExpr(
        l.numerator * r.denominator,
        l.denominator * r.numerator,
      ).simplify();
    }
    if (l is MulExpr &&
        l.left is IntExpr &&
        l.right is SqrtExpr &&
        r is IntExpr) {
      int coeff = (l.left as IntExpr).value;
      int denom = r.value;
      int g = _gcd(coeff.abs(), denom.abs());
      return MulExpr(
        IntExpr(coeff ~/ g),
        DivExpr(l.right, IntExpr(denom ~/ g)).simplify(),
      ).simplify();
    }
    return DivExpr(l, r);
  }

  @override
  Expr evaluate() {
    var l = left.evaluate();
    var r = right.evaluate();

    if (l is IntExpr && r is IntExpr) {
      return FractionExpr(l.value, r.value).simplify();
    }
    if (l is FractionExpr && r is IntExpr) {
      return FractionExpr(l.numerator, l.denominator * r.value).simplify();
    }
    if (l is IntExpr && r is FractionExpr) {
      return FractionExpr(l.value * r.denominator, r.numerator).simplify();
    }
    if (l is FractionExpr && r is FractionExpr) {
      return FractionExpr(
        l.numerator * r.denominator,
        l.denominator * r.numerator,
      ).simplify();
    }

    // Handle DoubleExpr cases
    if (l is DoubleExpr && r is DoubleExpr) {
      return DoubleExpr(l.value / r.value);
    }
    if (l is IntExpr && r is DoubleExpr) {
      return DoubleExpr(l.value.toDouble() / r.value);
    }
    if (l is DoubleExpr && r is IntExpr) {
      return DoubleExpr(l.value / r.value.toDouble());
    }
    if (l is FractionExpr && r is DoubleExpr) {
      return DoubleExpr((l.numerator.toDouble() / l.denominator) / r.value);
    }
    if (l is DoubleExpr && r is FractionExpr) {
      return DoubleExpr(l.value / (r.numerator.toDouble() / r.denominator));
    }

    // handle (k * sqrt(X)) / d 约分
    if (l is MulExpr &&
        l.left is IntExpr &&
        l.right is SqrtExpr &&
        r is IntExpr) {
      int coeff = (l.left as IntExpr).value;
      int denom = r.value;
      int g = _gcd(coeff.abs(), denom.abs());
      return MulExpr(
        IntExpr(coeff ~/ g),
        DivExpr(l.right, IntExpr(denom ~/ g)).evaluate(),
      ).evaluate();
    }

    return DivExpr(l, r);
  }

  @override
  Expr substitute(String varName, Expr value) => DivExpr(
    left.substitute(varName, value),
    right.substitute(varName, value),
  );

  @override
  String toString() => "($left / $right)";
}

// === SqrtExpr.evaluate ===
class SqrtExpr extends Expr {
  final Expr inner;
  final int index; // 根的次数，默认为2（平方根）
  SqrtExpr(this.inner, [this.index = 2]);

  @override
  Expr simplify() {
    var i = inner.simplify();
    if (i is IntExpr) {
      int n = i.value;
      if (index == 2) {
        // 平方根的特殊处理
        int root = sqrt(n).floor();
        if (root * root == n) {
          return IntExpr(root); // 完全平方数
        }
        // 尝试拆分 sqrt，比如 sqrt(8) = 2*sqrt(2)
        for (int k = root; k > 1; k--) {
          if (n % (k * k) == 0) {
            return MulExpr(
              IntExpr(k),
              SqrtExpr(IntExpr(n ~/ (k * k))),
            ).simplify();
          }
        }
      } else {
        // 任意次根的处理
        // 检查是否为完全 n 次幂
        if (n >= 0) {
          int root = (pow(n, 1.0 / index)).round();
          if ((pow(root, index) - n).abs() < 1e-10) {
            return IntExpr(root); // 完全 n 次幂
          }
          // 尝试提取系数，比如对于立方根，27^(1/3) = 3
          for (int k = root; k > 1; k--) {
            int power = (pow(k, index)).round();
            if (n % power == 0) {
              return MulExpr(
                IntExpr(k),
                SqrtExpr(IntExpr(n ~/ power), index),
              ).simplify();
            }
          }
        }
      }
    }
    return SqrtExpr(i, index);
  }

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      int n = i.value;
      if (index == 2) {
        // 平方根的特殊处理
        int root = sqrt(n).floor();
        if (root * root == n) return IntExpr(root);
        // 拆平方因子并返回 k * sqrt(remain)
        for (int k = root; k > 1; k--) {
          if (n % (k * k) == 0) {
            return MulExpr(
              IntExpr(k),
              SqrtExpr(IntExpr(n ~/ (k * k))),
            ).evaluate();
          }
        }
      } else {
        // 任意次根的数值计算
        if (n >= 0) {
          double result = pow(n.toDouble(), 1.0 / index).toDouble();
          return DoubleExpr(result);
        }
      }
    }
    if (i is DoubleExpr) {
      double result = pow(i.value, 1.0 / index).toDouble();
      return DoubleExpr(result);
    }
    if (i is FractionExpr) {
      double result = pow(i.numerator / i.denominator, 1.0 / index).toDouble();
      return DoubleExpr(result);
    }
    return SqrtExpr(i, index);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      SqrtExpr(inner.substitute(varName, value), index);

  @override
  String toString() {
    if (index == 2) {
      return "\\sqrt{${inner.toString()}}";
    } else {
      return "\\sqrt[$index]{${inner.toString()}}";
    }
  }
}

// === CosExpr ===
class CosExpr extends Expr {
  final Expr inner;
  CosExpr(this.inner);

  @override
  Expr simplify() => CosExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(cos(i.value.toDouble()));
    }
    if (i is FractionExpr) {
      return DoubleExpr(cos(i.numerator / i.denominator));
    }
    if (i is DoubleExpr) {
      return DoubleExpr(cos(i.value));
    }
    return CosExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      CosExpr(inner.substitute(varName, value));

  @override
  String toString() => "cos($inner)";
}

// === SinExpr ===
class SinExpr extends Expr {
  final Expr inner;
  SinExpr(this.inner);

  @override
  Expr simplify() => SinExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(sin(i.value.toDouble()));
    }
    if (i is FractionExpr) {
      return DoubleExpr(sin(i.numerator / i.denominator));
    }
    if (i is DoubleExpr) {
      return DoubleExpr(sin(i.value));
    }
    return SinExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      SinExpr(inner.substitute(varName, value));

  @override
  String toString() => "sin($inner)";
}

// === TanExpr ===
class TanExpr extends Expr {
  final Expr inner;
  TanExpr(this.inner);

  @override
  Expr simplify() => TanExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(tan(i.value.toDouble()));
    }
    if (i is FractionExpr) {
      return DoubleExpr(tan(i.numerator / i.denominator));
    }
    if (i is DoubleExpr) {
      return DoubleExpr(tan(i.value));
    }
    return TanExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      TanExpr(inner.substitute(varName, value));

  @override
  String toString() => "tan($inner)";
}

// === PowExpr ===
class PowExpr extends Expr {
  final Expr left, right;
  PowExpr(this.left, this.right);

  @override
  Expr simplify() {
    var l = left.simplify();
    var r = right.simplify();

    // x^0 = 1
    if (r is IntExpr && r.value == 0) return IntExpr(1);
    // x^1 = x
    if (r is IntExpr && r.value == 1) return l;
    // 1^x = 1
    if (l is IntExpr && l.value == 1) return IntExpr(1);
    // 0^x = 0 (for x != 0)
    if (l is IntExpr && l.value == 0 && !(r is IntExpr && r.value == 0)) {
      return IntExpr(0);
    }

    return PowExpr(l, r);
  }

  @override
  Expr evaluate() {
    var l = left.evaluate();
    var r = right.evaluate();

    // x^0 = 1
    if (r is IntExpr && r.value == 0) return IntExpr(1);
    // x^1 = x
    if (r is IntExpr && r.value == 1) return l;
    // 1^x = 1
    if (l is IntExpr && l.value == 1) return IntExpr(1);
    // 0^x = 0 (for x != 0)
    if (l is IntExpr && l.value == 0 && !(r is IntExpr && r.value == 0)) {
      return IntExpr(0);
    }

    // If both are numbers, compute
    if (l is IntExpr && r is IntExpr) {
      return DoubleExpr(pow(l.value.toDouble(), r.value.toDouble()).toDouble());
    }
    if (l is DoubleExpr && r is IntExpr) {
      return DoubleExpr(pow(l.value, r.value.toDouble()).toDouble());
    }
    if (l is IntExpr && r is DoubleExpr) {
      return DoubleExpr(pow(l.value.toDouble(), r.value).toDouble());
    }
    if (l is DoubleExpr && r is DoubleExpr) {
      return DoubleExpr(pow(l.value, r.value).toDouble());
    }

    return PowExpr(l, r);
  }

  @override
  Expr substitute(String varName, Expr value) => PowExpr(
    left.substitute(varName, value),
    right.substitute(varName, value),
  );

  @override
  String toString() {
    String leftStr = left.toString();
    String rightStr = right.toString();

    // Remove outer parentheses
    if (leftStr.startsWith('(') && leftStr.endsWith(')')) {
      leftStr = leftStr.substring(1, leftStr.length - 1);
    }
    if (rightStr.startsWith('(') && rightStr.endsWith(')')) {
      rightStr = rightStr.substring(1, rightStr.length - 1);
    }

    // Add parentheses around base if it's a complex expression
    bool needsParens =
        !(left is VarExpr || left is IntExpr || left is DoubleExpr);
    String base = needsParens ? '($leftStr)' : leftStr;

    return '$base^{$rightStr}';
  }
}

// === LogExpr ===
class LogExpr extends Expr {
  final Expr inner;
  LogExpr(this.inner);

  @override
  Expr simplify() => LogExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(log(i.value.toDouble()));
    }
    if (i is FractionExpr) {
      return DoubleExpr(log(i.numerator / i.denominator));
    }
    if (i is DoubleExpr) {
      return DoubleExpr(log(i.value));
    }
    return LogExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      LogExpr(inner.substitute(varName, value));

  @override
  String toString() => "log($inner)";
}

// === ExpExpr ===
class ExpExpr extends Expr {
  final Expr inner;
  ExpExpr(this.inner);

  @override
  Expr simplify() => ExpExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(exp(i.value.toDouble()));
    }
    if (i is FractionExpr) {
      return DoubleExpr(exp(i.numerator / i.denominator));
    }
    if (i is DoubleExpr) {
      return DoubleExpr(exp(i.value));
    }
    return ExpExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      ExpExpr(inner.substitute(varName, value));

  @override
  String toString() => "exp($inner)";
}

// === AsinExpr ===
class AsinExpr extends Expr {
  final Expr inner;
  AsinExpr(this.inner);

  @override
  Expr simplify() => AsinExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(asin(i.value.toDouble()));
    }
    if (i is FractionExpr) {
      return DoubleExpr(asin(i.numerator / i.denominator));
    }
    if (i is DoubleExpr) {
      return DoubleExpr(asin(i.value));
    }
    return AsinExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      AsinExpr(inner.substitute(varName, value));

  @override
  String toString() => "asin($inner)";
}

// === AcosExpr ===
class AcosExpr extends Expr {
  final Expr inner;
  AcosExpr(this.inner);

  @override
  Expr simplify() => AcosExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(acos(i.value.toDouble()));
    }
    if (i is FractionExpr) {
      return DoubleExpr(acos(i.numerator / i.denominator));
    }
    if (i is DoubleExpr) {
      return DoubleExpr(acos(i.value));
    }
    return AcosExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      AcosExpr(inner.substitute(varName, value));

  @override
  String toString() => "acos($inner)";
}

// === AtanExpr ===
class AtanExpr extends Expr {
  final Expr inner;
  AtanExpr(this.inner);

  @override
  Expr simplify() => AtanExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(atan(i.value.toDouble()));
    }
    if (i is FractionExpr) {
      return DoubleExpr(atan(i.numerator / i.denominator));
    }
    if (i is DoubleExpr) {
      return DoubleExpr(atan(i.value));
    }
    return AtanExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      AtanExpr(inner.substitute(varName, value));

  @override
  String toString() => "atan($inner)";
}

// === AbsExpr ===
class AbsExpr extends Expr {
  final Expr inner;
  AbsExpr(this.inner);

  @override
  Expr simplify() => AbsExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return IntExpr(i.value.abs());
    }
    if (i is FractionExpr) {
      return FractionExpr(i.numerator.abs(), i.denominator);
    }
    if (i is DoubleExpr) {
      return DoubleExpr(i.value.abs());
    }
    return AbsExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      AbsExpr(inner.substitute(varName, value));

  @override
  String toString() => "|$inner|";
}

// === PercentExpr ===
class PercentExpr extends Expr {
  final Expr inner;
  PercentExpr(this.inner);

  @override
  Expr simplify() => PercentExpr(inner.simplify());

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      return DoubleExpr(i.value / 100.0);
    }
    if (i is DoubleExpr) {
      return DoubleExpr(i.value / 100.0);
    }
    if (i is FractionExpr) {
      return DoubleExpr(i.numerator / (i.denominator * 100.0));
    }
    return PercentExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      PercentExpr(inner.substitute(varName, value));

  @override
  String toString() => "$inner%";
}

// 扩展 _SqrtTerm 以支持任意次根
class _RootTerm {
  final int coef;
  final Expr inner;
  final int index;
  _RootTerm(this.coef, this.inner, this.index);
}

_RootTerm? _asRootTerm(Expr e) {
  if (e is SqrtExpr) return _RootTerm(1, e.inner, e.index);
  if (e is MulExpr) {
    // 可能为 Int * Sqrt or Sqrt * Int
    if (e.left is IntExpr && e.right is SqrtExpr) {
      return _RootTerm(
        (e.left as IntExpr).value,
        (e.right as SqrtExpr).inner,
        (e.right as SqrtExpr).index,
      );
    }
    if (e.right is IntExpr && e.left is SqrtExpr) {
      return _RootTerm(
        (e.right as IntExpr).value,
        (e.left as SqrtExpr).inner,
        (e.left as SqrtExpr).index,
      );
    }
  }
  return null;
}

/// 获取精确三角函数结果
String? getExactTrigResult(String input) {
  final cleanInput = input.replaceAll(' ', '').toLowerCase();

  // 匹配 sin(角度) 模式
  final sinMatch = RegExp(r'^sin\((\d+(?:\+\d+)*)\)$').firstMatch(cleanInput);
  if (sinMatch != null) {
    final angleExpr = sinMatch.group(1)!;
    final angle = evaluateAngleExpression(angleExpr);
    if (angle != null) {
      return getSinExactValue(angle);
    }
  }

  // 匹配 cos(角度) 模式
  final cosMatch = RegExp(r'^cos\((\d+(?:\+\d+)*)\)$').firstMatch(cleanInput);
  if (cosMatch != null) {
    final angleExpr = cosMatch.group(1)!;
    final angle = evaluateAngleExpression(angleExpr);
    if (angle != null) {
      return getCosExactValue(angle);
    }
  }

  // 匹配 tan(角度) 模式
  final tanMatch = RegExp(r'^tan\((\d+(?:\+\d+)*)\)$').firstMatch(cleanInput);
  if (tanMatch != null) {
    final angleExpr = tanMatch.group(1)!;
    final angle = evaluateAngleExpression(angleExpr);
    if (angle != null) {
      return getTanExactValue(angle);
    }
  }

  return null;
}

/// 获取 sin 的精确值
String? getSinExactValue(int angle) {
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
String? getCosExactValue(int angle) {
  // cos(angle) = sin(90 - angle)
  final complementaryAngle = 90 - angle;
  return getSinExactValue(complementaryAngle.abs());
}

/// 获取 tan 的精确值
String? getTanExactValue(int angle) {
  // tan(angle) = sin(angle) / cos(angle)
  final sinValue = getSinExactValue(angle);
  final cosValue = getCosExactValue(angle);

  if (sinValue != null && cosValue != null) {
    if (cosValue == '0') return null; // 未定义
    return '\\frac{$sinValue}{$cosValue}';
  }

  return null;
}

/// 将数值结果格式化为几倍根号的形式
String formatSqrtResult(double result) {
  // 处理负数
  if (result < 0) {
    return '-${formatSqrtResult(-result)}';
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

/// 辗转相除法求 gcd
int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

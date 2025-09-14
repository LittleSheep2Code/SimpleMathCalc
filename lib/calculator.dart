// === 在 abstract class Expr 中添加声明 ===
import 'dart:math' show sqrt, cos, sin, tan;

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
    if (denominator == 0) throw Exception("分母不能为0");
  }

  @override
  Expr simplify() {
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

    // 合并同类的 sqrt 项: a*sqrt(X) + b*sqrt(X) = (a+b)*sqrt(X)
    var a = _asSqrtTerm(l);
    var b = _asSqrtTerm(r);
    if (a != null && b != null && a.inner.toString() == b.inner.toString()) {
      return MulExpr(IntExpr(a.coef + b.coef), SqrtExpr(a.inner)).simplify();
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

    // 处理同类 sqrt 项: a*sqrt(X) - b*sqrt(X) = (a-b)*sqrt(X)
    var a = _asSqrtTerm(l);
    var b = _asSqrtTerm(r);
    if (a != null && b != null && a.inner.toString() == b.inner.toString()) {
      return MulExpr(IntExpr(a.coef - b.coef), SqrtExpr(a.inner)).simplify();
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

    // sqrt * sqrt: sqrt(a)*sqrt(a) = a
    if (l is SqrtExpr &&
        r is SqrtExpr &&
        l.inner.toString() == r.inner.toString()) {
      return l.inner.simplify();
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
  SqrtExpr(this.inner);

  @override
  Expr simplify() {
    var i = inner.simplify();
    if (i is IntExpr) {
      int n = i.value;
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
    }
    return SqrtExpr(i);
  }

  @override
  Expr evaluate() {
    var i = inner.evaluate();
    if (i is IntExpr) {
      int n = i.value;
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
    }
    return SqrtExpr(i);
  }

  @override
  Expr substitute(String varName, Expr value) =>
      SqrtExpr(inner.substitute(varName, value));

  @override
  String toString() => "sqrt($inner)";
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

// === 辅助：识别 a * sqrt(X) 形式 ===
class _SqrtTerm {
  final int coef;
  final Expr inner;
  _SqrtTerm(this.coef, this.inner);
}

_SqrtTerm? _asSqrtTerm(Expr e) {
  if (e is SqrtExpr) return _SqrtTerm(1, e.inner);
  if (e is MulExpr) {
    // 可能为 Int * Sqrt or Sqrt * Int
    if (e.left is IntExpr && e.right is SqrtExpr) {
      return _SqrtTerm((e.left as IntExpr).value, (e.right as SqrtExpr).inner);
    }
    if (e.right is IntExpr && e.left is SqrtExpr) {
      return _SqrtTerm((e.right as IntExpr).value, (e.left as SqrtExpr).inner);
    }
  }
  return null;
}

/// 辗转相除法求 gcd
int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

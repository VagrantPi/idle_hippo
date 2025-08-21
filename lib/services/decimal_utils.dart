import 'package:decimal/decimal.dart';

class DecimalUtils {
  // 以 Decimal 做加法，並四捨五入到指定小數位後回傳 double
  static double add(double a, num b, {int scale = 4}) {
    final da = Decimal.parse(a.toString());
    final db = b is int ? Decimal.fromInt(b) : Decimal.parse(b.toString());
    final sum = da + db;
    final roundedStr = double.parse(sum.toString()).toStringAsFixed(scale);
    return double.parse(roundedStr);
  }

  // 以 Decimal 做減法
  static double subtract(double a, num b, {int scale = 4}) {
    final da = Decimal.parse(a.toString());
    final db = b is int ? Decimal.fromInt(b) : Decimal.parse(b.toString());
    final diff = da - db;
    final roundedStr = double.parse(diff.toString()).toStringAsFixed(scale);
    return double.parse(roundedStr);
  }

  // 以 Decimal 做乘法
  static double multiply(double a, num b, {int scale = 4}) {
    final da = Decimal.parse(a.toString());
    final db = b is int ? Decimal.fromInt(b) : Decimal.parse(b.toString());
    final product = da * db;
    final roundedStr = double.parse(product.toString()).toStringAsFixed(scale);
    return double.parse(roundedStr);
  }

  // 以 Decimal 做除法
  static double divide(double a, num b, {int scale = 4}) {
    final da = Decimal.parse(a.toString());
    final db = b is int ? Decimal.fromInt(b) : Decimal.parse(b.toString());
    if (db == Decimal.zero) return 0.0;
    final quotient = da / db;
    final roundedStr = double.parse(quotient.toString()).toStringAsFixed(scale);
    return double.parse(roundedStr);
  }

  // 累加多個數值
  static double sum(List<num> values, {int scale = 4}) {
    if (values.isEmpty) return 0.0;
    
    Decimal result = Decimal.zero;
    for (final value in values) {
      final d = value is int ? Decimal.fromInt(value) : Decimal.parse(value.toString());
      result += d;
    }
    
    final roundedStr = double.parse(result.toString()).toStringAsFixed(scale);
    return double.parse(roundedStr);
  }
}

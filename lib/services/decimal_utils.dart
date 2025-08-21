import 'package:decimal/decimal.dart';

class DecimalUtils {
  // 以 Decimal 做加總，並四捨五入到指定小數位後回傳 double
  static double add(double a, num b, {int scale = 4}) {
    final da = Decimal.parse(a.toString());
    final db = b is int ? Decimal.fromInt(b) : Decimal.parse(b.toString());
    final sum = da + db;
    // 使用 Decimal -> String -> double 再以 toStringAsFixed 進行固定小數位格式化
    // 避免依賴 Decimal 的特定格式 API。
    final roundedStr = double.parse(sum.toString()).toStringAsFixed(scale);
    return double.parse(roundedStr);
  }
}

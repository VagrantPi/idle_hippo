import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/decimal_utils.dart';

void main() {
  group('DecimalUtils 四則運算與加總', () {
    test('加法：四捨五入至 4 位', () {
      final v = DecimalUtils.add(1.23456, 0.33333, scale: 4);
      expect(v, 1.5679);
    });

    test('減法：四捨五入至 4 位', () {
      final v = DecimalUtils.subtract(5.0, 1.23456, scale: 4);
      expect(v, 3.7654);
    });

    test('乘法：四捨五入至 4 位', () {
      final v = DecimalUtils.multiply(1.2345, 2.5, scale: 4);
      expect(v, 3.0863);
    });

    test('除法：四捨五入至 4 位，分母為 0 回傳 0.0', () {
      final v1 = DecimalUtils.divide(10.0, 4, scale: 4);
      final v2 = DecimalUtils.divide(10.0, 0, scale: 4);
      expect(v1, 2.5);
      expect(v2, 0.0);
    });

    test('加總：四捨五入至 4 位', () {
      final v = DecimalUtils.sum([0.11111, 0.22222, 0.33333], scale: 4);
      expect(v, 0.6667);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/purchase_models.dart';

void main() {
  group('PurchaseModels 測試', () {
    test('ProductInfo 應該正確建立與比較', () {
      const product1 = ProductInfo(
        id: 'test_product',
        name: 'Test Product',
        desc: 'Test Description',
        image: 'test.png',
        price: 1.99,
        currency: 'USD',
      );

      const product2 = ProductInfo(
        id: 'test_product',
        name: 'Test Product',
        desc: 'Test Description',
        image: 'test.png',
        price: 1.99,
        currency: 'USD',
      );

      expect(product1, equals(product2));
      expect(product1.hashCode, equals(product2.hashCode));
    });

    test('PurchaseEvent 應該正確建立與比較', () {
      const event1 = PurchaseEvent(
        productId: 'test_product',
        status: PurchaseStatus.success,
        message: 'Success',
      );

      const event2 = PurchaseEvent(
        productId: 'test_product',
        status: PurchaseStatus.success,
        message: 'Success',
      );

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('PurchaseAvailability 應該正確建立與比較', () {
      const availability1 = PurchaseAvailability(true, remaining: 5);
      const availability2 = PurchaseAvailability(true, remaining: 5);

      expect(availability1, equals(availability2));
      expect(availability1.hashCode, equals(availability2.hashCode));
    });

    test('PurchaseRecord 應該正確序列化與反序列化', () {
      const record = PurchaseRecord(
        total: 5,
        daily: DailyRecord(date: '2025-09-14', count: 2),
        monthly: MonthlyRecord(ym: '2025-09', count: 3),
      );

      final json = record.toJson();
      final restored = PurchaseRecord.fromJson(json);

      expect(restored.total, equals(5));
      expect(restored.daily?.date, equals('2025-09-14'));
      expect(restored.daily?.count, equals(2));
      expect(restored.monthly?.ym, equals('2025-09'));
      expect(restored.monthly?.count, equals(3));
    });

    test('DailyRecord 應該正確序列化與反序列化', () {
      const record = DailyRecord(date: '2025-09-14', count: 3);

      final json = record.toJson();
      final restored = DailyRecord.fromJson(json);

      expect(restored.date, equals('2025-09-14'));
      expect(restored.count, equals(3));
    });

    test('MonthlyRecord 應該正確序列化與反序列化', () {
      const record = MonthlyRecord(ym: '2025-09', count: 5);

      final json = record.toJson();
      final restored = MonthlyRecord.fromJson(json);

      expect(restored.ym, equals('2025-09'));
      expect(restored.count, equals(5));
    });

    test('InstallRecord 應該正確序列化與反序列化', () {
      const record = InstallRecord(firstOpenDate: '2025-08-01');

      final json = record.toJson();
      final restored = InstallRecord.fromJson(json);

      expect(restored.firstOpenDate, equals('2025-08-01'));
    });

    test('PurchaseRecord copyWith 應該正確運作', () {
      const original = PurchaseRecord(
        total: 5,
        daily: DailyRecord(date: '2025-09-14', count: 2),
      );

      final updated = original.copyWith(
        total: 10,
        monthly: MonthlyRecord(ym: '2025-09', count: 3),
      );

      expect(updated.total, equals(10));
      expect(updated.daily?.date, equals('2025-09-14'));
      expect(updated.daily?.count, equals(2));
      expect(updated.monthly?.ym, equals('2025-09'));
      expect(updated.monthly?.count, equals(3));
    });
  });
}

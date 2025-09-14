import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/purchase_models.dart';
import 'package:idle_hippo/services/mock_purchase_service.dart';

void main() {
  group('MockPurchaseService 測試', () {
    late MockPurchaseService service;

    setUp(() {
      service = MockPurchaseService();
    });

    tearDown(() {
      service.dispose();
    });

    test('應該能查詢商品資訊', () async {
      final products = await service.queryProducts(['test1', 'test2']);

      expect(products, hasLength(2));
      expect(products[0].id, equals('test1'));
      expect(products[0].name, equals('Mock Product test1'));
      expect(products[0].price, equals(1.99));
      expect(products[0].currency, equals('USD'));
      expect(products[1].id, equals('test2'));
    });

    test('購買應該在 2 秒後成功', () async {
      final events = <PurchaseEvent>[];
      service.purchaseStream.listen(events.add);

      final stopwatch = Stopwatch()..start();
      await service.buy('test_product');
      stopwatch.stop();

      // 檢查時間約為 2 秒
      expect(stopwatch.elapsedMilliseconds, greaterThan(1900));
      expect(stopwatch.elapsedMilliseconds, lessThan(2100));

      // 檢查事件
      expect(events, hasLength(1));
      expect(events[0].productId, equals('test_product'));
      expect(events[0].status, equals(PurchaseStatus.success));
    });

    test('恢復購買應該在 1 秒後成功', () async {
      final events = <PurchaseEvent>[];
      service.purchaseStream.listen(events.add);

      final stopwatch = Stopwatch()..start();
      await service.restore();
      stopwatch.stop();

      // 檢查時間約為 1 秒
      expect(stopwatch.elapsedMilliseconds, greaterThan(900));
      expect(stopwatch.elapsedMilliseconds, lessThan(1100));

      // 檢查事件
      expect(events, hasLength(1));
      expect(events[0].productId, equals('card_click_perm'));
      expect(events[0].status, equals(PurchaseStatus.success));
      expect(events[0].message, equals('Restored purchase'));
    });

    test('應該能處理多個購買請求', () async {
      final events = <PurchaseEvent>[];
      service.purchaseStream.listen(events.add);

      // 同時發起多個購買
      await Future.wait([
        service.buy('product1'),
        service.buy('product2'),
        service.buy('product3'),
      ]);

      expect(events, hasLength(3));
      expect(events.map((e) => e.productId), containsAll(['product1', 'product2', 'product3']));
      expect(events.every((e) => e.status == PurchaseStatus.success), isTrue);
    });
  });

  group('IapPurchaseService 測試', () {
    late IapPurchaseService service;

    setUp(() {
      service = IapPurchaseService();
    });

    tearDown(() {
      service.dispose();
    });

    test('查詢商品應該拋出未實作錯誤', () async {
      expect(
        () => service.queryProducts(['test']),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('購買應該回傳錯誤事件', () async {
      final events = <PurchaseEvent>[];
      service.purchaseStream.listen(events.add);

      await service.buy('test_product');

      expect(events, hasLength(1));
      expect(events[0].productId, equals('test_product'));
      expect(events[0].status, equals(PurchaseStatus.error));
      expect(events[0].message, contains('not implemented'));
    });

    test('恢復購買應該回傳錯誤事件', () async {
      final events = <PurchaseEvent>[];
      service.purchaseStream.listen(events.add);

      await service.restore();

      expect(events, hasLength(1));
      expect(events[0].status, equals(PurchaseStatus.error));
      expect(events[0].message, contains('not implemented'));
    });
  });
}

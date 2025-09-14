import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/purchase_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:idle_hippo/models/purchase_models.dart';

void main() {
  group('PurchaseRepository 測試', () {
    late PurchaseRepository repository;

    setUp(() {
      // 以記憶體實作初始化 SharedPreferences，避免 plugin 造成測試等待
      SharedPreferences.setMockInitialValues({});
      repository = PurchaseRepository();
    });

    test('應該能儲存和讀取購買記錄', () async {
      const record = PurchaseRecord(
        total: 5,
        daily: DailyRecord(date: '2025-09-14', count: 2),
        monthly: MonthlyRecord(ym: '2025-09', count: 3),
      );

      await repository.savePurchaseRecord('test_product', record);
      final retrieved = await repository.getPurchaseRecord('test_product');

      expect(retrieved, isNotNull);
      expect(retrieved!.total, equals(5));
      expect(retrieved.daily?.date, equals('2025-09-14'));
      expect(retrieved.daily?.count, equals(2));
      expect(retrieved.monthly?.ym, equals('2025-09'));
      expect(retrieved.monthly?.count, equals(3));
    });

    test('不存在的商品應該回傳 null', () async {
      final retrieved = await repository.getPurchaseRecord('nonexistent');
      expect(retrieved, isNull);
    });

    test('應該能儲存和讀取安裝記錄', () async {
      const record = InstallRecord(firstOpenDate: '2025-08-01');

      await repository.saveInstallRecord(record);
      final retrieved = await repository.getInstallRecord();

      expect(retrieved, isNotNull);
      expect(retrieved!.firstOpenDate, equals('2025-08-01'));
    });

    test('ensureInstallRecord 應該在首次呼叫時建立記錄', () async {
      final testDate = DateTime(2025, 9, 14);
      
      final record = await repository.ensureInstallRecord(testDate);
      expect(record.firstOpenDate, equals('2025-09-14'));

      // 第二次呼叫應該回傳相同記錄
      final record2 = await repository.ensureInstallRecord(testDate);
      expect(record2.firstOpenDate, equals('2025-09-14'));
    });

    test('應該正確重置每日記錄', () async {
      // 設定舊的每日記錄
      const oldRecord = PurchaseRecord(
        daily: DailyRecord(date: '2025-09-13', count: 3),
      );
      await repository.savePurchaseRecord('daily_product', oldRecord);

      // 重置到新的日期
      final newDate = DateTime(2025, 9, 14);
      await repository.resetDailyRecords(newDate);

      // 檢查記錄是否被重置
      final retrieved = await repository.getPurchaseRecord('daily_product');
      expect(retrieved?.daily?.date, equals('2025-09-14'));
      expect(retrieved?.daily?.count, equals(0));
    });

    test('應該正確重置每月記錄', () async {
      // 設定舊的每月記錄
      const oldRecord = PurchaseRecord(
        monthly: MonthlyRecord(ym: '2025-08', count: 5),
      );
      await repository.savePurchaseRecord('monthly_product', oldRecord);

      // 重置到新的月份
      final newDate = DateTime(2025, 9, 14);
      await repository.resetMonthlyRecords(newDate);

      // 檢查記錄是否被重置
      final retrieved = await repository.getPurchaseRecord('monthly_product');
      expect(retrieved?.monthly?.ym, equals('2025-09'));
      expect(retrieved?.monthly?.count, equals(0));
    });

    test('相同日期不應該重置每日記錄', () async {
      // 設定當日記錄
      const record = PurchaseRecord(
        daily: DailyRecord(date: '2025-09-14', count: 3),
      );
      await repository.savePurchaseRecord('daily_product', record);

      // 用相同日期重置
      final sameDate = DateTime(2025, 9, 14);
      await repository.resetDailyRecords(sameDate);

      // 檢查記錄沒有被重置
      final retrieved = await repository.getPurchaseRecord('daily_product');
      expect(retrieved?.daily?.date, equals('2025-09-14'));
      expect(retrieved?.daily?.count, equals(3));
    });

    test('相同月份不應該重置每月記錄', () async {
      // 設定當月記錄
      const record = PurchaseRecord(
        monthly: MonthlyRecord(ym: '2025-09', count: 5),
      );
      await repository.savePurchaseRecord('monthly_product', record);

      // 用相同月份重置
      final sameMonth = DateTime(2025, 9, 20);
      await repository.resetMonthlyRecords(sameMonth);

      // 檢查記錄沒有被重置
      final retrieved = await repository.getPurchaseRecord('monthly_product');
      expect(retrieved?.monthly?.ym, equals('2025-09'));
      expect(retrieved?.monthly?.count, equals(5));
    });

    test('應該能處理多個商品的記錄', () async {
      const record1 = PurchaseRecord(total: 1);
      const record2 = PurchaseRecord(total: 2);

      await repository.savePurchaseRecord('product1', record1);
      await repository.savePurchaseRecord('product2', record2);

      final retrieved1 = await repository.getPurchaseRecord('product1');
      final retrieved2 = await repository.getPurchaseRecord('product2');

      expect(retrieved1?.total, equals(1));
      expect(retrieved2?.total, equals(2));
    });
  });
}

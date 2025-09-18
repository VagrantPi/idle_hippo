import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/sku_mapper.dart';

void main() {
  group('SkuMapper 測試', () {
    late SkuMapper skuMapper;

    setUpAll(() async {
      // 設定測試環境
      TestWidgetsFlutterBinding.ensureInitialized();

      skuMapper = SkuMapper.instance;
      await skuMapper.init();
    });

    group('對照成功測試', () {
      test('應該成功將 store.card_click_perm 轉換為 card_click_perm', () {
        // Given
        const String storeId = 'store.card_click_perm';

        // When
        final String skuId = skuMapper.getSkuId(storeId);

        // Then
        expect(skuId, equals('card_click_perm'));
      });

      test('應該成功將 store.card_idle_perm 轉換為 card_idle_perm', () {
        // Given
        const String storeId = 'store.card_idle_perm';

        // When
        final String skuId = skuMapper.getSkuId(storeId);

        // Then
        expect(skuId, equals('card_idle_perm'));
      });

      test('應該成功將 store.pack_monthly 轉換為 pack_monthly', () {
        // Given
        const String storeId = 'store.pack_monthly';

        // When
        final String skuId = skuMapper.getSkuId(storeId);

        // Then
        expect(skuId, equals('pack_monthly'));
      });
    });

    group('對照失敗測試', () {
      test('不存在的 storeId 應該拋出 SkuMappingNotFound 例外', () {
        // Given
        const String invalidStoreId = 'store.not_exists';

        // When & Then
        expect(
          () => skuMapper.getSkuId(invalidStoreId),
          throwsA(isA<SkuMappingNotFound>()),
        );
      });

      test('SkuMappingNotFound 例外應該包含正確的 storeId', () {
        // Given
        const String invalidStoreId = 'store.invalid_item';

        // When & Then
        try {
          skuMapper.getSkuId(invalidStoreId);
          fail('應該拋出 SkuMappingNotFound 例外');
        } catch (e) {
          expect(e, isA<SkuMappingNotFound>());
          expect((e as SkuMappingNotFound).storeId, equals(invalidStoreId));
          expect(e.toString(), contains(invalidStoreId));
        }
      });

      test('沒有 store. 前綴的 ID 應該拋出 SkuMappingNotFound 例外', () {
        // Given
        const String invalidStoreId = 'card_click_perm';

        // When & Then
        expect(
          () => skuMapper.getSkuId(invalidStoreId),
          throwsA(isA<SkuMappingNotFound>()),
        );
      });

      test('空字串應該拋出 SkuMappingNotFound 例外', () {
        // Given
        const String emptyStoreId = '';

        // When & Then
        expect(
          () => skuMapper.getSkuId(emptyStoreId),
          throwsA(isA<SkuMappingNotFound>()),
        );
      });
    });

    group('全域一致性檢查測試', () {
      test('所有 tabs 中的 storeId 都應該能成功轉換', () {
        // When
        final bool isValid = skuMapper.validateAllTabsStoreIds();

        // Then
        expect(isValid, isTrue);
      });

      test('getAllStoreIds 應該回傳所有有效的 storeId', () {
        // When
        final List<String> storeIds = skuMapper.getAllStoreIds();

        // Then
        expect(storeIds, contains('store.card_click_perm'));
        expect(storeIds, contains('store.card_idle_perm'));
        expect(storeIds, contains('store.pack_monthly'));
        expect(storeIds.length, greaterThan(0));

        // 驗證所有 storeId 都以 'store.' 開頭
        for (final storeId in storeIds) {
          expect(storeId, startsWith('store.'));
        }
      });

      test('所有 getAllStoreIds 回傳的 storeId 都應該能成功轉換', () {
        // Given
        final List<String> allStoreIds = skuMapper.getAllStoreIds();

        // When & Then
        for (final String storeId in allStoreIds) {
          expect(() => skuMapper.getSkuId(storeId), returnsNormally);

          // 驗證轉換結果格式正確
          final String skuId = skuMapper.getSkuId(storeId);
          expect(skuId, isNot(contains('store.')));
          expect(skuId.isNotEmpty, isTrue);
        }
      });
    });

    group('初始化測試', () {
      test('重複初始化應該正常運作', () async {
        // Given & When
        await skuMapper.init();
        await skuMapper.init(); // 重複初始化

        // Then
        expect(
          () => skuMapper.getSkuId('store.card_click_perm'),
          returnsNormally,
        );
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/localization_service.dart';

void main() {
  // 初始化測試環境
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalizationService localizationService;

  setUp(() async {
    localizationService = LocalizationService();
    // 重置為預設語言（等待初始化完成，避免與後續 changeLanguage 產生競態）
    await localizationService.init(language: 'en');
  });

  group('LocalizationService 測試', () {
    test('應以預設語言（en）初始化', () {
      expect(localizationService.currentLanguage, equals('en'));
    });

    test('應可正確切換語言', () async {
      // 使用 changeLanguage 方法切換語言
      await localizationService.changeLanguage('zh');
      expect(localizationService.currentLanguage, equals('zh'));

      await localizationService.changeLanguage('jp');
      expect(localizationService.currentLanguage, equals('jp'));

      await localizationService.changeLanguage('ko');
      expect(localizationService.currentLanguage, equals('ko'));
    });

    test('缺少鍵時應回傳後備文字', () {
      const testKey = 'non_existent_key';
      final result = localizationService.getString(testKey);
      expect(result, equals(testKey)); // 應該返回 key 本身作為 fallback
    });

    test('遇到無效語言應優雅處理', () async {
      // 儲存當前語言
      final originalLanguage = localizationService.currentLanguage;

      // 測試無效語言代碼
      await localizationService.init(language: 'invalid_lang');

      // 驗證語言應該保持不變或回退到預設英文
      expect(
        ['en', originalLanguage].contains(localizationService.currentLanguage),
        isTrue,
        reason:
            'Should fallback to a valid language when invalid language code is provided',
      );
    });
  });
}

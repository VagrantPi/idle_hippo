import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/localization_service.dart';

void main() {
  // 初始化測試環境
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late LocalizationService localizationService;

  setUp(() {
    localizationService = LocalizationService();
    // 重置為預設語言
    localizationService.init(language: 'en');
  });

  group('LocalizationService Tests', () {
    test('should initialize with default language (en)', () {
      expect(localizationService.currentLanguage, equals('en'));
    });

    test('should change language correctly', () {
      localizationService.init(language: 'zh');
      expect(localizationService.currentLanguage, equals('zh'));
      
      localizationService.init(language: 'jp');
      expect(localizationService.currentLanguage, equals('jp'));
      
      localizationService.init(language: 'ko');
      expect(localizationService.currentLanguage, equals('ko'));
    });

    test('should return fallback text for missing keys', () {
      const testKey = 'non_existent_key';
      final result = localizationService.getString(testKey);
      expect(result, equals(testKey)); // 應該返回 key 本身作為 fallback
    });

    test('should handle invalid language gracefully', () async {
      // 儲存當前語言
      final originalLanguage = localizationService.currentLanguage;
      
      // 測試無效語言代碼
      await localizationService.init(language: 'invalid_lang');
      
      // 驗證語言應該保持不變或回退到預設英文
      expect(
        ['en', originalLanguage].contains(localizationService.currentLanguage),
        isTrue,
        reason: 'Should fallback to a valid language when invalid language code is provided'
      );
    });
  });
}

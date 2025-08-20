import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:idle_hippo/services/localization_service.dart';

void main() {
  group('LocalizationService Tests', () {
    late LocalizationService localizationService;

    setUp(() {
      localizationService = LocalizationService();
      // 重置為預設語言
      localizationService.init(language: 'en');
    });

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
      final result = localizationService.getText(testKey);
      expect(result, equals(testKey)); // 應該返回 key 本身作為 fallback
    });

    test('should handle invalid language gracefully', () {
      localizationService.init(language: 'invalid_lang');
      // 應該保持原有語言或回到預設語言
      expect(['en', 'zh', 'jp', 'ko'].contains(localizationService.currentLanguage), isTrue);
    });

    test('should notify listeners when language changes', () {
      bool listenerCalled = false;
      
      localizationService.addListener(() {
        listenerCalled = true;
      });
      
      localizationService.init(language: 'zh');
      expect(listenerCalled, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/localization_service.dart';

void main() {
  late LocalizationService localizationService;

  setUp(() async {
    localizationService = LocalizationService();
    await localizationService.init(language: 'en');
  });

  group('LocalizationService（使用模擬資產）', () {
    test('應以預設語言（en）初始化', () {
      expect(localizationService.currentLanguage, equals('en'));
    });

    test('應能正確格式化多語言字串', () async {
      // 測試英文
      String messageEn = localizationService.getString('tutorial.pet_intro');
      expect(
        messageEn,
        'Pets can be obtained through gacha; they are your strongest allies',
      );

      // 測試繁體中文
      await localizationService.changeLanguage('zh');
      String messageZh = localizationService.getString('tutorial.pet_intro');
      expect(messageZh, '寵物可以靠抽卡獲取，寵物是你最強力的夥伴');

      // 測試日文
      await localizationService.changeLanguage('jp');
      String messageJp = localizationService.getString('tutorial.pet_intro');
      expect(messageJp, 'ペットはガチャで入手できます。最強の相棒です');
    });
  });
}

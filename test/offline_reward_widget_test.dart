import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/localization_service.dart';

// 輔助函式，手動將 asset 載入到 rootBundle 中
Future<void> loadAssetAsRealRootBundle(String path) async {
  final bytes = await File(path).readAsBytes();
  rootBundle.evict(path);
  await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/assets',
    ByteData.sublistView(bytes).buffer.asByteData(),
    (data) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalizationService with mock assets', () {
    testWidgets('correctly formats strings for multiple languages', (tester) async {
      // runAsync 確保在穩定的環境中執行非同步操作
      await tester.runAsync(() async {
        await loadAssetAsRealRootBundle('assets/lang/en.json');
        await loadAssetAsRealRootBundle('assets/lang/zh.json');
        await loadAssetAsRealRootBundle('assets/lang/jp.json');
      });

      final localizationService = LocalizationService();

      // 測試英文
      await localizationService.init(language: 'en');
      String messageEn = localizationService.getString(
        'offline.message',
        replacements: {'time': '1h', 'points': '100'},
      );
      expect(messageEn, 'You were away 1h, earned ≈ 100');

      // 測試繁體中文
      await localizationService.init(language: 'zh');
      String messageZh = localizationService.getString(
        'offline.message',
        replacements: {'time': '1小時', 'points': '100'},
      );
      expect(messageZh, '你離線了 1小時，共累積 ≈ 100');

      // 測試日文
      await localizationService.init(language: 'jp');
      String messageJp = localizationService.getString(
        'offline.message',
        replacements: {'time': '1時間', 'points': '100'},
      );
      expect(messageJp, '1時間 の間オフライン、約 100 を獲得');
    });
  });
}

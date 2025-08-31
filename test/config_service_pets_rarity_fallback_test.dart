import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/config_service.dart';

void main() {
  // 測試中需先初始化 Flutter 綁定，否則讀取 assets 時會噴錯
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigService 寵物稀有度回退測試', () {
    late ConfigService configService;

    setUp(() async {
      configService = ConfigService();
      if (!configService.isLoaded) {
        await configService.loadConfig();
      }
    });

    test('當寵物未定義 per-pet rarities 時，應回退到 default_rarities', () async {
      final cfg = configService.getPetRarityConfig('MooDeng', 'SSR');
      expect(cfg, isNotNull, reason: '應取得 default_rarities 中的設定');
      expect(cfg!['baseIdlePerSec'], isNotNull);
      expect((cfg['baseIdlePerSec'] as num).toDouble(), 0.5);
    });

    test('路徑讀取 pets 列表應存在且包含 MooDeng', () async {
      final petsList = configService.getValue('pets.pets') as List<dynamic>?;
      expect(petsList, isNotNull);
      final ids = petsList!
          .whereType<Map<String, dynamic>>()
          .map((e) => e['id'] as String)
          .toList();
      expect(ids, contains('MooDeng'));
    });
  });
}

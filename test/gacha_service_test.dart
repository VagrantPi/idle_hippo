import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:idle_hippo/services/gacha_service.dart';
import 'package:idle_hippo/models/pet.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/config_service.dart';

void main() {
  // 確保 Flutter 測試綁定初始化，供 rootBundle 載入資產
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---- Mock flutter_secure_storage ----
  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final Map<String, String> inMemorySecure = <String, String>{};

  setUpAll(() async {
    // 設置 channel 的 mock handler，用於單元測試環境
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (
          MethodCall call,
        ) async {
          final args = (call.arguments is Map)
              ? Map<String, dynamic>.from(call.arguments as Map)
              : const <String, dynamic>{};
          switch (call.method) {
            case 'read':
              return inMemorySecure[args['key'] as String?];
            case 'write':
              final key = args['key'] as String?;
              final value = args['value'] as String?;
              if (key != null) inMemorySecure[key] = value ?? '';
              return true;
            case 'delete':
              final key = args['key'] as String?;
              if (key != null) inMemorySecure.remove(key);
              return true;
            case 'readAll':
              return Map<String, String>.from(inMemorySecure);
            case 'deleteAll':
              inMemorySecure.clear();
              return true;
            case 'containsKey':
              final key = args['key'] as String?;
              return key != null && inMemorySecure.containsKey(key);
            default:
              return null;
          }
        });
  });

  tearDownAll(() async {
    // 移除 mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  group('GachaService 測試', () {
    late GachaService gachaService;

    setUp(() async {
      gachaService = GachaService();
    });

    test('初始化抽卡服務', () async {
      await gachaService.initialize();
      expect(gachaService.getPetTickets(), greaterThanOrEqualTo(0));
    });

    test('增加抽獎券功能', () async {
      await gachaService.initialize();
      final initialTickets = gachaService.getPetTickets();

      await gachaService.addPetTickets(5);
      expect(gachaService.getPetTickets(), equals(initialTickets + 5));
    });

    test('單次抽卡功能', () async {
      await gachaService.initialize();

      // 確保有足夠的抽獎券
      await gachaService.addPetTickets(10);
      final initialTickets = gachaService.getPetTickets();

      final result = await gachaService.performSingleDraw();

      // 驗證抽卡結果
      final cfg = ConfigService();
      if (!cfg.isLoaded) {
        await cfg.loadConfig();
      }
      final petsList = cfg.getValue('pets.pets') as List<dynamic>?;
      final allowedIds = (petsList ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((e) => e['id'] as String)
          .where((id) => id.isNotEmpty)
          .toList();
      expect(allowedIds, isNotEmpty, reason: '設定檔應提供至少一個寵物 id');
      expect(result.petKey, isIn(allowedIds));
      expect(result.rarity, isA<PetRarity>());
      expect(result.name, isNotEmpty);
      expect(result.imagePath, isNotEmpty);
      expect(result.timestamp, greaterThan(0));

      // 驗證抽獎券被扣除
      expect(gachaService.getPetTickets(), equals(initialTickets - 1));
    });

    test('十一連抽功能', () async {
      await gachaService.initialize();

      // 確保有足夠的抽獎券
      await gachaService.addPetTickets(20);
      final initialTickets = gachaService.getPetTickets();

      final results = await gachaService.performTenPlusOneDraw();

      // 驗證抽卡結果
      expect(results.length, equals(11));

      final cfg = ConfigService();
      if (!cfg.isLoaded) {
        await cfg.loadConfig();
      }
      final petsList = cfg.getValue('pets.pets') as List<dynamic>?;
      final allowedIds = (petsList ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((e) => e['id'] as String)
          .where((id) => id.isNotEmpty)
          .toList();
      expect(allowedIds, isNotEmpty, reason: '設定檔應提供至少一個寵物 id');

      for (final result in results) {
        expect(result.petKey, isIn(allowedIds));
        expect(result.rarity, isA<PetRarity>());
        expect(result.name, isNotEmpty);
        expect(result.imagePath, isNotEmpty);
        expect(result.timestamp, greaterThan(0));
      }

      // 驗證抽獎券被扣除
      expect(gachaService.getPetTickets(), equals(initialTickets - 10));
    });

    test('抽獎券不足時拋出異常', () async {
      await gachaService.initialize();

      // 清空抽獎券
      await gachaService.clearGachaHistory(); // 重置狀態

      // 測試單抽異常
      try {
        await gachaService.performSingleDraw();
        fail('應該拋出異常');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      // 測試十一連抽異常
      try {
        await gachaService.performTenPlusOneDraw();
        fail('應該拋出異常');
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('抽卡歷史記錄功能', () async {
      await gachaService.initialize();

      // 清空歷史記錄
      await gachaService.clearGachaHistory();
      expect(gachaService.getGachaHistory().length, equals(0));

      // 確保有足夠的抽獎券
      await gachaService.addPetTickets(5);

      // 執行抽卡
      await gachaService.performSingleDraw();

      // 驗證歷史記錄
      final history = gachaService.getGachaHistory();
      expect(history.length, equals(1));

      final record = history.first;
      expect(record.rarity, isIn(['RR', 'R', 'S', 'SR', 'SSR']));
      expect(record.name, isNotEmpty);
      expect(record.timestamp, greaterThan(0));
    });

    test('抽卡歷史記錄最多保留 gacha.history.maxRecords，預設 50 條', () async {
      await gachaService.initialize();

      // 清空歷史記錄
      await gachaService.clearGachaHistory();

      // 確保有足夠的抽獎券
      await gachaService.addPetTickets(60);

      // 執行 60 次抽卡
      for (int i = 0; i < 60; i++) {
        await gachaService.performSingleDraw();
      }

      // 驗證歷史記錄最多 50 條
      final history = gachaService.getGachaHistory();
      expect(history.length, lessThanOrEqualTo(50));
    });

    test('稀有度機率分布測試', () {
      final results = gachaService.simulateGacha1000Times();

      // 驗證所有稀有度都有結果
      expect(results.keys, containsAll(PetRarity.values));

      // 驗證總數為 1000
      final totalCount = results.values.reduce((a, b) => a + b);
      expect(totalCount, equals(1000));

      // 驗證機率分布在合理範圍內（允許 ±5% 誤差）
      expect(results[PetRarity.ssr]! / 1000, closeTo(0.02, 0.05));
      expect(results[PetRarity.sr]! / 1000, closeTo(0.08, 0.05));
      expect(results[PetRarity.s]! / 1000, closeTo(0.10, 0.05));
      expect(results[PetRarity.r]! / 1000, closeTo(0.20, 0.05));
      expect(results[PetRarity.rr]! / 1000, closeTo(0.60, 0.05));

      // 使用服務內建驗證方法
      expect(gachaService.validateProbabilityDistribution(results), isTrue);
    });

    test('機率驗證功能', () {
      // 驗證機率總和為 1.0
      const probabilities = {
        PetRarity.ssr: 0.02,
        PetRarity.sr: 0.08,
        PetRarity.s: 0.10,
        PetRarity.r: 0.20,
        PetRarity.rr: 0.60,
      };

      final totalProbability = probabilities.values.reduce((a, b) => a + b);
      expect(totalProbability, closeTo(1.0, 0.001));
    });
  });

  group('GachaResult 測試', () {
    test('GachaResult 序列化和反序列化', () {
      final originalResult = GachaResult(
        petKey: 'MooDeng',
        name: '彈跳豬 MooDeng',
        rarity: PetRarity.ssr,
        imagePath: 'assets/images/character/MooDeng.png',
        isNew: true,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final map = originalResult.toMap();
      final deserializedResult = GachaResult.fromMap(map);

      expect(deserializedResult.petKey, equals(originalResult.petKey));
      expect(deserializedResult.name, equals(originalResult.name));
      expect(deserializedResult.rarity, equals(originalResult.rarity));
      expect(deserializedResult.imagePath, equals(originalResult.imagePath));
      expect(deserializedResult.isNew, equals(originalResult.isNew));
      expect(deserializedResult.timestamp, equals(originalResult.timestamp));
    });
  });

  group('GachaHistoryRecord 測試', () {
    test('GachaHistoryRecord 序列化和反序列化', () {
      final originalRecord = GachaHistoryRecord(
        rarity: 'SSR',
        name: '彈跳豬 MooDeng',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final map = originalRecord.toMap();
      final deserializedRecord = GachaHistoryRecord.fromMap(map);

      expect(deserializedRecord.rarity, equals(originalRecord.rarity));
      expect(deserializedRecord.name, equals(originalRecord.name));
      expect(deserializedRecord.timestamp, equals(originalRecord.timestamp));
    });

    test('GachaHistoryRecord 相等性比較', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final record1 = GachaHistoryRecord(
        rarity: 'SSR',
        name: '彈跳豬 MooDeng',
        timestamp: timestamp,
      );

      final record2 = GachaHistoryRecord(
        rarity: 'SSR',
        name: '彈跳豬 MooDeng',
        timestamp: timestamp,
      );

      final record3 = GachaHistoryRecord(
        rarity: 'SR',
        name: '彈跳豬 MooDeng',
        timestamp: timestamp,
      );

      expect(record1, equals(record2));
      expect(record1.hashCode, equals(record2.hashCode));
      expect(record1, isNot(equals(record3)));
    });
  });
}

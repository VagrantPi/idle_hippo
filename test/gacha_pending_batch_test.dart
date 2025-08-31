import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:idle_hippo/services/gacha_service.dart';
import 'package:idle_hippo/services/config_service.dart';

void main() {
  // 初始化測試綁定
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage
  const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> _inMemorySecure = <String, String>{};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (MethodCall call) async {
      final args = (call.arguments is Map)
          ? Map<String, dynamic>.from(call.arguments as Map)
          : const <String, dynamic>{};
      switch (call.method) {
        case 'read':
          return _inMemorySecure[args['key'] as String?];
        case 'write':
          final key = args['key'] as String?;
          final value = args['value'] as String?;
          if (key != null) _inMemorySecure[key] = value ?? '';
          return true;
        case 'delete':
          final key = args['key'] as String?;
          if (key != null) _inMemorySecure.remove(key);
          return true;
        case 'readAll':
          return Map<String, String>.from(_inMemorySecure);
        case 'deleteAll':
          _inMemorySecure.clear();
          return true;
        case 'containsKey':
          final key = args['key'] as String?;
          return key != null && _inMemorySecure.containsKey(key);
        default:
          return null;
      }
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  group('兩階段提交（PendingGachaBatch）', () {
    test('建立 pending 後不立即寫入歷史，提交後才落盤（冪等）', () async {
      final gacha = GachaService();
      await gacha.initialize();

      // 確保配置載入
      final cfg = ConfigService();
      if (!cfg.isLoaded) await cfg.loadConfig();

      // 準備票券
      await gacha.addPetTickets(20);
      final ticketsBefore = gacha.getPetTickets();

      // 建立 pending（透過十一連抽 API）
      final results = await gacha.performTenPlusOneDraw();
      expect(results.length, 11);

      // 票券應先扣除 10
      expect(gacha.getPetTickets(), ticketsBefore - 10);

      // 歷史此時不應增加（pending 尚未提交）
      final historyBeforeCommit = gacha.getGachaHistory();
      final beforeLen = historyBeforeCommit.length;

      // 第一次提交：應套用 11 筆
      final committed1 = await gacha.commitPendingBatchIfAny();
      expect(committed1, isTrue);
      final historyAfterCommit = gacha.getGachaHistory();
      expect(historyAfterCommit.length, beforeLen + 11);

      // 第二次提交：冪等（無 pending），應回傳 false，歷史不變
      final committed2 = await gacha.commitPendingBatchIfAny();
      expect(committed2, isFalse);
      expect(gacha.getGachaHistory().length, historyAfterCommit.length);
    });

    test('初始化自動恢復：存在 pending 會自動提交', () async {
      final g1 = GachaService();
      await g1.initialize();

      await g1.addPetTickets(20);
      final initialHist = g1.getGachaHistory().length;

      // 建立 pending，但不提交
      await g1.performTenPlusOneDraw();
      final midHist = g1.getGachaHistory().length;
      expect(midHist, initialHist, reason: '建立 pending 後歷史不應變動');

      // 模擬重啟（再次 initialize 會自動提交 pending）
      await g1.initialize();
      final afterHist = g1.getGachaHistory().length;
      expect(afterHist, initialHist + 11,
          reason: '初始化應自動提交 pending 批次');
    });
  });
}

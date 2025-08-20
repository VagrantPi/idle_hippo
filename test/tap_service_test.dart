import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/tap_service.dart';

void main() {
  group('TapService - Step 5 spec', () {
    late DateTime now;
    late TapService tapService;

    setUp(() {
      now = DateTime.utc(2025, 1, 1, 0, 0, 0, 0);
      DateTime nowProvider() => now;
      tapService = TapService(
        now: nowProvider,
        basePoints: 1,
        cooldownSeconds: 0.5,
      );
    });

    test('單點擊有效：base=1，cooldown=0.5s，單擊一次應+1', () {
      final gained = tapService.tryTap();
      expect(gained, 1);
      expect(tapService.acceptedTapEvents, 1);
    });

    test('連點防作弊：0.1s 內快速連點 10 下，僅第一次有效', () {
      int total = 0;
      for (int i = 0; i < 10; i++) {
        total += tapService.tryTap();
      }
      expect(total, 1);
      expect(tapService.acceptedTapEvents, 1);
      expect(tapService.totalTapEvents, 10);
    });

    test('間隔符合累積：每隔 1s 點擊 5 次，總共 +5', () {
      int total = 0;
      for (int i = 0; i < 5; i++) {
        total += tapService.tryTap();
        // 前一次點擊後前進 1 秒
        now = now.add(const Duration(seconds: 1));
      }
      expect(total, 5);
      expect(tapService.acceptedTapEvents, 5);
      expect(tapService.totalTapEvents, 5);
    });
  });
}

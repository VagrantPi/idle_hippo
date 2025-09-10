import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_hippo/services/secure_save_service.dart';
import 'package:idle_hippo/models/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureSaveService fast-cache path', () {
    late SecureSaveService saveService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      saveService = SecureSaveService();
      await saveService.init(currentVersion: 1);
    });

    test('save writes fast cache immediately', () async {
      final s0 = GameState.initial(1).copyWith(memePoints: 123.45);
      await saveService.save(s0);

      final prefs = await SharedPreferences.getInstance();
      final fastStr = prefs.getString('game_state_fast');
      expect(fastStr, isNotNull);

      final parsed = GameState.fromJson(fastStr!);
      expect(parsed.memePoints, 123.45);
      expect(parsed.lastTs, greaterThan(0));
    });

    test('load prefers fast cache when durable is unavailable', () async {
      // Arrange: put a newer state into fast cache
      final prefs = await SharedPreferences.getInstance();
      final fastState = GameState.initial(1)
          .copyWith(memePoints: 999.0)
          .updateTimestamp();
      await prefs.setString('game_state_fast', fastState.toJson());

      // Act: load (secure storage plugin is not available in unit tests)
      final loaded = await saveService.load();

      // Assert: should return fast cache content
      expect(loaded.memePoints, 999.0);
    });
  });
}


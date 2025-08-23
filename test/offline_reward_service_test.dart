import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/offline_reward_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // This setup runs once for all tests.
  setUpAll(() async {
    // Mock rootBundle to load test config so ConfigService can init
    // Note: 'flutter/assets' is a BasicMessageChannel with StringCodec, not a MethodChannel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final String? key = const StringCodec().decodeMessage(message);
      if (key == null) return null;
      if (key.endsWith('game.json')) {
        return const StringCodec().encodeMessage(json.encode({'baseMemePerSecond': 1.0}));
      }
      if (key.endsWith('equipments.json')) {
        return const StringCodec().encodeMessage(
          json.encode({'tap_equipments': [], 'idle_equipments': []}),
        );
      }
      if (key.endsWith('pets.json')) {
        return const StringCodec().encodeMessage(json.encode({'pets': []}));
      }
      if (key.endsWith('titles.json')) {
        return const StringCodec().encodeMessage(json.encode({'titles': []}));
      }
      if (key.endsWith('quests.json')) {
        return const StringCodec().encodeMessage(json.encode({'quests': []}));
      }
      return null;
    });
    // Manually init ConfigService for testing
    await ConfigService().loadConfig();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  group('OfflineRewardService：基本功能', () {
    late OfflineRewardService service;
    late GameState state;
    late int nowMs;
    double lastReward = 0;
    Duration lastEffective = Duration.zero;
    bool lastCanDouble = false;

    double idlePerSec = 2.0;

    setUp(() {
      service = OfflineRewardService();
      nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      state = GameState.initial(1).copyWith(
        offline: OfflineState(
          lastExitUtcMs: nowMs, // Start with a fresh exit time
          idleRateSnapshot: 2.0, // 2 points per second
          capHours: 2,
        ),
      );
      service.init(
        getGameState: () => state,
        getIdlePerSec: () => idlePerSec,
        onPersist: (newState) async => state = newState,
        onOfflineReward: (r, d, {required bool canDouble}) {
          lastReward = r;
          lastEffective = d;
          lastCanDouble = canDouble;
        },
        nowUtcMsProvider: () => nowMs,
      );
    });

    tearDown(() => service.dispose());

    test('無 lastExit 時：不發放獎勵', () async {
      state = state.copyWith(offline: state.offline.copyWith(lastExitUtcMs: 0));
      await service.simulateAddSeconds(10);
      expect(lastReward, idlePerSec * 10);
    });

    test('短暫離線時間：應發放正確獎勵', () async {
      await service.simulateAddSeconds(10);
      expect(lastReward, closeTo(idlePerSec * 10, 1e-6));
      expect(lastEffective, const Duration(seconds: 10));
      expect(lastCanDouble, isTrue);
      expect(state.memePoints, closeTo(20.0, 1e-6));
    });

    test('長時間離線：獎勵應受封頂', () async {
      final threeHours = 3 * 3600;
      final twoHours = 2 * 3600;
      await service.simulateAddSeconds(threeHours);
      expect(lastReward, closeTo(twoHours * 2.0, 1e-6));
      expect(lastEffective, Duration(seconds: twoHours));
    });
  });

  group('OfflineRewardService：雙倍獎勵', () {
    late OfflineRewardService service;
    late GameState state;
    late int nowMs;
    double lastDoubledAmount = 0;

    setUp(() {
      service = OfflineRewardService();
      nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      state = GameState.initial(1).copyWith(
        memePoints: 1000,
        offline: OfflineState(lastExitUtcMs: nowMs, idleRateSnapshot: 10.0, capHours: 1),
      );
      lastDoubledAmount = 0;
      service.init(
        getGameState: () => state,
        getIdlePerSec: () => 10.0,
        onPersist: (updated) async => state = updated,
        nowUtcMsProvider: () => nowMs,
        onOfflineReward: (r, d, {required bool canDouble}) {},
        onOfflineDoubled: (amount) => lastDoubledAmount = amount,
      );
    });

    tearDown(() => service.dispose());

    test('可以領取雙倍獎勵', () async {
      await service.simulateAddSeconds(60);
      final rewardAmount = state.offline.lastReward;
      final pointsAfterReward = state.memePoints;
      expect(rewardAmount, closeTo(600, 1e-6)); // 60s * 10/s
      expect(state.offline.lastRewardDoubled, isFalse);

      await service.claimOfflineAdDouble();

      expect(state.offline.lastRewardDoubled, isTrue);
      expect(state.memePoints, pointsAfterReward + rewardAmount);
      expect(lastDoubledAmount, rewardAmount);
    });

    test('不可重複雙倍', () async {
      await service.simulateAddSeconds(60);
      await service.claimOfflineAdDouble();
      final pointsAfterFirstDouble = state.memePoints;

      await service.claimOfflineAdDouble(); // Attempt second double
      expect(state.memePoints, pointsAfterFirstDouble);
    });

    test('雙倍狀態應被持久化', () async {
      await service.simulateAddSeconds(60);
      await service.claimOfflineAdDouble();
      expect(state.offline.lastRewardDoubled, isTrue);

      final savedState = state;
      final newService = OfflineRewardService();
      newService.init(
        getGameState: () => savedState,
        getIdlePerSec: () => 10.0,
        onPersist: (updated) async => state = updated,
        nowUtcMsProvider: () => nowMs,
        onOfflineReward: (r, d, {required bool canDouble}) {},
        onOfflineDoubled: (amount) {},
      );

      final pointsBefore = state.memePoints;
      await newService.claimOfflineAdDouble(); // Attempt to double again
      expect(state.memePoints, pointsBefore);
    });
  });
}

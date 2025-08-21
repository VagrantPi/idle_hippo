import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';

void main() {
  group('GameState Model Tests', () {
    test('should create initial state correctly', () {
      final state = GameState.initial(1);
      
      expect(state.saveVersion, 1);
      expect(state.memePoints, 0.0);
      expect(state.equipments, isEmpty);
      expect(state.lastTs, greaterThan(0));
      expect(state.validate(), true);
    });

    test('should serialize and deserialize correctly', () {
      final originalState = GameState(
        saveVersion: 1,
        memePoints: 123.0,
        equipments: {'tiktok': 2, 'idle_chip': 0},
        lastTs: 1724000000000,
      );

      final json = originalState.toJson();
      final deserializedState = GameState.fromJson(json);

      expect(deserializedState, equals(originalState));
    });

    test('should validate correctly', () {
      // Valid state
      final validState = GameState(
        saveVersion: 1,
        memePoints: 100.0,
        equipments: {'weapon': 1},
        lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      expect(validState.validate(), true);

      // Invalid states
      final invalidMemePoints = GameState(
        saveVersion: 1,
        memePoints: -1.0,
        equipments: {},
        lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      expect(invalidMemePoints.validate(), false);

      final invalidEquipment = GameState(
        saveVersion: 1,
        memePoints: 0.0,
        equipments: {'weapon': -1},
        lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      expect(invalidEquipment.validate(), false);
    });

    test('should update timestamp correctly', () async {
      final originalState = GameState.initial(1);
      
      // 加入小延遲確保時間戳不同
      await Future.delayed(const Duration(milliseconds: 1));
      
      final updatedState = originalState.updateTimestamp();
      
      expect(updatedState.lastTs, greaterThan(originalState.lastTs));
      expect(updatedState.saveVersion, originalState.saveVersion);
      expect(updatedState.memePoints, originalState.memePoints);
    });

    test('should copy with new values correctly', () {
      final originalState = GameState.initial(1);
      final copiedState = originalState.copyWith(
        memePoints: 100.0,
        equipments: {'weapon': 2},
      );
      
      expect(copiedState.memePoints, 100.0);
      expect(copiedState.equipments['weapon'], 2);
      expect(copiedState.saveVersion, originalState.saveVersion);
      expect(copiedState.lastTs, originalState.lastTs);
    });

    test('should handle JSON parsing errors gracefully', () {
      expect(
        () => GameState.fromJson('invalid json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should maintain data integrity through serialization cycles', () {
      final originalState = GameState(
        saveVersion: 2,
        memePoints: 999.0,
        equipments: {'sword': 5, 'shield': 3, 'potion': 0},
        lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      // Multiple serialization cycles
      var currentState = originalState;
      for (int i = 0; i < 5; i++) {
        final json = currentState.toJson();
        currentState = GameState.fromJson(json);
      }

      expect(currentState, equals(originalState));
      expect(currentState.validate(), true);
    });

    test('should handle edge case values', () {
      final edgeState = GameState(
        saveVersion: 0,
        memePoints: 0.0,
        equipments: {},
        lastTs: 1,
      );

      expect(edgeState.validate(), true);
      
      final json = edgeState.toJson();
      final deserializedState = GameState.fromJson(json);
      expect(deserializedState, equals(edgeState));
    });
  });
}

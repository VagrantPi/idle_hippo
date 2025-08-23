import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';

void main() {
  group('GameState 模型測試', () {
    test('應正確建立初始狀態', () {
      final state = GameState.initial(1);
      
      expect(state.saveVersion, 1);
      expect(state.memePoints, 0.0);
      expect(state.equipments, isEmpty);
      expect(state.lastTs, greaterThan(0));
      expect(state.validate(), true);
    });

    test('應能正確序列化與還原', () {
      final originalState = GameState(
        saveVersion: 1,
        memePoints: 123.0,
        equipments: {'youtube': 2, 'idle_chip': 0},
        lastTs: 1724000000000,
      );

      final json = originalState.toJson();
      final deserializedState = GameState.fromJson(json);

      expect(deserializedState, equals(originalState));
    });

    test('應能正確驗證', () {
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

    test('應能正確更新時間戳', () async {
      final originalState = GameState.initial(1);
      
      // 加入小延遲確保時間戳不同
      await Future.delayed(const Duration(milliseconds: 1));
      
      final updatedState = originalState.updateTimestamp();
      
      expect(updatedState.lastTs, greaterThan(originalState.lastTs));
      expect(updatedState.saveVersion, originalState.saveVersion);
      expect(updatedState.memePoints, originalState.memePoints);
    });

    test('copyWith 應能正確套用新值', () {
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

    test('遇到 JSON 解析錯誤應優雅處理', () {
      expect(
        () => GameState.fromJson('invalid json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('多次序列化循環後應維持資料完整性', () {
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

    test('邊界值應能正確處理', () {
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

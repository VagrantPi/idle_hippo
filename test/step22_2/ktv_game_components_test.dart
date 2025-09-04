import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/ui/components/ktv_note_entity.dart';
import 'package:idle_hippo/ui/components/ktv_lane_layout.dart';
import 'package:idle_hippo/models/ktv_models.dart';

void main() {
  group('KTV 遊戲組件測試', () {
    group('NoteEntity 測試', () {
      test('音符實體初始化正確', () {
        final note = NoteEntity(
          targetTime: 10.0,
          laneIndex: 1,
          spawnY: -100.0,
          judgeY: 800.0,
        );

        expect(note.targetTime, equals(10.0));
        expect(note.laneIndex, equals(1));
        expect(note.spawnY, equals(-100.0));
        expect(note.judgeY, equals(800.0));
        expect(note.currentY, equals(-100.0));
        expect(note.isActive, isTrue);
        expect(note.hasReachedJudgeline, isFalse);
      });

      test('音符位置更新正確', () {
        final note = NoteEntity(
          targetTime: 10.0,
          laneIndex: 1,
          spawnY: -100.0,
          judgeY: 800.0,
        );

        // 測試音符移動到一半的位置
        note.update(8.75, 1500.0); // 距離目標時間 1.25 秒，在 approachTime 1.5 秒範圍內

        // 應該移動到接近判定線的位置
        expect(note.currentY, greaterThan(-100.0));
        expect(note.currentY, lessThan(800.0));
        expect(note.hasReachedJudgeline, isFalse);
      });

      test('音符到達判定線時狀態正確', () {
        final note = NoteEntity(
          targetTime: 10.0,
          laneIndex: 1,
          spawnY: -100.0,
          judgeY: 800.0,
        );

        // 測試音符到達判定線
        note.update(10.0, 1500.0);

        expect(note.hasReachedJudgeline, isTrue);
        expect(note.currentY, equals(800.0));
        expect(note.reachTime, equals(10.0));
      });

      test('音符大小計算正確', () {
        final note = NoteEntity(
          targetTime: 10.0,
          laneIndex: 1,
          spawnY: -100.0,
          judgeY: 800.0,
        );

        // 在起始位置
        note.currentY = -100.0;
        final startSize = note.getSize(56.0);
        expect(startSize, equals(56.0 * 0.6)); // 最小尺寸

        // 在判定線位置
        note.currentY = 800.0;
        final endSize = note.getSize(56.0);
        expect(endSize, equals(56.0)); // 最大尺寸

        // 在中間位置
        note.currentY = 350.0; // 中間位置
        final midSize = note.getSize(56.0);
        expect(midSize, greaterThan(startSize));
        expect(midSize, lessThan(endSize));
      });

      test('音符回收判斷正確', () {
        final note = NoteEntity(
          targetTime: 10.0,
          laneIndex: 1,
          spawnY: -100.0,
          judgeY: 800.0,
        );

        // 未到達判定線時不應回收
        expect(note.shouldDespawn(10.5, 150.0), isFalse);

        // 到達判定線但在寬限期內
        note.update(10.0, 1500.0);
        expect(note.shouldDespawn(10.1, 150.0), isFalse);

        // 超過寬限期應該回收
        expect(note.shouldDespawn(10.2, 150.0), isTrue);
      });
    });

    group('NotePool 測試', () {
      test('音符池初始化正確', () {
        final pool = NotePool(maxPoolSize: 10);

        expect(pool.activeNotes, isEmpty);
        expect(pool.getStats()['active'], equals(0));
        expect(pool.getStats()['total'], equals(0));
      });

      test('音符池獲取和釋放正確', () {
        final pool = NotePool(maxPoolSize: 3);

        // 獲取音符
        final note1 = pool.acquire(10.0, 1, -100.0, 800.0);
        expect(note1, isNotNull);
        expect(pool.activeNotes.length, equals(1));

        final note2 = pool.acquire(11.0, 2, -100.0, 800.0);
        expect(note2, isNotNull);
        expect(pool.activeNotes.length, equals(2));

        // 釋放音符
        pool.release(note1!);
        expect(pool.activeNotes.length, equals(1));
        expect(note1.isActive, isFalse);
      });

      test('音符池達到上限時拒絕創建', () {
        final pool = NotePool(maxPoolSize: 2);

        final note1 = pool.acquire(10.0, 1, -100.0, 800.0);
        final note2 = pool.acquire(11.0, 2, -100.0, 800.0);
        final note3 = pool.acquire(12.0, 3, -100.0, 800.0);

        expect(note1, isNotNull);
        expect(note2, isNotNull);
        expect(note3, isNull); // 應該拒絕創建
        expect(pool.activeNotes.length, equals(2));
      });

      test('音符池清空功能正確', () {
        final pool = NotePool(maxPoolSize: 10);

        pool.acquire(10.0, 1, -100.0, 800.0);
        pool.acquire(11.0, 2, -100.0, 800.0);

        expect(pool.activeNotes.length, equals(2));

        pool.clear();
        expect(pool.activeNotes.length, equals(0));
      });
    });

    group('LaneLayout 測試', () {
      test('軌道佈局初始化正確', () {
        final layout = LaneLayout(
          keyCount: 3,
          screenWidth: 400.0,
          screenHeight: 800.0,
          lanePadding: 16.0,
          perspectiveDepth: 0.22,
          judgelineY: 0.82,
          spawnY: -0.10,
        );

        expect(layout.keyCount, equals(3));
        expect(layout.lanes.length, equals(3));
      });

      test('軌道中心位置計算正確', () {
        final layout = LaneLayout(
          keyCount: 3,
          screenWidth: 400.0,
          screenHeight: 800.0,
          lanePadding: 16.0,
          perspectiveDepth: 0.22,
          judgelineY: 0.82,
          spawnY: -0.10,
        );

        // 檢查軌道是否均勻分佈
        final lane0X = layout.getLaneCenterX(0);
        final lane1X = layout.getLaneCenterX(1);
        final lane2X = layout.getLaneCenterX(2);

        expect(lane0X, lessThan(lane1X));
        expect(lane1X, lessThan(lane2X));

        // 第一條軌道應該在左側
        expect(lane0X, greaterThan(0));
        // 最後一條軌道應該在右側
        expect(lane2X, lessThan(400.0));
      });

      test('軌道索引驗證正確', () {
        final layout = LaneLayout(
          keyCount: 3,
          screenWidth: 400.0,
          screenHeight: 800.0,
          lanePadding: 16.0,
          perspectiveDepth: 0.22,
          judgelineY: 0.82,
          spawnY: -0.10,
        );

        expect(layout.isValidLaneIndex(0), isTrue);
        expect(layout.isValidLaneIndex(1), isTrue);
        expect(layout.isValidLaneIndex(2), isTrue);
        expect(layout.isValidLaneIndex(-1), isFalse);
        expect(layout.isValidLaneIndex(3), isFalse);
      });

      test('軌道形狀透視效果正確', () {
        final layout = LaneLayout(
          keyCount: 3,
          screenWidth: 400.0,
          screenHeight: 800.0,
          lanePadding: 16.0,
          perspectiveDepth: 0.22,
          judgelineY: 0.82,
          spawnY: -0.10,
        );

        final lane = layout.getLane(1);

        // 上方應該比下方窄（透視效果）
        expect(lane.topWidth, lessThan(lane.bottomWidth));

        // 檢查不同 Y 位置的寬度
        final topWidth = lane.getWidthAtY(lane.topY);
        final bottomWidth = lane.getWidthAtY(lane.bottomY);

        expect(topWidth, equals(lane.topWidth));
        expect(bottomWidth, equals(lane.bottomWidth));
      });
    });

    group('KtvDifficulty 測試', () {
      test('難度配置解析正確', () {
        final difficultyData = {
          'level': 'hard',
          'key_count': 5,
          'beatmap': [
            {'time': 1.0, 'position': 1},
            {'time': 2.0, 'position': 3},
          ],
        };

        final difficulty = KtvDifficulty.fromJson(difficultyData);

        expect(difficulty.level, equals('hard'));
        expect(difficulty.keyCount, equals(5));
        expect(difficulty.beatmap, isNotNull);
        expect(difficulty.beatmap!.length, equals(2));
      });

      test('難度配置容錯處理正確', () {
        final difficultyData = {
          'level': 'easy',
          'key_count': '3', // 字串格式
        };

        final difficulty = KtvDifficulty.fromJson(difficultyData);

        expect(difficulty.level, equals('easy'));
        expect(difficulty.keyCount, equals(3)); // 應該正確轉換
        expect(difficulty.beatmap, isNull);
      });
    });
  });
}

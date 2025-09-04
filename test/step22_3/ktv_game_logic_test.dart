import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/game/ktv_game_logic.dart';
import 'package:idle_hippo/models/ktv_models.dart';
import 'package:idle_hippo/ui/components/ktv_beatmap_note.dart';

// Helper to create a BeatmapNote for tests
BeatmapNote _createNote(String id, int timeMs, int position) {
  return BeatmapNote(
    id: id,
    time: Duration(milliseconds: timeMs),
    position: position,
    type: 'tap',
  );
}

void main() {
  group('KtvGameLogic (判定邏輯測試)', () {
    late KtvGameLogic logic;
    const int numLanes = 3;
    const int perfectMs = 40;
    const int greatMs = 90;
    const int lateGraceMs = 120;

    setUp(() {
      logic = KtvGameLogic(
        numLanes: numLanes,
        perfectMs: perfectMs,
        greatMs: greatMs,
        lateGraceMs: lateGraceMs,
      );
    });

    test('點擊在 Perfect 判定區間內應判定為 PERFECT', () async {
      final note = _createNote('n1', 500, 1);
      logic.loadBeatmap([note]);

      logic.onLaneTap(0, 510); // delta = +10ms

      final result = await logic.judgementStream.first;
      expect(result.judgement, Judgement.perfect);
      expect(result.note.id, 'n1');
      expect(result.deltaMs, 10);
    });

    test('點擊在 Great 判定區間內應判定為 GREAT', () async {
      final note = _createNote('n1', 1000, 2);
      logic.loadBeatmap([note]);

      logic.onLaneTap(1, 930); // delta = -70ms

      final result = await logic.judgementStream.first;
      expect(result.judgement, Judgement.great);
      expect(result.note.id, 'n1');
      expect(result.deltaMs, -70);
    });

    test('過早點擊應被忽略，不產生任何判定', () async {
      final note = _createNote('n1', 1000, 1);
      logic.loadBeatmap([note]);

      logic.onLaneTap(0, 900); // delta = -100ms, > greatMs

      // 驗證在短時間內不會有事件發出：到期時主動關閉 sink 以結束驗證
      final silentStream = logic.judgementStream.timeout(
        const Duration(milliseconds: 50),
        onTimeout: (sink) => sink.close(),
      );
      await expectLater(silentStream, emitsDone);

      // Clean up the stream controller to prevent test leaks
      logic.dispose();
    });

    test('超過 lateGraceMs 未點擊，應自動判定為 MISS', () async {
      final note = _createNote('n1', 1000, 1);
      logic.loadBeatmap([note]);

      // Simulate time passing beyond the grace period
      logic.update(1000 + lateGraceMs + 10); // 1130ms

      final result = await logic.judgementStream.first;
      expect(result.judgement, Judgement.miss);
      expect(result.note.id, 'n1');
      expect(result.deltaMs, greaterThan(lateGraceMs));
    });

    test('音符被判定後，不應再次被判定', () async {
      final note = _createNote('n1', 1000, 1);
      logic.loadBeatmap([note]);

      // First tap (Perfect)
      logic.onLaneTap(0, 1000);
      final firstResult = await logic.judgementStream.first;
      expect(firstResult.judgement, Judgement.perfect);

      // Second tap on the same lane, should be ignored
      logic.onLaneTap(0, 1005);

      // Also, update loop should not trigger a MISS
      logic.update(2000);

      // 驗證後續不會再有事件：到期時主動關閉 sink 以結束驗證
      final noMoreStream = logic.judgementStream.timeout(
        const Duration(milliseconds: 50),
        onTimeout: (sink) => sink.close(),
      );
      await expectLater(noMoreStream, emitsDone);

      logic.dispose();
    });

    test('空軌道上的點擊應被忽略', () async {
      logic.loadBeatmap([]); // No notes

      logic.onLaneTap(0, 1000);

      final emptyStream = logic.judgementStream.timeout(
        const Duration(milliseconds: 50),
        onTimeout: (sink) => sink.close(),
      );
      await expectLater(emptyStream, emitsDone);
      logic.dispose();
    });

    test('處理多個音符和多個軌道', () async {
      final note1 = _createNote('n1', 1000, 1);
      final note2 = _createNote('n2', 1050, 2);
      final note3 = _createNote('n3', 1200, 1); // Will be missed
      logic.loadBeatmap([note1, note2, note3]);

      final judgements = <JudgementResult>[];
      final sub = logic.judgementStream.listen(judgements.add);

      logic.onLaneTap(0, 990); // n1 -> Perfect (-10ms)
      logic.onLaneTap(1, 1120); // n2 -> Great (+70ms)
      logic.update(1200 + lateGraceMs + 10); // n3 -> Miss

      await Future.delayed(const Duration(milliseconds: 10));

      expect(judgements.length, 3);
      expect(judgements[0].note.id, 'n1');
      expect(judgements[0].judgement, Judgement.perfect);
      expect(judgements[1].note.id, 'n2');
      expect(judgements[1].judgement, Judgement.great);
      expect(judgements[2].note.id, 'n3');
      expect(judgements[2].judgement, Judgement.miss);

      sub.cancel();
    });
  });
}

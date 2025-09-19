import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/game/ktv_scoring.dart';
import 'package:idle_hippo/models/ktv_models.dart';

void main() {
  group('KtvScoring（分數、COMBO 與結算）', () {
    test('案例 1：全 PERFECT', () {
      final scoring = KtvScoring();
      const noteCount = 100;
      for (int i = 0; i < noteCount; i++) {
        scoring.onJudge(Judgement.perfect);
      }

      expect(scoring.baseScoreSum, noteCount * 1.0);
      expect(scoring.maxCombo, noteCount);

      // multiplier = 1 + 0.1 * floor(100/10) ≈ 2.0（允許微小誤差）
      expect(scoring.comboMultiplier, moreOrLessEquals(2.0));

      // final ≈ 200.0（乘算與小數向下取 2 位，允許浮點誤差）
      expect(scoring.finalizeMemePoints(), moreOrLessEquals(200.0));
    });

    test('案例 2：含 GREAT（不斷 combo）', () {
      final scoring = KtvScoring();
      const noteCount = 10;
      // 先打 8 顆 perfect
      for (int i = 0; i < 8; i++) {
        scoring.onJudge(Judgement.perfect);
      }
      // 中間 2 顆 great
      scoring.onJudge(Judgement.great);
      scoring.onJudge(Judgement.great);

      // baseScoreSum = 8*1 + 2*0.5 = 9.0
      expect(scoring.baseScoreSum, 9.0);
      expect(scoring.maxCombo, noteCount);

      // multiplier = 1 + 0.1 * floor(10/10) = 1.1（允許微小誤差）
      expect(scoring.comboMultiplier, moreOrLessEquals(1.1));

      // final = 9.0 * 1.1 = 9.9（允許浮點誤差）
      expect(scoring.finalizeMemePoints(), moreOrLessEquals(9.9));
    });

    test('案例 3：含 MISS（斷 combo）', () {
      final scoring = KtvScoring();
      // 前 5 顆 Perfect
      for (int i = 0; i < 5; i++) {
        scoring.onJudge(Judgement.perfect);
      }
      // 第 6 顆 Miss（combo 歸零）
      scoring.onJudge(Judgement.miss);
      // 後續 4 顆 Perfect（重建連擊）
      for (int i = 0; i < 4; i++) {
        scoring.onJudge(Judgement.perfect);
      }

      // baseScoreSum = 9.0；maxCombo = max(5, 4) = 5
      expect(scoring.baseScoreSum, 9.0);
      expect(scoring.maxCombo, 5);

      // multiplier ≈ 1.0（允許微小誤差）
      expect(scoring.comboMultiplier, moreOrLessEquals(1.0));

      // final ≈ 9.0（允許浮點誤差）
      expect(scoring.finalizeMemePoints(), moreOrLessEquals(9.0));
    });

    test('向下取 2 位小數（不四捨五入）', () {
      final scoring = KtvScoring();
      // 模擬 baseScore=12.345 與 multiplier=1.0
      scoring.baseScoreSum = 12.345;
      scoring.maxCombo = 0;
      // 期望向下取 2 位 -> 約 12.34（允許浮點誤差）
      expect(scoring.finalizeMemePoints(), moreOrLessEquals(12.34));

      // 若 multiplier 產生小數，依乘後再向下取 2 位
      scoring.baseScoreSum = 9.99;
      scoring.maxCombo = 12; // floor(12/10) = 1 -> x1.1
      // 9.99 * 1.1 ≈ 10.989 -> 向下取 2 位 ≈ 10.98（允許浮點誤差）
      expect(scoring.finalizeMemePoints(), moreOrLessEquals(10.98));
    });
  });
}

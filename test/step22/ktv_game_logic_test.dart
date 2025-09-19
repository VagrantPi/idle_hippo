import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/game/ktv_geometry_judge.dart';
import 'package:idle_hippo/models/ktv_models.dart';

void main() {
  group('KtvGeometryJudge（幾何版判定測試）', () {
    // 規格預設：bandHeight=64, noteHeight=28
    const double bandHeight = 64;
    const double noteHeight = 28;
    const double bandCenterY = 500; // 任意

    test('完全包含 → PERFECT', () {
      // bandTop = 500-32=468, bandBottom=532
      // 設定 note 完全落在其中，取中心不變（上下各留 10px）
      final judgement = KtvGeometryJudge.judge(
        bandCenterY: bandCenterY,
        bandHeight: bandHeight,
        noteCenterY: bandCenterY,
        noteHeight: noteHeight,
        eps: 1.0,
      );
      expect(judgement, Judgement.perfect);
    });

    test('部分重疊（非完全包含）→ GREAT', () {
      // 讓 noteBottom = bandTop + 10，noteTop < bandTop
      final bandTop = bandCenterY - bandHeight / 2; // 468
      final noteBottom = bandTop + 10; // 478
      final noteTop = noteBottom - noteHeight; // 450 (< bandTop)
      final noteCenter = (noteTop + noteBottom) / 2; // 464

      final judgement = KtvGeometryJudge.judge(
        bandCenterY: bandCenterY,
        bandHeight: bandHeight,
        noteCenterY: noteCenter,
        noteHeight: noteHeight,
        eps: 1.0,
      );
      expect(judgement, Judgement.great);
    });

    test('完全外部 → MISS', () {
      // 讓 note 完全在帶上方：noteBottom <= bandTop
      final bandTop = bandCenterY - bandHeight / 2; // 468
      final noteBottom = bandTop - 1; // 467
      final noteTop = noteBottom - noteHeight; // 439
      final noteCenter = (noteTop + noteBottom) / 2;

      final judgement = KtvGeometryJudge.judge(
        bandCenterY: bandCenterY,
        bandHeight: bandHeight,
        noteCenterY: noteCenter,
        noteHeight: noteHeight,
        eps: 1.0,
      );
      expect(judgement, Judgement.miss);
    });
  });
}

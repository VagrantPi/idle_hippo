import 'package:idle_hippo/models/ktv_models.dart';

/// 幾何重疊判定：依據 Note 與 JudgeBand 在 y 軸的包含/重疊關係
/// - PERFECT：note 完全包含於 band（含 ±eps 容忍）
/// - GREAT：note 與 band 有重疊，但非完全包含
/// - MISS：完全不重疊（在帶上方或下方）
class KtvGeometryJudge {
  static Judgement judge({
    required double bandCenterY,
    required double bandHeight,
    required double noteCenterY,
    required double noteHeight,
    double eps = 1.0,
  }) {
    final bandTop = bandCenterY - bandHeight / 2;
    final bandBottom = bandCenterY + bandHeight / 2;
    final noteTop = noteCenterY - noteHeight / 2;
    final noteBottom = noteCenterY + noteHeight / 2;

    final fullyInside =
        noteTop >= bandTop - eps && noteBottom <= bandBottom + eps;
    if (fullyInside) return Judgement.perfect;

    final overlaps = noteBottom > bandTop && noteTop < bandBottom;
    if (overlaps) return Judgement.great;

    return Judgement.miss;
  }
}

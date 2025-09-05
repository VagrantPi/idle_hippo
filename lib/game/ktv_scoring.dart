import 'dart:math' as math;

import 'package:idle_hippo/models/ktv_models.dart';

/// Step 22-4: 分數、COMBO 與結算計算器（純邏輯，獨立於 UI）
class KtvScoring {
  // 基礎分數總和（未乘算），以 double 累加
  double baseScoreSum = 0.0;

  // 連擊統計
  int combo = 0;
  int maxCombo = 0;

  // 命中統計
  int perfectCount = 0;
  int greatCount = 0;
  int missCount = 0;

  /// 處理一次判定，更新分數與連擊
  void onJudge(Judgement grade) {
    switch (grade) {
      case Judgement.perfect:
        baseScoreSum += 1.0;
        perfectCount += 1;
        combo += 1;
        break;
      case Judgement.great:
        baseScoreSum += 0.5;
        greatCount += 1;
        combo += 1;
        break;
      case Judgement.miss:
        missCount += 1;
        combo = 0;
        break;
    }
    if (combo > maxCombo) maxCombo = combo;
  }

  /// Combo 乘算加成：1 + 0.1 × floor(maxCombo / 10)
  double get comboMultiplier {
    final steps = maxCombo ~/ 10; // floor
    return 1.0 + 0.1 * steps;
  }

  /// 計算最終迷因點數（向下取 2 位小數）
  double finalizeMemePoints() {
    final raw = baseScoreSum * comboMultiplier;
    return _roundDown(raw, 2);
  }

  /// 將 x 向下取至 decimals 位（不做四捨五入）
  double _roundDown(double x, int decimals) {
    if (decimals <= 0) {
      return x.floorToDouble();
    }
    final scale = math.pow(10, decimals).toDouble();
    return (x * scale).floor() / scale;
  }

  /// 重置統計（供再次遊玩或測試）
  void reset() {
    baseScoreSum = 0.0;
    combo = 0;
    maxCombo = 0;
    perfectCount = 0;
    greatCount = 0;
    missCount = 0;
  }
}


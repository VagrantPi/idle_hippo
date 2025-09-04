import 'package:flutter/material.dart';

/// 軌道佈局計算器，負責計算透視軌道的形狀和位置
class LaneLayout {
  final int keyCount;
  final double screenWidth;
  final double screenHeight;
  final double lanePadding;
  final double perspectiveDepth;
  final double judgelineY;
  final double spawnY;

  late final List<LaneShape> _lanes;

  LaneLayout({
    required this.keyCount,
    required this.screenWidth,
    required this.screenHeight,
    required this.lanePadding,
    required this.perspectiveDepth,
    required this.judgelineY,
    required this.spawnY,
  }) {
    _calculateLanes();
  }

  void _calculateLanes() {
    _lanes = [];

    // 幾何參數
    final spawnYPx = screenHeight * spawnY;
    final judgeYPx = screenHeight * judgelineY;

    // 底部（靠近玩家）總寬度，保留左右外側留白 lanePadding
    final leftBottom = lanePadding;
    final rightBottom = screenWidth - lanePadding;
    final bottomSpan = rightBottom - leftBottom;

    // 底部每條軌道的內容寬度（扣除軌道之間的間距 lanePadding）
    final gapsCount = keyCount - 1;
    final totalInnerGaps = lanePadding * gapsCount;
    final laneBottomWidth = (bottomSpan - totalInnerGaps) / keyCount;

    // 透視縮放比例（越靠上越窄），以畫面中心為縮放中心
    final r = 1.0 - perspectiveDepth;
    final screenCenter = screenWidth / 2;

    // 為每條軌道計算上下邊界（四個 X）
    double currentLeft = leftBottom;
    for (int i = 0; i < keyCount; i++) {
      final bLeft = currentLeft;
      final bRight = bLeft + laneBottomWidth;

      // 頂端位置由底部位置繞畫面中心縮放 r 倍（包含軌道與間距）
      final tLeft = screenCenter + (bLeft - screenCenter) * r;
      final tRight = screenCenter + (bRight - screenCenter) * r;

      _lanes.add(
        LaneShape(
          index: i,
          topY: spawnYPx,
          bottomY: judgeYPx,
          topLeftX: tLeft,
          topRightX: tRight,
          bottomLeftX: bLeft,
          bottomRightX: bRight,
        ),
      );

      currentLeft = bRight + lanePadding; // 下一條從右邊界 + 間距開始
    }
  }

  /// 獲取指定軌道的形狀
  LaneShape getLane(int index) {
    if (index < 0 || index >= _lanes.length) {
      throw ArgumentError(
        'Lane index $index out of range [0, ${_lanes.length - 1}]',
      );
    }
    return _lanes[index];
  }

  /// 獲取所有軌道
  List<LaneShape> get lanes => List.unmodifiable(_lanes);

  /// 獲取軌道中心 X 座標
  double getLaneCenterX(int laneIndex) {
    final lane = getLane(laneIndex);
    return (lane.bottomLeftX + lane.bottomRightX) / 2;
  }

  /// 檢查位置是否在有效軌道範圍內
  bool isValidLaneIndex(int laneIndex) {
    return laneIndex >= 0 && laneIndex < keyCount;
  }

  /// 根據點擊的 X（以畫面座標）回傳對應的軌道索引（0-based）。
  /// 使用判定線 y=bottomY 的底部邊界來做區分。
  /// 若不在任何軌道範圍，回傳 null。
  int? laneIndexOf(double x) {
    for (final lane in _lanes) {
      final left = lane.bottomLeftX;
      final right = lane.bottomRightX;
      if (x >= left && x <= right) {
        return lane.index;
      }
    }
    return null;
  }
}

/// 單一軌道的形狀資訊
class LaneShape {
  final int index;
  final double topY;
  final double bottomY;
  final double topLeftX;
  final double topRightX;
  final double bottomLeftX;
  final double bottomRightX;

  const LaneShape({
    required this.index,
    required this.topY,
    required this.bottomY,
    required this.topLeftX,
    required this.topRightX,
    required this.bottomLeftX,
    required this.bottomRightX,
  });

  double getWidthAtY(double y) {
    final left = getLeftAtY(y);
    final right = getRightAtY(y);
    return (right - left).abs();
  }

  double getLeftAtY(double y) {
    final p = ((y - topY) / (bottomY - topY)).clamp(0.0, 1.0);
    return topLeftX + (bottomLeftX - topLeftX) * p;
  }

  double getRightAtY(double y) {
    final p = ((y - topY) / (bottomY - topY)).clamp(0.0, 1.0);
    return topRightX + (bottomRightX - topRightX) * p;
  }

  double getCenterXAtY(double y) {
    return (getLeftAtY(y) + getRightAtY(y)) / 2;
  }

  Path getPath() {
    final path = Path()
      ..moveTo(topLeftX, topY)
      ..lineTo(topRightX, topY)
      ..lineTo(bottomRightX, bottomY)
      ..lineTo(bottomLeftX, bottomY)
      ..close();
    return path;
  }

  // 向後相容：提供 topWidth/bottomWidth 屬性以支援既有測試
  double get topWidth => (topRightX - topLeftX).abs();
  double get bottomWidth => (bottomRightX - bottomLeftX).abs();
}

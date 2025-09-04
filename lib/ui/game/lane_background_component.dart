import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/ui/components/ktv_lane_layout.dart';

/// 使用 Flame Component 繪製 KTV 軌道與判定線
class LaneBackgroundComponent extends PositionComponent {
  final LaneLayout laneLayout;
  final double judgelineY; // 相對螢幕高度 (0~1)
  final double screenHeight; // 螢幕實際高度（以 viewport 座標）

  LaneBackgroundComponent({
    required this.laneLayout,
    required this.judgelineY,
    required this.screenHeight,
  }) : super(priority: -10); // 置於背景

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 先繪製「整體軌道區域」的大梯形背景，讓遠端連成一體
    final topY = laneLayout.lanes.first.topY;
    final bottomY = laneLayout.lanes.first.bottomY;
    final leftBottom = 0 + laneLayout.lanePadding; // 外側留白
    final rightBottom = laneLayout.screenWidth - laneLayout.lanePadding;

    final r = 1.0 - laneLayout.perspectiveDepth; // 透視收斂比例
    final groupBottomWidth = rightBottom - leftBottom;
    final groupTopWidth = groupBottomWidth * r;
    final leftTop = (laneLayout.screenWidth - groupTopWidth) / 2;
    final rightTop = leftTop + groupTopWidth;

    final groupPath = Path()
      ..moveTo(leftTop, topY)
      ..lineTo(rightTop, topY)
      ..lineTo(rightBottom, bottomY)
      ..lineTo(leftBottom, bottomY)
      ..close();
    canvas.drawPath(groupPath, lanePaint);

    // 再繪製各軌道的邊框，作為分隔線
    for (final lane in laneLayout.lanes) {
      final path = lane.getPath();
      canvas.drawPath(path, borderPaint);
    }

    final judgeY = screenHeight * judgelineY;

    // 橘色判定線厚度 = 藍色音符高度的 2 倍
    final noteBaseSize = ConfigService()
        .getValue('game.ktv.noteBaseSize', defaultValue: 56.0)
        .toDouble();
    final judgeLineThickness = noteBaseSize * 2;

    final judgelinePaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.8)
      ..strokeWidth = judgeLineThickness;

    // 判定線
    canvas.drawLine(
      Offset(0, judgeY),
      Offset(laneLayout.screenWidth, judgeY),
      judgelinePaint,
    );

    // 判定區域
    final judgeAreaPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.2);

    final judgeAreaHeight = judgeLineThickness;
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        judgeY - judgeAreaHeight / 2,
        laneLayout.screenWidth,
        judgeAreaHeight,
      ),
      judgeAreaPaint,
    );
  }
}

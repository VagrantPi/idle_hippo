import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 橘色判定帶 Component（可視 + 幾何資訊保存）
class JudgeBandComponent extends PositionComponent {
  final int laneIndex;
  final double centerY; // 像素座標
  final double heightPx; // 幾何判定帶高度
  final double laneLeftX;
  final double laneRightX;

  JudgeBandComponent({
    required this.laneIndex,
    required this.centerY,
    required this.heightPx,
    required this.laneLeftX,
    required this.laneRightX,
  }) : super(priority: -5) {
    position = Vector2(laneLeftX, centerY - heightPx / 2);
    size = Vector2(laneRightX - laneLeftX, heightPx);
    anchor = Anchor.topLeft;
  }

  double get top => centerY - heightPx / 2;
  double get bottom => centerY + heightPx / 2;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.orange.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, border);
  }
}

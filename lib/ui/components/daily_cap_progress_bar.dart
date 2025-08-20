import 'package:flutter/material.dart';

class DailyCapProgressBar extends StatelessWidget {
  final double current;
  final double max;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final Color backgroundColor;
  final Color fillColor;

  const DailyCapProgressBar({
    super.key,
    required this.current,
    required this.max,
    this.height = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.backgroundColor = const Color(0xFFE9ECEF), // 淡灰
    this.fillColor = const Color(0xFF1E66FF), // 藍色
  });

  @override
  Widget build(BuildContext context) {
    final clampedMax = max <= 0 ? 1.0 : max;
    // 顯示剩餘比例：隨著 current 增加，填充減少
    final ratio = ((clampedMax - current) / clampedMax).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: borderRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fillWidth = width * ratio;
          return SizedBox(
            height: height,
            child: Stack(
              children: [
                // 背景
                Container(
                  width: double.infinity,
                  height: height,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                  ),
                ),
                // 填充
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: fillWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: fillColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

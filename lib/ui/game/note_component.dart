import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:idle_hippo/services/config_service.dart';
import '../components/ktv_lane_layout.dart';
import '../components/ktv_beatmap_note.dart';

class NoteComponent extends PositionComponent
    with TapCallbacks, CollisionCallbacks {
  final BeatmapNote note;
  final int laneIndex;
  final LaneLayout laneLayout;
  final double approachTimeMs;
  final Function(NoteComponent) onDespawn;
  late final double _noteBaseSize;

  late final double _spawnY;
  late final double _targetY;
  late final double _despawnY;

  bool _isActive = true;

  NoteComponent({
    required this.note,
    required this.laneIndex,
    required this.laneLayout,
    required this.approachTimeMs,
    required this.onDespawn,
  }) : super(
         anchor: Anchor.center,
         size: Vector2(50, 30), // 初始值，後續會依據位置調整
       ) {
    _noteBaseSize = ConfigService()
        .getValue('game.ktv.noteBaseSize', defaultValue: 56.0)
        .toDouble();
    final lane = laneLayout.lanes[laneIndex];
    _targetY = lane.bottomY;
    _spawnY = lane.topY;
    // 讓音符通過判定線後持續到底部才回收
    _despawnY = laneLayout.screenHeight + 50; // 畫面底部外再多給一點緩衝

    // Set initial position（置於對應 Y 的中心線上）
    position = Vector2(lane.getCenterXAtY(_spawnY), _spawnY);

    // Hitbox for tap detection & future collisions
    // Added in onLoad to ensure the component is fully mounted
  }

  bool get isActive => _isActive;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Add a rectangle hitbox centered within the component
    add(RectangleHitbox());
  }

  void updatePosition(double currentTimeSec) {
    if (!_isActive) return;
    // 以毫秒為單位計算進度：progress = 1 - (timeUntilHitMs / approachTimeMs)
    final noteTimeMs = note.time.inMilliseconds.toDouble();
    final currentMs = currentTimeSec * 1000.0;
    final timeUntilHitMs = noteTimeMs - currentMs; // >0 尚未到線，<0 已過線

    // 進度：0 表示剛生成在頂端，1 表示到達判定線；允許略過 1 後續滑到底部
    double progress = 1.0 - (timeUntilHitMs / approachTimeMs);
    // 夾住範圍避免初次出現就落在視野外或判定線以下
    progress = progress.clamp(0.0, 1.5);

    // 沿著軌道由 spawnY 向 targetY 移動
    position.y = _spawnY + (_targetY - _spawnY) * progress;
    // X 依當前 Y 的軌道中心線移動（非固定直線）
    position.x = laneLayout.lanes[laneIndex].getCenterXAtY(position.y);

    // 音符寬度 = 當前 Y 的軌道寬度；高度 = 固定基準高
    final width = laneLayout.lanes[laneIndex].getWidthAtY(position.y);
    final height = _noteBaseSize;
    size.setValues(width, height);

    // 當完全離開畫面底部時才回收
    if (position.y > _despawnY) {
      _despawn();
      return;
    }
  }

  bool shouldDespawn(double currentTimeSec, double graceMs) {
    if (!_isActive) return false;
    // 改為依位置判斷：超出畫面下緣才回收
    return position.y > _despawnY;
  }

  void _despawn() {
    if (!_isActive) return;
    _isActive = false;
    onDespawn(this);
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) return;

    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.lightBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: size.x,
      height: size.y,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8.0));
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!_isActive) return;
    // Handle tap on note (placeholder for scoring logic later)
    _despawn();
  }
}

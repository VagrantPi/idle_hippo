/// 音符實體，代表一個在軌道上移動的音符
class NoteEntity {
  final double targetTime; // 音符應該到達判定線的時間（秒）
  final int laneIndex; // 軌道索引 (0-based)
  final double spawnY; // 生成位置 Y 座標
  final double judgeY; // 判定線 Y 座標

  double currentY; // 當前 Y 座標
  bool isActive; // 是否活躍
  bool hasReachedJudgeline; // 是否已到達判定線
  double reachTime; // 實際到達判定線的時間

  NoteEntity({
    required this.targetTime,
    required this.laneIndex,
    required this.spawnY,
    required this.judgeY,
  }) : currentY = spawnY,
       isActive = true,
       hasReachedJudgeline = false,
       reachTime = 0.0;

  /// 根據當前音訊時間更新音符位置
  void update(double audioTime, double approachTimeMs) {
    if (!isActive) return;

    final approachTimeSec = approachTimeMs / 1000.0;
    final timeToJudge = targetTime - audioTime;

    if (timeToJudge <= 0 && !hasReachedJudgeline) {
      hasReachedJudgeline = true;
      reachTime = audioTime;
      currentY = judgeY;
    } else if (timeToJudge > 0 && timeToJudge <= approachTimeSec) {
      // 線性插值計算位置，只在 approachTime 範圍內更新
      final progress = 1.0 - (timeToJudge / approachTimeSec);
      currentY = spawnY + (judgeY - spawnY) * progress.clamp(0.0, 1.0);
    }
  }

  /// 計算音符大小（透視縮放效果）
  double getSize(double baseSize) {
    final progress = (currentY - spawnY) / (judgeY - spawnY);
    return baseSize * (0.6 + 0.4 * progress.clamp(0.0, 1.0));
  }

  /// 重置音符狀態以供重用
  void reset(double newTargetTime, int newLaneIndex) {
    // 由於 targetTime 和 laneIndex 是 final，需要創建新實例
    // 這個方法主要用於重置可變狀態
    currentY = spawnY;
    isActive = true;
    hasReachedJudgeline = false;
    reachTime = 0.0;
  }

  /// 檢查是否應該被回收
  bool shouldDespawn(double audioTime, double despawnGraceMs) {
    if (!hasReachedJudgeline) return false;

    final graceSec = despawnGraceMs / 1000.0;
    return (audioTime - reachTime) > graceSec;
  }
}

/// 音符物件池，用於管理音符實體
class NotePool {
  final List<NoteEntity> _activeNotes = [];
  final int maxPoolSize;

  NotePool({this.maxPoolSize = 256});

  /// 創建一個新的音符實體
  NoteEntity? acquire(
    double targetTime,
    int laneIndex,
    double spawnY,
    double judgeY,
  ) {
    if (_activeNotes.length >= maxPoolSize) {
      return null; // 達到上限，拒絕創建
    }

    final note = NoteEntity(
      targetTime: targetTime,
      laneIndex: laneIndex,
      spawnY: spawnY,
      judgeY: judgeY,
    );

    _activeNotes.add(note);
    return note;
  }

  /// 回收音符實體
  void release(NoteEntity note) {
    note.isActive = false;
    _activeNotes.remove(note);
  }

  /// 獲取所有活躍音符
  List<NoteEntity> get activeNotes => List.unmodifiable(_activeNotes);

  /// 清空所有音符
  void clear() {
    for (final note in _activeNotes) {
      note.isActive = false;
    }
    _activeNotes.clear();
  }

  /// 獲取統計資訊
  Map<String, int> getStats() {
    return {'active': _activeNotes.length, 'total': _activeNotes.length};
  }
}

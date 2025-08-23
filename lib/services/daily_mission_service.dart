import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/decimal_utils.dart';
import 'package:idle_hippo/services/idle_income_service.dart';
import 'package:idle_hippo/services/config_service.dart';

typedef NowProvider = DateTime Function();

class DailyMissionService {
  final IdleIncomeService _idleIncomeService = IdleIncomeService();
  final NowProvider _now;
  final int? _tapTargetOverride; // 測試可覆寫

  // 任務獎勵序列
  static const List<int> _rewardSequence = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89];

  // 事件回調
  void Function(double points)? _onRewardEarned;

  DailyMissionService({NowProvider? now, int? tapTargetOverride})
      : _now = now ?? DateTime.now,
        _tapTargetOverride = tapTargetOverride;

  double _tapTarget() {
    if (_tapTargetOverride != null) return _tapTargetOverride.toDouble();
    final v = ConfigService().getValue('game.daily_mission.tap_target', defaultValue: 50);
    if (v is num) return v.toDouble();
    return 50.0;
  }

  /// 設定獎勵回調
  void setRewardCallback(void Function(double points)? callback) {
    _onRewardEarned = callback;
  }

  // tz=Asia/Taipei (UTC+8)
  String _todayAsiaTaipei() {
    final utcNow = _now().toUtc();
    final taipei = utcNow.add(const Duration(hours: 8));
    return '${taipei.year.toString().padLeft(4, '0')}-${taipei.month.toString().padLeft(2, '0')}-${taipei.day.toString().padLeft(2, '0')}';
  }

  /// 確保每日任務區塊存在並處理跨日重置
  GameState ensureDailyMissionBlock(GameState state) {
    final today = _todayAsiaTaipei();
    final mission = state.dailyMission;

    // 如果沒有任務或跨日，重置為第一個任務
    if (mission == null || mission.date != today) {
      return state.copyWith(
        dailyMission: DailyMissionState(
          date: today,
          index: 1,
          type: 'tapX',
          progress: 0.0,
          target: _tapTarget(),
          idlePerSecSnapshot: 0.0,
          todayCompleted: 0,
        ),
      );
    }

    // 同一天：若為 tap 類任務且目標與設定不同，進行同步（支援從 50 改為 5 等動態配置）
    if (mission.type == 'tapX') {
      final desired = _tapTarget();
      if (mission.target != desired) {
        final updated = mission.copyWith(
          target: desired,
          // 同步後若進度超過新目標，將進度鎖到目標
          progress: mission.progress > desired ? desired : mission.progress,
        );
        return state.copyWith(dailyMission: updated);
      }
    }

    // 同一天：若為 accumulateX，且歷史資料目標為 0（或以下），進行補救同步
    if (mission.type == 'accumulateX') {
      if (mission.target <= 0) {
        final currentIdlePerSec = _idleIncomeService.currentIdlePerSec;
        // 若 idlePerSec 為 0，使用 0.1 作為最低計算基準，避免目標為 0
        final effectiveIdlePerSec = currentIdlePerSec > 0 ? currentIdlePerSec : 0.1;
        final targetX = DecimalUtils.multiply(effectiveIdlePerSec, 600.0); // 10分鐘的放置收益

        final updated = mission.copyWith(
          target: targetX,
          idlePerSecSnapshot: currentIdlePerSec,
          // 若當前進度已超過新目標，鎖定到新目標
          progress: mission.progress > targetX ? targetX : mission.progress,
        );
        return state.copyWith(dailyMission: updated);
      }
    }

    return state;
  }

  /// 生成下一個任務
  GameState generateNextMission(GameState state) {
    final s0 = ensureDailyMissionBlock(state);
    final mission = s0.dailyMission!;

    // 如果已完成 10 個任務，不生成新任務
    if (mission.todayCompleted >= 10) {
      return s0;
    }

    final nextIndex = mission.todayCompleted + 1;
    final isOdd = nextIndex % 2 == 1;

    if (isOdd) {
      // 奇數序：點擊 50 次任務
      return s0.copyWith(
        dailyMission: mission.copyWith(
          index: nextIndex,
          type: 'tapX',
          progress: 0.0,
          target: _tapTarget(),
          idlePerSecSnapshot: 0.0,
        ),
      );
    } else {
      // 偶數序：累積點數任務
      final currentIdlePerSec = _idleIncomeService.currentIdlePerSec;
      // 若 idlePerSec 為 0，使用 0.1 作為最低計算基準，避免目標為 0
      final effectiveIdlePerSec = currentIdlePerSec > 0 ? currentIdlePerSec : 0.1;
      final targetX = DecimalUtils.multiply(effectiveIdlePerSec, 600.0); // 10分鐘的放置收益

      return s0.copyWith(
        dailyMission: mission.copyWith(
          index: nextIndex,
          type: 'accumulateX',
          progress: 0.0,
          target: targetX,
          idlePerSecSnapshot: currentIdlePerSec,
        ),
      );
    }
  }

  /// 處理有效點擊事件（A類任務進度）
  GameState onValidTap(GameState state) {
    final s0 = ensureDailyMissionBlock(state);
    final mission = s0.dailyMission!;

    // 只有 tapX 類型任務才計數
    if (mission.type != 'tapX') {
      return s0;
    }

    // 如果已完成所有任務，不處理
    if (mission.todayCompleted >= 10) {
      return s0;
    }

    final newProgress = DecimalUtils.add(mission.progress, 1.0);
    final updatedMission = mission.copyWith(progress: newProgress);
    final s1 = s0.copyWith(dailyMission: updatedMission);

    // 達標時僅鎖定進度，不自動完成；等待 QuestPage 的 claim
    return _clampProgressIfReached(s1);
  }

  /// 處理資源獲得事件（B類任務進度）
  GameState onEarnPoints(GameState state, double delta) {
    if (delta <= 0) return state;

    final s0 = ensureDailyMissionBlock(state);
    final mission = s0.dailyMission!;

    // 只有 accumulateX 類型任務才計數
    if (mission.type != 'accumulateX') {
      return s0;
    }

    // 如果已完成所有任務，不處理
    if (mission.todayCompleted >= 10) {
      return s0;
    }

    final newProgress = DecimalUtils.add(mission.progress, delta);
    final updatedMission = mission.copyWith(progress: newProgress);
    final s1 = s0.copyWith(dailyMission: updatedMission);

    // 達標時僅鎖定進度，不自動完成；等待 QuestPage 的 claim
    return _clampProgressIfReached(s1);
  }

  /// 若達標，將進度鎖定為目標值（不自動完成）
  GameState _clampProgressIfReached(GameState state) {
    final mission = state.dailyMission!;
    if (mission.progress > mission.target) {
      return state.copyWith(
        dailyMission: mission.copyWith(progress: mission.target),
      );
    }
    return state;
  }

  /// 完成任務並發放獎勵
  GameState _completeMission(GameState state) {
    final mission = state.dailyMission!;
    final completedIndex = mission.index;

    // 發放獎勵
    final reward = _rewardSequence[completedIndex - 1].toDouble();
    _onRewardEarned?.call(reward);

    final newMemePoints = DecimalUtils.add(state.memePoints, reward);
    final newTodayCompleted = mission.todayCompleted + 1;

    // 保存完成任務快照（保留完成時的 target/progress 數字）
    final double snapProgress = mission.progress > mission.target ? mission.target : mission.progress;
    final completedRecord = CompletedMissionRecord(
      index: mission.index,
      type: mission.type,
      progress: snapProgress,
      target: mission.target,
    );
    final completedList = List<CompletedMissionRecord>.from(mission.completed)..add(completedRecord);

    // 更新狀態
    GameState s1 = state.copyWith(
      memePoints: newMemePoints,
      dailyMission: mission.copyWith(
        todayCompleted: newTodayCompleted,
        completed: completedList,
      ),
    );

    // 如果還沒完成 10 個任務，生成下一個
    if (newTodayCompleted < 10) {
      s1 = generateNextMission(s1);
    }

    return s1;
  }

  /// 取得指定序號的獎勵點數
  double getRewardForIndex(int index) {
    if (index < 1 || index > _rewardSequence.length) return 0.0;
    return _rewardSequence[index - 1].toDouble();
  }

  /// 若當前任務達標，執行領取與切換到下一個任務
  /// 注意：若已被自動判定完成並切到下一個（todayCompleted 已加），本方法不再重複發放
  GameState claimIfReady(GameState state) {
    final s0 = ensureDailyMissionBlock(state);
    final m = s0.dailyMission!;
    // 僅在尚未計入完成（todayCompleted 尚未追上 index）且進度達標時執行
    final notCountedAsCompleted = m.todayCompleted < m.index;
    if (m.progress >= m.target && notCountedAsCompleted) {
      return _completeMission(s0);
    }
    return s0;
  }

  /// 強制完成當前任務（Debug用）
  GameState forceCompleteMission(GameState state) {
    final s0 = ensureDailyMissionBlock(state);
    final mission = s0.dailyMission!;

    if (mission.todayCompleted >= 10) {
      return s0;
    }

    // 設定進度為目標值以觸發完成
    final updatedMission = mission.copyWith(progress: mission.target);
    final s1 = s0.copyWith(dailyMission: updatedMission);

    return _completeMission(s1);
  }

  /// 模擬跨日重置（Debug用）
  GameState simulateDayReset(GameState state) {
    // 暫時修改日期來觸發重置
    final tempState = state.copyWith(
      dailyMission: state.dailyMission?.copyWith(date: 'fake-old-date'),
    );

    return ensureDailyMissionBlock(tempState);
  }

  /// 獲取任務統計資訊
  Map<String, dynamic> getStats(GameState state) {
    final s = ensureDailyMissionBlock(state);
    final mission = s.dailyMission!;

    return {
      'date': mission.date,
      'index': mission.index,
      'type': mission.type,
      'progress': mission.progress,
      'target': mission.target,
      'idlePerSecSnapshot': mission.idlePerSecSnapshot,
      'todayCompleted': mission.todayCompleted,
      'isCompleted': mission.todayCompleted >= 10,
      'nextReward': mission.todayCompleted < 10 ? _rewardSequence[mission.todayCompleted] : 0,
    };
  }

  /// 獲取任務顯示文案的參數
  Map<String, dynamic> getDisplayParams(GameState state) {
    final s = ensureDailyMissionBlock(state);
    final mission = s.dailyMission!;

    if (mission.todayCompleted >= 10) {
      return {
        'type': 'completed',
        'progress': 10,
        'target': 10,
      };
    }

    return {
      'type': mission.type,
      'progress': mission.progress.toInt(),
      'target': mission.target.toInt(),
      'points': mission.target.toInt(), // 用於 accumulateX 的 {points} 參數
    };
  }

  /// 產出今日 10 個任務的規劃清單
  /// 回傳每筆包含：index, type, target, progress, status(done/current/locked), reward, displayPoints
  List<Map<String, dynamic>> getTodayPlan(GameState state) {
    final s = ensureDailyMissionBlock(state);
    final mission = s.dailyMission!;
    final todayCompleted = mission.todayCompleted;

    // 當前 idle 速率（用於生成偶數序的 accumulateX 目標，即便尚未開啟也要顯示）
    final currentIdlePerSec = _idleIncomeService.currentIdlePerSec;
    // 若 idlePerSec 為 0，使用 0.1 作為最低計算基準，避免目標為 0
    final effectiveIdlePerSec = currentIdlePerSec > 0 ? currentIdlePerSec : 0.1;
    final accumulateTarget = DecimalUtils.multiply(effectiveIdlePerSec, 600.0);

    final List<Map<String, dynamic>> plan = [];
    for (int i = 1; i <= 10; i++) {
      final bool isOdd = i % 2 == 1;
      final String type = isOdd ? 'tapX' : 'accumulateX';
      final double defaultTarget = isOdd ? _tapTarget() : accumulateTarget;

      String status;
      if (todayCompleted >= i) {
        status = 'done';
      } else if (mission.todayCompleted < 10 && mission.index == i) {
        status = 'current';
      } else {
        status = 'locked';
      }

      // 對於 done：若有完成快照，優先使用快照中的 target/progress；
      // current 使用凍結 mission.target/progress；其餘（locked）採預覽目標，進度 0。
      double target;
      double progress;
      if (status == 'done') {
        final rec = mission.completed.firstWhere(
          (r) => r.index == i,
          orElse: () => CompletedMissionRecord(index: i, type: type, progress: defaultTarget, target: defaultTarget),
        );
        target = rec.target;
        progress = rec.progress;
      } else if (status == 'current') {
        target = mission.target;
        progress = mission.progress;
      } else {
        target = defaultTarget;
        progress = 0.0;
      }

      final reward = getRewardForIndex(i);
      final displayPoints = (!isOdd && status == 'locked')
          ? '??'
          : target.toInt().toString();

      plan.add({
        'index': i,
        'type': type,
        'target': target,
        'progress': progress,
        'status': status,
        'reward': reward,
        'displayPoints': displayPoints,
      });
    }

    return plan;
  }
}

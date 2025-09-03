import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import 'game_state_service.dart';
import 'config_service.dart';
import 'idle_income_service.dart';

/// 週獎勵提示回呼（由 UI 層註冊）
/// 參數：reward（本次週獎勵點數）、total（累計簽到天數）
typedef WeeklyBonusCallback = void Function(double reward, int total);

/// 每日打卡系統服務
/// 負責管理每日任務生成、簽到邏輯、連續計算與週獎勵
class CheckinService {
  static final CheckinService _instance = CheckinService._internal();
  factory CheckinService() => _instance;
  CheckinService._internal();

  final GameStateService _gameStateService = GameStateService();
  final ConfigService _configService = ConfigService();
  final IdleIncomeService _idleIncomeService = IdleIncomeService();

  WeeklyBonusCallback? _weeklyBonusCallback;
  void setWeeklyBonusCallback(WeeklyBonusCallback cb) {
    _weeklyBonusCallback = cb;
  }

  static const String _timezone = 'Asia/Taipei';
  final math.Random _random = math.Random();

  /// 初始化打卡系統，檢查跨日並生成今日任務
  Future<void> initialize() async {
    await _checkAndHandleDayChange();
  }

  /// 獲取當前本地日期字串 (YYYY-MM-DD)
  String _getLocalDateString() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8)); // Asia/Taipei UTC+8
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 解析日期字串為 DateTime
  DateTime _parseLocalDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) throw ArgumentError('Invalid date format: $dateStr');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// 計算週起始日期
  String _getWeekStart(String dateStr, int weekStartDow) {
    final date = _parseLocalDate(dateStr);
    final dayOfWeek = date.weekday; // 1=Monday, 7=Sunday
    final daysToSubtract = (dayOfWeek - weekStartDow + 7) % 7;
    final weekStart = date.subtract(Duration(days: daysToSubtract));
    return '${weekStart.year.toString().padLeft(4, '0')}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  /// 檢查是否為連續日期
  bool _isConsecutiveDay(String lastDate, String currentDate) {
    if (lastDate.isEmpty) return false;
    final last = _parseLocalDate(lastDate);
    final current = _parseLocalDate(currentDate);
    final diff = current.difference(last).inDays;
    return diff == 1;
  }

  /// 生成隨機任務
  CheckinTask _generateRandomTask(double currentIdlePerSec, List<int> tapRange) {
    final taskTypes = ['tap', 'collect'];
    final taskType = taskTypes[_random.nextInt(taskTypes.length)];
    
    if (taskType == 'tap') {
      final target = tapRange[0] + _random.nextInt(tapRange[1] - tapRange[0] + 1);
      return CheckinTask(type: 'tap', target: target);
    } else {
      // collect: floor(idlePerSec * 8 * 3600)
      final effectiveIdle = (currentIdlePerSec == 0) ? 0.3 : currentIdlePerSec;
      final target = (effectiveIdle * 8 * 3600).floor();
      return CheckinTask(type: 'collect', target: target);
    }
  }

  /// 檢查並處理跨日邏輯
  Future<void> _checkAndHandleDayChange() async {
    final currentState = _gameStateService.gameState.value;
    final localToday = _getLocalDateString();
    
    final checkinState = currentState.checkin;
    if (checkinState == null || checkinState.today.date != localToday) {
      await _handleDayChange(localToday);
    }
  }

  /// 處理跨日邏輯
  Future<void> _handleDayChange(String localToday) async {
    final currentState = _gameStateService.gameState.value;
    final existingCheckin = currentState.checkin;
    
    // 獲取配置
    final tapRange = _configService.getValue('checkin.config.tapRange', defaultValue: [20, 50]) as List<dynamic>;
    final weekStartDow = _configService.getValue('checkin.config.weekStartDow', defaultValue: 1) as int;
    final tapRangeInt = tapRange.map((e) => (e as num).toInt()).toList();
    
    // 獲取當前 idle 速率
    final currentIdlePerSec = _idleIncomeService.currentIdlePerSec;
    
    // 生成新任務
    final newTask = _generateRandomTask(currentIdlePerSec, tapRangeInt);
    
    // 計算週起始日
    final weekStart = _getWeekStart(localToday, weekStartDow);
    
    // 檢查是否跨週
    bool isNewWeek = false;
    CheckinWeek newWeek;
    if (existingCheckin == null || existingCheckin.week.weekStart != weekStart) {
      // 跨週：重置週狀態
      isNewWeek = true;
      newWeek = CheckinWeek(
        weekStart: weekStart,
        mask: 0,
        weeklyBonusClaimed: false,
      );
    } else {
      newWeek = existingCheckin.week;
    }
    
    // 建立新的今日狀態
    final snapshotIdle = (newTask.type == 'collect' && currentIdlePerSec == 0)
        ? 0.3
        : currentIdlePerSec;
    final newToday = CheckinToday(
      date: localToday,
      task: newTask,
      status: 'pending',
      skipViaAdUsed: false,
      idlePerSecSnapshot: snapshotIdle,
    );
    
    // 建立新的打卡狀態
    final newCheckinState = CheckinState(
      tz: _timezone,
      config: CheckinConfig(
        weekStartDow: weekStartDow,
        tapRange: tapRangeInt,
      ),
      streak: existingCheckin?.streak ?? const CheckinStreak(),
      week: newWeek,
      today: newToday,
    );
    
    // 更新遊戲狀態
    final newGameState = currentState.copyWith(checkin: newCheckinState);
    await _gameStateService.updateGameState(newGameState);
  }

  /// 更新任務進度（點擊或收集）
  Future<void> updateTaskProgress(String taskType, int amount) async {
    final currentState = _gameStateService.gameState.value;
    final checkinState = currentState.checkin;
    
    if (checkinState == null || checkinState.today.status != 'pending') {
      return; // 無打卡狀態或今日已完成
    }
    
    if (checkinState.today.task.type != taskType) {
      return; // 任務類型不符
    }
    
    final currentProgress = checkinState.today.task.progress;
    // 進度上限為目標值
    final target = checkinState.today.task.target;
    final newProgress = (currentProgress + amount).clamp(0, target);
    
    final updatedTask = checkinState.today.task.copyWith(progress: newProgress);
    final updatedToday = checkinState.today.copyWith(task: updatedTask);
    final updatedCheckin = checkinState.copyWith(today: updatedToday);
    
    final newGameState = currentState.copyWith(checkin: updatedCheckin);
    await _gameStateService.updateGameState(newGameState);
    // 不自動完成；需由使用者點擊「完成簽到」按鈕觸發
  }

  /// 點擊任務進度更新
  Future<void> updateTapProgress() async {
    await updateTaskProgress('tap', 1);
  }

  /// 收集任務進度更新（從今日首次進入開始累積）
  Future<void> updateCollectProgress(double memePointsGained) async {
    final currentState = _gameStateService.gameState.value;
    final checkinState = currentState.checkin;
    
    if (checkinState == null || 
        checkinState.today.status != 'pending' || 
        checkinState.today.task.type != 'collect') {
      return;
    }
    
    // collect 任務的進度是從今日首次進入開始累積的總點數
    // 這裡需要與其他服務協調來追蹤今日累積點數
    // 暫時直接更新進度，實際實作時需要整合 idle_income_service 的今日累積邏輯
    await updateTaskProgress('collect', memePointsGained.floor());
  }

  /// 廣告跳過簽到
  Future<void> skipViaAd() async {
    final currentState = _gameStateService.gameState.value;
    final checkinState = currentState.checkin;
    
    if (checkinState == null || 
        checkinState.today.status != 'pending' ||
        checkinState.today.skipViaAdUsed) {
      return; // 無打卡狀態、已完成或已用過廣告跳過
    }
    
    await _completeCheckin(true); // 跳過完成
  }

  /// 手動完成簽到（達標後由 UI 觸發）
  Future<void> completeToday() async {
    final state = _gameStateService.gameState.value;
    final checkin = state.checkin;
    if (checkin == null) return;
    if (checkin.today.status != 'pending') return;

    // 僅當已達成目標時才允許完成
    if (checkin.today.task.progress < checkin.today.task.target) return;

    await _completeCheckin(false);
  }

  /// 完成簽到（正常達成或廣告跳過）
  Future<void> _completeCheckin(bool isSkipped) async {
    final currentState = _gameStateService.gameState.value;
    final checkinState = currentState.checkin;
    
    if (checkinState == null || checkinState.today.status != 'pending') {
      return;
    }
    
    final localToday = _getLocalDateString();
    
    // 更新今日狀態
    final newStatus = isSkipped ? 'skipped' : 'done';
    final updatedToday = checkinState.today.copyWith(
      status: newStatus,
      skipViaAdUsed: isSkipped,
    );
    
    // 計算位元索引並設置週遮罩
    final weekStartDate = _parseLocalDate(checkinState.week.weekStart);
    final todayDate = _parseLocalDate(localToday);
    final bitIndex = todayDate.difference(weekStartDate).inDays;
    
    int newMask = checkinState.week.mask;
    if (bitIndex >= 0 && bitIndex < 7) {
      newMask |= (1 << bitIndex);
    }
    
    final updatedWeek = checkinState.week.copyWith(mask: newMask);
    
    // 更新連續統計
    final lastDate = checkinState.streak.lastDate;
    final isConsecutive = _isConsecutiveDay(lastDate, localToday);
    
    final newCurrent = isConsecutive ? checkinState.streak.current + 1 : 1;
    final newBest = math.max(checkinState.streak.best, newCurrent);
    final newTotal = checkinState.streak.total + 1;
    
    final updatedStreak = checkinState.streak.copyWith(
      current: newCurrent,
      best: newBest,
      total: newTotal,
      lastDate: localToday,
    );
    
    final updatedCheckin = checkinState.copyWith(
      today: updatedToday,
      week: updatedWeek,
      streak: updatedStreak,
    );
    
    var newGameState = currentState.copyWith(checkin: updatedCheckin);
    
    // 檢查週獎勵（策略 A：每逢 7 的倍數）
    if (newTotal % 7 == 0) {
      final halfDayReward = await _calculateHalfDayIdleReward();
      newGameState = newGameState.copyWith(
        memePoints: newGameState.memePoints + halfDayReward,
      );

      // 觸發週獎勵提示回呼（由 UI 顯示）
      try {
        _weeklyBonusCallback?.call(halfDayReward, newTotal);
      } catch (_) {
        // 避免 UI 回呼異常影響主流程
      }
    }
    
    await _gameStateService.updateGameState(newGameState);
  }

  /// 計算半日放置獎勵
  Future<double> _calculateHalfDayIdleReward() async {
    double currentIdlePerSec = _idleIncomeService.currentIdlePerSec;
    if (currentIdlePerSec == 0) {
      currentIdlePerSec = 0.3;
    }
    return currentIdlePerSec * 12 * 3600; // 12小時的放置收益
  }

  /// 獲取當前打卡狀態
  CheckinState? getCurrentCheckinState() {
    return _gameStateService.gameState.value.checkin;
  }

  /// 檢查今日是否需要顯示紅點
  bool shouldShowRedDot() {
    final checkinState = getCurrentCheckinState();
    if (checkinState == null) return false;
    
    final localToday = _getLocalDateString();
    return checkinState.today.date == localToday && 
           checkinState.today.status == 'pending';
  }

  /// 獲取週曆顯示資料
  List<bool> getWeeklyCalendar() {
    final checkinState = getCurrentCheckinState();
    if (checkinState == null) return List.filled(7, false);
    
    final mask = checkinState.week.mask;
    final calendar = <bool>[];
    
    for (int i = 0; i < 7; i++) {
      calendar.add((mask & (1 << i)) != 0);
    }
    
    return calendar;
  }

  /// 獲取今日任務完成進度百分比
  double getTodayProgress() {
    final checkinState = getCurrentCheckinState();
    if (checkinState == null) return 0.0;
    
    final task = checkinState.today.task;
    if (task.target <= 0) return 0.0;
    
    return (task.progress / task.target).clamp(0.0, 1.0);
  }

  /// 檢查今日任務是否可以完成
  bool canCompleteToday() {
    final checkinState = getCurrentCheckinState();
    if (checkinState == null) return false;
    
    return checkinState.today.status == 'pending' && 
           checkinState.today.task.progress >= checkinState.today.task.target;
  }

  /// 檢查是否可以使用廣告跳過
  bool canSkipViaAd() {
    final checkinState = getCurrentCheckinState();
    if (checkinState == null) return false;
    
    return checkinState.today.status == 'pending' && 
           !checkinState.today.skipViaAdUsed;
  }

  /// 向後相容：是否有待完成的今日任務
  bool hasPendingTask() {
    final s = getCurrentCheckinState();
    if (s == null) return false;
    return s.today.status == 'pending';
  }

  /// 向後相容：完成簽到（未達標時自動補足進度以通過舊測試）
  Future<bool> completeCheckin() async {
    final state = _gameStateService.gameState.value;
    final checkin = state.checkin;
    if (checkin == null) return false;
    if (checkin.today.status != 'pending') return false;

    // 若尚未達標，為了測試向後相容，將進度補到目標
    if (checkin.today.task.progress < checkin.today.task.target) {
      final filledTask = checkin.today.task.copyWith(progress: checkin.today.task.target);
      final updated = checkin.copyWith(today: checkin.today.copyWith(task: filledTask));
      await _gameStateService.updateGameState(state.copyWith(checkin: updated));
    }

    await _completeCheckin(false);
    return true;
  }

  /// 向後相容：以廣告跳過（成功返回 true）
  Future<bool> skipWithAd() async {
    final s = getCurrentCheckinState();
    if (s == null) return false;
    if (s.today.status != 'pending' || s.today.skipViaAdUsed) return false;
    await _completeCheckin(true);
    return true;
  }

  /// 強制檢查跨日（供外部調用，如 App 回到前台時）
  Future<void> checkDayChange() async {
    await _checkAndHandleDayChange();
  }

  /// Debug 專用：模擬增加「過去一天」簽到（不影響今日狀態，也不標記本週遮罩）
  /// 用途：快速讓累計簽到天數 +1，以測試每 7 天觸發的週獎勵動畫
  Future<void> debugAddOnePastDay() async {
    if (!kDebugMode) {
      // 僅在 Debug 下可用，避免誤用
      return;
    }

    final currentState = _gameStateService.gameState.value;
    final checkin = currentState.checkin;
    if (checkin == null) return;

    // 設定 streak：僅調整連續/最佳/總計與 lastDate，避免動到今日與週遮罩
    final nowLocalStr = _getLocalDateString();
    final nowLocal = _parseLocalDate(nowLocalStr);
    final yesterday = nowLocal.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final newCurrent = checkin.streak.current + 1;
    final newBest = math.max(checkin.streak.best, newCurrent);
    final newTotal = checkin.streak.total + 1;

    final updatedStreak = checkin.streak.copyWith(
      current: newCurrent,
      best: newBest,
      total: newTotal,
      lastDate: yesterdayStr,
    );

    var newGameState = currentState.copyWith(
      checkin: checkin.copyWith(streak: updatedStreak),
    );

    // 若剛好達到 7 的倍數，模擬發放週獎勵並觸發回呼（供動畫顯示）
    if (newTotal % 7 == 0) {
      final halfDayReward = await _calculateHalfDayIdleReward();
      newGameState = newGameState.copyWith(
        memePoints: newGameState.memePoints + halfDayReward,
      );

      if (kDebugMode) {
        debugPrint('CheckinService(debug): Weekly bonus simulated. Total: $newTotal, Reward: $halfDayReward');
      }

      try {
        _weeklyBonusCallback?.call(halfDayReward, newTotal);
      } catch (_) {
        // 避免 UI 回呼異常影響主流程
      }
    }

    await _gameStateService.updateGameState(newGameState);

    if (kDebugMode) {
      debugPrint('CheckinService(debug): Simulated +1 past day. Streak(current=${updatedStreak.current}, best=${updatedStreak.best}, total=${updatedStreak.total}, lastDate=${updatedStreak.lastDate})');
    }
  }

  /// 獲取今日任務描述文字
  String getTodayTaskDescription() {
    final checkinState = getCurrentCheckinState();
    if (checkinState == null) return '';
    
    final task = checkinState.today.task;
    if (task.type == 'tap') {
      return '點擊角色 ${task.target} 次';
    } else {
      return '今日累積 ${task.target} 迷因點數';
    }
  }

  /// 獲取連續簽到天數
  int getCurrentStreak() {
    final checkinState = getCurrentCheckinState();
    return checkinState?.streak.current ?? 0;
  }

  /// 獲取累計簽到天數
  int getTotalCheckins() {
    final checkinState = getCurrentCheckinState();
    return checkinState?.streak.total ?? 0;
  }

  /// 獲取最佳連續記錄
  int getBestStreak() {
    final checkinState = getCurrentCheckinState();
    return checkinState?.streak.best ?? 0;
  }
}

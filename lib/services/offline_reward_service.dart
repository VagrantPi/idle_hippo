import 'package:flutter/widgets.dart';
import 'package:idle_hippo/models/game_state.dart';

/// 離線收益計算與生命週期管理
/// - 暫存 lastExitUtcMs 與 idleRateSnapshot 於 GameState.offline
/// - 回前台時計算 pendingReward（一次性），上限 capHours
class OfflineRewardService with WidgetsBindingObserver {
  static final OfflineRewardService _instance = OfflineRewardService._internal();
  factory OfflineRewardService() => _instance;
  OfflineRewardService._internal();

  // 外部注入
  late double Function() _getIdlePerSec; // 當前放置速率（每秒）
  late GameState Function() _getGameState; // 取得最新的 GameState（由宿主維護）
  late Future<void> Function(GameState) _persist; // 寫入存檔
  void Function(double reward, Duration effective)? _onPendingReward;
  int Function()? _nowUtcMsProvider; // 測試注入當前 UTC ms

  bool _initialized = false;

  void init({
    required double Function() getIdlePerSec,
    required GameState Function() getGameState,
    required Future<void> Function(GameState) onPersist,
    void Function(double, Duration)? onPendingReward,
    int Function()? nowUtcMsProvider,
  }) {
    _getIdlePerSec = getIdlePerSec;
    _getGameState = getGameState;
    _persist = onPersist;
    _onPendingReward = onPendingReward;
    _nowUtcMsProvider = nowUtcMsProvider;

    if (!_initialized) {
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
    }
  }

  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
  }

  int _nowMs() => _nowUtcMsProvider?.call() ?? DateTime.now().toUtc().millisecondsSinceEpoch;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_initialized) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _onBackground();
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onBackground() async {
    final now = _nowMs();
    final gs = _getGameState();
    final snapshot = _getIdlePerSec();

    final updated = gs.copyWith(
      offline: gs.offline.copyWith(
        lastExitUtcMs: now,
        idleRateSnapshot: snapshot,
      ),
    );
    await _persist(updated);
  }

  Future<void> _onResumed() async {
    final gs = _getGameState();
    // 若已有待領取（舊版本遺留），立即入帳並清空，仍通知 UI 顯示本次金額
    if (gs.offline.pendingReward > 0) {
      final eff = _effectiveDuration(gs);
      final applied = gs.memePoints + gs.offline.pendingReward;
      final now = _nowMs();
      final migrated = gs.copyWith(
        memePoints: applied,
        offline: gs.offline.copyWith(
          pendingReward: 0.0,
          lastExitUtcMs: now,
        ),
      );
      await _persist(migrated);
      _onPendingReward?.call(gs.offline.pendingReward, eff);
      return;
    }

    final now = _nowMs();
    final last = gs.offline.lastExitUtcMs;
    if (last <= 0) return; // 沒有離線記錄

    final elapsedMs = now - last;
    if (elapsedMs <= 0) return; // 負數/無效

    final capSeconds = (gs.offline.capHours * 3600).toDouble();
    final elapsedSeconds = elapsedMs / 1000.0;
    final effectiveSeconds = elapsedSeconds.clamp(0.0, capSeconds);

    final snapshot = gs.offline.idleRateSnapshot;
    if (snapshot <= 0 || effectiveSeconds <= 0) return;

    final reward = snapshot * effectiveSeconds;
    if (reward <= 0) return;

    // 立即入帳並清空 pending，更新 lastExitUtcMs 以避免重複結算
    final nowTs = _nowMs();
    final updated = gs.copyWith(
      memePoints: gs.memePoints + reward,
      offline: gs.offline.copyWith(
        pendingReward: 0.0,
        lastExitUtcMs: nowTs,
      ),
    );
    await _persist(updated);
    _onPendingReward?.call(reward, Duration(seconds: effectiveSeconds.floor()));
  }

  Duration _effectiveDuration(GameState gs) {
    final now = _nowMs();
    final last = gs.offline.lastExitUtcMs;
    if (last <= 0) return Duration.zero;
    final elapsedMs = now - last;
    if (elapsedMs <= 0) return Duration.zero;
    final capSeconds = (gs.offline.capHours * 3600).toDouble();
    final eff = (elapsedMs / 1000.0).clamp(0.0, capSeconds);
    return Duration(seconds: eff.floor());
  }

  // Debug：將 lastExitUtcMs 回推 seconds，並觸發一次 resume 計算
  Future<void> simulateAddSeconds(int seconds) async {
    if (seconds <= 0) return;
    final gs = _getGameState();
    // 當前放置速率快照（用於回前台計算獎勵）
    final snapshot = _getIdlePerSec();
    // 若不存在離線記錄：建立基準並直接回推 seconds 以在單次呼叫中產生待領取
    if (gs.offline.lastExitUtcMs <= 0) {
      final newLast = _nowMs() - seconds * 1000;
      final baseline = gs.copyWith(
        offline: gs.offline.copyWith(
          lastExitUtcMs: newLast,
          idleRateSnapshot: snapshot,
        ),
      );
      await _persist(baseline);
      await _onResumed();
      return;
    }

    // 已有離線記錄：將 lastExit 回推 seconds 後觸發一次結算
    final newLast = gs.offline.lastExitUtcMs - seconds * 1000;
    final updated = gs.copyWith(
      offline: gs.offline.copyWith(
        lastExitUtcMs: newLast,
        idleRateSnapshot: snapshot,
      ),
    );
    await _persist(updated);
    await _onResumed();
  }

  // Debug：清除待領取
  Future<void> clearPending() async {
    final gs = _getGameState();
    if (gs.offline.pendingReward <= 0) return;
    final updated = gs.copyWith(
      offline: gs.offline.copyWith(pendingReward: 0.0),
    );
    await _persist(updated);
  }
}

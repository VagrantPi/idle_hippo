import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

class GameClockService with WidgetsBindingObserver {
  static final GameClockService _instance = GameClockService._internal();
  factory GameClockService() => _instance;
  GameClockService._internal();

  // 配置參數
  static const double _targetFps = 60.0;
  static const double _maxDeltaSeconds = 0.2;
  static const double _emaAlpha = 0.2;
  static const Duration _tickInterval = Duration(milliseconds: 16); // ~60fps

  // 狀態變數
  Timer? _gameTimer;
  DateTime? _lastTickTime;
  bool _isInForeground = true;
  bool _isRunning = false;
  bool _isFixedStepMode = false;
  double _fixedDelta = 1.0 / 60.0; // 60fps for testing

  // 訂閱者管理
  final Map<String, void Function(double deltaSeconds)> _subscribers = {};

  // 統計資料
  double _smoothDelta = 1.0 / _targetFps;
  final List<double> _recentDeltas = [];
  int _frameCount = 0;
  DateTime? _fpsCountStartTime;

  // Getters
  bool get isRunning => _isRunning;
  bool get isInForeground => _isInForeground;
  int get subscribersCount => _subscribers.length;
  double get currentFps {
    if (_fpsCountStartTime == null || _frameCount == 0) return 0.0;
    final elapsed = DateTime.now().difference(_fpsCountStartTime!).inMilliseconds;
    if (elapsed == 0) return 0.0;
    return _frameCount * 1000.0 / elapsed;
  }
  double get averageDeltaMs => _smoothDelta * 1000.0;
  String get lifecycleState => _isInForeground ? 'foreground' : 'background';

  /// 初始化 GameClock
  void init() {
    WidgetsBinding.instance.addObserver(this);
    _fpsCountStartTime = DateTime.now();
    _frameCount = 0;
    print('GameClock: Initialized');
  }

  /// 啟動時間系統
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _lastTickTime = DateTime.now();
    _resetFpsCounter();
    
    if (_isInForeground) {
      _startTimer();
    }
    
    print('GameClock: Started');
  }

  /// 停止時間系統
  void stop() {
    if (!_isRunning) return;
    
    _isRunning = false;
    _stopTimer();
    print('GameClock: Stopped');
  }

  /// 清理資源
  void dispose() {
    stop();
    WidgetsBinding.instance.removeObserver(this);
    _subscribers.clear();
    print('GameClock: Disposed');
  }

  /// 訂閱時間更新
  void subscribe(String id, void Function(double deltaSeconds) handler) {
    _subscribers[id] = handler;
    print('GameClock: Subscribed $id (total: ${_subscribers.length})');
  }

  /// 取消訂閱
  void unsubscribe(String id) {
    if (_subscribers.remove(id) != null) {
      print('GameClock: Unsubscribed $id (total: ${_subscribers.length})');
    }
  }

  /// 切換固定步長測試模式
  void setFixedStepMode(bool enabled, {double? fixedDelta}) {
    _isFixedStepMode = enabled;
    if (fixedDelta != null) {
      _fixedDelta = fixedDelta;
    }
    print('GameClock: Fixed step mode ${enabled ? 'enabled' : 'disabled'} (delta: $_fixedDelta)');
  }

  /// 啟動計時器
  void _startTimer() {
    if (_gameTimer?.isActive == true) return;
    
    _gameTimer = Timer.periodic(_tickInterval, (timer) {
      if (_isInForeground && _isRunning) {
        _tick();
      }
    });
  }

  /// 停止計時器
  void _stopTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  /// 主要 tick 邏輯
  void _tick() {
    final now = DateTime.now();
    
    if (_lastTickTime == null) {
      _lastTickTime = now;
      return;
    }

    // 計算原始 delta
    double rawDelta = now.difference(_lastTickTime!).inMicroseconds / 1000000.0;
    _lastTickTime = now;

    // 處理異常值
    if (rawDelta.isNaN || rawDelta.isInfinite || rawDelta < 0) {
      print('GameClock: Invalid delta detected, skipping frame');
      return;
    }

    // Delta 夾制
    rawDelta = math.min(rawDelta, _maxDeltaSeconds);

    // 使用固定步長或實際 delta
    final deltaSeconds = _isFixedStepMode ? _fixedDelta : rawDelta;

    // 更新平滑 delta (EMA) - 在 fixedStep 模式下也使用固定值
    final deltaForStats = _isFixedStepMode ? _fixedDelta : rawDelta;
    _smoothDelta = _emaAlpha * deltaForStats + (1.0 - _emaAlpha) * _smoothDelta;

    // 更新統計 - 在 fixedStep 模式下使用固定值
    _updateStats(deltaForStats);

    // 廣播給所有訂閱者
    _broadcastTick(deltaSeconds);
  }

  /// 更新統計資料
  void _updateStats(double rawDelta) {
    _frameCount++;
    
    // 保持最近的 delta 記錄用於分析
    _recentDeltas.add(rawDelta);
    if (_recentDeltas.length > 60) { // 保持最近 60 幀
      _recentDeltas.removeAt(0);
    }

    // 每秒重置 fps 計數器
    if (_fpsCountStartTime != null && 
        DateTime.now().difference(_fpsCountStartTime!).inSeconds >= 1) {
      _resetFpsCounter();
    }
  }

  /// 重置 fps 計數器
  void _resetFpsCounter() {
    _fpsCountStartTime = DateTime.now();
    _frameCount = 0;
  }

  /// 廣播 tick 事件給所有訂閱者
  void _broadcastTick(double deltaSeconds) {
    for (final handler in _subscribers.values) {
      try {
        handler(deltaSeconds);
      } catch (e) {
        print('GameClock: Error in subscriber handler: $e');
      }
    }
  }

  /// 測試用途：手動推進時間，繞過計時器（不受前/後台限制）
  /// 僅用於測試快速模擬長時間累積，避免實際等待。
  /// 注意：會套用與 _tick 相同的統計更新語意（含夾制）。
  void debugPump(double deltaSeconds, {int times = 1}) {
    if (deltaSeconds.isNaN || deltaSeconds.isInfinite || deltaSeconds <= 0) {
      return;
    }
    final clamped = math.min(deltaSeconds, _maxDeltaSeconds);
    for (int i = 0; i < times; i++) {
      // 在 fixedStep 模式下，以固定值進行
      final deltaForStats = _isFixedStepMode ? _fixedDelta : clamped;
      _smoothDelta = _emaAlpha * deltaForStats + (1.0 - _emaAlpha) * _smoothDelta;
      _updateStats(deltaForStats);
      final deltaToBroadcast = _isFixedStepMode ? _fixedDelta : clamped;
      _broadcastTick(deltaToBroadcast);
    }
  }

  /// 應用生命週期變化處理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final wasInForeground = _isInForeground;
    _isInForeground = state == AppLifecycleState.resumed;
    
    print('GameClock: Lifecycle changed to $state (foreground: $_isInForeground)');
    
    if (_isInForeground && !wasInForeground) {
      // 回到前台 - 重置時間基準避免大 delta
      _lastTickTime = DateTime.now();
      _resetFpsCounter();
      
      if (_isRunning) {
        _startTimer();
      }
    } else if (!_isInForeground && wasInForeground) {
      // 進入背景 - 停止計時器
      _stopTimer();
    }
  }

  /// 獲取詳細統計資訊（用於 debug）
  Map<String, dynamic> getStats() {
    return {
      'isRunning': _isRunning,
      'isInForeground': _isInForeground,
      'subscribersCount': _subscribers.length,
      'currentFps': currentFps,
      'averageDeltaMs': averageDeltaMs,
      'smoothDeltaMs': _smoothDelta * 1000.0,
      'isFixedStepMode': _isFixedStepMode,
      'fixedDelta': _fixedDelta,
      'frameCount': _frameCount,
    };
  }
}

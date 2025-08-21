import '../services/config_service.dart';
import '../services/game_clock_service.dart';

class IdleIncomeService {
  static final IdleIncomeService _instance = IdleIncomeService._internal();
  factory IdleIncomeService() => _instance;
  IdleIncomeService._internal();

  final ConfigService _configService = ConfigService();
  final GameClockService _gameClock = GameClockService();
  
  // 狀態變數
  bool _isSubscribed = false;
  bool _testingMode = false; // 測試模式：不訂閱 GameClock，由測試手動推進
  
  // 測試覆寫：允許在測試中直接指定 idle_per_sec
  double? _idlePerSecOverride;
  
  // 統計資料
  double _totalIdleTime = 0.0;
  double _totalIdleIncome = 0.0;
  
  // 收益回調函數
  void Function(double points)? _onIncomeGenerated;
  
  // Getters
  double get totalIdleTime => _totalIdleTime;
  double get totalIdleIncome => _totalIdleIncome;
  double get currentIdlePerSec {
    if (_idlePerSecOverride != null) return _idlePerSecOverride!;
    // 預設為 0.1，以在測試或尚未載入設定時提供合理的非零值
    final v = _configService.getValue('game.idle.base_per_sec', defaultValue: 0.1);
    if (v is num) return v.toDouble();
    return 0.1;
  }

  /// 測試用途：設定 idle_per_sec 覆寫（傳入 null 以清除）
  void setTestingIdlePerSec(double? value) {
    _idlePerSecOverride = value;
  }
  
  /// 初始化放置收益系統
  void init({void Function(double points)? onIncomeGenerated}) {
    // 只在第一次初始化時設定回調函數
    if (_onIncomeGenerated == null && onIncomeGenerated != null) {
      _onIncomeGenerated = onIncomeGenerated;
    }
    
    if (!_testingMode && !_isSubscribed) {
      _gameClock.subscribe('idle_income', _onTick);
      _isSubscribed = true;
      print('IdleIncomeService: Initialized and subscribed to GameClock');
    }
  }
  
  /// 清理資源
  void dispose() {
    if (_isSubscribed) {
      _gameClock.unsubscribe('idle_income');
      _isSubscribed = false;
      print('IdleIncomeService: Disposed and unsubscribed from GameClock');
    }
  }
  
  /// 重置統計資料
  void resetStats() {
    _totalIdleTime = 0.0;
    _totalIdleIncome = 0.0;
  }
  
  /// GameClock tick 處理
  void _onTick(double deltaSeconds) {
    final idlePerSec = currentIdlePerSec;
    
    if (idlePerSec <= 0) return;
    
    // 計算本幀的放置收益
    final idleIncome = idlePerSec * deltaSeconds;
    
    // 直接透過回調將收益加到 GameState
    _onIncomeGenerated?.call(idleIncome);
    
    // 更新統計
    _totalIdleTime += deltaSeconds;
    _totalIdleIncome += idleIncome;
  }

  /// 測試用途：啟用/關閉測試模式（啟用後不會訂閱 GameClock）
  void enableTestingMode(bool enabled) {
    _testingMode = enabled;
    if (_testingMode && _isSubscribed) {
      _gameClock.unsubscribe('idle_income');
      _isSubscribed = false;
    }
  }

  /// 測試用途：手動推進一個 tick（只在測試模式下使用）
  void onTickForTest(double deltaSeconds) {
    _onTick(deltaSeconds);
  }
  
  /// 獲取詳細統計資訊（用於 debug）
  Map<String, dynamic> getStats() {
    return {
      'currentIdlePerSec': currentIdlePerSec,
      'totalIdleTime': _totalIdleTime,
      'totalIdleIncome': _totalIdleIncome,
      'averageIncomePerSec': _totalIdleTime > 0 ? _totalIdleIncome / _totalIdleTime : 0.0,
      'isSubscribed': _isSubscribed,
    };
  }
}

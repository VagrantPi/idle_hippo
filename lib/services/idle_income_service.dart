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
  
  // 統計資料
  double _totalIdleTime = 0.0;
  double _totalIdleIncome = 0.0;
  
  // 收益回調函數
  void Function(double points)? _onIncomeGenerated;
  
  // Getters
  double get totalIdleTime => _totalIdleTime;
  double get totalIdleIncome => _totalIdleIncome;
  double get currentIdlePerSec => _configService.getValue('game.idle.base_per_sec', defaultValue: 0.1);
  
  /// 初始化放置收益系統
  void init({void Function(double points)? onIncomeGenerated}) {
    // 只在第一次初始化時設定回調函數
    if (_onIncomeGenerated == null && onIncomeGenerated != null) {
      _onIncomeGenerated = onIncomeGenerated;
    }
    
    if (!_isSubscribed) {
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

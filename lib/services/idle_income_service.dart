import '../services/config_service.dart';
import '../services/game_clock_service.dart';
import '../services/equipment_service.dart';
import '../services/pet_service.dart';
import '../services/decimal_utils.dart';
import '../models/game_state.dart';

class IdleIncomeService {
  static final IdleIncomeService _instance = IdleIncomeService._internal();
  factory IdleIncomeService() => _instance;
  IdleIncomeService._internal();

  final ConfigService _configService = ConfigService();
  final GameClockService _gameClock = GameClockService();
  final EquipmentService _equipmentService = EquipmentService();
  final PetService _petService = PetService();
  
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
  
  // 當前 GameState 參考（用於計算裝備加成）
  GameState? _currentGameState;
  
  // Getters
  double get totalIdleTime => _totalIdleTime;
  double get totalIdleIncome => _totalIdleIncome;
  double get currentIdlePerSec {
    if (_idlePerSecOverride != null) return _idlePerSecOverride!;
    
    // 基礎放置速率
    final baseVal = _configService.getValue('game.idle.base_per_sec', defaultValue: 0.1);
    final base = baseVal is num ? baseVal.toDouble() : 0.1;
    
    // 放置裝備加成
    double equipmentBonus = 0.0;
    if (_currentGameState != null) {
      equipmentBonus = _equipmentService.sumIdleBonus(_currentGameState!);
    }
    
    // 寵物加成：始終以 PetService 的即時狀態為準
    // 若尚未有任何寵物（例如從舊存檔載入），且 GameState 帶有 petState，僅初始化一次
    double petBonus = 0.0;
    if (_petService.currentState.pets.isEmpty && _currentGameState?.petState != null) {
      _petService.initialize(_currentGameState!.petState);
    }
    petBonus = _petService.getCurrentPetIdlePerSec();
    
    return DecimalUtils.add(DecimalUtils.add(base, equipmentBonus), petBonus);
  }

  /// 測試用途：設定 idle_per_sec 覆寫（傳入 null 以清除）
  void setTestingIdlePerSec(double? value) {
    _idlePerSecOverride = value;
  }

  /// 更新當前 GameState（用於計算裝備加成）
  void updateGameState(GameState gameState) {
    _currentGameState = gameState;
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
    }
  }
  
  /// 清理資源
  void dispose() {
    if (_isSubscribed) {
      _gameClock.unsubscribe('idle_income');
      _isSubscribed = false;
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
    final idleIncome = DecimalUtils.multiply(idlePerSec, deltaSeconds);
    
    // 直接透過回調將收益加到 GameState
    _onIncomeGenerated?.call(idleIncome);
    
    // 更新統計
    _totalIdleTime = DecimalUtils.add(_totalIdleTime, deltaSeconds);
    _totalIdleIncome = DecimalUtils.add(_totalIdleIncome, idleIncome);
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

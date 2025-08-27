import 'dart:math';
import 'dart:async';
import 'package:idle_hippo/models/pet.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/pet_service.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/secure_save_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/rewarded_ad_service.dart';

/// 抽卡結果
class GachaResult {
  final String petKey;
  final String name;
  final PetRarity rarity;
  final String imagePath;
  final bool isNew; // 是否為新獲得的寵物
  final int timestamp;

  const GachaResult({
    required this.petKey,
    required this.name,
    required this.rarity,
    required this.imagePath,
    required this.isNew,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'petKey': petKey,
      'name': name,
      'rarity': rarity.value,
      'imagePath': imagePath,
      'isNew': isNew,
      'timestamp': timestamp,
    };
  }

  factory GachaResult.fromMap(Map<String, dynamic> map) {
    return GachaResult(
      petKey: map['petKey'] as String,
      name: map['name'] as String,
      rarity: PetRarity.fromString(map['rarity'] as String),
      imagePath: map['imagePath'] as String,
      isNew: map['isNew'] as bool,
      timestamp: map['timestamp'] as int,
    );
  }
}


/// 抽卡服務
class GachaService {
  static final GachaService _instance = GachaService._internal();
  factory GachaService() => _instance;
  GachaService._internal();

  final ConfigService _configService = ConfigService();
  final SecureSaveService _saveService = SecureSaveService();
  final Random _random = Random();
  final RewardedAdService _rewardedAdService = RewardedAdService();
  final GameStateService _gameStateService = GameStateService();
  
  GameState? _currentState;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ---- Tickets Stream (broadcast) ----
  final StreamController<int> _petTicketsController = StreamController<int>.broadcast();
  Stream<int> get petTicketsStream => _petTicketsController.stream;
  void _emitPetTickets() {
    final count = _currentState?.petTickets ?? 0;
    // 嘗試送出最新票數，避免因為沒有人訂閱而拋錯
    try {
      _petTicketsController.add(count);
    } catch (_) {}
  }

  // ---- Gacha History Stream (broadcast) ----
  final StreamController<List<GachaHistoryRecord>> _gachaHistoryController =
      StreamController<List<GachaHistoryRecord>>.broadcast();
  Stream<List<GachaHistoryRecord>> get gachaHistoryStream => _gachaHistoryController.stream;
  void _emitGachaHistory() {
    final history = _currentState?.gachaHistory ?? const <GachaHistoryRecord>[];
    try {
      _gachaHistoryController.add(history);
    } catch (_) {}
  }

  // 抽卡機率設定 (累積機率)
  static const Map<PetRarity, double> _rarityProbabilities = {
    PetRarity.ssr: 0.02,  // 2%
    PetRarity.sr: 0.10,   // 8% (累積 10%)
    PetRarity.s: 0.20,    // 10% (累積 20%)
    PetRarity.r: 0.40,    // 20% (累積 40%)
    PetRarity.rr: 1.00,   // 60% (累積 100%)
  };

  // 可抽取的寵物列表（預設僅 MooDeng，實際會從配置載入）
  static const List<String> _availablePets = ['MooDeng'];

  /// 初始化服務
  Future<void> initialize() async {
    // 確保配置已載入
    if (!_configService.isLoaded) {
      await _configService.loadConfig();
    }
    await _gameStateService.initialize();
    _currentState = _gameStateService.gameState.value;
    _gameStateService.gameState.addListener(() {
      _currentState = _gameStateService.gameState.value;
      _emitPetTickets();
      _emitGachaHistory();
    });

    await _rewardedAdService.initialize(_gameStateService);

    await PetService().initialize(_currentState?.petState);
    _emitPetTickets();
    _emitGachaHistory();
    _initialized = true;
  }

  /// 確保服務已初始化（Hot reload 後可再次觸發）
  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// 保存狀態
  Future<void> _saveState(GameState state) async {
    await _gameStateService.updateGameState(state);
    await PetService().initialize(state.petState); // PetService might need its own state management later
  }

  /// 執行單次抽卡
  Future<GachaResult> performSingleGacha() async {
    if (_currentState == null) {
      await initialize();
    }
    
    final currentState = _currentState!;
    
    // 檢查抽獎券數量
    if (currentState.petTickets < 1) {
      throw Exception('抽獎券不足');
    }

    // 扣除抽獎券
    final updatedState = currentState.copyWith(petTickets: currentState.petTickets - 1);
    await _saveState(updatedState);

    // 執行抽卡
    final result = _performGacha();
    
    // 處理抽卡結果
    await _processGachaResult(result);
    
    // 記錄抽卡歷史
    await _addGachaHistory(result);

    return result;
  }

  /// 執行十連抽 (實際獲得 11 次)
  Future<List<GachaResult>> performTenPlusOneGacha() async {
    if (_currentState == null) {
      await initialize();
    }
    
    final currentState = _currentState!;
    
    // 檢查抽獎券數量
    if (currentState.petTickets < 10) {
      throw Exception('抽獎券不足，需要 10 張');
    }

    // 扣除抽獎券
    final updatedState = currentState.copyWith(petTickets: currentState.petTickets - 10);
    await _saveState(updatedState);

    // 執行 11 次抽卡
    final results = <GachaResult>[];
    for (int i = 0; i < 11; i++) {
      final result = _performGacha();
      await _processGachaResult(result);
      await _addGachaHistory(result);
      results.add(result);
    }

    return results;
  }

  /// 執行抽卡邏輯
  GachaResult _performGacha() {
    // 抽取稀有度
    final rarity = _drawRarity();
    
    // 隨機選擇寵物（優先從配置載入）
    final petKey = _rollPet();
    
    // 獲取寵物配置
    final petConfig = _configService.getPetConfig(petKey);
    if (petConfig == null) {
      throw Exception('寵物配置不存在: $petKey');
    }

    final rarityConfig = petConfig['rarities'][rarity.value];
    if (rarityConfig == null) {
      throw Exception('稀有度配置不存在: ${rarity.value}');
    }

    // 檢查是否為新寵物
    final currentState = _currentState!;
    final petId = '${petKey}_${rarity.value}';
    final isNew = currentState.petState?.pets.any((pet) => 
      '${pet.petKey}_${pet.rarity.value}' == petId) != true;

    return GachaResult(
      petKey: petKey,
      name: petConfig['name'] as String,
      rarity: rarity,
      imagePath: petConfig['image'] as String,
      isNew: isNew,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 抽取稀有度
  PetRarity _drawRarity() {
    final roll = _random.nextDouble();
    
    for (final entry in _rarityProbabilities.entries) {
      if (roll <= entry.value) {
        return entry.key;
      }
    }
    
    return PetRarity.rr; // 預設返回最低稀有度
  }

  /// 處理抽卡結果
  Future<void> _processGachaResult(GachaResult result) async {
    final currentState = _currentState!;
    final petState = currentState.petState ?? const PetState();
    
    final petId = '${result.petKey}_${result.rarity.value}';
    
    // 查找是否已存在相同寵物
    final existingPetIndex = petState.pets.indexWhere((pet) => 
      '${pet.petKey}_${pet.rarity.value}' == petId);

    List<Pet> updatedPets = List<Pet>.from(petState.pets);

    if (existingPetIndex != -1) {
      // 已存在，增加升級點數
      final existingPet = updatedPets[existingPetIndex];
      updatedPets[existingPetIndex] = existingPet.addUpgradePoints(1);
    } else {
      // 新寵物，加入列表
      final petConfig = _configService.getPetConfig(result.petKey);
      if (petConfig == null) {
        throw Exception('寵物配置不存在: ${result.petKey}');
      }
      final rarityConfig = petConfig['rarities'][result.rarity.value];
      
      final newPet = Pet(
        petKey: result.petKey,
        name: result.name,
        imagePath: result.imagePath,
        rarity: result.rarity,
        baseIdlePerSec: (rarityConfig['baseIdlePerSec'] as num).toDouble(),
        level: 1,
        upgradePoints: 0,
        isEquipped: false,
      );
      
      updatedPets.add(newPet);
    }

    // 更新寵物狀態
    final updatedPetState = petState.copyWith(pets: updatedPets);
    final updatedState = currentState.copyWith(petState: updatedPetState);
    await _saveState(updatedState);
  }

  /// 添加抽卡歷史記錄
  Future<void> _addGachaHistory(GachaResult result) async {
    final currentState = _currentState!;
    final currentHistory = currentState.gachaHistory;
    
    final newRecord = GachaHistoryRecord(
      rarity: result.rarity.value,
      name: result.name,
      timestamp: result.timestamp,
      petKey: result.petKey,
    );
    
    // 添加新記錄到開頭
    final updatedHistory = <GachaHistoryRecord>[newRecord, ...currentHistory];
    
    // 保持最多 N 條記錄（由設定決定，預設 50）
    final maxRecords = _configService.getValue('game.gacha.history.maxRecords', defaultValue: 50) as int;
    final limitedHistory = updatedHistory.take(maxRecords).toList();
    
    // 更新到 GameState
    final updatedState = currentState.copyWith(gachaHistory: limitedHistory);
    await _saveState(updatedState);
    _emitGachaHistory();
  }

  /// 獲取抽卡歷史記錄
  List<GachaHistoryRecord> getGachaHistory() {
    return _currentState?.gachaHistory ?? <GachaHistoryRecord>[];
  }

  /// 清空抽卡歷史記錄 (Debug 用)
  Future<void> clearGachaHistory() async {
    if (_currentState == null) {
      await initialize();
    }
    final updatedState = _currentState!.copyWith(gachaHistory: []);
    await _saveState(updatedState);
    _emitGachaHistory();
  }

  /// 模擬抽卡 1000 次 (Debug 用)
  Map<PetRarity, int> simulateGacha1000Times() {
    final results = <PetRarity, int>{};
    
    for (final rarity in PetRarity.values) {
      results[rarity] = 0;
    }
    
    for (int i = 0; i < 1000; i++) {
      final rarity = _drawRarity();
      results[rarity] = (results[rarity] ?? 0) + 1;
    }
    
    return results;
  }

  /// 驗證機率分佈是否在誤差範圍內
  bool validateProbabilityDistribution(Map<PetRarity, int> results) {
    // 以總樣本數計算每個稀有度的期望數量，允許「總數的 ±5%」誤差
    final total = results.values.fold<int>(0, (sum, v) => sum + v);
    if (total == 0) return false;

    // 個別稀有度「實際」機率（非累積）
    const ratios = {
      PetRarity.ssr: 0.02,
      PetRarity.sr: 0.08,
      PetRarity.s: 0.10,
      PetRarity.r: 0.20,
      PetRarity.rr: 0.60,
    };

    final allowedError = (total * 0.05); // 5% of total

    for (final entry in ratios.entries) {
      final expected = (entry.value * total);
      final actual = (results[entry.key] ?? 0).toDouble();
      final diff = (actual - expected).abs();
      if (diff > allowedError) {
        return false;
      }
    }

    return true;
  }

  /// 增加抽獎券 (Debug 用)
  Future<void> addPetTickets(int amount) async {
    if (_currentState == null) {
      await initialize();
    }
    final updatedState = _currentState!.copyWith(
      petTickets: _currentState!.petTickets + amount
    );
    await _saveState(updatedState);
  }

  /// 獲取當前抽獎券數量
  int getPetTickets() {
    return _currentState?.petTickets ?? 0;
  }

  /// 執行單次抽卡
  Future<GachaResult> performSingleDraw() async {
    if (_currentState == null) {
      await initialize();
    }

    final currentState = _currentState!;
    if (currentState.petTickets < 1) {
      throw Exception('抽獎券不足');
    }

    // 扣除抽獎券
    final updatedState = currentState.copyWith(petTickets: currentState.petTickets - 1);
    await _saveState(updatedState);

    // 執行抽卡
    final result = _performSingleGacha();
    
    // 處理抽卡結果
    await _processGachaResult(result);
    
    // 記錄抽卡歷史
    await _recordGachaHistory(result);

    return result;
  }

  /// 執行十一連抽
  Future<List<GachaResult>> performTenPlusOneDraw() async {
    if (_currentState == null) await initialize();

    final currentState = _currentState!;
    if (currentState.petTickets < 10) {
      throw Exception('抽獎券不足');
    }

    // 扣除抽獎券
    final updatedState = currentState.copyWith(petTickets: currentState.petTickets - 10);
    await _saveState(updatedState);

    return _performMultipleDraws(11);
  }

  /// 執行廣告觀看後的十一連抽
  Future<List<GachaResult>> drawTenPlusOneWithAd() async {
    if (!_initialized) await initialize();

    if (!(await _rewardedAdService.canShowGachaTenPackAd())) {
      throw Exception('今日已無廣告抽卡機會');
    }

    // 消耗廣告次數
    final consumed = await _rewardedAdService.consumeGachaTenPackAd();
    if (!consumed) {
      throw Exception('消耗廣告次數失敗');
    }

    // 執行抽卡，不消耗票券
    return _performMultipleDraws(11);
  }

  /// 執行多次抽卡的內部邏輯
  Future<List<GachaResult>> _performMultipleDraws(int count) async {
    final results = <GachaResult>[];
    for (int i = 0; i < count; i++) {
      final result = _performSingleGacha();
      results.add(result);
      await _processGachaResult(result);
      await _recordGachaHistory(result);
    }
    return results;
  }

  /// 執行單次抽卡邏輯
  GachaResult _performSingleGacha() {
    final rarity = _rollRarity();
    final petKey = _rollPet();
    final petConfig = _configService.getPetConfig(petKey);
    if (petConfig == null) {
      throw Exception('寵物配置不存在: $petKey');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return GachaResult(
      petKey: petKey,
      name: petConfig['name'] as String,
      rarity: rarity,
      imagePath: petConfig['image'] as String,
      isNew: !_isPetOwned(petKey, rarity),
      timestamp: timestamp,
    );
  }

  /// 隨機選擇稀有度
  PetRarity _rollRarity() {
    final roll = _random.nextDouble();
    double cumulative = 0.0;
    
    for (final entry in _rarityProbabilities.entries) {
      cumulative += entry.value;
      if (roll <= cumulative) {
        return entry.key;
      }
    }
    
    return PetRarity.rr; // 預設返回最低稀有度
  }

  /// 隨機選擇寵物
  String _rollPet() {
    final petsList = _configService.getValue('pets.pets') as List<dynamic>?;
    if (petsList != null && petsList.isNotEmpty) {
      final ids = petsList
          .whereType<Map<String, dynamic>>()
          .map((e) => e['id'] as String)
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) {
        return ids[_random.nextInt(ids.length)];
      }
    }
    // fallback
    return _availablePets[_random.nextInt(_availablePets.length)];
  }

  /// 記錄抽卡歷史
  Future<void> _recordGachaHistory(GachaResult result) async {
    if (_currentState == null) return;
    
    final currentState = _currentState!;
    final currentHistory = currentState.gachaHistory;
    
    final newRecord = GachaHistoryRecord(
      rarity: result.rarity.value,
      name: result.name,
      timestamp: result.timestamp,
      petKey: result.petKey,
    );
    
    // 添加新記錄到開頭
    final updatedHistory = <GachaHistoryRecord>[newRecord, ...currentHistory];
    
    // 保持最多 N 條記錄（由設定決定，預設 50）
    final maxRecords = _configService.getValue('game.gacha.history.maxRecords', defaultValue: 50) as int;
    final limitedHistory = updatedHistory.take(maxRecords).toList();
    
    // 更新到 GameState
    final updatedState = currentState.copyWith(gachaHistory: limitedHistory);
    await _saveState(updatedState);
    _emitGachaHistory();
  }

  /// 檢查是否已擁有指定寵物
  bool _isPetOwned(String petKey, PetRarity rarity) {
    final petState = _currentState?.petState;
    if (petState == null) return false;
    
    final petId = '${petKey}_${rarity.value}';
    return petState.pets.any((pet) => '${pet.petKey}_${pet.rarity.value}' == petId);
  }
}

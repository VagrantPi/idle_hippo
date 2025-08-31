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

    // 自動恢復：若存在未提交的抽卡批次，嘗試提交（冪等）
    try {
      await commitPendingBatchIfAny();
    } catch (_) {}
  }

  /// 確保服務已初始化（Hot reload 後可再次觸發）
  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// 保存狀態
  Future<void> _saveState(GameState state) async {
    // 先同步更新本地狀態，避免緊接著的讀取看到舊資料（如 pending 未清）
    _currentState = state;
    _emitPetTickets();
    _emitGachaHistory();
    await _gameStateService.updateGameState(state);
    await PetService().initialize(state.petState); // TODO: PetService 應拆出自己的狀態管理
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

    final rarityConfig = _configService.getPetRarityConfig(petKey, rarity.value);
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
      final rarityConfig = _configService.getPetRarityConfig(result.petKey, result.rarity.value);
      if (rarityConfig == null) {
        throw Exception('稀有度配置不存在: ${result.rarity.value}');
      }
      
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
    return await createPendingTenPlusOneBatch();
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

  /// 執行多次抽卡的內部邏輯（不改變票券）：批次應用並一次保存
  Future<List<GachaResult>> _performMultipleDraws(int count) async {
    if (_currentState == null) await initialize();
    final baseState = _currentState!;

    final results = <GachaResult>[];
    for (int i = 0; i < count; i++) {
      results.add(_performSingleGacha());
    }

    final nextState = _applyBatchChanges(baseState, results);
    await _saveState(nextState);
    return results;
  }

  // ================= Two-phase commit for 10+1 =================

  /// 建立十加一抽的 Pending 批次：
  /// 1) 檢查票券並先扣除 10 張
  /// 2) 產生 11 筆結果，寫入 pendingGachaBatch
  /// 3) 立即回傳結果給 UI 開始動畫（未套用到寵物/歷史）
  Future<List<GachaResult>> createPendingTenPlusOneBatch() async {
    if (_currentState == null) await initialize();
    final s = _currentState!;
    if (s.petTickets < 10) {
      throw Exception('抽獎券不足');
    }

    // 若已存在未提交批次，先嘗試提交或清除（冪等處理）
    if (s.pendingGachaBatch != null) {
      await commitPendingBatchIfAny();
    }

    // 生成結果
    final results = <GachaResult>[];
    for (int i = 0; i < 11; i++) {
      results.add(_performSingleGacha());
    }

    final batchId = 'g_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final pending = PendingGachaBatch(
      batchId: batchId,
      createdAt: createdAt,
      results: results
          .map((r) => PendingGachaBatchItem(
                petKey: r.petKey,
                name: r.name,
                rarity: r.rarity.value,
                imagePath: r.imagePath,
                timestamp: r.timestamp,
              ))
          .toList(),
    );

    final next = s.copyWith(
      petTickets: s.petTickets - 10,
      pendingGachaBatch: pending,
    );
    await _saveState(next);
    return results;
  }

  /// 提交 Pending 批次（若存在）。冪等：
  /// - 若歷史已含該批次所有 timestamp，視為已提交，僅清除 pending。
  /// - 否則批次套用到寵物與歷史，然後清除 pending。
  Future<bool> commitPendingBatchIfAny() async {
    if (_currentState == null) await initialize();
    final s = _currentState!;
    final pending = s.pendingGachaBatch;
    if (pending == null) return false;

    // 將 pending 轉回 GachaResult 以重用既有批次邏輯
    List<GachaResult> results = pending.results
        .map((e) => GachaResult(
              petKey: e.petKey,
              name: e.name,
              rarity: PetRarity.fromString(e.rarity),
              imagePath: e.imagePath,
              isNew: !_isPetOwned(e.petKey, PetRarity.fromString(e.rarity)),
              timestamp: e.timestamp,
            ))
        .toList();

    // 冪等檢查：歷史是否已有這批 timestamps（至少大多數匹配視為已寫入）
    final pendingTimestamps = results.map((r) => r.timestamp).toSet();
    final existingTs = s.gachaHistory.map((h) => h.timestamp).toSet();
    final int overlap = pendingTimestamps.where(existingTs.contains).length;
    final bool alreadyApplied = overlap >= (results.length * 0.8).floor();

    GameState nextState;
    if (alreadyApplied) {
      // 僅清除 pending
      nextState = s.copyWith(clearPendingGachaBatch: true);
    } else {
      // 批次套用
      nextState = _applyBatchChanges(s, results).copyWith(clearPendingGachaBatch: true);
    }

    await _saveState(nextState);
    return true;
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

  /// 將一批抽卡結果批次套用到狀態（只計算，不即時寫入）
  GameState _applyBatchChanges(GameState state, List<GachaResult> results) {
    // 1) 更新寵物清單/升級點數
    final petState = state.petState ?? const PetState();
    final updatedPets = List<Pet>.from(petState.pets);

    for (final result in results) {
      final petId = '${result.petKey}_${result.rarity.value}';
      final idx = updatedPets.indexWhere((p) => '${p.petKey}_${p.rarity.value}' == petId);
      if (idx != -1) {
        final existing = updatedPets[idx];
        updatedPets[idx] = existing.addUpgradePoints(1);
      } else {
        final rarityCfg = _configService.getPetRarityConfig(result.petKey, result.rarity.value);
        if (rarityCfg == null) {
          // 若配置缺失，跳過該筆以避免整批失敗
          continue;
        }
        final newPet = Pet(
          petKey: result.petKey,
          name: result.name,
          imagePath: result.imagePath,
          rarity: result.rarity,
          baseIdlePerSec: (rarityCfg['baseIdlePerSec'] as num).toDouble(),
          level: 1,
          upgradePoints: 0,
          isEquipped: false,
        );
        updatedPets.add(newPet);
      }
    }

    final nextPetState = petState.copyWith(pets: updatedPets);

    // 2) 批次更新抽卡歷史（插入到開頭，並裁切至上限）
    final newRecords = results
        .map((r) => GachaHistoryRecord(
              rarity: r.rarity.value,
              name: r.name,
              timestamp: r.timestamp,
              petKey: r.petKey,
            ))
        .toList();
    final maxRecords = _configService.getValue('game.gacha.history.maxRecords', defaultValue: 50) as int;
    final mergedHistory = <GachaHistoryRecord>[...newRecords, ...state.gachaHistory];
    final limited = mergedHistory.take(maxRecords).toList();

    return state.copyWith(
      petState: nextPetState,
      gachaHistory: limited,
    );
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

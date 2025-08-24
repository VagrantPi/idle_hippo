import 'dart:async';
import '../models/pet.dart';
import 'config_service.dart';

class PetService {
  static final PetService _instance = PetService._internal();
  factory PetService() => _instance;
  PetService._internal();

  final ConfigService _configService = ConfigService();
  
  StreamController<PetState>? _petStateController;
  Stream<PetState> get petStateStream {
    _ensureController();
    return _petStateController!.stream;
  }

  PetState _currentState = const PetState();
  PetState get currentState => _currentState;

  /// 初始化寵物系統
  Future<void> initialize(PetState? savedState) async {
    if (savedState != null && savedState.pets.isNotEmpty) {
      _currentState = savedState;
    } else {
      // 確保設定已載入，否則無法從 pets.json 建立初始寵物
      if (!_configService.isLoaded) {
        await _configService.loadConfig();
      }
      // 建立初始寵物列表
      _currentState = await _createInitialPets();
    }
    _emitState();
  }

  /// 建立初始寵物列表（五隻不同稀有度的 MooDeng）
  Future<PetState> _createInitialPets() async {
    final petsConfig = _configService.getValue('pets.pets', defaultValue: []);
    if (petsConfig.isEmpty) {
      return const PetState();
    }

    final petConfig = petsConfig[0] as Map<String, dynamic>;
    final petKey = petConfig['id'] as String;
    final petName = petConfig['name'] as String;
    final imagePath = petConfig['image'] as String;
    final rarities = petConfig['rarities'] as Map<String, dynamic>;

    final List<Pet> pets = [];

    // 為每個稀有度建立一隻寵物
    for (final rarityEntry in rarities.entries) {
      final rarityData = rarityEntry.value as Map<String, dynamic>;
      final rarity = PetRarity.fromString(rarityData['rarity'] as String);
      final baseIdlePerSec = (rarityData['baseIdlePerSec'] as num).toDouble();

      pets.add(Pet(
        petKey: petKey,
        name: petName,
        imagePath: imagePath,
        rarity: rarity,
        baseIdlePerSec: baseIdlePerSec,
        level: 1,
        upgradePoints: 0,
        isEquipped: false,
      ));
    }

    // 按稀有度排序（SSR > SR > S > R > RR）
    pets.sort((a, b) {
      final rarityCompare = b.rarity.sortWeight.compareTo(a.rarity.sortWeight);
      if (rarityCompare != 0) return rarityCompare;
      // 相同稀有度按 petKey 字典序排序
      return a.petKey.compareTo(b.petKey);
    });

    return PetState(pets: pets);
  }

  /// 裝備寵物
  Future<void> equipPet(Pet pet) async {
    _currentState = _currentState.equipPet(pet);
    _emitState();
    await _saveState();
  }

  /// 取消裝備所有寵物
  Future<void> unequipAll() async {
    _currentState = _currentState.unequipAll();
    _emitState();
    await _saveState();
  }

  /// 與測試相容：提供 unequipPet() 作為別名，行為等同於卸下所有寵物
  Future<void> unequipPet() async {
    await unequipAll();
  }

  /// 增加寵物升級點數
  Future<void> addUpgradePoints(PetRarity rarity, int points) async {
    final targetPet = _currentState.pets.firstWhere(
      (pet) => pet.rarity == rarity,
      orElse: () => throw Exception('找不到稀有度為 ${rarity.value} 的寵物'),
    );

    final updatedPet = targetPet.addUpgradePoints(points);
    _currentState = _currentState.updatePet(updatedPet);
    _emitState();
    await _saveState();
  }

  /// 升級寵物
  Future<bool> upgradePet(Pet pet) async {
    if (!pet.canUpgrade) return false;

    final upgradedPet = pet.upgrade();
    _currentState = _currentState.updatePet(upgradedPet);
    _emitState();
    await _saveState();
    return true;
  }

  /// 取得當前裝備寵物的 idlePerSec 貢獻
  double getCurrentPetIdlePerSec() {
    final equippedPet = _currentState.equippedPet;
    if (equippedPet == null) return 0.0;

    final upgradeConfig = _configService.getValue('pets.upgrade', defaultValue: {});
    final levelUpUpgradeBase = (upgradeConfig['levelUpUpgradeBase'] ?? 0.5).toDouble();
    final decayLevels = (upgradeConfig['levelUpUpgradeDecayLevels'] ?? 10) as int;
    final decayRate = (upgradeConfig['levelUpUpgradeDecayRate'] ?? 0.5).toDouble();

    return equippedPet.getCurrentIdlePerSec(levelUpUpgradeBase, decayLevels, decayRate);
  }

  /// 取得特定寵物的當前 idlePerSec
  double getPetIdlePerSec(Pet pet) {
    final upgradeConfig = _configService.getValue('pets.upgrade', defaultValue: {});
    final levelUpUpgradeBase = (upgradeConfig['levelUpUpgradeBase'] ?? 0.5).toDouble();
    final decayLevels = (upgradeConfig['levelUpUpgradeDecayLevels'] ?? 10) as int;
    final decayRate = (upgradeConfig['levelUpUpgradeDecayRate'] ?? 0.5).toDouble();

    return pet.getCurrentIdlePerSec(levelUpUpgradeBase, decayLevels, decayRate);
  }

  /// 取得費氏數列升級需求
  int getFibonacciUpgradeRequirement(int targetLevel) {
    if (targetLevel <= 1) return 1;
    if (targetLevel == 2) return 2;
    
    int prev = 1;
    int curr = 2;
    
    for (int i = 3; i <= targetLevel; i++) {
      int next = prev + curr;
      prev = curr;
      curr = next;
      if (i == targetLevel) {
        return curr;
      }
    }
    
    return curr;
  }

  /// 計算等級加成倍率
  double calculateLevelUpgradeMultiplier(int level) {
    if (level <= 1) return 1.0;
    
    final upgradeConfig = _configService.getValue('pets.upgrade', defaultValue: {});
    final levelUpUpgradeBase = (upgradeConfig['levelUpUpgradeBase'] ?? 0.5).toDouble();
    final decayLevels = (upgradeConfig['levelUpUpgradeDecayLevels'] ?? 10) as int;
    final decayRate = (upgradeConfig['levelUpUpgradeDecayRate'] ?? 0.5).toDouble();
    
    double totalUpgrade = 0.0;
    double currentUpgrade = levelUpUpgradeBase;
    
    for (int i = 2; i <= level; i++) {
      totalUpgrade += currentUpgrade;
      
      // 每過 decayLevels 等級，升級加成減半
      if (i % decayLevels == 0) {
        currentUpgrade *= decayRate;
      }
    }
    
    return 1.0 + totalUpgrade;
  }

  /// 取得按稀有度排序的寵物列表
  List<Pet> getSortedPets() {
    final pets = List<Pet>.from(_currentState.pets);
    pets.sort((a, b) {
      final rarityCompare = b.rarity.sortWeight.compareTo(a.rarity.sortWeight);
      if (rarityCompare != 0) return rarityCompare;
      return a.petKey.compareTo(b.petKey);
    });
    return pets;
  }

  /// 根據稀有度取得寵物
  Pet? getPetByRarity(PetRarity rarity) {
    try {
      return _currentState.pets.firstWhere((pet) => pet.rarity == rarity);
    } catch (e) {
      return null;
    }
  }

  /// 檢查是否有寵物可以升級
  bool hasUpgradablePets() {
    return _currentState.pets.any((pet) => pet.canUpgrade);
  }

  /// 取得所有可升級的寵物
  List<Pet> getUpgradablePets() {
    return _currentState.pets.where((pet) => pet.canUpgrade).toList();
  }

  /// 儲存狀態到本地存儲
  Future<void> _saveState() async {
    // 這裡應該通過 GameState 來保存，暫時先不實作
    // 等待 GameState 更新後再實作
  }

  /// 重置寵物系統（用於測試或重新開始）
  Future<void> reset() async {
    _currentState = await _createInitialPets();
    _emitState();
    await _saveState();
  }

  /// 為所有寵物增加升級點數
  Future<void> addUpgradePointsToAll(int points) async {
    final updatedPets = _currentState.pets.map((pet) => pet.addUpgradePoints(points)).toList();
    _currentState = _currentState.copyWith(pets: updatedPets);
    _emitState();
    await _saveState();
  }

  /// 釋放資源
  void dispose() {
    // 減少測試間相互影響：允許在 dispose 後重建 controller
    _petStateController?.close();
    _petStateController = null;
  }

  /// Debug: 取得寵物詳細資訊
  Map<String, dynamic> getDebugInfo() {
    final upgradeConfig = _configService.getValue('pets.upgrade', defaultValue: {});
    
    return {
      'totalPets': _currentState.pets.length,
      'equippedPetId': _currentState.equippedPetId,
      'equippedPetIdlePerSec': getCurrentPetIdlePerSec(),
      'upgradeConfig': upgradeConfig,
      'pets': _currentState.pets.map((pet) => {
        'petKey': pet.petKey,
        'rarity': pet.rarity.value,
        'level': pet.level,
        'upgradePoints': pet.upgradePoints,
        'nextLevelRequirement': pet.nextLevelRequirement,
        'canUpgrade': pet.canUpgrade,
        'currentIdlePerSec': getPetIdlePerSec(pet),
        'isEquipped': pet.isEquipped,
      }).toList(),
    };
  }

  // --- 私有工具方法 ---
  void _ensureController() {
    if (_petStateController == null || _petStateController!.isClosed) {
      _petStateController = StreamController<PetState>.broadcast();
    }
  }

  void _emitState() {
    _ensureController();
    _petStateController!.add(_currentState);
  }
}

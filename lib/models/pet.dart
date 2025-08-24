import 'dart:ui';

/// 寵物稀有度枚舉
enum PetRarity {
  rr('RR'),
  r('R'),
  s('S'),
  sr('SR'),
  ssr('SSR');

  const PetRarity(this.value);
  final String value;

  /// 從字串轉換為稀有度
  static PetRarity fromString(String value) {
    return PetRarity.values.firstWhere(
      (rarity) => rarity.value == value,
      orElse: () => PetRarity.rr,
    );
  }

  /// 稀有度排序權重（數字越大稀有度越高）
  int get sortWeight {
    switch (this) {
      case PetRarity.rr:
        return 1;
      case PetRarity.r:
        return 2;
      case PetRarity.s:
        return 3;
      case PetRarity.sr:
        return 4;
      case PetRarity.ssr:
        return 5;
    }
  }

  /// 取得稀有度顏色
  Color getColor() {
    switch (this) {
      case PetRarity.rr:
        return const Color(0xFF808080); // 灰色
      case PetRarity.r:
        return const Color(0xFF00FF00); // 綠色
      case PetRarity.s:
        return const Color(0xFF0000FF); // 藍色
      case PetRarity.sr:
        return const Color(0xFF800080); // 紫色
      case PetRarity.ssr:
        return const Color(0xFFFF0000); // 紅色
    }
  }
}

/// 寵物實例類別
class Pet {
  final String petKey; // 寵物種類識別碼 (如 "MooDeng")
  final String name; // 寵物名稱
  final String imagePath; // 圖片路徑
  final PetRarity rarity; // 稀有度
  final double baseIdlePerSec; // 基礎放置收益
  final int level; // 當前等級
  final int upgradePoints; // 累積升級點數
  final bool isEquipped; // 是否已裝備

  const Pet({
    required this.petKey,
    required this.name,
    required this.imagePath,
    required this.rarity,
    required this.baseIdlePerSec,
    this.level = 1,
    this.upgradePoints = 0,
    this.isEquipped = false,
  });

  /// 從 Map 建立 Pet 實例
  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      petKey: map['petKey'] as String,
      name: map['name'] as String,
      imagePath: map['imagePath'] as String,
      rarity: PetRarity.fromString(map['rarity'] as String),
      baseIdlePerSec: (map['baseIdlePerSec'] as num).toDouble(),
      level: (map['level'] ?? 1) as int,
      upgradePoints: (map['upgradePoints'] ?? 0) as int,
      isEquipped: (map['isEquipped'] ?? false) as bool,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'petKey': petKey,
      'name': name,
      'imagePath': imagePath,
      'rarity': rarity.value,
      'baseIdlePerSec': baseIdlePerSec,
      'level': level,
      'upgradePoints': upgradePoints,
      'isEquipped': isEquipped,
    };
  }

  /// 計算費氏數列升級需求
  int getUpgradeRequirement(int targetLevel) {
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

  /// 取得下一級升級需求
  int get nextLevelRequirement => getUpgradeRequirement(level + 1);

  /// 檢查是否可以升級
  bool get canUpgrade => upgradePoints >= nextLevelRequirement;

  /// 計算當前等級加成倍率
  double getLevelUpgradeMultiplier(double levelUpUpgradeBase, int decayLevels, double decayRate) {
    if (level <= 1) return 1.0;
    
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

  /// 計算當前實際 idlePerSec
  double getCurrentIdlePerSec(double levelUpUpgradeBase, int decayLevels, double decayRate) {
    final multiplier = getLevelUpgradeMultiplier(levelUpUpgradeBase, decayLevels, decayRate);
    return baseIdlePerSec * multiplier;
  }

  /// 複製並更新部分欄位
  Pet copyWith({
    String? petKey,
    String? name,
    String? imagePath,
    PetRarity? rarity,
    double? baseIdlePerSec,
    int? level,
    int? upgradePoints,
    bool? isEquipped,
  }) {
    return Pet(
      petKey: petKey ?? this.petKey,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      rarity: rarity ?? this.rarity,
      baseIdlePerSec: baseIdlePerSec ?? this.baseIdlePerSec,
      level: level ?? this.level,
      upgradePoints: upgradePoints ?? this.upgradePoints,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }

  /// 升級寵物
  Pet upgrade() {
    if (!canUpgrade) return this;
    
    final requiredPoints = nextLevelRequirement;
    return copyWith(
      level: level + 1,
      upgradePoints: upgradePoints - requiredPoints,
    );
  }

  /// 增加升級點數
  Pet addUpgradePoints(int points) {
    return copyWith(upgradePoints: upgradePoints + points);
  }

  /// 設定裝備狀態
  Pet setEquipped(bool equipped) {
    return copyWith(isEquipped: equipped);
  }

  @override
  String toString() {
    return 'Pet(petKey: $petKey, rarity: ${rarity.value}, level: $level, '
           'upgradePoints: $upgradePoints, isEquipped: $isEquipped)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pet &&
        other.petKey == petKey &&
        other.name == name &&
        other.imagePath == imagePath &&
        other.rarity == rarity &&
        other.baseIdlePerSec == baseIdlePerSec &&
        other.level == level &&
        other.upgradePoints == upgradePoints &&
        other.isEquipped == isEquipped;
  }

  @override
  int get hashCode {
    return petKey.hashCode ^
        name.hashCode ^
        imagePath.hashCode ^
        rarity.hashCode ^
        baseIdlePerSec.hashCode ^
        level.hashCode ^
        upgradePoints.hashCode ^
        isEquipped.hashCode;
  }
}

/// 寵物狀態類別（用於 GameState）
class PetState {
  final List<Pet> pets; // 所有寵物列表
  final String? equippedPetId; // 當前裝備的寵物 ID (petKey + rarity)

  const PetState({
    this.pets = const [],
    this.equippedPetId,
  });

  /// 從 Map 建立 PetState
  factory PetState.fromMap(Map<String, dynamic> map) {
    final petsData = map['pets'] as List<dynamic>? ?? [];
    final pets = petsData
        .map((petData) => Pet.fromMap(petData as Map<String, dynamic>))
        .toList();

    return PetState(
      pets: pets,
      equippedPetId: map['equippedPetId'] as String?,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'pets': pets.map((pet) => pet.toMap()).toList(),
      'equippedPetId': equippedPetId,
    };
  }

  /// 取得當前裝備的寵物
  Pet? get equippedPet {
    if (equippedPetId == null) return null;
    try {
      return pets.firstWhere((pet) => _getPetId(pet) == equippedPetId);
    } catch (e) {
      return null;
    }
  }

  /// 生成寵物唯一 ID
  String _getPetId(Pet pet) => '${pet.petKey}_${pet.rarity.value}';

  /// 複製並更新部分欄位
  PetState copyWith({
    List<Pet>? pets,
    String? equippedPetId,
  }) {
    return PetState(
      pets: pets ?? List<Pet>.from(this.pets),
      equippedPetId: equippedPetId ?? this.equippedPetId,
    );
  }

  /// 更新特定寵物
  PetState updatePet(Pet updatedPet) {
    final updatedPets = pets.map((pet) {
      if (_getPetId(pet) == _getPetId(updatedPet)) {
        return updatedPet;
      }
      return pet;
    }).toList();

    return copyWith(pets: updatedPets);
  }

  /// 裝備寵物
  PetState equipPet(Pet pet) {
    // 先將所有寵物設為未裝備
    final updatedPets = pets.map((p) => p.setEquipped(false)).toList();
    
    // 設定目標寵物為已裝備
    final targetIndex = updatedPets.indexWhere((p) => _getPetId(p) == _getPetId(pet));
    if (targetIndex != -1) {
      updatedPets[targetIndex] = updatedPets[targetIndex].setEquipped(true);
    }

    return PetState(
      pets: updatedPets,
      equippedPetId: _getPetId(pet),
    );
  }

  /// 取消裝備
  PetState unequipAll() {
    final updatedPets = pets.map((pet) => pet.setEquipped(false)).toList();
    return PetState(
      pets: updatedPets,
      equippedPetId: null,
    );
  }

  @override
  String toString() {
    return 'PetState(pets: ${pets.length}, equippedPetId: $equippedPetId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PetState &&
        _listEquals(other.pets, pets) &&
        other.equippedPetId == equippedPetId;
  }

  @override
  int get hashCode {
    return pets.hashCode ^ (equippedPetId?.hashCode ?? 0);
  }

  bool _listEquals(List<Pet> a, List<Pet> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

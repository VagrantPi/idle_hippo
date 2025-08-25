import 'package:idle_hippo/models/game_state.dart';
import '../services/config_service.dart';
import '../services/decimal_utils.dart';

class EquipmentService {
  static final EquipmentService _instance = EquipmentService._internal();
  factory EquipmentService() => _instance;
  EquipmentService._internal();

  final ConfigService _config = ConfigService();
  // 測試用：允許注入 tap_equipments，避免測試依賴資產
  List<Map<String, dynamic>>? _tapEquipmentsOverride;
  // 測試用：允許注入 idle_equipments
  List<Map<String, dynamic>>? _idleEquipmentsOverride;

  /// 測試時注入 tap equipments（僅單元測試使用）
  void setTapEquipmentsForTest(List<Map<String, dynamic>> items) {
    _tapEquipmentsOverride = items;
  }

  /// 測試時注入 idle equipments（僅單元測試使用）
  void setIdleEquipmentsForTest(List<Map<String, dynamic>> items) {
    _idleEquipmentsOverride = items;
  }

  /// 清除測試注入
  void clearTestOverrides() {
    _tapEquipmentsOverride = null;
    _idleEquipmentsOverride = null;
  }

  List<Map<String, dynamic>> _tapEquipments() {
    if (_tapEquipmentsOverride != null) return _tapEquipmentsOverride!;
    final list = _config.getValue('equipments.tap_equipments', defaultValue: []);
    if (list is List) {
      return list.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  List<Map<String, dynamic>> _idleEquipments() {
    if (_idleEquipmentsOverride != null) return _idleEquipmentsOverride!;
    final list = _config.getValue('equipments.idle_equipments', defaultValue: []);
    if (list is List) {
      return list.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  /// 供 UI 使用：取得所有 tap 類型裝備清單（只讀）
  List<Map<String, dynamic>> listTapEquipments() {
    // 回傳複本避免外部修改
    return List<Map<String, dynamic>>.from(_tapEquipments());
  }

  /// 供 UI 使用：取得所有 idle 類型裝備清單（只讀）
  List<Map<String, dynamic>> listIdleEquipments() {
    // 回傳複本避免外部修改
    return List<Map<String, dynamic>>.from(_idleEquipments());
  }

  Map<String, dynamic>? _findTapEquipment(String id) {
    for (final e in _tapEquipments()) {
      if (e['id'] == id) return e;
    }
    return null;
  }

  Map<String, dynamic>? _findIdleEquipment(String id) {
    for (final e in _idleEquipments()) {
      if (e['id'] == id) return e;
    }
    return null;
  }

  /// 讀取裝備相依（requires），格式：{"id": "rgb_keyboard", "level": 3}
  (String id, int level)? _requireOf(Map<String, dynamic> equip) {
    final req = equip['requires'];
    if (req is Map<String, dynamic>) {
      final rid = req['id'];
      final lv = req['level'];
      if (rid is String && lv is num) {
        return (rid, lv.toInt());
      }
    }
    return null;
  }

  /// 讀取放置裝備解鎖條件（unlock），格式：{"type": "equip_level", "id": "youtube", "level": 3}
  (String type, String id, int level)? _unlockConditionOf(Map<String, dynamic> equip) {
    final unlock = equip['unlock'];
    if (unlock is Map<String, dynamic>) {
      final type = unlock['type'];
      final id = unlock['id'];
      final level = unlock['level'];
      if (type is String && id is String && level is num) {
        return (type, id, level.toInt());
      }
    }
    return null;
  }

  /// 檢查指定 tap 裝備是否已解鎖（依相依條件）
  bool isUnlockedBy(Map<String, int> equipments, String id) {
    final equip = _findTapEquipment(id);
    if (equip == null) return false;
    final req = _requireOf(equip);
    if (req == null) return true; // 無相依直接解鎖
    final current = equipments[req.$1] ?? 0;
    return current >= req.$2;
  }

  /// 檢查指定 idle 裝備是否已解鎖（依解鎖條件）
  bool isIdleEquipmentUnlocked(Map<String, int> equipments, String id) {
    final equip = _findIdleEquipment(id);
    if (equip == null) return false;
    final condition = _unlockConditionOf(equip);
    if (condition == null) return true; // 無條件直接解鎖
    
    final (type, reqId, reqLevel) = condition;
    if (type == 'equip_level') {
      final current = equipments[reqId] ?? 0;
      return current >= reqLevel;
    }
    
    return false; // 未知類型條件
  }

  // 統一：以 double 計算累積加成（支援小數）
  double _cumulativeBonus(Map<String, dynamic> equip, int level) {
    final levels = equip['levels'] as List<dynamic>?;
    if (levels == null) return 0.0;
    
    final bonuses = <num>[];
    for (final m in levels) {
      if (m is! Map<String, dynamic>) continue;
      final lv = (m['level'] as num).toInt();
      if (lv <= level) {
        final b = m['bonus'];
        if (b is num) bonuses.add(b);
      }
    }
    return DecimalUtils.sum(bonuses);
  }

  // 計算放置裝備的累積 bonus_per_sec
  double _cumulativeIdleBonus(Map<String, dynamic> equip, int level) {
    if (level <= 0) return 0.0;
    final levels = equip['levels'] as List<dynamic>?;
    if (levels == null) return 0.0;
    
    final bonuses = <num>[];
    for (final m in levels) {
      final lv = (m['level'] as num).toInt();
      if (lv <= level) {
        final b = m['bonus_per_sec'];
        if (b is num) bonuses.add(b);
      }
    }
    return DecimalUtils.sum(bonuses);
  }

  /// 供 UI 使用：取得指定 tap 裝備在某等級時的累積加成（double）
  double cumulativeBonusFor(String id, int level) {
    final equip = _findTapEquipment(id);
    if (equip == null) return 0.0;
    return _cumulativeBonus(equip, level);
  }

  /// 供 UI 使用：取得指定 idle 裝備在某等級時的累積 bonus_per_sec（double）
  double cumulativeIdleBonusFor(String id, int level) {
    final equip = _findIdleEquipment(id);
    if (equip == null) return 0.0;
    return _cumulativeIdleBonus(equip, level);
  }

  int _maxLevel(Map<String, dynamic> equip) {
    final max = equip['max_level'];
    if (max is num) return max.toInt();
    return 10;
  }

  double sumTapBonus(GameState state) {
    final bonuses = <double>[];
    for (final entry in state.equipments.entries) {
      final equip = _findTapEquipment(entry.key);
      if (equip == null) continue;
      final level = entry.value;
      if (level <= 0) continue;
      bonuses.add(_cumulativeBonus(equip, level));
    }
    return DecimalUtils.sum(bonuses);
  }

  /// 計算所有放置裝備的總 bonus_per_sec
  double sumIdleBonus(GameState state) {
    final bonuses = <double>[];
    for (final entry in state.equipments.entries) {
      final equip = _findIdleEquipment(entry.key);
      if (equip == null) continue;
      final level = entry.value;
      if (level <= 0) continue;
      bonuses.add(_cumulativeIdleBonus(equip, level));
    }
    return DecimalUtils.sum(bonuses);
  }

  double computeTapGain(GameState state) {
    final baseVal = _config.getValue('game.tap.base', defaultValue: 1);
    final base = baseVal is num ? baseVal.toDouble() : 1.0;
    return DecimalUtils.add(base, sumTapBonus(state));
  }

  int? getNextCost(String id, int currentLevel) {
    final equip = _findTapEquipment(id);
    if (equip == null) return null;
    final maxLv = _maxLevel(equip);
    if (currentLevel >= maxLv) return null;
    final nextLv = currentLevel + 1;
    final levels = (equip['levels'] as List).cast<Map<String, dynamic>>();
    final found = levels.firstWhere(
      (m) => (m['level'] as num).toInt() == nextLv,
      orElse: () => const {},
    );
    if (found.isEmpty) return null;
    final cost = found['cost'];
    if (cost is num) return cost.toInt();
    return null;
  }

  /// 取得放置裝備的下一級升級成本
  int? getIdleNextCost(String id, int currentLevel) {
    final equip = _findIdleEquipment(id);
    if (equip == null) return null;
    final maxLv = _maxLevel(equip);
    if (currentLevel >= maxLv) return null;
    final nextLv = currentLevel + 1;
    final levels = (equip['levels'] as List).cast<Map<String, dynamic>>();
    final found = levels.firstWhere(
      (m) => (m['level'] as num).toInt() == nextLv,
      orElse: () => const {},
    );
    if (found.isEmpty) return null;
    final cost = found['cost'];
    if (cost is num) return cost.toInt();
    return null;
  }

  bool canUpgrade(GameState state, String id) {
    final currentLevel = state.equipments[id] ?? 0;
    final cost = getNextCost(id, currentLevel);
    if (cost == null) return false;
    if (!isUnlockedBy(state.equipments, id)) return false;
    return state.memePoints >= cost;
  }

  /// 檢查放置裝備是否可升級
  bool canUpgradeIdle(GameState state, String id) {
    // 僅針對 youtube 需要主線解鎖，其餘依自身 unlock 條件
    if (id == 'youtube') {
      // 與 UI 與 quests.json 對齊：使用 equipment.youtube 作為解鎖鍵
      final questUnlocked = state.mainQuest?.unlockedRewards.contains('equipment.$id') ?? false;
      if (!questUnlocked) return false;
    }
    final currentLevel = state.equipments[id] ?? 0;
    final cost = getIdleNextCost(id, currentLevel);
    if (cost == null) return false;
    if (!isIdleEquipmentUnlocked(state.equipments, id)) return false;
    return state.memePoints >= cost;
  }

  GameState upgrade(GameState state, String id) {
    final currentLevel = state.equipments[id] ?? 0;
    final cost = getNextCost(id, currentLevel);
    if (cost == null) return state; // 已滿級或裝備不存在
    if (!isUnlockedBy(state.equipments, id)) return state; // 未解鎖
    if (state.memePoints < cost) return state; // 資源不足

    final newMap = Map<String, int>.from(state.equipments);
    newMap[id] = currentLevel + 1;

    return state.copyWith(
      memePoints: DecimalUtils.add(state.memePoints, -cost),
      equipments: newMap,
    );
  }

  /// 升級放置裝備
  GameState upgradeIdle(GameState state, String id) {
    // 僅針對 youtube 需要主線解鎖
    if (id == 'youtube') {
      // 與 UI 與 quests.json 對齊：使用 equipment.youtube 作為解鎖鍵
      final questUnlocked = state.mainQuest?.unlockedRewards.contains('equipment.$id') ?? false;
      if (!questUnlocked) return state;
    }
    final currentLevel = state.equipments[id] ?? 0;
    final cost = getIdleNextCost(id, currentLevel);
    if (cost == null) return state; // 已滿級或裝備不存在
    if (!isIdleEquipmentUnlocked(state.equipments, id)) return state; // 未解鎖
    if (state.memePoints < cost) return state; // 資源不足

    final newMap = Map<String, int>.from(state.equipments);
    newMap[id] = currentLevel + 1;

    return state.copyWith(
      memePoints: DecimalUtils.add(state.memePoints, -cost),
      equipments: newMap,
    );
  }
}

import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/decimal_utils.dart';

class EquipmentService {
  static final EquipmentService _instance = EquipmentService._internal();
  factory EquipmentService() => _instance;
  EquipmentService._internal();

  final ConfigService _config = ConfigService();
  // 測試用：允許注入 tap_equipments，避免測試依賴資產
  List<Map<String, dynamic>>? _tapEquipmentsOverride;

  /// 測試時注入 tap equipments（僅單元測試使用）
  void setTapEquipmentsForTest(List<Map<String, dynamic>> items) {
    _tapEquipmentsOverride = items;
  }

  /// 清除測試注入
  void clearTestOverrides() {
    _tapEquipmentsOverride = null;
  }

  List<Map<String, dynamic>> _tapEquipments() {
    if (_tapEquipmentsOverride != null) return _tapEquipmentsOverride!;
    final list = _config.getValue('equipments.tap_equipments', defaultValue: []);
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

  Map<String, dynamic>? _findTapEquipment(String id) {
    for (final e in _tapEquipments()) {
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

  /// 檢查指定裝備是否已解鎖（依相依條件）
  bool isUnlockedBy(Map<String, int> equipments, String id) {
    final equip = _findTapEquipment(id);
    if (equip == null) return false;
    final req = _requireOf(equip);
    if (req == null) return true; // 無相依直接解鎖
    final current = equipments[req.$1] ?? 0;
    return current >= req.$2;
  }

  // 統一：以 double 計算累積加成（支援小數）
  double _cumulativeBonus(Map<String, dynamic> equip, int level) {
    if (level <= 0) return 0.0;
    final levels = (equip['levels'] as List).cast<Map<String, dynamic>>();
    double sum = 0.0;
    for (final m in levels) {
      final lv = (m['level'] as num).toInt();
      if (lv <= level) {
        final b = m['bonus'];
        if (b is num) sum += b.toDouble();
      }
    }
    return sum;
  }

  /// 供 UI 使用：取得指定裝備在某等級時的累積加成（double）
  double cumulativeBonusFor(String id, int level) {
    final equip = _findTapEquipment(id);
    if (equip == null) return 0.0;
    return _cumulativeBonus(equip, level);
  }

  int _maxLevel(Map<String, dynamic> equip) {
    final max = equip['max_level'];
    if (max is num) return max.toInt();
    return 10;
  }

  double sumTapBonus(GameState state) {
    double sum = 0.0;
    final equips = state.equipments;
    for (final entry in equips.entries) {
      final equip = _findTapEquipment(entry.key);
      if (equip == null) continue;
      final level = entry.value;
      if (level <= 0) continue;
      sum += _cumulativeBonus(equip, level);
    }
    return sum;
  }

  double computeTapGain(GameState state) {
    final baseVal = _config.getValue('game.tap.base', defaultValue: 1);
    final base = baseVal is num ? baseVal.toDouble() : 1.0;
    return base + sumTapBonus(state);
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

  bool canUpgrade(GameState state, String id) {
    final currentLevel = state.equipments[id] ?? 0;
    final cost = getNextCost(id, currentLevel);
    if (cost == null) return false;
    if (!isUnlockedBy(state.equipments, id)) return false;
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
}

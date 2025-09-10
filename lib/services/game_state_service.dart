import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import 'secure_save_service.dart';
import 'config_service.dart';

/// A service to manage the global game state.
/// It handles loading, saving, and notifying listeners of state changes.
class GameStateService {
  static final GameStateService _instance = GameStateService._internal();
  factory GameStateService() => _instance;
  GameStateService._internal();

  final SecureSaveService _saveService = SecureSaveService();

  late ValueNotifier<GameState> gameState = ValueNotifier(
    GameState.initial(1),
  ); // 使用預設版本號 1
  bool _initialized = false;
  bool _testMode = false;
  bool _allowTestFallback = false; // 僅在單元測試允許 fallback

  /// 向後相容：回傳目前的遊戲狀態（供舊測試使用）
  GameState get currentState => gameState.value;

  /// Initializes the service by loading the game state from secure storage.
  Future<void> initialize() async {
    if (_initialized) return;

    final loadedState = await _saveService.load();
    gameState = ValueNotifier(loadedState);
    _initialized = true;
    // 確保初次啟動也有基準存檔，避免後續重啟讀到空白初始狀態
    try {
      await _saveService.save(loadedState);
    } catch (_) {
      // 忽略初始化寫入錯誤；後續 updateGameState 仍會再嘗試
    }
  }

  /// Updates the game state and saves it to secure storage.
  /// This will also notify any listeners.
  Future<void> updateGameState(
    GameState newState, {
    bool forceReplace = false,
    bool throwOnError = false,
  }) async {
    // 若尚未初始化，優先執行正式初始化，避免誤入測試模式
    if (!_initialized) {
      try {
        await initialize();
      } catch (_) {
        // 最差情況：仍未能初始化時，僅更新記憶體快照，避免崩潰
        gameState = ValueNotifier(newState);
        _initialized = true;
      }
    }
    // 防止競態導致裝備等級回退：預設以目前狀態為基準做 max 合併；重置流程可強制覆寫
    final GameState guarded;
    if (!forceReplace) {
      final current = gameState.value;
      final mergedEquip = Map<String, int>.from(newState.equipments);
      current.equipments.forEach((k, v) {
        final nv = mergedEquip[k];
        if (nv == null || nv < v) {
          mergedEquip[k] = v;
        }
      });
      guarded = newState.copyWith(equipments: mergedEquip);
    } else {
      guarded = newState;
    }

    // 在寫入前重新評估稱號（僅針對裝備相關條件）
    final evaluated = _evaluateTitlesEquipConditions(guarded);
    gameState.value = evaluated;
    // 在測試模式下避免觸發平台相依的 secure storage
    if (!_testMode) {
      try {
        await _saveService.save(evaluated);
      } on MissingPluginException {
        // 僅在允許時才切換為測試模式（單元測試）
        if (_allowTestFallback) {
          _testMode = true;
        }
        if (throwOnError) rethrow;
      } catch (_) {
        // 其他寫入錯誤：不切換為測試模式，保留後續寫入嘗試機會
        if (throwOnError) rethrow;
      }
    }
  }

  /// Initializes the service for testing purposes with a specific initial state.
  Future<void> initializeForTest(GameState initialState) async {
    gameState = ValueNotifier(initialState);
    _initialized = true;
    _testMode = true;
    _allowTestFallback = true;
  }

  // ----------------------
  // Internal: Titles Check
  // ----------------------
  String _normalizeEquipId(String raw) {
    var id = raw.trim();
    if (id.startsWith('equip.')) {
      id = id.substring('equip.'.length);
    }
    switch (id) {
      case '114514':
        return 'title_114514';
      case 'Mask':
      case 'mask':
        return 'faceMask';
      default:
        return id;
    }
  }

  bool _isEquipmentLevelReached(
    Map<String, int> equipments,
    String equipId,
    int requiredLevel,
  ) {
    final norm = _normalizeEquipId(equipId);
    final altLower = norm.toLowerCase();
    final current =
        equipments[norm] ?? equipments[altLower] ?? equipments[equipId] ?? 0;
    return current >= requiredLevel;
  }

  GameState _evaluateTitlesEquipConditions(GameState state) {
    final cfg = ConfigService();
    final titlesList =
        (cfg.getValue('titles.titles', defaultValue: []) as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];

    if (titlesList.isEmpty) return state;

    final equipments = state.equipments;
    final titlesState = state.titles;
    var newStates = Map<String, String>.from(titlesState?.states ?? const {});
    var hasNewClaimable = titlesState?.hasClaimable ?? false;

    // 第一輪：處理 equip_level_reach 與 equip_pair_levels
    for (final t in titlesList) {
      final id = t['id']?.toString();
      if (id == null) continue;
      final cond = t['condition'];
      if (cond is! Map<String, dynamic>) continue;
      final kind = cond['kind']?.toString();
      if (kind != 'equip_level_reach' && kind != 'equip_pair_levels') continue;

      // 若已領取則跳過
      final persisted = titlesState?.states[id];
      if (persisted == 'claimed') continue;

      bool met = false;
      if (kind == 'equip_level_reach') {
        final equipId = cond['equip_id'] as String?;
        final level = (cond['level'] as num?)?.toInt() ?? 0;
        met =
            equipId != null &&
            _isEquipmentLevelReached(equipments, equipId, level);
      } else if (kind == 'equip_pair_levels') {
        final pairs = cond['pairs'] as List?;
        if (pairs != null) {
          met = pairs.every((pair) {
            final equipId = pair is Map ? pair['equip_id'] as String? : null;
            final level = pair is Map
                ? (pair['level'] as num?)?.toInt() ?? 0
                : 0;
            return equipId != null &&
                _isEquipmentLevelReached(equipments, equipId, level);
          });
        }
      }

      if (met) {
        if (persisted != 'claimed') {
          newStates[id] = 'claimable';
          hasNewClaimable = true;
        }
      }
    }

    // 若沒有改變就直接回傳
    final changed =
        hasNewClaimable != (titlesState?.hasClaimable ?? false) ||
        !_mapEquals(newStates, titlesState?.states ?? const {});
    if (!changed) return state;

    final newTitles = (titlesState ?? const TitlesState()).copyWith(
      states: newStates,
      hasClaimable: hasNewClaimable,
    );
    return state.copyWith(titles: newTitles);
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

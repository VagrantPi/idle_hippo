import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tutorial_state.dart';
import 'gacha_service.dart';
import '../models/game_state.dart';

/// Step 25-2: 寵物系統引導（4 步），具備持久化與獎勵發放（10 張寵物抽獎券）。
class PetTutorialService extends ChangeNotifier {
  static final PetTutorialService _instance = PetTutorialService._internal();
  factory PetTutorialService() => _instance;
  PetTutorialService._internal();

  // Storage keys (SharedPreferences)
  static const String _keyStep = 'tutorial_pet.step';
  static const String _keyCompleted = 'tutorial_pet.completed';
  static const String _keyRewardGiven = 'tutorial_pet.rewardGiven';

  // Steps definition (1..4) following spec
  // focusTargetId is a logical id used by UI to highlight
  static final List<TutorialStepDef> _steps = [
    // index 0 unused to keep 1-based step index
    const TutorialStepDef(
      focusTargetId: 'UNUSED',
      instructionKey: 'UNUSED',
      action: 'none',
    ),
    // 1. 寵物頁面：Focus nav 寵物按鈕，等待 1 秒後顯示「下一步」
    const TutorialStepDef(
      focusTargetId: 'nav_pets',
      instructionKey: 'tutorial.pet_intro',
      action: 'wait_then_next',
      pageKey: 'home',
    ),
    // 2. 返回首頁：Focus nav 首頁按鈕，點擊後前進
    const TutorialStepDef(
      focusTargetId: 'nav_home',
      instructionKey: 'tutorial.back_home',
      action: 'tap',
      pageKey: 'pets',
    ),
    // 3. 首頁顯示抽獎券：等待 1 秒後顯示「下一步」
    const TutorialStepDef(
      focusTargetId: 'home_pet_ticket',
      instructionKey: 'tutorial.pet_ticket_info',
      action: 'wait_then_next',
      pageKey: 'home',
    ),
    // 4. 結束引導：點擊「下一步」後結束並發放獎勵
    const TutorialStepDef(
      focusTargetId: 'btn_next',
      instructionKey: 'tutorial.pet_ticket_reward',
      action: 'complete',
    ),
  ];

  // Internal persisted state
  final ValueNotifier<PetTutorialState> state = ValueNotifier(
    const PetTutorialState(),
  );
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final step = prefs.getInt(_keyStep) ?? 0;
      final completed = prefs.getBool(_keyCompleted) ?? false;
      final rewardGiven = prefs.getBool(_keyRewardGiven) ?? false;
      state.value = PetTutorialState(
        step: step,
        completed: completed,
        rewardGiven: rewardGiven,
      );
    } catch (_) {
      state.value = const PetTutorialState();
    }
    _initialized = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyStep, state.value.step);
      await prefs.setBool(_keyCompleted, state.value.completed);
      await prefs.setBool(_keyRewardGiven, state.value.rewardGiven);
    } catch (_) {}
  }

  // External info for UI
  TutorialStepDef? get currentStepDef {
    final s = state.value.step;
    if (s <= 0 || s >= _steps.length) return null;
    return _steps[s];
  }

  String? get currentInstructionKey => currentStepDef?.instructionKey;
  String? get currentFocusTargetId => currentStepDef?.focusTargetId;
  String? get currentTargetPageKey => currentStepDef?.pageKey;
  bool get isCompleted => state.value.completed;
  bool get rewardGiven => state.value.rewardGiven;

  Future<void> reset() async {
    state.value = const PetTutorialState();
    await _persist();
    notifyListeners();
  }

  Future<void> setStep(int step) async {
    final clamped = step.clamp(0, 4);
    state.value = state.value.copyWith(step: clamped);
    await _persist();
    notifyListeners();
  }

  /// 自動觸發條件：完成主線第三章（解鎖 system.pet）
  Future<bool> maybeStartFromGameState(GameState gs) async {
    if (state.value.completed || state.value.step > 0) return false;
    final unlocked = gs.mainQuest?.unlockedRewards ?? const <String>[];
    if (unlocked.contains('system.pet')) {
      state.value = state.value.copyWith(step: 1);
      await _persist();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 是否允許在當前步驟點擊某個目標
  bool isAllowedTarget(String targetId) {
    if (state.value.completed) return true;
    final def = currentStepDef;
    if (def == null) return false;
    switch (def.action) {
      case 'wait_then_next':
      case 'complete':
        return targetId == 'btn_next';
      case 'tap':
        return def.focusTargetId == targetId;
      default:
        return false;
    }
  }

  /// 記錄行為並推進進度；返回是否接受且有進展
  Future<bool> recordAction(String targetId) async {
    if (!isAllowedTarget(targetId)) return false;
    final s = state.value;
    if (s.completed) return false;

    final def = currentStepDef;
    if (def == null) return false;

    // Step logic
    if (def.action == 'tap') {
      // 前進到下一步
      final next = (s.step + 1).clamp(0, 4);
      state.value = s.copyWith(step: next);
      await _persist();
      notifyListeners();
      return true;
    }
    if (def.action == 'wait_then_next' && targetId == 'btn_next') {
      final next = (s.step + 1).clamp(0, 4);
      state.value = s.copyWith(step: next);
      await _persist();
      notifyListeners();
      return true;
    }
    if (def.action == 'complete' && targetId == 'btn_next') {
      // 完成並發放獎勵（若尚未發放）
      await _giveRewardIfNeeded();
      state.value = s.copyWith(completed: true);
      await _persist();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> _giveRewardIfNeeded() async {
    if (state.value.rewardGiven) return;
    final gacha = GachaService();
    if (!gacha.isInitialized) {
      await gacha.initialize();
    }
    await gacha.addPetTickets(10);
    state.value = state.value.copyWith(rewardGiven: true);
  }
}

/// Internal state for Pet Tutorial
class PetTutorialState {
  final int step; // 0: 未開始, 1..4
  final bool completed;
  final bool rewardGiven;

  const PetTutorialState({
    this.step = 0,
    this.completed = false,
    this.rewardGiven = false,
  });

  PetTutorialState copyWith({int? step, bool? completed, bool? rewardGiven}) {
    return PetTutorialState(
      step: step ?? this.step,
      completed: completed ?? this.completed,
      rewardGiven: rewardGiven ?? this.rewardGiven,
    );
  }
}

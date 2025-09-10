import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tutorial_state.dart';

/// Step 25: New user tutorial (14 steps) with persistence.
class TutorialService extends ChangeNotifier {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  // Storage keys
  static const String _keyStep = 'tutorial.step';
  static const String _keyCompleted = 'tutorial.completed';
  static const String _keyMangaPage = 'tutorial.manga_page';

  final ValueNotifier<TutorialState> state = ValueNotifier(
    const TutorialState(),
  );
  bool _initialized = false;

  // Steps mapping per spec (1..14)
  // focusTargetId is an agreed logical id in UI layers
  static final List<TutorialStepDef> _steps = [
    // index placeholder to align 1-based steps; index 0 unused
    const TutorialStepDef(
      focusTargetId: 'UNUSED',
      instructionKey: 'UNUSED',
      action: 'none',
    ),
    // 1. manga cinematic pages 1..4 (tap to next page)
    const TutorialStepDef(
      focusTargetId: 'manga',
      instructionKey: 'tutorial.manga',
      action: 'tap_screen',
    ),
    // 2. tap hippo
    const TutorialStepDef(
      focusTargetId: 'hippo',
      instructionKey: 'tutorial.tap_hippo',
      action: 'tap',
    ),
    // 3. open mainline
    const TutorialStepDef(
      focusTargetId: 'btn_mainline',
      instructionKey: 'tutorial.open_mainline',
      action: 'tap',
    ),
    // 4. mainline story title focus
    const TutorialStepDef(
      focusTargetId: 'mainline_title',
      instructionKey: 'tutorial.mainline_story',
      action: 'wait_then_next',
      pageKey: 'quest',
    ),
    // 5. claim first mainline
    const TutorialStepDef(
      focusTargetId: 'btn_mainline_claim',
      instructionKey: 'tutorial.claim_first_mainline',
      action: 'tap',
      pageKey: 'quest',
    ),
    // 6. auto navigate equipment -> upgrade youtube
    const TutorialStepDef(
      focusTargetId: 'btn_upgrade_youtube',
      instructionKey: 'tutorial.upgrade_youtube',
      action: 'tap',
      pageKey: 'equipment',
    ),
    // 7. back home
    const TutorialStepDef(
      focusTargetId: 'nav_home',
      instructionKey: 'tutorial.back_home',
      action: 'tap',
    ),
    // 8. explain idle vs tap（等待 1 秒顯示下一步）
    const TutorialStepDef(
      focusTargetId: 'panel_meme_points',
      instructionKey: 'tutorial.explain_idle_vs_tap',
      action: 'wait_then_next',
      pageKey: 'home',
    ),
    // 9. daily quests entry（等待 1 秒顯示下一步）
    const TutorialStepDef(
      focusTargetId: 'btn_daily_quests',
      instructionKey: 'tutorial.daily_quests',
      action: 'wait_then_next',
      pageKey: 'home',
    ),
    // 10. settings -> daily check-in entry (需等使用者點擊設定鍵；重啟停留在主畫面)
    const TutorialStepDef(
      focusTargetId: 'btn_settings',
      instructionKey: 'tutorial.daily_checkin_entry',
      action: 'tap',
      pageKey: 'home',
    ),
    // 11. daily check-in detail focus（等待 1 秒顯示下一步）
    const TutorialStepDef(
      focusTargetId: 'item_daily_checkin',
      instructionKey: 'tutorial.daily_checkin_detail',
      action: 'wait_then_next',
      pageKey: 'settings',
    ),
    // 12. back home
    const TutorialStepDef(
      focusTargetId: 'nav_home',
      instructionKey: 'tutorial.back_home_again',
      action: 'tap',
    ),
    // 13. epilogue full-screen（點擊下一步即結束教學）
    const TutorialStepDef(
      focusTargetId: 'epilogue',
      instructionKey: 'tutorial.epilogue',
      action: 'wait_then_next',
    ),
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final step = prefs.getInt(_keyStep) ?? 0;
      final completed = prefs.getBool(_keyCompleted) ?? false;
      final manga = prefs.getInt(_keyMangaPage) ?? 0;
      state.value = TutorialState(
        step: step,
        completed: completed,
        mangaPage: manga,
      );
    } catch (_) {
      state.value = const TutorialState();
    }
    _initialized = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyStep, state.value.step);
      await prefs.setBool(_keyCompleted, state.value.completed);
      await prefs.setInt(_keyMangaPage, state.value.mangaPage);
    } catch (_) {}
  }

  TutorialStepDef? get currentStepDef {
    final s = state.value.step;
    if (s <= 0 || s >= _steps.length) return null;
    return _steps[s];
  }

  String? get currentInstructionKey => currentStepDef?.instructionKey;
  String? get currentFocusTargetId => currentStepDef?.focusTargetId;
  String? get currentTargetPageKey => currentStepDef?.pageKey;

  bool get isCompleted => state.value.completed;

  Future<void> reset() async {
    state.value = const TutorialState();
    await _persist();
    notifyListeners();
  }

  Future<void> setStep(int step) async {
    final clamped = step.clamp(0, 14);
    state.value = state.value.copyWith(step: clamped);
    await _persist();
    notifyListeners();
  }

  Future<void> complete() async {
    // 結束教學：標記 completed=true，保留當前步驟（常見於 step=13）
    state.value = state.value.copyWith(completed: true, mangaPage: 4);
    await _persist();
    notifyListeners();
  }

  // Step 1: Manga page advance; returns true if advanced a page/step
  Future<bool> advanceManga() async {
    final s = state.value;
    if (s.completed) return false;
    if (s.step == 0) {
      // start tutorial
      state.value = s.copyWith(step: 1, mangaPage: 1);
      await _persist();
      notifyListeners();
      return true;
    }
    if (s.step != 1) return false;
    final nextPage = (s.mangaPage <= 0 ? 1 : s.mangaPage + 1);
    if (nextPage <= 4) {
      state.value = s.copyWith(mangaPage: nextPage);
      await _persist();
      notifyListeners();
      if (nextPage == 4) {
        // Next tap should move to step 2
      }
      return true;
    }
    return false;
  }

  // When manga finished and user taps again, move to step 2
  Future<bool> finishMangaIfReady() async {
    final s = state.value;
    if (s.step == 1 && s.mangaPage >= 4) {
      state.value = s.copyWith(step: 2, mangaPage: 4);
      await _persist();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Returns whether the given logical id is allowed to be interacted at current step
  bool isAllowedTarget(String targetId) {
    if (state.value.completed) return true;
    final def = currentStepDef;
    if (def == null) return false;
    // Steps that require waiting then pressing a Next button
    if (def.action == 'wait_then_next') {
      return targetId == 'btn_next';
    }
    return def.focusTargetId == targetId;
  }

  // Record an action performed on a target; returns true if accepted and progressed
  Future<bool> recordAction(String targetId) async {
    if (!isAllowedTarget(targetId)) return false;
    final s = state.value;
    if (s.completed) return false;

    // Progress logic
    if (s.step == 1) {
      // Manga handled separately
      return false;
    }
    // Step 2: 需要達到 10 迷因點數才可前進，由 checkMemePoints 觸發
    if (s.step == 2 && targetId == 'hippo') {
      return true; // 接受點擊，但不前進
    }
    if (s.step < 13) {
      state.value = s.copyWith(step: s.step + 1);
      await _persist();
      notifyListeners();
      return true;
    }
    if (s.step == 13 && targetId == 'btn_next') {
      await complete();
      return true;
    }
    return false;
  }

  // 教學條件判斷：迷因點數達成
  Future<void> checkMemePoints(num memePoints) async {
    final s = state.value;
    if (s.completed) return;
    if (s.step == 2 && memePoints >= 10) {
      state.value = s.copyWith(step: 3);
      await _persist();
      notifyListeners();
    }
  }
}

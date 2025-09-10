class TutorialState {
  final int step; // 0 = not started, 1..14 per spec
  final bool completed;
  final int mangaPage; // 0 when not in manga, 1..4 during step 1

  const TutorialState({
    this.step = 0,
    this.completed = false,
    this.mangaPage = 0,
  });

  TutorialState copyWith({int? step, bool? completed, int? mangaPage}) {
    return TutorialState(
      step: step ?? this.step,
      completed: completed ?? this.completed,
      mangaPage: mangaPage ?? this.mangaPage,
    );
  }

  Map<String, dynamic> toMap() => {
    'step': step,
    'completed': completed,
    'mangaPage': mangaPage,
  };

  factory TutorialState.fromMap(Map<String, dynamic> map) => TutorialState(
    step: (map['step'] ?? 0) as int,
    completed: (map['completed'] ?? false) as bool,
    mangaPage: (map['mangaPage'] ?? 0) as int,
  );
}

class TutorialStepDef {
  final String focusTargetId; // logical target id in UI
  final String instructionKey; // localization key
  final String action; // tap/click/auto
  final String?
  pageKey; // optional page key (home, quest, equipment, settings, pets, ...)
  const TutorialStepDef({
    required this.focusTargetId,
    required this.instructionKey,
    required this.action,
    this.pageKey,
  });
}

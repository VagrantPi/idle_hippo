import 'dart:convert';
import 'pet.dart';
import 'package:idle_hippo/services/config_service.dart';

/// 待提交的抽卡批次（兩階段提交用）
class PendingGachaBatchItem {
  final String petKey;
  final String name;
  final String rarity; // 存字串以降低相依
  final String imagePath;
  final int timestamp;

  const PendingGachaBatchItem({
    required this.petKey,
    required this.name,
    required this.rarity,
    required this.imagePath,
    required this.timestamp,
  });

  factory PendingGachaBatchItem.fromMap(Map<String, dynamic> map) {
    return PendingGachaBatchItem(
      petKey: map['petKey'] as String,
      name: map['name'] as String,
      rarity: map['rarity'] as String,
      imagePath: map['imagePath'] as String,
      timestamp: (map['timestamp'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'petKey': petKey,
    'name': name,
    'rarity': rarity,
    'imagePath': imagePath,
    'timestamp': timestamp,
  };
}

class PendingGachaBatch {
  final String batchId;
  final int createdAt; // epoch ms
  final List<PendingGachaBatchItem> results;

  const PendingGachaBatch({
    required this.batchId,
    required this.createdAt,
    required this.results,
  });

  factory PendingGachaBatch.fromMap(Map<String, dynamic> map) {
    return PendingGachaBatch(
      batchId: map['batchId'] as String,
      createdAt: (map['createdAt'] as num).toInt(),
      results: (map['results'] is List)
          ? List<Map<String, dynamic>>.from(
              map['results'] as List,
            ).map(PendingGachaBatchItem.fromMap).toList()
          : const <PendingGachaBatchItem>[],
    );
  }

  Map<String, dynamic> toMap() => {
    'batchId': batchId,
    'createdAt': createdAt,
    'results': results.map((e) => e.toMap()).toList(),
  };
}

/// 抽卡歷史記錄
class GachaHistoryRecord {
  final String rarity;
  final String name;
  final int timestamp;
  final String? petKey; // 2025-08: optional, for i18n lookup

  const GachaHistoryRecord({
    required this.rarity,
    required this.name,
    required this.timestamp,
    this.petKey,
  });

  factory GachaHistoryRecord.fromMap(Map<String, dynamic> map) {
    return GachaHistoryRecord(
      rarity: map['rarity'] as String,
      name: map['name'] as String,
      timestamp: map['timestamp'] as int,
      petKey: map.containsKey('petKey') ? map['petKey'] as String? : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rarity': rarity,
      'name': name,
      'timestamp': timestamp,
      if (petKey != null) 'petKey': petKey,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GachaHistoryRecord &&
        other.rarity == rarity &&
        other.name == name &&
        other.timestamp == timestamp &&
        other.petKey == petKey;
  }

  @override
  int get hashCode =>
      rarity.hashCode ^
      name.hashCode ^
      timestamp.hashCode ^
      (petKey?.hashCode ?? 0);
}

class GachaState {
  final String lastDate; // YYYY-MM-DD in Asia/Taipei
  final int tenPackAdRemaining;

  const GachaState({required this.lastDate, this.tenPackAdRemaining = 1});

  factory GachaState.initial() {
    // 從設定檔讀取每日上限，未載入時回退為 1
    final limit =
        (ConfigService().getValue(
              'game.gacha.daily_ad_draw_limit',
              defaultValue: 1,
            )
            as int);
    return GachaState(lastDate: '', tenPackAdRemaining: limit);
  }

  factory GachaState.fromMap(Map<String, dynamic> map) {
    return GachaState(
      lastDate: (map['lastDate'] ?? '') as String,
      tenPackAdRemaining: (map['tenPackAdRemaining'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'lastDate': lastDate,
    'tenPackAdRemaining': tenPackAdRemaining,
  };

  GachaState copyWith({String? lastDate, int? tenPackAdRemaining}) {
    return GachaState(
      lastDate: lastDate ?? this.lastDate,
      tenPackAdRemaining: tenPackAdRemaining ?? this.tenPackAdRemaining,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GachaState &&
        other.lastDate == lastDate &&
        other.tenPackAdRemaining == tenPackAdRemaining;
  }

  @override
  int get hashCode => lastDate.hashCode ^ tenPackAdRemaining.hashCode;
}

/// Step 23: 卡拉 OK 每日限制狀態
class KaraokeState {
  final String lastPlayDate; // YYYY-MM-DD in Asia/Taipei
  final bool playedToday; // 是否已於當日完成並結算過

  const KaraokeState({
    required this.lastPlayDate,
    required this.playedToday,
  });

  factory KaraokeState.initial() => const KaraokeState(
        lastPlayDate: '',
        playedToday: false,
      );

  factory KaraokeState.fromMap(Map<String, dynamic> map) {
    return KaraokeState(
      lastPlayDate: (map['lastPlayDate'] ?? '') as String,
      playedToday: (map['playedToday'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'lastPlayDate': lastPlayDate,
        'playedToday': playedToday,
      };

  KaraokeState copyWith({String? lastPlayDate, bool? playedToday}) {
    return KaraokeState(
      lastPlayDate: lastPlayDate ?? this.lastPlayDate,
      playedToday: playedToday ?? this.playedToday,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KaraokeState &&
        other.lastPlayDate == lastPlayDate &&
        other.playedToday == playedToday;
  }

  @override
  int get hashCode => lastPlayDate.hashCode ^ playedToday.hashCode;
}

class PetTicketQuest {
  final double k;
  final double target;
  final double progress;
  final double idleSnapshot;
  final bool available;

  const PetTicketQuest({
    this.k = 0.0,
    this.target = 0.0,
    this.progress = 0.0,
    this.idleSnapshot = 0.0,
    this.available = false,
  });

  factory PetTicketQuest.fromMap(Map<String, dynamic> map) {
    return PetTicketQuest(
      k: (map['k'] ?? 0.0).toDouble(),
      target: (map['target'] ?? 0.0).toDouble(),
      progress: (map['progress'] ?? 0.0).toDouble(),
      idleSnapshot: (map['idleSnapshot'] ?? 0.0).toDouble(),
      available: (map['available'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
    'k': k,
    'target': target,
    'progress': progress,
    'idleSnapshot': idleSnapshot,
    'available': available,
  };

  PetTicketQuest copyWith({
    double? k,
    double? target,
    double? progress,
    double? idleSnapshot,
    bool? available,
  }) {
    return PetTicketQuest(
      k: k ?? this.k,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      idleSnapshot: idleSnapshot ?? this.idleSnapshot,
      available: available ?? this.available,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PetTicketQuest &&
        other.k == k &&
        other.target == target &&
        other.progress == progress &&
        other.idleSnapshot == idleSnapshot &&
        other.available == available;
  }

  @override
  int get hashCode =>
      k.hashCode ^
      target.hashCode ^
      progress.hashCode ^
      idleSnapshot.hashCode ^
      available.hashCode;
}

class CompletedMissionRecord {
  final int index;
  final String type;
  final double progress;
  final double target;

  const CompletedMissionRecord({
    required this.index,
    required this.type,
    required this.progress,
    required this.target,
  });

  factory CompletedMissionRecord.fromMap(Map<String, dynamic> map) {
    return CompletedMissionRecord(
      index: (map['index'] ?? 1) as int,
      type: (map['type'] ?? 'tapX') as String,
      progress: (map['progress'] ?? 0.0).toDouble(),
      target: (map['target'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'index': index,
    'type': type,
    'progress': progress,
    'target': target,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompletedMissionRecord &&
        other.index == index &&
        other.type == type &&
        other.progress == progress &&
        other.target == target;
  }

  @override
  int get hashCode =>
      index.hashCode ^ type.hashCode ^ progress.hashCode ^ target.hashCode;
}

class DailyMissionState {
  final String date; // YYYY-MM-DD in Asia/Taipei
  final int index; // 今日第幾個任務(1~10)
  final String type; // "tapX" | "accumulateX"
  final double progress; // 目前進度（A: 次數, B: 點數）
  final double target; // 目標（A: 50, B: X）
  final double idlePerSecSnapshot; // 僅 B 類使用
  final int todayCompleted; // 今日已完成任務數(0~10)
  final List<CompletedMissionRecord> completed; // 今日已完成任務的快照（跨日清空）

  const DailyMissionState({
    required this.date,
    required this.index,
    required this.type,
    required this.progress,
    required this.target,
    required this.idlePerSecSnapshot,
    required this.todayCompleted,
    this.completed = const [],
  });

  factory DailyMissionState.fromMap(Map<String, dynamic> map) {
    return DailyMissionState(
      date: (map['date'] ?? '') as String,
      index: (map['index'] ?? 1) as int,
      type: (map['type'] ?? 'tapX') as String,
      progress: (map['progress'] ?? 0.0).toDouble(),
      target: (map['target'] ?? 50.0).toDouble(),
      idlePerSecSnapshot: (map['idlePerSecSnapshot'] ?? 0.0).toDouble(),
      todayCompleted: (map['todayCompleted'] ?? 0) as int,
      completed: map.containsKey('completed') && map['completed'] is List
          ? List<Map<String, dynamic>>.from(
              map['completed'] as List,
            ).map(CompletedMissionRecord.fromMap).toList()
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date,
    'index': index,
    'type': type,
    'progress': progress,
    'target': target,
    'idlePerSecSnapshot': idlePerSecSnapshot,
    'todayCompleted': todayCompleted,
    'completed': completed.map((e) => e.toMap()).toList(),
  };

  DailyMissionState copyWith({
    String? date,
    int? index,
    String? type,
    double? progress,
    double? target,
    double? idlePerSecSnapshot,
    int? todayCompleted,
    List<CompletedMissionRecord>? completed,
  }) {
    return DailyMissionState(
      date: date ?? this.date,
      index: index ?? this.index,
      type: type ?? this.type,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      idlePerSecSnapshot: idlePerSecSnapshot ?? this.idlePerSecSnapshot,
      todayCompleted: todayCompleted ?? this.todayCompleted,
      completed: completed ?? List<CompletedMissionRecord>.from(this.completed),
    );
  }

  @override
  String toString() {
    return 'DailyMissionState(date: $date, index: $index, type: $type, '
        'progress: $progress, target: $target, todayCompleted: $todayCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyMissionState &&
        other.date == date &&
        other.index == index &&
        other.type == type &&
        other.progress == progress &&
        other.target == target &&
        other.idlePerSecSnapshot == idlePerSecSnapshot &&
        other.todayCompleted == todayCompleted &&
        _listCompletedEquals(other.completed, completed);
  }

  @override
  int get hashCode {
    return date.hashCode ^
        index.hashCode ^
        type.hashCode ^
        progress.hashCode ^
        target.hashCode ^
        idlePerSecSnapshot.hashCode ^
        todayCompleted.hashCode ^
        completed.hashCode;
  }

  static bool _listCompletedEquals(
    List<CompletedMissionRecord> a,
    List<CompletedMissionRecord> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class DailyTapState {
  final String date; // YYYY-MM-DD in Asia/Taipei
  final int todayGained;
  final bool adDoubledToday;

  const DailyTapState({
    required this.date,
    required this.todayGained,
    required this.adDoubledToday,
  });

  factory DailyTapState.fromMap(Map<String, dynamic> map) {
    return DailyTapState(
      date: (map['date'] ?? '') as String,
      todayGained: (map['todayGained'] ?? 0) as int,
      adDoubledToday: (map['adDoubledToday'] ?? false) as bool,
    );
  }
  Map<String, dynamic> toMap() => {
    'date': date,
    'todayGained': todayGained,
    'adDoubledToday': adDoubledToday,
  };

  DailyTapState copyWith({
    String? date,
    int? todayGained,
    bool? adDoubledToday,
  }) {
    return DailyTapState(
      date: date ?? this.date,
      todayGained: todayGained ?? this.todayGained,
      adDoubledToday: adDoubledToday ?? this.adDoubledToday,
    );
  }
}

class OfflineState {
  final int lastExitUtcMs; // UTC milliseconds
  final double idleRateSnapshot; // per second
  final double pendingReward; // not yet claimed
  final int capHours; // cap in hours, default 6

  // Step 11: Fields for reward doubling
  final double lastReward;
  final double lastRewardSec;
  final int lastRewardAtMs;
  final bool lastRewardDoubled;

  const OfflineState({
    this.lastExitUtcMs = 0,
    this.idleRateSnapshot = 0.0,
    this.pendingReward = 0.0,
    this.capHours = 6,
    this.lastReward = 0.0,
    this.lastRewardSec = 0.0,
    this.lastRewardAtMs = 0,
    this.lastRewardDoubled = false,
  });

  factory OfflineState.fromMap(Map<String, dynamic> map) {
    return OfflineState(
      lastExitUtcMs: (map['lastExitUtcMs'] ?? 0) as int,
      idleRateSnapshot: (map['idle_rate_snapshot'] ?? 0.0).toDouble(),
      pendingReward: (map['pendingReward'] ?? 0.0).toDouble(),
      capHours: (map['capHours'] ?? 6) as int,
      lastReward: (map['lastReward'] ?? 0.0).toDouble(),
      lastRewardSec: (map['lastRewardSec'] ?? 0.0).toDouble(),
      lastRewardAtMs: (map['lastRewardAtMs'] ?? 0) as int,
      lastRewardDoubled: (map['lastRewardDoubled'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
    'lastExitUtcMs': lastExitUtcMs,
    'idle_rate_snapshot': idleRateSnapshot,
    'pendingReward': pendingReward,
    'capHours': capHours,
    'lastReward': lastReward,
    'lastRewardSec': lastRewardSec,
    'lastRewardAtMs': lastRewardAtMs,
    'lastRewardDoubled': lastRewardDoubled,
  };

  bool validate() {
    if (lastExitUtcMs < 0) return false;
    if (idleRateSnapshot < 0) return false;
    if (pendingReward < 0) return false;
    if (capHours <= 0) return false;
    if (lastReward < 0) return false;
    if (lastRewardSec < 0) return false;
    if (lastRewardAtMs < 0) return false;
    return true;
  }

  OfflineState copyWith({
    int? lastExitUtcMs,
    double? idleRateSnapshot,
    double? pendingReward,
    int? capHours,
    double? lastReward,
    double? lastRewardSec,
    int? lastRewardAtMs,
    bool? lastRewardDoubled,
  }) {
    return OfflineState(
      lastExitUtcMs: lastExitUtcMs ?? this.lastExitUtcMs,
      idleRateSnapshot: idleRateSnapshot ?? this.idleRateSnapshot,
      pendingReward: pendingReward ?? this.pendingReward,
      capHours: capHours ?? this.capHours,
      lastReward: lastReward ?? this.lastReward,
      lastRewardSec: lastRewardSec ?? this.lastRewardSec,
      lastRewardAtMs: lastRewardAtMs ?? this.lastRewardAtMs,
      lastRewardDoubled: lastRewardDoubled ?? this.lastRewardDoubled,
    );
  }

  @override
  String toString() {
    return 'Offline(lastExitUtcMs: $lastExitUtcMs, snapshot: $idleRateSnapshot, '
        'pending: $pendingReward, capHours: $capHours, lastReward: $lastReward, '
        'lastRewardDoubled: $lastRewardDoubled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineState &&
        other.lastExitUtcMs == lastExitUtcMs &&
        other.idleRateSnapshot == idleRateSnapshot &&
        other.pendingReward == pendingReward &&
        other.capHours == capHours &&
        other.lastReward == lastReward &&
        other.lastRewardSec == lastRewardSec &&
        other.lastRewardAtMs == lastRewardAtMs &&
        other.lastRewardDoubled == lastRewardDoubled;
  }

  @override
  int get hashCode =>
      lastExitUtcMs.hashCode ^
      idleRateSnapshot.hashCode ^
      pendingReward.hashCode ^
      capHours.hashCode ^
      lastReward.hashCode ^
      lastRewardSec.hashCode ^
      lastRewardAtMs.hashCode ^
      lastRewardDoubled.hashCode;
}

class MainQuestState {
  final int currentStage; // 當前階段 (1-6)
  final int tapCountProgress; // 累積點擊次數
  final double memePointsEarned; // 歷史累積獲得點數
  final List<String> unlockedRewards; // 已解鎖的獎勵列表
  final bool claimable; // 是否已達成、待確認領取

  const MainQuestState({
    this.currentStage = 1,
    this.tapCountProgress = 0,
    this.memePointsEarned = 0.0,
    this.unlockedRewards = const [],
    this.claimable = false,
  });

  factory MainQuestState.fromMap(Map<String, dynamic> map) {
    return MainQuestState(
      currentStage: (map['currentStage'] ?? 1) as int,
      tapCountProgress: (map['tapCountProgress'] ?? 0) as int,
      memePointsEarned: (map['memePointsEarned'] ?? 0.0).toDouble(),
      unlockedRewards:
          map.containsKey('unlockedRewards') && map['unlockedRewards'] is List
          ? List<String>.from(map['unlockedRewards'] as List)
          : const [],
      claimable: (map['claimable'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
    'currentStage': currentStage,
    'tapCountProgress': tapCountProgress,
    'memePointsEarned': memePointsEarned,
    'unlockedRewards': unlockedRewards,
    'claimable': claimable,
  };

  MainQuestState copyWith({
    int? currentStage,
    int? tapCountProgress,
    double? memePointsEarned,
    List<String>? unlockedRewards,
    bool? claimable,
  }) {
    return MainQuestState(
      currentStage: currentStage ?? this.currentStage,
      tapCountProgress: tapCountProgress ?? this.tapCountProgress,
      memePointsEarned: memePointsEarned ?? this.memePointsEarned,
      unlockedRewards:
          unlockedRewards ?? List<String>.from(this.unlockedRewards),
      claimable: claimable ?? this.claimable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MainQuestState &&
        other.currentStage == currentStage &&
        other.tapCountProgress == tapCountProgress &&
        other.memePointsEarned == memePointsEarned &&
        _listStringEquals(other.unlockedRewards, unlockedRewards) &&
        other.claimable == claimable;
  }

  @override
  int get hashCode =>
      currentStage.hashCode ^
      tapCountProgress.hashCode ^
      memePointsEarned.hashCode ^
      unlockedRewards.hashCode ^
      claimable.hashCode;

  static bool _listStringEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'MainQuestState(currentStage: $currentStage, tapCountProgress: $tapCountProgress, '
        'memePointsEarned: $memePointsEarned, unlockedRewards: $unlockedRewards, claimable: $claimable)';
  }
}

/// 稱號狀態（持久化）
/// 每日打卡任務
class CheckinTask {
  final String type; // "tap" | "collect"
  final int target; // tap: n次, collect: m點數
  final int progress; // 當前進度

  const CheckinTask({
    required this.type,
    required this.target,
    this.progress = 0,
  });

  factory CheckinTask.fromMap(Map<String, dynamic> map) {
    return CheckinTask(
      type: (map['type'] ?? 'tap') as String,
      target: (map['target'] ?? 0) as int,
      progress: (map['progress'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'target': target,
    'progress': progress,
  };

  CheckinTask copyWith({String? type, int? target, int? progress}) {
    return CheckinTask(
      type: type ?? this.type,
      target: target ?? this.target,
      progress: progress ?? this.progress,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckinTask &&
        other.type == type &&
        other.target == target &&
        other.progress == progress;
  }

  @override
  int get hashCode => type.hashCode ^ target.hashCode ^ progress.hashCode;
}

/// 打卡今日狀態
class CheckinToday {
  final String date; // YYYY-MM-DD in Asia/Taipei
  final CheckinTask task;
  final String status; // "pending" | "done" | "skipped"
  final bool skipViaAdUsed; // 今日是否已用廣告跳過
  final double idlePerSecSnapshot; // 生成今日任務時拍的 idlePerSec 快照

  const CheckinToday({
    required this.date,
    required this.task,
    this.status = 'pending',
    this.skipViaAdUsed = false,
    this.idlePerSecSnapshot = 0.0,
  });

  factory CheckinToday.fromMap(Map<String, dynamic> map) {
    return CheckinToday(
      date: (map['date'] ?? '') as String,
      task: CheckinTask.fromMap((map['task'] ?? {}) as Map<String, dynamic>),
      status: (map['status'] ?? 'pending') as String,
      skipViaAdUsed: (map['skipViaAdUsed'] ?? false) as bool,
      idlePerSecSnapshot: (map['idlePerSecSnapshot'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date,
    'task': task.toMap(),
    'status': status,
    'skipViaAdUsed': skipViaAdUsed,
    'idlePerSecSnapshot': idlePerSecSnapshot,
  };

  CheckinToday copyWith({
    String? date,
    CheckinTask? task,
    String? status,
    bool? skipViaAdUsed,
    double? idlePerSecSnapshot,
  }) {
    return CheckinToday(
      date: date ?? this.date,
      task: task ?? this.task,
      status: status ?? this.status,
      skipViaAdUsed: skipViaAdUsed ?? this.skipViaAdUsed,
      idlePerSecSnapshot: idlePerSecSnapshot ?? this.idlePerSecSnapshot,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckinToday &&
        other.date == date &&
        other.task == task &&
        other.status == status &&
        other.skipViaAdUsed == skipViaAdUsed &&
        other.idlePerSecSnapshot == idlePerSecSnapshot;
  }

  @override
  int get hashCode =>
      date.hashCode ^
      task.hashCode ^
      status.hashCode ^
      skipViaAdUsed.hashCode ^
      idlePerSecSnapshot.hashCode;
}

/// 打卡連續統計
class CheckinStreak {
  final int current; // 連續簽到天數
  final int best; // 歷史最長連續
  final int total; // 累計簽到天數
  final String lastDate; // 上次簽到日期（local, YYYY-MM-DD）

  const CheckinStreak({
    this.current = 0,
    this.best = 0,
    this.total = 0,
    this.lastDate = '',
  });

  factory CheckinStreak.fromMap(Map<String, dynamic> map) {
    return CheckinStreak(
      current: (map['current'] ?? 0) as int,
      best: (map['best'] ?? 0) as int,
      total: (map['total'] ?? 0) as int,
      lastDate: (map['lastDate'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'current': current,
    'best': best,
    'total': total,
    'lastDate': lastDate,
  };

  CheckinStreak copyWith({
    int? current,
    int? best,
    int? total,
    String? lastDate,
  }) {
    return CheckinStreak(
      current: current ?? this.current,
      best: best ?? this.best,
      total: total ?? this.total,
      lastDate: lastDate ?? this.lastDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckinStreak &&
        other.current == current &&
        other.best == best &&
        other.total == total &&
        other.lastDate == lastDate;
  }

  @override
  int get hashCode =>
      current.hashCode ^ best.hashCode ^ total.hashCode ^ lastDate.hashCode;

  // 向後相容：別名，對應舊測試使用的 longest
  int get longest => best;
}

/// 打卡週狀態
class CheckinWeek {
  final String weekStart; // 本週起始日（local, YYYY-MM-DD）
  final int mask; // 7-bit 完成遮罩
  final bool weeklyBonusClaimed; // 週獎勵是否已領取

  const CheckinWeek({
    this.weekStart = '',
    this.mask = 0,
    this.weeklyBonusClaimed = false,
  });

  factory CheckinWeek.fromMap(Map<String, dynamic> map) {
    return CheckinWeek(
      weekStart: (map['weekStart'] ?? '') as String,
      mask: (map['mask'] ?? 0) as int,
      weeklyBonusClaimed: (map['weeklyBonusClaimed'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
    'weekStart': weekStart,
    'mask': mask,
    'weeklyBonusClaimed': weeklyBonusClaimed,
  };

  CheckinWeek copyWith({
    String? weekStart,
    int? mask,
    bool? weeklyBonusClaimed,
  }) {
    return CheckinWeek(
      weekStart: weekStart ?? this.weekStart,
      mask: mask ?? this.mask,
      weeklyBonusClaimed: weeklyBonusClaimed ?? this.weeklyBonusClaimed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckinWeek &&
        other.weekStart == weekStart &&
        other.mask == mask &&
        other.weeklyBonusClaimed == weeklyBonusClaimed;
  }

  @override
  int get hashCode =>
      weekStart.hashCode ^ mask.hashCode ^ weeklyBonusClaimed.hashCode;

  // 向後相容：別名，對應舊測試使用的 completedMask
  int get completedMask => mask;
}

/// 打卡配置
class CheckinConfig {
  final int weekStartDow; // 週起始：1=周一
  final List<int> tapRange; // 點擊任務目標範圍 [min, max]

  const CheckinConfig({this.weekStartDow = 1, this.tapRange = const [20, 50]});

  factory CheckinConfig.fromMap(Map<String, dynamic> map) {
    return CheckinConfig(
      weekStartDow: (map['weekStartDow'] ?? 1) as int,
      tapRange: map.containsKey('tapRange') && map['tapRange'] is List
          ? List<int>.from(map['tapRange'] as List)
          : const [20, 50],
    );
  }

  Map<String, dynamic> toMap() => {
    'weekStartDow': weekStartDow,
    'tapRange': tapRange,
  };

  CheckinConfig copyWith({int? weekStartDow, List<int>? tapRange}) {
    return CheckinConfig(
      weekStartDow: weekStartDow ?? this.weekStartDow,
      tapRange: tapRange ?? List<int>.from(this.tapRange),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckinConfig &&
        other.weekStartDow == weekStartDow &&
        _listIntEquals(other.tapRange, tapRange);
  }

  @override
  int get hashCode => weekStartDow.hashCode ^ tapRange.hashCode;

  static bool _listIntEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 每日打卡系統狀態
class CheckinState {
  final String tz; // 時區，固定 "Asia/Taipei"
  final CheckinConfig config;
  final CheckinStreak streak;
  final CheckinWeek week;
  final CheckinToday today;

  const CheckinState({
    this.tz = 'Asia/Taipei',
    this.config = const CheckinConfig(),
    this.streak = const CheckinStreak(),
    this.week = const CheckinWeek(),
    required this.today,
  });

  factory CheckinState.fromMap(Map<String, dynamic> map) {
    return CheckinState(
      tz: (map['tz'] ?? 'Asia/Taipei') as String,
      config: CheckinConfig.fromMap(
        (map['config'] ?? {}) as Map<String, dynamic>,
      ),
      streak: CheckinStreak.fromMap(
        (map['streak'] ?? {}) as Map<String, dynamic>,
      ),
      week: CheckinWeek.fromMap((map['week'] ?? {}) as Map<String, dynamic>),
      today: CheckinToday.fromMap((map['today'] ?? {}) as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() => {
    'tz': tz,
    'config': config.toMap(),
    'streak': streak.toMap(),
    'week': week.toMap(),
    'today': today.toMap(),
  };

  CheckinState copyWith({
    String? tz,
    CheckinConfig? config,
    CheckinStreak? streak,
    CheckinWeek? week,
    CheckinToday? today,
  }) {
    return CheckinState(
      tz: tz ?? this.tz,
      config: config ?? this.config,
      streak: streak ?? this.streak,
      week: week ?? this.week,
      today: today ?? this.today,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckinState &&
        other.tz == tz &&
        other.config == config &&
        other.streak == streak &&
        other.week == week &&
        other.today == today;
  }

  @override
  int get hashCode =>
      tz.hashCode ^
      config.hashCode ^
      streak.hashCode ^
      week.hashCode ^
      today.hashCode;
}

class TitlesState {
  final Map<String, String>
  states; // titleId -> 'locked' | 'claimable' | 'claimed'
  final Map<String, int> claimedAt; // titleId -> epochMs
  final bool hasClaimable; // 供紅點顯示（Navbar/頁籤）

  const TitlesState({
    this.states = const {},
    this.claimedAt = const {},
    this.hasClaimable = false,
  });

  factory TitlesState.fromMap(Map<String, dynamic> map) {
    final rawStates = map['states'];
    final rawClaimedAt = map['claimedAt'];
    // states
    final Map<String, String> parsedStates = {};
    if (rawStates is Map) {
      rawStates.forEach((key, value) {
        parsedStates[key.toString()] = value.toString();
      });
    }
    // claimedAt
    final Map<String, int> parsedClaimedAt = {};
    if (rawClaimedAt is Map) {
      rawClaimedAt.forEach((key, value) {
        parsedClaimedAt[key.toString()] = (value as num).toInt();
      });
    }
    return TitlesState(
      states: parsedStates,
      claimedAt: parsedClaimedAt,
      hasClaimable:
          (map['redDot'] is Map && (map['redDot']['hasClaimable'] is bool))
          ? (map['redDot']['hasClaimable'] as bool)
          : false,
    );
  }

  Map<String, dynamic> toMap() => {
    'states': states,
    'claimedAt': claimedAt,
    'redDot': {'hasClaimable': hasClaimable},
  };

  TitlesState copyWith({
    Map<String, String>? states,
    Map<String, int>? claimedAt,
    bool? hasClaimable,
  }) {
    return TitlesState(
      states: states ?? Map<String, String>.from(this.states),
      claimedAt: claimedAt ?? Map<String, int>.from(this.claimedAt),
      hasClaimable: hasClaimable ?? this.hasClaimable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TitlesState &&
        _mapStringEquals(other.states, states) &&
        _mapIntEquals(other.claimedAt, claimedAt) &&
        other.hasClaimable == hasClaimable;
  }

  @override
  int get hashCode =>
      states.hashCode ^ claimedAt.hashCode ^ hasClaimable.hashCode;

  static bool _mapStringEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || a[k] != b[k]) return false;
    }
    return true;
  }

  static bool _mapIntEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || a[k] != b[k]) return false;
    }
    return true;
  }
}

class GameState {
  final int saveVersion;
  final double memePoints;
  final Map<String, int> equipments;
  final int lastTs;
  final DailyTapState? dailyTap;
  final OfflineState offline;
  final DailyMissionState? dailyMission;
  final MainQuestState? mainQuest;
  final PetState? petState;
  final PetTicketQuest? petTicketQuest;
  final int petTickets;
  final List<GachaHistoryRecord> gachaHistory;
  final GachaState? gacha;
  final TitlesState? titles;
  final PendingGachaBatch? pendingGachaBatch;
  final CheckinState? checkin;
  final KaraokeState? karaoke; // Step23: 每日卡拉OK次數限制

  const GameState({
    required this.saveVersion,
    required this.memePoints,
    required this.equipments,
    required this.lastTs,
    this.dailyTap,
    this.offline = const OfflineState(),
    this.dailyMission,
    this.mainQuest,
    this.petState,
    this.petTicketQuest,
    this.petTickets = 0,
    this.gachaHistory = const [],
    this.gacha,
    this.titles,
    this.pendingGachaBatch,
    this.checkin,
    this.karaoke,
  });

  /// 建立初始狀態
  factory GameState.initial(int currentVersion) {
    return GameState(
      saveVersion: currentVersion,
      memePoints: 0.0,
      equipments: {},
      lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
      dailyTap: null,
      offline: const OfflineState(),
      dailyMission: null,
      mainQuest: const MainQuestState(),
      petTicketQuest: null,
      petTickets: 0,
      gachaHistory: const [],
      gacha: null,
      titles: const TitlesState(),
      karaoke: null,
    );
  }

  /// 從 JSON 字串建立 GameState
  factory GameState.fromJson(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return GameState.fromMap(json);
    } catch (e) {
      throw FormatException('Invalid JSON format: $e');
    }
  }

  /// 從 Map 建立 GameState
  factory GameState.fromMap(Map<String, dynamic> map) {
    return GameState(
      saveVersion: map['save_version'] as int,
      memePoints: (map['memePoints'] as num).toDouble(),
      equipments: Map<String, int>.from(map['equipments'] as Map),
      lastTs: map['lastTs'] as int,
      dailyTap:
          map.containsKey('dailyTap') && map['dailyTap'] is Map<String, dynamic>
          ? DailyTapState.fromMap(map['dailyTap'] as Map<String, dynamic>)
          : null,
      offline:
          map.containsKey('offline') && map['offline'] is Map<String, dynamic>
          ? OfflineState.fromMap(map['offline'] as Map<String, dynamic>)
          : const OfflineState(),
      dailyMission:
          map.containsKey('dailyMission') &&
              map['dailyMission'] is Map<String, dynamic>
          ? DailyMissionState.fromMap(
              map['dailyMission'] as Map<String, dynamic>,
            )
          : null,
      // 保持與原始資料一致：若未提供 mainQuest，維持為 null
      mainQuest:
          map.containsKey('mainQuest') &&
              map['mainQuest'] is Map<String, dynamic>
          ? MainQuestState.fromMap(map['mainQuest'] as Map<String, dynamic>)
          : null,
      petState:
          map.containsKey('petState') && map['petState'] is Map<String, dynamic>
          ? PetState.fromMap(map['petState'] as Map<String, dynamic>)
          : null,
      petTicketQuest:
          map.containsKey('petTicketQuest') &&
              map['petTicketQuest'] is Map<String, dynamic>
          ? PetTicketQuest.fromMap(
              map['petTicketQuest'] as Map<String, dynamic>,
            )
          : null,
      petTickets: (map['petTickets'] ?? 0) as int,
      gachaHistory:
          map.containsKey('gachaHistory') && map['gachaHistory'] is List
          ? List<Map<String, dynamic>>.from(
              map['gachaHistory'] as List,
            ).map(GachaHistoryRecord.fromMap).toList()
          : const [],
      gacha: map.containsKey('gacha') && map['gacha'] is Map<String, dynamic>
          ? GachaState.fromMap(map['gacha'] as Map<String, dynamic>)
          : null,
      titles: map.containsKey('titles') && map['titles'] is Map<String, dynamic>
          ? TitlesState.fromMap(map['titles'] as Map<String, dynamic>)
          : null,
      pendingGachaBatch:
          map.containsKey('pendingGachaBatch') &&
              map['pendingGachaBatch'] is Map<String, dynamic>
          ? PendingGachaBatch.fromMap(
              map['pendingGachaBatch'] as Map<String, dynamic>,
            )
          : null,
      checkin:
          map.containsKey('checkin') && map['checkin'] is Map<String, dynamic>
          ? CheckinState.fromMap(map['checkin'] as Map<String, dynamic>)
          : null,
      karaoke: map.containsKey('karaoke') && map['karaoke'] is Map<String, dynamic>
          ? KaraokeState.fromMap(map['karaoke'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 轉換為 JSON 字串
  String toJson() {
    return jsonEncode(toMap());
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'save_version': saveVersion,
      'memePoints': memePoints,
      'equipments': equipments,
      'lastTs': lastTs,
      if (dailyTap != null) 'dailyTap': dailyTap!.toMap(),
      'offline': offline.toMap(),
      if (dailyMission != null) 'dailyMission': dailyMission!.toMap(),
      if (mainQuest != null) 'mainQuest': mainQuest!.toMap(),
      if (petState != null) 'petState': petState!.toMap(),
      if (petTicketQuest != null) 'petTicketQuest': petTicketQuest!.toMap(),
      'petTickets': petTickets,
      'gachaHistory': gachaHistory.map((record) => record.toMap()).toList(),
      if (gacha != null) 'gacha': gacha!.toMap(),
      if (titles != null) 'titles': titles!.toMap(),
      if (pendingGachaBatch != null)
        'pendingGachaBatch': pendingGachaBatch!.toMap(),
      if (checkin != null) 'checkin': checkin!.toMap(),
      if (karaoke != null) 'karaoke': karaoke!.toMap(),
    };
  }

  /// 驗證資料有效性
  bool validate() {
    try {
      // 檢查必要欄位存在且類型正確
      if (saveVersion < 0) return false;
      if (memePoints < 0.0) return false;
      if (lastTs <= 0) return false;

      // 檢查 equipments 中的值都是非負數
      for (final level in equipments.values) {
        if (level < 0) return false;
      }
      // dailyTap 若存在，檢查 todayGained 非負
      if (dailyTap != null && dailyTap!.todayGained < 0) return false;
      // 檢查 offline 區塊
      if (!offline.validate()) return false;
      // 檢查 titles 區塊（若存在）
      if (titles != null) {
        for (final s in titles!.states.values) {
          if (s != 'locked' && s != 'claimable' && s != 'claimed') return false;
        }
        for (final ts in titles!.claimedAt.values) {
          if (ts < 0) return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 複製並更新部分欄位
  GameState copyWith({
    int? saveVersion,
    double? memePoints,
    Map<String, int>? equipments,
    int? lastTs,
    DailyTapState? dailyTap,
    OfflineState? offline,
    DailyMissionState? dailyMission,
    MainQuestState? mainQuest,
    PetState? petState,
    PetTicketQuest? petTicketQuest,
    int? petTickets,
    List<GachaHistoryRecord>? gachaHistory,
    GachaState? gacha,
    TitlesState? titles,
    PendingGachaBatch? pendingGachaBatch,
    bool? clearPendingGachaBatch,
    CheckinState? checkin,
    KaraokeState? karaoke,
  }) {
    return GameState(
      saveVersion: saveVersion ?? this.saveVersion,
      memePoints: memePoints ?? this.memePoints,
      equipments: equipments ?? Map<String, int>.from(this.equipments),
      lastTs: lastTs ?? this.lastTs,
      dailyTap: dailyTap ?? this.dailyTap,
      offline: offline ?? this.offline,
      dailyMission: dailyMission ?? this.dailyMission,
      mainQuest: mainQuest ?? this.mainQuest,
      petState: petState ?? this.petState,
      petTicketQuest: petTicketQuest ?? this.petTicketQuest,
      petTickets: petTickets ?? this.petTickets,
      gachaHistory:
          gachaHistory ?? List<GachaHistoryRecord>.from(this.gachaHistory),
      gacha: gacha ?? this.gacha,
      titles: titles ?? this.titles,
      pendingGachaBatch: (clearPendingGachaBatch == true)
          ? null
          : (pendingGachaBatch ?? this.pendingGachaBatch),
      checkin: checkin ?? this.checkin,
      karaoke: karaoke ?? this.karaoke,
    );
  }

  /// 更新時間戳
  GameState updateTimestamp() {
    return copyWith(lastTs: DateTime.now().toUtc().millisecondsSinceEpoch);
  }

  @override
  String toString() {
    return 'GameState(saveVersion: $saveVersion, memePoints: $memePoints, '
        'equipments: $equipments, lastTs: $lastTs, offline: $offline, '
        'petTickets: $petTickets, pets: ${petState?.pets.length ?? 0}, '
        'equipped: ${petState?.equippedPetId}, gachaHistory: ${gachaHistory.length}, gacha: ${gacha != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameState &&
        other.saveVersion == saveVersion &&
        other.memePoints == memePoints &&
        _mapEquals(other.equipments, equipments) &&
        other.lastTs == lastTs &&
        _dailyTapEquals(other.dailyTap, dailyTap) &&
        other.offline == offline &&
        _dailyMissionEquals(other.dailyMission, dailyMission) &&
        _mainQuestEquals(other.mainQuest, mainQuest) &&
        other.petState == petState &&
        other.petTicketQuest == petTicketQuest &&
        other.petTickets == petTickets &&
        _listGachaHistoryEquals(other.gachaHistory, gachaHistory) &&
        other.gacha == gacha &&
        other.titles == titles &&
        _pendingBatchEquals(other.pendingGachaBatch, pendingGachaBatch) &&
        other.checkin == checkin &&
        other.karaoke == karaoke;
  }

  @override
  int get hashCode {
    return saveVersion.hashCode ^
        memePoints.hashCode ^
        equipments.hashCode ^
        lastTs.hashCode ^
        (dailyTap?.hashCode ?? 0) ^
        offline.hashCode ^
        (dailyMission?.hashCode ?? 0) ^
        (mainQuest?.hashCode ?? 0) ^
        (petState?.hashCode ?? 0) ^
        (petTicketQuest?.hashCode ?? 0) ^
        petTickets.hashCode ^
        gachaHistory.hashCode ^
        (gacha?.hashCode ?? 0) ^
        (titles?.hashCode ?? 0) ^
        (pendingGachaBatch?.hashCode ?? 0) ^
        (checkin?.hashCode ?? 0) ^
        (karaoke?.hashCode ?? 0);
  }

  bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  bool _dailyTapEquals(DailyTapState? a, DailyTapState? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.date == b.date &&
        a.todayGained == b.todayGained &&
        a.adDoubledToday == b.adDoubledToday;
  }

  bool _dailyMissionEquals(DailyMissionState? a, DailyMissionState? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a == b;
  }

  bool _mainQuestEquals(MainQuestState? a, MainQuestState? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a == b;
  }

  bool _listGachaHistoryEquals(
    List<GachaHistoryRecord> a,
    List<GachaHistoryRecord> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _pendingBatchEquals(PendingGachaBatch? a, PendingGachaBatch? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.batchId != b.batchId || a.createdAt != b.createdAt) return false;
    if (a.results.length != b.results.length) return false;
    for (int i = 0; i < a.results.length; i++) {
      final x = a.results[i];
      final y = b.results[i];
      if (x.petKey != y.petKey ||
          x.rarity != y.rarity ||
          x.timestamp != y.timestamp)
        return false;
    }
    return true;
  }
}

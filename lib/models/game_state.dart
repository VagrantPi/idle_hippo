import 'dart:convert';

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

  DailyTapState copyWith({String? date, int? todayGained, bool? adDoubledToday}) {
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

class GameState {
  final int saveVersion;
  final double memePoints;
  final Map<String, int> equipments;
  final int lastTs;
  final DailyTapState? dailyTap;
  final OfflineState offline;

  const GameState({
    required this.saveVersion,
    required this.memePoints,
    required this.equipments,
    required this.lastTs,
    this.dailyTap,
    this.offline = const OfflineState(),
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
      dailyTap: map.containsKey('dailyTap') && map['dailyTap'] is Map<String, dynamic>
          ? DailyTapState.fromMap(map['dailyTap'] as Map<String, dynamic>)
          : null,
      offline: map.containsKey('offline') && map['offline'] is Map<String, dynamic>
          ? OfflineState.fromMap(map['offline'] as Map<String, dynamic>)
          : const OfflineState(),
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
  }) {
    return GameState(
      saveVersion: saveVersion ?? this.saveVersion,
      memePoints: memePoints ?? this.memePoints,
      equipments: equipments ?? Map<String, int>.from(this.equipments),
      lastTs: lastTs ?? this.lastTs,
      dailyTap: dailyTap ?? this.dailyTap,
      offline: offline ?? this.offline,
    );
  }

  /// 更新時間戳
  GameState updateTimestamp() {
    return copyWith(
      lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() {
    return 'GameState(saveVersion: $saveVersion, memePoints: $memePoints, '
           'equipments: $equipments, lastTs: $lastTs, offline: $offline)';
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
        other.offline == offline;
  }

  @override
  int get hashCode {
    return saveVersion.hashCode ^
        memePoints.hashCode ^
        equipments.hashCode ^
        lastTs.hashCode ^
        (dailyTap?.hashCode ?? 0) ^
        offline.hashCode;
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
    return a.date == b.date && a.todayGained == b.todayGained && a.adDoubledToday == b.adDoubledToday;
  }
}

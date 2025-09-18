
/// 限時 buff 狀態
class TimedBuff {
  final String type; // 'click_2x', 'idle_2x', 'offline_6h'
  final double multiplier; // 倍數或加成值
  final int expiresAtMs; // UTC 毫秒時間戳

  const TimedBuff({
    required this.type,
    required this.multiplier,
    required this.expiresAtMs,
  });

  factory TimedBuff.fromMap(Map<String, dynamic> map) {
    return TimedBuff(
      type: map['type'] as String,
      multiplier: (map['multiplier'] as num).toDouble(),
      expiresAtMs: (map['expiresAtMs'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'multiplier': multiplier,
    'expiresAtMs': expiresAtMs,
  };

  /// 檢查 buff 是否已過期
  bool isExpired(int currentTimeMs) {
    return currentTimeMs >= expiresAtMs;
  }

  /// 獲取剩餘時間（毫秒）
  int getRemainingMs(int currentTimeMs) {
    final remaining = expiresAtMs - currentTimeMs;
    return remaining > 0 ? remaining : 0;
  }

  TimedBuff copyWith({
    String? type,
    double? multiplier,
    int? expiresAtMs,
  }) {
    return TimedBuff(
      type: type ?? this.type,
      multiplier: multiplier ?? this.multiplier,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimedBuff &&
        other.type == type &&
        other.multiplier == multiplier &&
        other.expiresAtMs == expiresAtMs;
  }

  @override
  int get hashCode {
    return type.hashCode ^ multiplier.hashCode ^ expiresAtMs.hashCode;
  }

  @override
  String toString() {
    return 'TimedBuff(type: $type, multiplier: $multiplier, expiresAtMs: $expiresAtMs)';
  }
}

/// 永久權益狀態
class PermanentEntitlements {
  final double clickBoost; // card_click_perm: 1.5 = +50%
  final double idleBoost; // card_idle_perm: 1.2 = +20%
  final bool offlineExtended; // card_offline_perm_6h: +6h
  final bool capIncreased; // card_cap_perm: +50%

  const PermanentEntitlements({
    this.clickBoost = 1.0,
    this.idleBoost = 1.0,
    this.offlineExtended = false,
    this.capIncreased = false,
  });

  factory PermanentEntitlements.fromMap(Map<String, dynamic> map) {
    return PermanentEntitlements(
      clickBoost: (map['clickBoost'] ?? 1.0) is num ? (map['clickBoost'] ?? 1.0).toDouble() : 1.0,
      idleBoost: (map['idleBoost'] ?? 1.0) is num ? (map['idleBoost'] ?? 1.0).toDouble() : 1.0,
      offlineExtended: (map['offlineExtended'] ?? false) as bool,
      capIncreased: (map['capIncreased'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
    'clickBoost': clickBoost,
    'idleBoost': idleBoost,
    'offlineExtended': offlineExtended,
    'capIncreased': capIncreased,
  };

  PermanentEntitlements copyWith({
    double? clickBoost,
    double? idleBoost,
    bool? offlineExtended,
    bool? capIncreased,
  }) {
    return PermanentEntitlements(
      clickBoost: clickBoost ?? this.clickBoost,
      idleBoost: idleBoost ?? this.idleBoost,
      offlineExtended: offlineExtended ?? this.offlineExtended,
      capIncreased: capIncreased ?? this.capIncreased,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermanentEntitlements &&
        other.clickBoost == clickBoost &&
        other.idleBoost == idleBoost &&
        other.offlineExtended == offlineExtended &&
        other.capIncreased == capIncreased;
  }

  @override
  int get hashCode {
    return clickBoost.hashCode ^
        idleBoost.hashCode ^
        offlineExtended.hashCode ^
        capIncreased.hashCode;
  }

  @override
  String toString() {
    return 'PermanentEntitlements(clickBoost: $clickBoost, idleBoost: $idleBoost, '
        'offlineExtended: $offlineExtended, capIncreased: $capIncreased)';
  }
}

/// Buff 系統狀態
class BuffState {
  final List<TimedBuff> activeBuffs;
  final PermanentEntitlements permanent;

  const BuffState({
    this.activeBuffs = const [],
    this.permanent = const PermanentEntitlements(),
  });

  factory BuffState.fromMap(Map<String, dynamic> map) {
    return BuffState(
      activeBuffs: map.containsKey('activeBuffs') && map['activeBuffs'] is List
          ? List<Map<String, dynamic>>.from(map['activeBuffs'] as List)
              .map(TimedBuff.fromMap)
              .toList()
          : const [],
      permanent: map.containsKey('permanent') && map['permanent'] is Map<String, dynamic>
          ? PermanentEntitlements.fromMap(map['permanent'] as Map<String, dynamic>)
          : const PermanentEntitlements(),
    );
  }

  Map<String, dynamic> toMap() => {
    'activeBuffs': activeBuffs.map((buff) => buff.toMap()).toList(),
    'permanent': permanent.toMap(),
  };

  /// 清理過期的 buff
  BuffState cleanExpiredBuffs(int currentTimeMs) {
    final validBuffs = activeBuffs
        .where((buff) => !buff.isExpired(currentTimeMs))
        .toList();
    
    return copyWith(activeBuffs: validBuffs);
  }

  /// 添加或延長限時 buff
  BuffState addOrExtendBuff({
    required String type,
    required double multiplier,
    required int durationMs,
    required int currentTimeMs,
  }) {
    final newBuffs = List<TimedBuff>.from(activeBuffs);
    
    // 查找相同類型的現有 buff
    final existingIndex = newBuffs.indexWhere((buff) => buff.type == type);
    
    if (existingIndex != -1) {
      // 延長現有 buff 的時間
      final existing = newBuffs[existingIndex];
      final newExpiresAt = existing.expiresAtMs + durationMs;
      newBuffs[existingIndex] = existing.copyWith(expiresAtMs: newExpiresAt);
    } else {
      // 添加新的 buff
      final newBuff = TimedBuff(
        type: type,
        multiplier: multiplier,
        expiresAtMs: currentTimeMs + durationMs,
      );
      newBuffs.add(newBuff);
    }
    
    return copyWith(activeBuffs: newBuffs);
  }

  /// 清理過期的 buff
  BuffState cleanupExpired(int currentTimeMs) {
    final validBuffs = activeBuffs.where((buff) => !buff.isExpired(currentTimeMs)).toList();
    
    if (validBuffs.length == activeBuffs.length) {
      return this; // 沒有過期的 buff，返回原狀態
    }
    
    return copyWith(activeBuffs: validBuffs);
  }

  /// 獲取點擊倍數
  double getClickMultiplier(int currentTimeMs) {
    double multiplier = 1.0;
    
    // 永久加成（使用配置的倍數）
    if (permanent.clickBoost > 1.0) {
      multiplier *= permanent.clickBoost;
    }
    
    // 限時加成
    for (final buff in activeBuffs) {
      if (buff.type == 'click_2x' && !buff.isExpired(currentTimeMs)) {
        multiplier *= buff.multiplier;
      }
    }
    
    return multiplier;
  }

  /// 獲取 idle 倍數
  double getIdleMultiplier(int currentTimeMs) {
    double multiplier = 1.0;
    
    // 永久加成（使用配置的倍數）
    if (permanent.idleBoost > 1.0) {
      multiplier *= permanent.idleBoost;
    }
    
    // 限時加成
    for (final buff in activeBuffs) {
      if (buff.type == 'idle_2x' && !buff.isExpired(currentTimeMs)) {
        multiplier *= buff.multiplier;
      }
    }
    
    return multiplier;
  }

  /// 獲取離線時間上限（小時）
  int getOfflineCapHours(int currentTimeMs) {
    int baseHours = 6;
    
    // 永久加成
    if (permanent.offlineExtended) {
      baseHours += 6; // +6 小時
    }
    
    // 限時加成
    for (final buff in activeBuffs) {
      if (buff.type == 'offline_6h' && !buff.isExpired(currentTimeMs)) {
        baseHours += buff.multiplier.toInt();
      }
    }
    
    return baseHours;
  }

  /// 獲取每日點擊上限倍數
  double getDailyCapMultiplier() {
    double multiplier = 1.0;
    
    // 永久加成
    if (permanent.capIncreased) {
      multiplier *= 1.5; // +50%
    }
    
    return multiplier;
  }

  BuffState copyWith({
    List<TimedBuff>? activeBuffs,
    PermanentEntitlements? permanent,
  }) {
    return BuffState(
      activeBuffs: activeBuffs ?? List<TimedBuff>.from(this.activeBuffs),
      permanent: permanent ?? this.permanent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BuffState &&
        _listEquals(other.activeBuffs, activeBuffs) &&
        other.permanent == permanent;
  }

  @override
  int get hashCode {
    return activeBuffs.hashCode ^ permanent.hashCode;
  }

  @override
  String toString() {
    return 'BuffState(activeBuffs: ${activeBuffs.length}, permanent: $permanent)';
  }

  static bool _listEquals(List<TimedBuff> a, List<TimedBuff> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

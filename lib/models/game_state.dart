import 'dart:convert';

class GameState {
  final int saveVersion;
  final int memePoints;
  final Map<String, int> equipments;
  final int lastTs;

  const GameState({
    required this.saveVersion,
    required this.memePoints,
    required this.equipments,
    required this.lastTs,
  });

  /// 建立初始狀態
  factory GameState.initial(int currentVersion) {
    return GameState(
      saveVersion: currentVersion,
      memePoints: 0,
      equipments: {},
      lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
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
      memePoints: map['memePoints'] as int,
      equipments: Map<String, int>.from(map['equipments'] as Map),
      lastTs: map['lastTs'] as int,
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
    };
  }

  /// 驗證資料有效性
  bool validate() {
    try {
      // 檢查必要欄位存在且類型正確
      if (saveVersion < 0) return false;
      if (memePoints < 0) return false;
      if (lastTs <= 0) return false;
      
      // 檢查 equipments 中的值都是非負數
      for (final level in equipments.values) {
        if (level < 0) return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 複製並更新部分欄位
  GameState copyWith({
    int? saveVersion,
    int? memePoints,
    Map<String, int>? equipments,
    int? lastTs,
  }) {
    return GameState(
      saveVersion: saveVersion ?? this.saveVersion,
      memePoints: memePoints ?? this.memePoints,
      equipments: equipments ?? Map<String, int>.from(this.equipments),
      lastTs: lastTs ?? this.lastTs,
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
           'equipments: $equipments, lastTs: $lastTs)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameState &&
        other.saveVersion == saveVersion &&
        other.memePoints == memePoints &&
        _mapEquals(other.equipments, equipments) &&
        other.lastTs == lastTs;
  }

  @override
  int get hashCode {
    return saveVersion.hashCode ^
        memePoints.hashCode ^
        equipments.hashCode ^
        lastTs.hashCode;
  }

  bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

import 'package:uuid/uuid.dart';

/// 音符節拍資料
class BeatmapNote {
  final String id;
  final Duration time; // 音符應被按下的精確時間點
  final int position; // 1-based 軌道位置
  final String type; // 'tap', 'hold_start', 'hold_end'

  BeatmapNote({
    String? id,
    required this.time,
    required this.position,
    this.type = 'tap',
  }) : id = id ?? const Uuid().v4();

  factory BeatmapNote.fromJson(Map<String, dynamic> json) {
    final timeInSeconds = (json['time'] as num?)?.toDouble() ?? 0.0;
    return BeatmapNote(
      // 如果 json 中有 id，就用它，否則產生一個新的
      id: json['id'] as String?,
      time: Duration(microseconds: (timeInSeconds * 1000000).round()),
      position: (json['position'] as int?) ?? 1,
      type: (json['type'] as String?) ?? 'tap',
    );
  }
}

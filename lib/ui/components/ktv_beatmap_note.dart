/// 音符節拍資料
class BeatmapNote {
  final double time; // 秒
  final int position; // 1-based 軌道位置
  
  const BeatmapNote({
    required this.time,
    required this.position,
  });
  
  factory BeatmapNote.fromJson(Map<String, dynamic> json) {
    return BeatmapNote(
      time: (json['time'] as num?)?.toDouble() ?? 0.0,
      position: (json['position'] as int?) ?? 1,
    );
  }
}

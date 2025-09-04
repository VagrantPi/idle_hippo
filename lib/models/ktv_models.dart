import 'dart:convert';
import 'package:idle_hippo/ui/components/ktv_beatmap_note.dart';

class KtvDifficulty {
  final String level; // "easy" | "hard"
  final int keyCount; // 顯示為星數（上限 5）
  final List<Map<String, dynamic>>? beatmap; // 本階段保留不使用

  const KtvDifficulty({
    required this.level,
    required this.keyCount,
    this.beatmap,
  });

  factory KtvDifficulty.fromJson(Map<String, dynamic> json) {
    return KtvDifficulty(
      level: (json['level'] ?? '').toString(),
      keyCount: (json['key_count'] is int)
          ? (json['key_count'] as int)
          : int.tryParse('${json['key_count']}') ?? 0,
      beatmap: (json['beatmap'] is List)
          ? (json['beatmap'] as List).whereType<Map<String, dynamic>>().toList()
          : null,
    );
  }
}

class KtvSong {
  final String id; // 唯一鍵
  final String title;
  final String image; // 封面資產路徑
  final String music; // MP3 下載 URL
  final int lengthSeconds;
  final List<KtvDifficulty> difficulties;

  const KtvSong({
    required this.id,
    required this.title,
    required this.image,
    required this.music,
    required this.lengthSeconds,
    required this.difficulties,
  });

  factory KtvSong.fromJson(Map<String, dynamic> json) {
    final diffs = <KtvDifficulty>[];
    if (json['difficulties'] is List) {
      for (final d in (json['difficulties'] as List)) {
        if (d is Map<String, dynamic>) {
          diffs.add(KtvDifficulty.fromJson(d));
        }
      }
    }
    return KtvSong(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      music: (json['music'] ?? '').toString(),
      lengthSeconds: (json['length_seconds'] is int)
          ? (json['length_seconds'] as int)
          : int.tryParse('${json['length_seconds']}') ?? 0,
      difficulties: diffs,
    );
  }
}

/// 判定結果的枚舉
enum Judgement { perfect, great, miss }

/// 判定事件的詳細資訊
class JudgementResult {
  /// 判定的音符
  final BeatmapNote note;

  /// 判定結果
  final Judgement judgement;

  /// 時間差 (ms)，正數為慢，負數為快
  final int deltaMs;

  JudgementResult({
    required this.note,
    required this.judgement,
    required this.deltaMs,
  });
}

class KtvCollectionParser {
  /// 從 JSON 字串解析歌曲清單，僅取規格定義欄位。
  static List<KtvSong> parse(String jsonString) {
    try {
      final root = json.decode(jsonString);
      if (root is! Map<String, dynamic>) return const [];
      final songs = root['songs'];
      if (songs is! List) return const [];
      final result = <KtvSong>[];
      for (final item in songs) {
        if (item is Map<String, dynamic>) {
          try {
            final song = KtvSong.fromJson(item);
            // 基本欄位驗證：id、title、music 缺任一則略過
            if (song.id.isEmpty || song.title.isEmpty || song.music.isEmpty) {
              continue;
            }
            result.add(song);
          } catch (_) {
            // 單筆錯誤略過
          }
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}

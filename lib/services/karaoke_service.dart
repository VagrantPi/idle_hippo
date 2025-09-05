import 'package:flutter/widgets.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/audio_download_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/song_catalog_service.dart';

typedef NowProvider = DateTime Function();

/// Step 23: 管理卡拉 OK 的每日限制、結算與批次下載檢查等邏輯。
class KaraokeService {
  final GameStateService _state;
  final AudioDownloadService _downloader;
  final SongCatalogService _catalog;
  final NowProvider _now;
  final bool _deferWrite;

  KaraokeService({
    GameStateService? state,
    AudioDownloadService? downloader,
    SongCatalogService? catalog,
    NowProvider? now,
    bool deferWrite = false,
  })  : _state = state ?? GameStateService(),
        _downloader = downloader ?? AudioDownloadService(),
        _catalog = catalog ?? SongCatalogService(),
        _now = now ?? DateTime.now,
        _deferWrite = deferWrite;

  // tz=Asia/Taipei (UTC+8)
  String _todayAsiaTaipei() {
    final utc = _now().toUtc();
    final taipei = utc.add(const Duration(hours: 8));
    return '${taipei.year.toString().padLeft(4, '0')}-${taipei.month.toString().padLeft(2, '0')}-${taipei.day.toString().padLeft(2, '0')}';
  }

  /// 讀取狀態並在跨日時重置 `playedToday=false`。
  /// 回傳更新後狀態。
  Future<GameState> ensureKaraokeBlock() async {
    final s = _state.currentState;
    final today = _todayAsiaTaipei();
    final k = s.karaoke;
    if (k == null) {
      final next = s.copyWith(karaoke: KaraokeState.initial());
      if (_deferWrite && WidgetsBinding.instance != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _state.updateGameState(next);
        });
      } else {
        await _state.updateGameState(next);
      }
      return next;
    }
    if (k.lastPlayDate != today) {
      final reset = k.copyWith(playedToday: false);
      final next = s.copyWith(karaoke: reset);
      if (_deferWrite && WidgetsBinding.instance != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _state.updateGameState(next);
        });
      } else {
        await _state.updateGameState(next);
      }
      return next;
    }
    return s;
  }

  /// 是否當日可進入遊戲（未結算過）。
  Future<bool> isPlayableToday() async {
    final s = await ensureKaraokeBlock();
    final today = _todayAsiaTaipei();
    final k = s.karaoke;
    if (k == null) return true;
    if (k.lastPlayDate == today && k.playedToday) return false;
    return true;
  }

  /// 在結算完成（獎勵已入帳）後呼叫，將當日標記為已玩。
  Future<void> markSettledToday() async {
    final s = _state.currentState;
    final today = _todayAsiaTaipei();
    final k0 = s.karaoke ?? KaraokeState.initial();
    final k1 = k0.copyWith(lastPlayDate: today, playedToday: true);
    await _state.updateGameState(s.copyWith(karaoke: k1));
  }

  /// 檢查是否所有歌曲皆已下載。
  Future<bool> allSongsDownloaded() async {
    final songs = await _catalog.loadSongs();
    for (final s in songs) {
      final ok = await _downloader.isCached(s.id);
      if (!ok) return false;
    }
    return true;
  }

  /// 取得尚未下載的歌曲 id 清單。
  Future<List<String>> pendingDownloadIds() async {
    final songs = await _catalog.loadSongs();
    final result = <String>[];
    for (final s in songs) {
      final ok = await _downloader.isCached(s.id);
      if (!ok) result.add(s.id);
    }
    return result;
  }

  /// 是否允許自動試聽：需位於可見區且音源已下載。
  Future<bool> shouldAutoPreview(bool isVisible, String songId) async {
    if (!isVisible) return false;
    return await _downloader.isCached(songId);
  }
}

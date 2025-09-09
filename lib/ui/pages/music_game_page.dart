import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:idle_hippo/models/ktv_models.dart';
import 'package:idle_hippo/services/audio_download_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/song_catalog_service.dart';
import 'package:idle_hippo/services/karaoke_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/ui/components/ktv_batch_download_dialog.dart';
import 'package:just_audio/just_audio.dart';
import 'package:idle_hippo/ui/components/ktv_download_dialog.dart';
import 'package:idle_hippo/ui/pages/ktv_game_play_page.dart';

class MusicGamePage extends StatefulWidget {
  const MusicGamePage({super.key});

  @override
  State<MusicGamePage> createState() => _MusicGamePageState();
}

class _MusicGamePageState extends State<MusicGamePage> {
  // 中間卡片視覺高度（維持原先大卡尺寸）
  static const double _centerCardHeight = 260;
  // 非置中卡片視覺高度（中間的 1/3）
  static const double _compactItemHeight = _centerCardHeight / 3;
  // 滾輪項目間距：非置中卡高度 + 1px
  static const double _wheelItemExtent = _compactItemHeight + 1;
  final AudioDownloadService _downloader = AudioDownloadService();
  final LocalizationService _loc = LocalizationService();
  final SongCatalogService _catalog = SongCatalogService();
  final KaraokeService _karaoke = KaraokeService(deferWrite: true);
  final AudioPlayer _previewPlayer = AudioPlayer();
  final GameStateService _gameStateService = GameStateService();

  List<KtvSong> _songs = [];
  bool _isLoading = true;
  String? _error;
  KtvSong? _downloadingSong;
  String? _pendingDifficulty;
  bool _isScrolling = false;
  bool _playLocked = false;
  bool _allDownloaded = false;
  List<KtvBatchSong>? _batchSongs; // 批次下載 Overlay 開關
  Timer? _previewTimer;
  VoidCallback? _gsListener;

  @override
  void initState() {
    super.initState();
    _initKaraokeState();
    _loadSongs();
    // 監聽全域 GameState，當結算更新 `playedToday` 後立即鎖住按鈕
    _gsListener = () {
      _karaoke.isPlayableToday().then((playable) {
        if (mounted) setState(() => _playLocked = !playable);
      });
    };
    _gameStateService.gameState.addListener(_gsListener!);
  }

  Future<void> _initKaraokeState() async {
    await _karaoke.ensureKaraokeBlock();
    final playable = await _karaoke.isPlayableToday();
    if (mounted) setState(() => _playLocked = !playable);
  }

  // 高度為參數的遮罩，圖片置中，超出即裁切
  Widget _maskedImageStrip(String imagePath, double height) {
    final isAsset = imagePath.startsWith('assets/');
    final imageWidget = isAsset
        ? Image.asset(
            imagePath,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
          )
        : Image.file(
            File(imagePath),
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
          );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Builder(builder: (context) {
          return imageWidget;
        }),
      ),
    );
  }

  // 僅視覺用（不含可互動按鈕）的中心卡片，供覆蓋層使用以讓滾動可穿透
  Widget _buildCenterOverlayCardVisual(KtvSong song) {
    return AnimatedScale(
      scale: _isScrolling ? 0.5 : 1.0,
      duration: Duration(milliseconds: _isScrolling ? 120 : 220),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: _centerCardHeight,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _maskedImageStrip(song.image, _centerCardHeight / 2),
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(song.lengthSeconds ~/ 60)}:${(song.lengthSeconds % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // AudioDownloadService doesn't have a dispose method
    _wheelController.dispose();
    _previewTimer?.cancel();
    _previewPlayer.dispose();
    if (_gsListener != null) {
      _gameStateService.gameState.removeListener(_gsListener!);
      _gsListener = null;
    }
    super.dispose();
  }

  Future<void> _loadSongs() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final songs = await _catalog.loadSongs();
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
          if (_songs.isNotEmpty) {
            _expandedIndex = 0;
          }
        });
        // 將滾輪捲動到中間項目
        if (_songs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            _wheelController.jumpToItem(0);
            // 首次進入頁面：若首曲已下載，立即試聽
            await _autoPreviewCurrent();
          });
        }
        // 檢查是否已全部下載
        final allOk = await _karaoke.allSongsDownloaded();
        if (mounted) setState(() => _allDownloaded = allOk);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _onTapDifficulty(KtvSong song, String difficulty) async {
    if (!mounted) return;

    if (_playLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _loc.getString(
              'ktv.daily_locked',
              defaultValue: 'Already completed today. Come back tomorrow!',
            ),
          ),
        ),
      );
      return;
    }

    // 檢查是否已快取
    if (await _downloader.isCached(song.id)) {
      final path = await _downloader.cachedFilePath(song.id);
      if (!mounted) return;

      // 導向遊戲播放頁面
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => KtvGamePlayPage(
            songId: song.id,
            title: song.title,
            difficulty: difficulty,
            filePath: path,
          ),
        ),
      );
      // 返回後刷新今日鎖狀態（確保結算後立即鎖住）
      await _initKaraokeState();
    } else {
      // 未快取 → 顯示下載對話框
      setState(() {
        _downloadingSong = song;
        _pendingDifficulty = difficulty;
      });
    }
  }

  int? _expandedIndex;
  final FixedExtentScrollController _wheelController =
      FixedExtentScrollController();

  Future<void> _showDifficultyPicker(KtvSong song) async {
    if (!mounted) return;
    final easy = song.difficulties.firstWhere(
      (d) => d.level == 'easy',
      orElse: () => const KtvDifficulty(level: 'easy', keyCount: 1),
    );
    final hard = song.difficulties.firstWhere(
      (d) => d.level == 'hard',
      orElse: () => const KtvDifficulty(level: 'hard', keyCount: 3),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            _loc.getString(
              'ktv.choose_difficulty',
              defaultValue: 'Choose Difficulty',
            ),
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.greenAccent),
                ),
                leading: const Icon(
                  Icons.sports_esports,
                  color: Colors.greenAccent,
                ),
                title: Text(
                  _loc.getString('ktv.easy', defaultValue: 'EASY'),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: _buildStarRow(easy.keyCount),
                onTap: () => Navigator.of(context).pop('easy'),
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.redAccent),
                ),
                leading: const Icon(Icons.whatshot, color: Colors.redAccent),
                title: Text(
                  _loc.getString('ktv.hard', defaultValue: 'HARD'),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: _buildStarRow(hard.keyCount),
                onTap: () => Navigator.of(context).pop('hard'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      await _onTapDifficulty(song, result);
    }
  }

  Future<void> _onTapDownloadAll() async {
    if (!mounted) return;
    final pending = await _karaoke.pendingDownloadIds();
    if (pending.isEmpty) {
      if (mounted) setState(() => _allDownloaded = true);
      return;
    }

    // 準備批次清單並開啟 Overlay 對話框
    final entries = <KtvBatchSong>[];
    for (final id in pending) {
      final song = _songs.firstWhere(
        (s) => s.id == id,
        orElse: () => const KtvSong(
          id: '',
          title: '',
          image: '',
          music: '',
          lengthSeconds: 0,
          difficulties: [],
        ),
      );
      if (song.id.isEmpty || song.music.isEmpty) continue;
      entries.add(KtvBatchSong(id: song.id, url: song.music, title: song.title));
    }
    if (entries.isEmpty) return;
    if (mounted) setState(() => _batchSongs = entries);
  }

  Future<void> _autoPreviewCurrent() async {
    if (!mounted) return;
    if (_expandedIndex == null) return;
    if (_isScrolling) return;
    final song = _songs[_expandedIndex!];
    await _tryAutoPreview(song);
  }

  Future<void> _tryAutoPreview(KtvSong song) async {
    // 僅當音檔已下載才試聽
    if (!await _downloader.isCached(song.id)) return;
    try {
      _stopPreview();
      final path = await _downloader.cachedFilePath(song.id);
      await _previewPlayer.setFilePath(path);
      await _previewPlayer.play();
      _previewTimer = Timer(const Duration(seconds: 10), () {
        _previewPlayer.stop();
      });
    } catch (_) {
      // 若裝置/格式限制導致失敗，靜默略過（整曲播放可在 setFilePath 成功後自然進行）
    }
  }

  void _stopPreview() {
    _previewTimer?.cancel();
    _previewTimer = null;
    _previewPlayer.stop();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loc.getString('ktv.error', defaultValue: 'Error'),
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSongs,
              child: Text(_loc.getString('ktv.retry', defaultValue: 'Retry')),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return Center(
        child: Text(
          _loc.getString('ktv.no_songs', defaultValue: 'No songs available'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              if (!_isScrolling) {
                setState(() => _isScrolling = true);
              }
              _stopPreview();
            } else if (notification is ScrollEndNotification) {
              if (_isScrolling) {
                setState(() => _isScrolling = false);
              }
              _autoPreviewCurrent();
            }
            return false;
          },
          child: ListWheelScrollView.useDelegate(
            controller: _wheelController,
            physics: const FixedExtentScrollPhysics(),
            itemExtent: _wheelItemExtent,
            perspective: 0.003,
            diameterRatio: 2.0,
            onSelectedItemChanged: (index) {
              setState(() {
                _expandedIndex = index;
              });
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: _songs.length,
              builder: (context, index) {
                final song = _songs[index];
                final isCenter = _expandedIndex == index;
                return _buildSongItem(song, isCenter);
              },
            ),
          ),
        ),
        if (_expandedIndex != null)
          Positioned.fill(
            child: Stack(
              children: [
                // 視覺層：不攔截手勢，讓底下 ListWheel 可滾動
                IgnorePointer(
                  ignoring: true,
                  child: Center(
                    child: _buildCenterOverlayCardVisual(
                      _songs[_expandedIndex!],
                    ),
                  ),
                ),
                // 互動層：僅提供右下角播放按鈕可點擊（其餘區域不攔截手勢）
                if (!_isScrolling)
                  Center(
                    child: SizedBox(
                      height: _centerCardHeight,
                      child: Padding(
                        // 對齊卡片左右 margin
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          // 對齊卡片內部 padding（右下角）
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: 20,
                              bottom: 20,
                            ),
                            child: FloatingActionButton.small(
                              heroTag: null,
                              backgroundColor: _playLocked
                                  ? Colors.grey
                                  : Colors.green.withValues(alpha: 0.9),
                              onPressed: () {
                                if (_isScrolling) return;
                                if (_playLocked) return;
                                _stopPreview();
                                final song = _songs[_expandedIndex!];
                                _showDifficultyPicker(song);
                              },
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSongItem(KtvSong song, bool isCenter) {
    return GestureDetector(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: isCenter
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isCenter
            ? SizedBox(height: _wheelItemExtent)
            : Align(
                alignment: Alignment.center,
                child: Container(
                  height: _compactItemHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          song.image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(song.lengthSeconds ~/ 60)}:${(song.lengthSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.9)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStarRow(int stars) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          Icons.star,
          size: 16,
          color: i < stars ? Colors.yellow : Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _loc.getPageName('musicGame');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
          // 背景圖片
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/KTVGamePlayPageBg.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.2),
            ),
          ),
          _buildBody(),
          // 下載 Overlay
          // 下載 Overlay
          if (_downloadingSong != null)
            Positioned.fill(
              child: KtvDownloadDialog(
                songId: _downloadingSong!.id,
                url: _downloadingSong!.music,
                onClose: () async {
                  // 關閉 overlay（未開始播放）
                  setState(() {
                    _downloadingSong = null;
                    _pendingDifficulty = null;
                  });
                  final allOk = await _karaoke.allSongsDownloaded();
                  if (mounted) setState(() => _allDownloaded = allOk);
                },
                onDownloaded: () async {
                  // 下載完成後：自動轉跳到遊戲畫面
                  final song = _downloadingSong;
                  final difficulty = _pendingDifficulty;
                  if (song == null || difficulty == null) {
                    // 回退：若狀態異常，僅刷新列表
                    await _loadSongs();
                    return;
                  }

                  // 捕捉當前 BuildContext，避免跨 async 間隙直接使用 State.context
                  final ctx = context;
                  final path = await _downloader.cachedFilePath(song.id);

                  if (!ctx.mounted) return;
                  // 先關閉 overlay 狀態
                  setState(() {
                    _downloadingSong = null;
                    _pendingDifficulty = null;
                  });

                  // 導向遊戲播放頁面
                  await Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (context) => KtvGamePlayPage(
                        songId: song.id,
                        title: song.title,
                        difficulty: difficulty,
                        filePath: path,
                      ),
                    ),
                  );
                  await _initKaraokeState();
                  final allOk = await _karaoke.allSongsDownloaded();
                  if (mounted) setState(() => _allDownloaded = allOk);
                },
              ),
            ),
          if (_batchSongs != null)
            Positioned.fill(
              child: KtvBatchDownloadDialog(
                songs: _batchSongs!,
                onClose: () async {
                  setState(() => _batchSongs = null);
                  final allOk = await _karaoke.allSongsDownloaded();
                  if (mounted) setState(() => _allDownloaded = allOk);
                },
                onCompleted: () async {
                  setState(() => _batchSongs = null);
                  final allOk = await _karaoke.allSongsDownloaded();
                  if (mounted) setState(() => _allDownloaded = allOk);
                  // 批次下載完成後，立即試聽目前顯示的歌曲
                  await _autoPreviewCurrent();
                },
              ),
            ),
          // 規則說明與右下 Download All（最上層顯示）
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 120, 48),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _loc.getString(
                      'ktv.rule',
                      defaultValue:
                          'You may play freely until you finish one game. Only the first completed game counts for daily reward.',
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 6,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _allDownloaded ? null : _onTapDownloadAll,
                    child: Text(
                      _allDownloaded
                          ? _loc.getString('ktv.all_downloaded', defaultValue: 'All downloaded')
                          : _loc.getString('ktv.download_all', defaultValue: 'Download All'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

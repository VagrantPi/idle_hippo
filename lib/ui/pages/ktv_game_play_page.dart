import 'dart:async';
import 'package:flutter/material.dart';
// removed rootBundle: song list now loads via SongCatalogService
import 'package:flame/game.dart';
import 'package:just_audio/just_audio.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/models/ktv_models.dart';
import 'package:idle_hippo/ui/components/ktv_lane_layout.dart';
import 'package:idle_hippo/ui/game/ktv_game.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/decimal_utils.dart';
import 'package:idle_hippo/services/karaoke_service.dart';
import 'package:idle_hippo/services/song_catalog_service.dart';

class KtvGamePlayPage extends StatefulWidget {
  final String songId;
  final String title;
  final String difficulty;
  final String filePath;
  final KtvSong? song;

  const KtvGamePlayPage({
    super.key,
    required this.songId,
    required this.title,
    required this.difficulty,
    required this.filePath,
    this.song,
  });

  @override
  State<KtvGamePlayPage> createState() => _KtvGamePlayPageState();
}

class _KtvGamePlayPageState extends State<KtvGamePlayPage> {
  final _player = AudioPlayer();
  final _loc = LocalizationService();
  final _config = ConfigService();

  bool _isCountingDown = true;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _settled = false; // 是否已結算入帳

  // KTV 遊戲
  LaneLayout? _laneLayout;
  KtvGame? _game;
  KtvSong? _song;
  KtvDifficulty? _difficulty; // 由 assets/audio/collect.json 載入
  final SongCatalogService _catalog = SongCatalogService();

  // 遊戲配置
  late double _approachTimeMs;
  late double _judgelineY;
  late double _spawnY;
  late double _lanePadding;
  late double _perspectiveDepth;
  late double _despawnGraceMs;

  // 遊戲狀態
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  // HUD 倒數顯示（每秒更新）
  Timer? _hudTimer;
  String _hudTimeText = '00:00';
  DateTime? _hudNextAllowedUpdate; // 用於控制首次載入延遲 1 秒才開始倒數

  // HUD：即時判定彈字
  String? _judgeText;
  Color _judgeColor = Colors.white;
  Timer? _judgeTimer;
  double _judgeOpacity = 0.0;

  StreamSubscription<Duration>? _hudPosSub;
  StreamSubscription<Duration?>? _hudDurSub;
  StreamSubscription<JudgementResult>? _judgementUiSub;

  // 中央 COMBO 顯示與跳動動畫
  int _lastComboShown = 0;
  double _comboScale = 1.0;
  Timer? _comboPulseTimer;

  @override
  void initState() {
    super.initState();
    _loadGameConfig();
    _initializeGame();
    _loadBeatmap();
    _startCountdown();
  }

  void _loadGameConfig() {
    _approachTimeMs = _config
        .getValue('game.ktv.approachTimeMs', defaultValue: 1500.0)
        .toDouble();
    _judgelineY = _config
        .getValue('game.ktv.judgelineY', defaultValue: 0.82)
        .toDouble();
    _spawnY = _config
        .getValue('game.ktv.spawnY', defaultValue: -0.10)
        .toDouble();
    _lanePadding = _config
        .getValue('game.ktv.lanePadding', defaultValue: 16.0)
        .toDouble();
    _perspectiveDepth = _config
        .getValue('game.ktv.perspectiveDepth', defaultValue: 0.22)
        .toDouble();
    _despawnGraceMs = _config
        .getValue('game.ktv.despawnGraceMs', defaultValue: 150.0)
        .toDouble();
  }

  void _initializeGame() {
    // LaneLayout 需等 build 時拿到螢幕尺寸
  }

  Future<void> _loadBeatmap() async {
    try {
      // 透過服務載入（優先 appdata，其次 assets）
      final songs = await _catalog.loadSongs();
      final song = songs.firstWhere(
        (s) => s.id == widget.songId,
        orElse: () => const KtvSong(
          id: '',
          title: '',
          image: '',
          music: '',
          lengthSeconds: 0,
          difficulties: [],
        ),
      );

      if (song.id.isEmpty) return;

      final difficulty = song.difficulties.firstWhere(
        (d) => d.level == widget.difficulty,
        orElse: () => KtvDifficulty(
          level: widget.difficulty,
          keyCount: widget.difficulty == 'hard' ? 5 : 3,
          beatmap: const [],
        ),
      );

      if (!mounted) return;
      setState(() {
        _song = song;
        _difficulty = difficulty;
      });
    } catch (_) {
      // 異常時維持現狀（畫面仍可顯示，但沒有譜面）
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _countdownTimer?.cancel();
    _hudPosSub?.cancel();
    _hudDurSub?.cancel();
    _judgeTimer?.cancel();
    _judgementUiSub?.cancel();
    _comboPulseTimer?.cancel();
    _hudTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdownValue > 1) {
            _countdownValue--;
          } else {
            _isCountingDown = false;
            timer.cancel();
            _startPlayback();
          }
        });
      }
    });
  }

  Future<void> _startPlayback() async {
    try {
      // 確保已載入 collect.json 的歌曲資料，取得 length_seconds
      if (_song == null) {
        await _loadBeatmap();
      }

      // 先用 metadata 的長度預填，讓 HUD 立即顯示總長度
      if ((_song?.lengthSeconds ?? 0) > 0) {
        setState(() {
          _duration = Duration(seconds: _song!.lengthSeconds);
        });
        _recomputeHudTime();
      }

      final loadedDur = await _player.setFilePath(widget.filePath);
      // 立即取得曲長（避免一開始顯示 00:00）
      setState(() {
        _duration = loadedDur ?? Duration(seconds: _song?.lengthSeconds ?? 0);
      });

      // 然後開始播放音樂
      _player.play();

      // 先啟動 Flame 遊戲時序
      _game?.start();

      // 啟動每秒 HUD 倒數計時器（首次開始：延遲 1 秒再開始倒數）
      _startHudTicker(delayFirstTick: true);

      setState(() => _isPlaying = true);

      // HUD 時間顯示
      // 監聽曲長（有些平台需透過 durationStream 才會正確更新）
      _duration = _player.duration ?? Duration.zero;
      _hudDurSub?.cancel();
      _hudDurSub = _player.durationStream.listen((d) {
        if (!mounted) return;
        if (d != null) {
          setState(() => _duration = d);
          // 曲長改變時立即重算 HUD
          _recomputeHudTime();
        }
      });
      _hudPosSub?.cancel();
      _hudPosSub = _player.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() {
          _position = pos;
        });
        // 位置更新時即時刷新 HUD 倒數（只在文字有變化時 setState）
        _updateHudTimeFromPosition();
      });

      // 監聽曲終，開結算畫面
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          // 曲終：停止 HUD 計時器並開啟結算
          _hudTimer?.cancel();
          if (mounted) _openResult();
        } else if (state.processingState == ProcessingState.ready) {
          // 有些平台在 ready 才能可靠拿到 duration
          final d = _player.duration;
          if (d != null && mounted) {
            setState(() => _duration = d);
            _recomputeHudTime();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Playback error: $e')));
      }
    }
  }

  void _startHudTicker({bool delayFirstTick = false}) {
    _hudTimer?.cancel();
    // 設定 HUD 更新允許時間：首次載入延遲 1 秒，其餘情境立即允許
    _hudNextAllowedUpdate = delayFirstTick
        ? DateTime.now().add(const Duration(seconds: 1))
        : null;
    _hudTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // 若尚未到達允許更新時間，略過這次
      if (_hudNextAllowedUpdate != null && DateTime.now().isBefore(_hudNextAllowedUpdate!)) {
        return;
      }
      _recomputeHudTime();
    });
  }

  void _recomputeHudTime() {
    final remaining = (_duration > Duration.zero)
        ? ((_duration - _position).isNegative ? Duration.zero : _duration - _position)
        : Duration.zero;
    setState(() {
      _hudTimeText = _formatMmSs(remaining);
    });
  }

  void _updateHudTimeFromPosition() {
    final remaining = (_duration > Duration.zero)
        ? ((_duration - _position).isNegative ? Duration.zero : _duration - _position)
        : Duration.zero;
    final nextText = _formatMmSs(remaining);
    // 首次載入的第一秒內不更新 HUD，避免一開始就扣一秒
    if (_hudNextAllowedUpdate != null && DateTime.now().isBefore(_hudNextAllowedUpdate!)) {
      return;
    }
    if (nextText != _hudTimeText && mounted) {
      setState(() {
        _hudTimeText = nextText;
      });
    }
  }

  void _subscribeJudgementIfNeeded() {
    if (_game == null) return;
    // 僅在首次建立 _game 後掛上一次
    _judgementUiSub ??= _game!.judgements.listen((result) {
      // 顯示彈字 300ms 並淡出
      final loc = _loc;
      switch (result.judgement) {
        case Judgement.perfect:
          _judgeText = loc.getString('ktv.judge.perfect', defaultValue: 'Perfect');
          _judgeColor = Colors.blueAccent;
          break;
        case Judgement.great:
          _judgeText = loc.getString('ktv.judge.great', defaultValue: 'Great');
          _judgeColor = Colors.greenAccent;
          break;
        case Judgement.miss:
          _judgeText = loc.getString('ktv.judge.miss', defaultValue: 'Miss');
          _judgeColor = Colors.redAccent;
          break;
      }
      _judgeTimer?.cancel();
      setState(() {
        _judgeOpacity = 1.0;
      });
      // 啟動淡出
      _judgeTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _judgeOpacity = 0.0;
        });
        // 在淡出結束後清理文字
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _judgeText = null);
        });
      });
      // 也觸發 HUD 重繪（分數/COMBO 來自 _game!.scoring）
      if (mounted) setState(() {});

      // 若為 Perfect/Great，且 COMBO 有增加，觸發中央 COMBO 跳動
      if (result.judgement != Judgement.miss && _game != null) {
        final currentCombo = _game!.scoring.combo;
        if (currentCombo > _lastComboShown) {
          _triggerComboPulse(currentCombo);
        }
      } else if (result.judgement == Judgement.miss) {
        // MISS 時重置上次顯示，避免之後從 1 開始不觸發
        _lastComboShown = _game?.scoring.combo ?? 0;
      }
    });
  }

  void _triggerComboPulse(int newCombo) {
    _lastComboShown = newCombo;
    _comboPulseTimer?.cancel();
    setState(() => _comboScale = 1.25);
    _comboPulseTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _comboScale = 1.0);
    });
  }

  String _formatMmSs(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double _roundDown2(double x) {
    final scaled = (x * 100).floor() / 100.0;
    return scaled;
  }

  Future<void> _openResult() async {
    if (_settled || _game == null) return;
    _settled = true;
    final scoring = _game!.scoring;
    final base = scoring.baseScoreSum;
    final mult = scoring.comboMultiplier;
    final finalPoints = scoring.finalizeMemePoints();

    // 入帳（只做一次）
    try {
      final service = GameStateService();
      final current = service.currentState;
      final newState = current.copyWith(
        memePoints: DecimalUtils.add(current.memePoints, finalPoints),
      );
      await service.updateGameState(newState);
    } catch (_) {
      // 測試或無初始化環境下允許跳過持久化錯誤
    }

    // Step23: 標記卡拉OK當日已結算
    try {
      await KaraokeService().markSettledToday();
    } catch (_) {}

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(
            _loc.getString('ktv.result.title', defaultValue: 'Results'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('ktv.result.perfect', 'PERFECT', scoring.perfectCount, color: Colors.blueAccent),
              _buildResultRow('ktv.result.great', 'GREAT', scoring.greatCount, color: Colors.greenAccent),
              _buildResultRow('ktv.result.miss', 'MISS', scoring.missCount, color: Colors.redAccent),
              _buildResultRow('ktv.result.max_combo', 'Max Combo', scoring.maxCombo),
              _buildResultRow(
                'ktv.result.combo_bonus',
                'Combo Bonus',
                'x${_roundDown2(mult).toStringAsFixed(2)}',
              ),
              _buildResultRow(
                'ktv.result.base_score',
                'Base Score',
                _roundDown2(base).toStringAsFixed(2),
              ),
              _buildResultRow(
                'ktv.result.total_meme',
                'Total Meme Points',
                finalPoints.toStringAsFixed(2),
                highlight: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => Theme.of(context).colorScheme.secondary,
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                _loc.getString('ktv.result.ok', defaultValue: 'OK'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  TextStyle _neonStyle(Color color, {double fontSize = 14, bool bold = false}) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      shadows: [
        Shadow(color: color.withValues(alpha: 0.9), blurRadius: 8, offset: const Offset(0, 0)),
        Shadow(color: color.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(0, 0)),
      ],
    );
  }

  Widget _buildResultRow(String key, String fallback, Object value, {bool highlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _loc.getString(key, defaultValue: fallback),
            style: color != null ? _neonStyle(color) : const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            '$value',
            style: highlight
                ? _neonStyle(Colors.amberAccent, fontSize: 16, bold: true)
                : (color != null ? _neonStyle(color) : const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _togglePause() {
    if (_isPaused) {
      _player.play();
      _game?.resume();
      // 恢復每秒 HUD 計時
      _startHudTicker();
    } else {
      _player.pause();
      _game?.pause();
      // 暫停時停止 HUD 計時
      _hudTimer?.cancel();
    }
    setState(() => _isPaused = !_isPaused);
  }

  // 與 Flame 重構後無需保留的列表比較邏輯已移除

  // 已改由 Flame 控制更新與渲染

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isCountingDown ? _buildCountdown() : _buildGamePlay(),
    );
  }

  Widget _buildCountdown() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInQuart),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            '$_countdownValue',
            key: ValueKey<int>(_countdownValue),
            style: const TextStyle(
              fontSize: 200,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 20.0,
                  color: Colors.black,
                  offset: Offset(0, 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamePlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 若尚未載入到難度與譜面，先顯示載入畫面
        if (_difficulty == null) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        // 初始化 LaneLayout 與 Flame Game（僅一次）
        if (_laneLayout == null) {
          final effectiveDifficulty = _difficulty!;
          final keyCount = effectiveDifficulty.keyCount;
          _laneLayout = LaneLayout(
            keyCount: keyCount,
            screenWidth: constraints.maxWidth,
            screenHeight: constraints.maxHeight,
            lanePadding: _lanePadding,
            perspectiveDepth: _perspectiveDepth,
            judgelineY: _judgelineY,
            spawnY: _spawnY,
          );
          _game = KtvGame(
            audioPlayer: _player,
            difficulty: effectiveDifficulty,
            laneLayout: _laneLayout!,
            approachTimeMs: _approachTimeMs,
            despawnGraceMs: _despawnGraceMs,
          );
          _subscribeJudgementIfNeeded();
          // 若音樂已經在播放，立即啟動遊戲時序以對齊進度
          if (_isPlaying) {
            _game!.start();
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 背景
            Container(color: Colors.black),

            // Flame 遊戲畫面
            if (_game != null) GameWidget(game: _game!),

            // UI 覆蓋層
            _buildGameUI(),
          ],
        );
      },
    );
  }

  Widget _buildGameUI() {
    return Stack(
      children: [
        // 頂部資訊欄
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 返回按鈕
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),

                  // 歌曲資訊
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.difficulty == 'hard'
                              ? _loc.getString('ktv.hard', defaultValue: 'Hard')
                              : _loc.getString(
                                  'ktv.easy',
                                  defaultValue: 'Easy',
                                ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 暫停按鈕
                  IconButton(
                    icon: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                    onPressed: _togglePause,
                  ),
                ],
              ),
            ),
          ),
        ),

        // HUD：分數 / 連擊 / 時間
        Positioned(
          top: 100,
          left: 16,
          right: 16,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左：分數
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hudChip(
                      label: _loc.getString('ktv.hud.score', defaultValue: 'Score'),
                      value: _roundDown2(_game?.scoring.baseScoreSum ?? 0.0).toStringAsFixed(2),
                    ),
                  ],
                ),

                // 右：剩餘時間
                _hudChip(
                  label: _loc.getString('ktv.hud.time', defaultValue: 'Time Left'),
                  value: _hudTimeText,
                ),
              ],
            ),
          ),
        ),

        // 即時判定彈字（在 COMBO 顯示上方，300ms 淡出）
        if (_judgeText != null)
          Positioned(
            top: _laneLayout?.screenHeight != null
                ? (_laneLayout!.screenHeight * 0.2) - 48
                : 120,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _judgeOpacity,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _judgeText!,
                      style: _neonStyle(_judgeColor, fontSize: 24, bold: true),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 中央：COMBO 顯示（僅在有連擊或曾經有 maxCombo>0 時顯示）
        if ((_game?.scoring.combo ?? 0) > 0)
          Positioned(
            top: _laneLayout?.screenHeight != null
                ? _laneLayout!.screenHeight * 0.2
                : 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedScale(
                  scale: _comboScale,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutBack,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_game?.scoring.combo ?? 0} COMBO',
                          style: _neonStyle(Colors.greenAccent, fontSize: 28, bold: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _hudChip({required String label, required String value, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}

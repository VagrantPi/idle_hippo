 import 'dart:async';
 import 'package:flutter/material.dart';
 import 'package:flutter/services.dart' show rootBundle;
 import 'package:flame/game.dart';
 import 'package:just_audio/just_audio.dart';
 import 'package:idle_hippo/services/audio_download_service.dart';
 import 'package:idle_hippo/services/localization_service.dart';
 import 'package:idle_hippo/services/config_service.dart';
 import 'package:idle_hippo/models/ktv_models.dart';
 import 'package:idle_hippo/ui/components/ktv_lane_layout.dart';
 import 'package:idle_hippo/ui/game/ktv_game.dart';

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
  
  // KTV 遊戲
  LaneLayout? _laneLayout;
  KtvGame? _game;
  KtvSong? _song;
  KtvDifficulty? _difficulty; // 由 assets/audio/collect.json 載入
  
  // 遊戲配置
  late double _approachTimeMs;
  late double _judgelineY;
  late double _spawnY;
  late double _lanePadding;
  late double _perspectiveDepth;
  late double _despawnGraceMs;
  
  // 遊戲狀態
  int _score = 0;
  int _combo = 0;

  @override
  void initState() {
    super.initState();
    _loadGameConfig();
    _initializeGame();
    _loadBeatmapFromAssets();
    _startCountdown();
  }
  
  void _loadGameConfig() {
    _approachTimeMs = _config.getValue('game.ktv.approachTimeMs', defaultValue: 1500.0).toDouble();
    _judgelineY = _config.getValue('game.ktv.judgelineY', defaultValue: 0.82).toDouble();
    _spawnY = _config.getValue('game.ktv.spawnY', defaultValue: -0.10).toDouble();
    _lanePadding = _config.getValue('game.ktv.lanePadding', defaultValue: 16.0).toDouble();
    _perspectiveDepth = _config.getValue('game.ktv.perspectiveDepth', defaultValue: 0.22).toDouble();
    _despawnGraceMs = _config.getValue('game.ktv.despawnGraceMs', defaultValue: 150.0).toDouble();
  }
  
  void _initializeGame() {
    // LaneLayout 需等 build 時拿到螢幕尺寸
  }
  
  Future<void> _loadBeatmapFromAssets() async {
    try {
      final jsonString = await rootBundle.loadString('assets/audio/collect.json');
      final songs = KtvCollectionParser.parse(jsonString);
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

      if (song.id.isEmpty) {
        // 找不到歌曲，維持現狀（畫面仍可顯示，但沒有譜面）
        return;
      }

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
      // 若解析失敗，使用既有 fallback（畫面仍可顯示，但沒有譜面）
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _countdownTimer?.cancel();
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
      await _player.setFilePath(widget.filePath);
      
      // 先啟動 Flame 遊戲時序
      _game?.start();
      
      // 然後開始播放音樂
      await _player.play();
      
      setState(() => _isPlaying = true);
      
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      }
    }
  }
  
  void _togglePause() {
    if (_isPaused) {
      _player.play();
      _game?.resume();
    } else {
      _player.pause();
      _game?.pause();
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
              scale: Tween<double>(
                begin: 0.5,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInQuart,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
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
            if (_game != null)
              GameWidget(game: _game!),
            
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
                              : _loc.getString('ktv.easy', defaultValue: 'Easy'),
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
        
        // 分數顯示
        Positioned(
          top: 100,
          right: 16,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 分數
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '分數: $_score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 連擊數（只在有連擊時顯示）
                if (_combo > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'COMBO: $_combo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

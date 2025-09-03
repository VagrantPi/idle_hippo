import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:idle_hippo/services/audio_download_service.dart';
import 'package:idle_hippo/services/localization_service.dart';

class KtvGamePlayPage extends StatefulWidget {
  final String songId;
  final String title;
  final String difficulty;
  final String filePath;

  const KtvGamePlayPage({
    super.key,
    required this.songId,
    required this.title,
    required this.difficulty,
    required this.filePath,
  });

  @override
  State<KtvGamePlayPage> createState() => _KtvGamePlayPageState();
}

class _KtvGamePlayPageState extends State<KtvGamePlayPage> {
  final _player = AudioPlayer();
  final _loc = LocalizationService();
  
  bool _isCountingDown = true;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景圖或專輯封面
        Container(
          color: Colors.black,
          child: Center(
            child: Icon(
              Icons.music_note,
              size: 200,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        
        // 頂部控制欄
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
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
        ),
      ],
    );
  }
}

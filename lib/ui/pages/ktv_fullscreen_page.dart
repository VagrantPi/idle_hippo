import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:idle_hippo/services/localization_service.dart';

class KtvFullscreenPage extends StatefulWidget {
  final String title;
  final String difficulty; // 'easy' | 'hard'
  final String filePath; // local mp3 path
  final VoidCallback onExit;

  const KtvFullscreenPage({
    super.key,
    required this.title,
    required this.difficulty,
    required this.filePath,
    required this.onExit,
  });

  @override
  State<KtvFullscreenPage> createState() => _KtvFullscreenPageState();
}

class _KtvFullscreenPageState extends State<KtvFullscreenPage> {
  final _player = AudioPlayer();
  final _loc = LocalizationService();

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setFilePath(widget.filePath);
      await _player.play();
      setState(() => _loading = false);
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          widget.onExit();
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diffLabel = widget.difficulty == 'hard'
        ? _loc.getString('ktv.hard', defaultValue: 'Hard')
        : _loc.getString('ktv.easy', defaultValue: 'Easy');

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with back button and song info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onExit,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: _loc.getString('ktv.back', defaultValue: 'Back'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title, 
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            diffLabel, 
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 12
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main content area
              Expanded(
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline, 
                                    color: Colors.redAccent, 
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _loc.getString('ktv.error', defaultValue: 'Error'), 
                                    style: const TextStyle(
                                      color: Colors.redAccent, 
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _error!, 
                                    style: const TextStyle(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : const Icon(
                              Icons.music_note, 
                              color: Colors.white24, 
                              size: 120,
                            ),
                ),
              ),
              
              // Playback controls
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 16,
                ),
                color: Colors.black,
                child: StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return ElevatedButton.icon(
                      onPressed: () async {
                        if (playing) {
                          await _player.pause();
                        } else {
                          await _player.play();
                        }
                        setState(() {});
                      },
                      icon: Icon(
                        playing ? Icons.pause : Icons.play_arrow, 
                        size: 28,
                      ),
                      label: Text(
                        _loc.getString(
                          playing ? 'ktv.pause' : 'ktv.play', 
                          defaultValue: playing ? 'Pause' : 'Play',
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

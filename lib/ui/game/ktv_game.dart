import 'dart:async';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:just_audio/just_audio.dart';
import 'package:idle_hippo/models/ktv_models.dart';
import 'package:idle_hippo/ui/components/ktv_lane_layout.dart';
import 'package:idle_hippo/ui/game/note_component.dart';
import 'package:idle_hippo/ui/game/lane_background_component.dart';
import 'package:idle_hippo/ui/components/ktv_beatmap_note.dart';

class KtvGame extends FlameGame {
  final AudioPlayer audioPlayer;
  final KtvDifficulty difficulty;
  final LaneLayout laneLayout;
  final double approachTimeMs;
  final double despawnGraceMs;
  
  final List<NoteComponent> activeNotes = [];
  final List<BeatmapNote> _beatmap = [];
  int _nextNoteIndex = 0;
  bool _isPlaying = false;
  // Base audio time from last stream tick
  double _lastAudioTimeSec = 0.0;
  // Smooth accumulator advanced each frame between audio ticks
  double _sinceAudioUpdateSec = 0.0;
  StreamSubscription<Duration>? _positionSub;
  
  KtvGame({
    required this.audioPlayer,
    required this.difficulty,
    required this.laneLayout,
    this.approachTimeMs = 1500,
    this.despawnGraceMs = 150,
  });
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    _loadBeatmap();
    
    // 固定解析度視口（遵循專案規範）
    camera.viewport = FixedResolutionViewport(resolution: Vector2(1080, 1920));
    
    // 背景軌道與判定線
    add(LaneBackgroundComponent(
      laneLayout: laneLayout,
      judgelineY: laneLayout.judgelineY,
      screenHeight: laneLayout.screenHeight,
    ));
  }
  
  void _loadBeatmap() {
    _beatmap.clear();
    _nextNoteIndex = 0;
    
    if (difficulty.beatmap != null) {
      for (final noteData in difficulty.beatmap!) {
        try {
          final note = BeatmapNote.fromJson(noteData);
          _beatmap.add(note);
        } catch (e) {
          print('Failed to parse beatmap note: $e');
        }
      }
      _beatmap.sort((a, b) => a.time.compareTo(b.time));
    }
  }
  
  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _nextNoteIndex = 0;
    _lastAudioTimeSec = audioPlayer.position.inMilliseconds / 1000.0;
    _sinceAudioUpdateSec = 0.0;
    _positionSub?.cancel();
    _positionSub = audioPlayer.positionStream.listen(_onPositionUpdate);
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _positionSub?.cancel();
    _positionSub = null;
  }

  void resume() {
    if (_isPlaying) return;
    _isPlaying = true;
    _lastAudioTimeSec = audioPlayer.position.inMilliseconds / 1000.0;
    _sinceAudioUpdateSec = 0.0;
    _positionSub?.cancel();
    _positionSub = audioPlayer.positionStream.listen(_onPositionUpdate);
  }
  
  void _onPositionUpdate(Duration position) {
    if (!_isPlaying) return;
    // Update base time from audio and reset the frame accumulator
    _lastAudioTimeSec = position.inMilliseconds / 1000.0;
    _sinceAudioUpdateSec = 0.0;
  }
  
  void _generateNotes(double audioTimeSec, double approachTimeSec) {
    const epsilon = 0.016; // ~1 frame at 60fps
    
    while (_nextNoteIndex < _beatmap.length) {
      final note = _beatmap[_nextNoteIndex];
      final spawnTime = note.time - approachTimeSec;
      
      if (audioTimeSec + epsilon >= spawnTime) {
        final laneIndex = note.position - 1;
        if (laneLayout.isValidLaneIndex(laneIndex)) {
          final noteComponent = NoteComponent(
            note: note,
            laneIndex: laneIndex,
            laneLayout: laneLayout,
            approachTimeMs: approachTimeMs,
            onDespawn: _onNoteDespawn,
          );
          
          add(noteComponent);
          activeNotes.add(noteComponent);
        }
        _nextNoteIndex++;
      } else {
        break;
      }
    }
  }
  
  void _onNoteDespawn(NoteComponent note) {
    activeNotes.remove(note);
    note.removeFromParent();
  }
  
  void _despawnNotes(double audioTimeSec) {
    final notesToRemove = <NoteComponent>[];
    
    for (final note in activeNotes) {
      if (note.shouldDespawn(audioTimeSec, despawnGraceMs)) {
        notesToRemove.add(note);
      }
    }
    
    for (final note in notesToRemove) {
      _onNoteDespawn(note);
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    if (!_isPlaying) return;

    // Advance smooth visual time between audio position updates
    _sinceAudioUpdateSec += dt;
    final visualTimeSec = _lastAudioTimeSec + _sinceAudioUpdateSec;

    // Generate/despawn based on smooth time for timely spawns
    final approachTimeSec = approachTimeMs / 1000.0;
    _generateNotes(visualTimeSec, approachTimeSec);
    _despawnNotes(visualTimeSec);

    // Update positions smoothly every frame
    // 使用快照避免在迭代時被回收導致 ConcurrentModificationError
    final notesSnapshot = List<NoteComponent>.from(activeNotes);
    for (final note in notesSnapshot) {
      note.updatePosition(visualTimeSec);
    }
  }
  
  @override
  void onRemove() {
    _positionSub?.cancel();
    super.onRemove();
  }
}

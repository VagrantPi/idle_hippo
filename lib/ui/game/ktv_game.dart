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

import 'package:idle_hippo/game/ktv_game_logic.dart';
import 'package:idle_hippo/game/ktv_scoring.dart';
import 'package:idle_hippo/game/ktv_geometry_judge.dart';
import 'package:idle_hippo/ui/game/judge_band_component.dart';
import 'package:idle_hippo/services/config_service.dart';

class KtvGame extends FlameGame with TapCallbacks {
  final AudioPlayer audioPlayer;
  final KtvDifficulty difficulty;
  final LaneLayout laneLayout;
  final double approachTimeMs;
  final double despawnGraceMs;

  late final KtvGameLogic _gameLogic;
  final KtvScoring scoring = KtvScoring();
  StreamSubscription<JudgementResult>? _judgementSub;
  // 幾何判定版：自行廣播判定事件供 UI 使用
  final StreamController<JudgementResult> _judgementCtrl = StreamController<JudgementResult>.broadcast();
  Stream<JudgementResult> get judgements => _judgementCtrl.stream;

  final Map<String, NoteComponent> _activeNotesById = {};
  final List<JudgeBandComponent> _bands = [];
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
  }) {
    _gameLogic = KtvGameLogic(numLanes: difficulty.keyCount);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _loadBeatmap();

    // 固定解析度視口（遵循專案規範）
    camera.viewport = FixedResolutionViewport(resolution: Vector2(1080, 1920));

    // 舊邏輯保留以利日後比較，但目前改用內部廣播
    _judgementSub = _gameLogic.judgementStream.listen(_onJudgement);

    // 背景軌道與判定線
    add(LaneBackgroundComponent(
      laneLayout: laneLayout,
      judgelineY: laneLayout.judgelineY,
      screenHeight: laneLayout.screenHeight,
    ));

    // 建立各 lane 的幾何判定帶（依新規格）
    _spawnJudgeBands();
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
    _gameLogic.loadBeatmap(_beatmap);
  }

  void _spawnJudgeBands() {
    // 判定帶高度與 LaneBackgroundComponent 的判定線厚度保持一致：noteBaseSize * 2
    final noteBaseSize = ConfigService()
        .getValue('game.ktv.noteBaseSize', defaultValue: 56.0)
        .toDouble();
    final bandHeight = noteBaseSize * 2;

    final judgeY = laneLayout.lanes.first.bottomY; // 以幾何 layout 的判定線為準

    for (final lane in laneLayout.lanes) {
      final left = lane.bottomLeftX;
      final right = lane.bottomRightX;
      final band = JudgeBandComponent(
        laneIndex: lane.index,
        centerY: judgeY,
        heightPx: bandHeight,
        laneLeftX: left,
        laneRightX: right,
      );
      _bands.add(band);
      add(band);
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
      // 以秒為單位計算生成時間，避免型別與精度問題
      final noteTimeSec = note.time.inMilliseconds / 1000.0;
      final spawnTimeSec = noteTimeSec - approachTimeSec;

      if (audioTimeSec + epsilon >= spawnTimeSec) {
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
          _activeNotesById[note.id] = noteComponent;
        }
        _nextNoteIndex++;
      } else {
        break;
      }
    }
  }

  void _onNoteDespawn(NoteComponent note) {
    _activeNotesById.remove(note.note.id);
    note.removeFromParent();
  }

  void _despawnNotes(double audioTimeSec) {
    final notesToRemove = <NoteComponent>[];
    final currentNotes = List<NoteComponent>.from(_activeNotesById.values);

    for (final note in currentNotes) {
      if (note.shouldDespawn(audioTimeSec, despawnGraceMs)) {
        notesToRemove.add(note);
      }
    }

    for (final note in notesToRemove) {
      // 判定為 Miss 的音符已經被 _onJudgement 處理掉了
      // 這裡只處理那些滑過螢幕但未被判定的情況 (如果有的話)
      if (_activeNotesById.containsKey(note.note.id)) {
        _onNoteDespawn(note);
      }
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

    // 判定邏輯更新 (使用更精確的音訊時間)
    // 幾何版自動 MISS：超過譜面時間 + 緩衝即 MISS
    _autoMissByTime(audioPlayer.position.inMilliseconds);

    // Update positions smoothly every frame
    // 使用快照避免在迭代時被回收導致 ConcurrentModificationError
    final notesSnapshot = List<NoteComponent>.from(_activeNotesById.values);
    for (final note in notesSnapshot) {
      note.updatePosition(visualTimeSec);
    }
  }

  void _autoMissByTime(int currentMs) {
    final list = List<NoteComponent>.from(_activeNotesById.values);
    for (final n in list) {
      final delta = currentMs - n.note.time.inMilliseconds;
      if (delta > despawnGraceMs) {
        // 逾時 MISS
        scoring.onJudge(Judgement.miss);
        _judgementCtrl.add(JudgementResult(
          note: n.note,
          judgement: Judgement.miss,
          deltaMs: delta.toInt(),
        ));
        _onNoteDespawn(n);
      }
    }
  }

  void _onJudgement(JudgementResult result) {
    print(
      '[${result.note.position}] Δ=${result.deltaMs}ms ${result.judgement.toString().split('.').last.toUpperCase()}',
    );

    // 更新分數與連擊統計（UI 可從 scoring 讀取）
    scoring.onJudge(result.judgement);

    final noteComponent = _activeNotesById[result.note.id];
    if (noteComponent != null) {
      // TODO: 根據判定結果播放動畫或效果
      _onNoteDespawn(noteComponent);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final laneIndex = laneLayout.laneIndexOf(event.localPosition.x);
    if (laneIndex == null) return;

    // 取該 lane 的前排音符候選（最接近判定帶中心 y）
    final judgeBand = _bands[laneIndex];
    final candidates = _activeNotesById.values
        .where((n) => n.laneIndex == laneIndex)
        .toList();
    if (candidates.isEmpty) return; // 防幽靈點

    candidates.sort((a, b) {
      final da = (a.position.y - judgeBand.centerY).abs();
      final db = (b.position.y - judgeBand.centerY).abs();
      if (da == db) {
        return a.note.time.compareTo(b.note.time);
      }
      return da.compareTo(db);
    });
    final note = candidates.first;

    // 若音符仍在判定帶上方超過預留距離，忽略此次點擊（避免早期誤擊被判 MISS）
    final preIgnoreHeight = ConfigService()
        .getValue('game.ktv.preJudgeIgnoreHeightPx', defaultValue: 50.0)
        .toDouble();
    final bandTop = judgeBand.centerY - judgeBand.heightPx / 2;
    final noteBottom = note.position.y + note.size.y / 2;
    if (noteBottom <= bandTop - preIgnoreHeight) {
      return; // 忽略早期點擊，不產生判定
    }

    // 幾何判定（以 y 為主）
    final judgement = KtvGeometryJudge.judge(
      bandCenterY: judgeBand.centerY,
      bandHeight: judgeBand.heightPx,
      noteCenterY: note.position.y,
      noteHeight: note.size.y,
      eps: ConfigService()
          .getValue('game.ktv.containmentEpsilonPx', defaultValue: 1.0)
          .toDouble(),
    );

    // 記分與移除
    scoring.onJudge(judgement);
    _judgementCtrl.add(JudgementResult(
      note: note.note,
      judgement: judgement,
      deltaMs: 0,
    ));
    _onNoteDespawn(note);
  }

  @override
  void onRemove() {
    _positionSub?.cancel();
    _judgementSub?.cancel();
    _gameLogic.dispose();
    super.onRemove();
  }
}

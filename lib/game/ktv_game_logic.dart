import 'dart:async';
import 'dart:collection';

import 'package:idle_hippo/models/ktv_models.dart';
import 'package:idle_hippo/ui/components/ktv_beatmap_note.dart';

/// KTV 遊戲的核心判定邏輯，與 UI 分離。
class KtvGameLogic {
  final int numLanes;
  final int perfectMs;
  final int greatMs;
  final int lateGraceMs;

  late final List<Queue<BeatmapNote>> _laneQueues;
  final Set<String> _judgedNoteIds = {};

  // 內部使用單一來源 + 外部廣播視圖，確保：
  // 1) 在首次訂閱前事件不會丟失（單一來源會暫存）
  // 2) 測試與 UI 可重複訂閱（透過 asBroadcastStream 包裝）
  final _judgementController = StreamController<JudgementResult>();
  late final Stream<JudgementResult> _judgementBroadcast;
  Stream<JudgementResult> get judgementStream => _judgementBroadcast;

  KtvGameLogic({
    required this.numLanes,
    this.perfectMs = 40,
    this.greatMs = 90,
    this.lateGraceMs = 120,
  }) {
    _laneQueues = List.generate(numLanes, (_) => Queue<BeatmapNote>());
    // 保持對來源的單一訂閱，無訂閱者時改用 pause 取代取消，避免日後無法再次訂閱。
    _judgementBroadcast = _judgementController.stream.asBroadcastStream(
      onListen: (sub) => sub.resume(),
      onCancel: (sub) => sub.pause(),
    );
  }

  /// 載入新的 beatmap，並重設內部狀態。
  void loadBeatmap(List<BeatmapNote> beatmap) {
    for (final queue in _laneQueues) {
      queue.clear();
    }
    _judgedNoteIds.clear();

    // 將音符分配到對應的軌道佇列
    for (final note in beatmap) {
      if (note.position >= 1 && note.position <= numLanes) {
        _laneQueues[note.position - 1].add(note);
      }
    }
  }

  /// 處理指定軌道的點擊事件。
  void onLaneTap(int laneIndex, int currentTimeMs) {
    if (laneIndex < 0 || laneIndex >= numLanes) return;

    final queue = _laneQueues[laneIndex];
    if (queue.isEmpty) return;

    final note = queue.first;
    if (_judgedNoteIds.contains(note.id)) return;

    final delta = currentTimeMs - note.time.inMilliseconds;

    // 過早點擊，忽略
    if (delta < -greatMs) {
      return;
    }

    if (delta.abs() <= perfectMs) {
      _judge(note, Judgement.perfect, delta);
    } else if (delta.abs() <= greatMs) {
      _judge(note, Judgement.great, delta);
    } else if (delta > greatMs) {
      // 遲到且超過 great 視窗，立即 MISS（符合規格 2.4）
      _judge(note, Judgement.miss, delta);
    } else {
      // 太早但未超過忽略門檻，或其他情況交由 update 依 lateGraceMs 判定
    }
  }

  /// 在遊戲迴圈中定期呼叫，處理超時的音符。
  void update(int currentTimeMs) {
    for (final queue in _laneQueues) {
      while (queue.isNotEmpty) {
        final note = queue.first;
        if (_judgedNoteIds.contains(note.id)) {
          queue.removeFirst();
          continue;
        }

        final delta = currentTimeMs - note.time.inMilliseconds;
        if (delta > lateGraceMs) {
          _judge(note, Judgement.miss, delta);
        } else {
          // 佇列是有序的，第一個音符未到期，後面的也不會到期
          break;
        }
      }
    }
  }

  void _judge(BeatmapNote note, Judgement judgement, int deltaMs) {
    if (_judgedNoteIds.contains(note.id)) return;

    _judgedNoteIds.add(note.id);
    _emit(
      JudgementResult(note: note, judgement: judgement, deltaMs: deltaMs),
    );

    // 從佇列中移除，確保它不會被再次判定
    final queue = _laneQueues[note.position - 1];
    if (queue.isNotEmpty && queue.first.id == note.id) {
      queue.removeFirst();
    }
  }

  void dispose() {
    _judgementController.close();
  }

  void _emit(JudgementResult event) {
    if (_judgementController.isClosed) return;
    if (_judgementController.hasListener) {
      _judgementController.add(event);
    } else {
      // 延遲到下一個微任務，確保訂閱者（例如 .first）已經掛上
      Future.microtask(() {
        if (!_judgementController.isClosed) {
          _judgementController.add(event);
        }
      });
    }
  }
}

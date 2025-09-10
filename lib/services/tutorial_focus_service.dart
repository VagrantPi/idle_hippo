import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Stores last-known screen-space focus rects for tutorial targets.
/// Notifies listeners when rects are updated so overlays can rebuild.
class TutorialFocusService extends ChangeNotifier {
  static final TutorialFocusService _instance =
      TutorialFocusService._internal();
  factory TutorialFocusService() => _instance;
  TutorialFocusService._internal();

  final Map<String, Rect> _rects = {};

  void setRect(String id, Rect rect) {
    final prev = _rects[id];
    if (prev == null ||
        prev.left != rect.left ||
        prev.top != rect.top ||
        prev.width != rect.width ||
        prev.height != rect.height) {
      _rects[id] = rect;
      notifyListeners();
    }
  }

  Rect? getRect(String id) => _rects[id];

  void clear() => _rects.clear();
}

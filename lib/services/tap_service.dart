import 'package:idle_hippo/services/config_service.dart';

typedef NowProvider = DateTime Function();

class TapService {
  final ConfigService _config = ConfigService();
  final NowProvider _now;

  // Optional overrides for testing
  final int? _basePointsOverride; // e.g., game.tap.base
  final double? _cooldownSecondsOverride; // e.g., game.tap.base_gain

  // Stats
  int totalTapEvents = 0; // all tap attempts
  int acceptedTapEvents = 0; // taps that passed cooldown
  DateTime? _lastAcceptedTapAt;

  TapService({
    NowProvider? now,
    int? basePoints,
    double? cooldownSeconds,
  })  : _now = now ?? DateTime.now,
        _basePointsOverride = basePoints,
        _cooldownSecondsOverride = cooldownSeconds;

  int get basePoints {
    if (_basePointsOverride != null) return _basePointsOverride;
    final v = _config.getValue('game.tap.base', defaultValue: 1);
    if (v is num) return v.toInt();
    return 1;
  }

  double get cooldownSeconds {
    if (_cooldownSecondsOverride != null) return _cooldownSecondsOverride;
    final v = _config.getValue('game.tap.base_gain', defaultValue: 0.5);
    if (v is num) return v.toDouble();
    return 0.5;
  }

  Map<String, dynamic> getStats() {
    return {
      'basePoints': basePoints,
      'cooldownSeconds': cooldownSeconds,
      'totalTapEvents': totalTapEvents,
      'acceptedTapEvents': acceptedTapEvents,
      'lastAcceptedTapAt': _lastAcceptedTapAt?.millisecondsSinceEpoch,
    };
  }

  /// Try to apply a tap. Returns the points gained for this tap (0 if ignored).
  int tryTap() {
    totalTapEvents += 1;

    final now = _now();
    if (_lastAcceptedTapAt == null) {
      _accept(now);
      return basePoints;
    }

    final elapsed = now.difference(_lastAcceptedTapAt!).inMilliseconds / 1000.0;
    if (elapsed + 1e-9 >= cooldownSeconds) {
      _accept(now);
      return basePoints;
    }

    // In cooldown, ignored
    return 0;
  }

  void _accept(DateTime now) {
    _lastAcceptedTapAt = now;
    acceptedTapEvents += 1;
  }

  /// Reset stats and cooldown (for debug/testing)
  void reset() {
    totalTapEvents = 0;
    acceptedTapEvents = 0;
    _lastAcceptedTapAt = null;
  }
}

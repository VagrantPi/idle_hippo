import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/config_service.dart';

typedef NowProvider = DateTime Function();

class DailyTapService {
  final ConfigService _config = ConfigService();
  final NowProvider _now;

  DailyTapService({NowProvider? now}) : _now = now ?? DateTime.now;

  // tz=Asia/Taipei (UTC+8)
  String _todayAsiaTaipei() {
    final utcNow = _now().toUtc();
    final taipei = utcNow.add(const Duration(hours: 8));
    return '${taipei.year.toString().padLeft(4, '0')}-${taipei.month.toString().padLeft(2, '0')}-${taipei.day.toString().padLeft(2, '0')}';
  }

  int get dailyCapBase {
    final v = _config.getValue('game.tap.daily_cap_base', defaultValue: 200);
    if (v is num) return v.toInt();
    // 兼容舊鍵
    final legacy = _config.getValue('game.dailyTapCap', defaultValue: 200);
    if (legacy is num) return legacy.toInt();
    return 200;
  }

  int get adMultiplier {
    final v = _config.getValue('game.tap.daily_cap_ad_multiplier', defaultValue: 2);
    if (v is num) return v.toInt();
    return 2;
  }

  GameState ensureDailyBlock(GameState state) {
    final today = _todayAsiaTaipei();
    final block = state.dailyTap ?? DailyTapState(date: today, todayGained: 0, adDoubledToday: false);
    // 修正異常值
    final gained = block.todayGained < 0 ? 0 : block.todayGained;

    if (block.date != today) {
      return state.copyWith(
        dailyTap: DailyTapState(date: today, todayGained: 0, adDoubledToday: false),
      );
    }
    return state.copyWith(dailyTap: block.copyWith(todayGained: gained));
  }

  int effectiveCap(GameState state) {
    final block = state.dailyTap;
    final doubled = block?.adDoubledToday == true;
    final base = dailyCapBase;
    return doubled ? base * adMultiplier : base;
  }

  // Returns (updatedState, allowedGain)
  ({GameState state, double allowedGain}) applyTap(GameState state, double requestedGain) {
    final s0 = ensureDailyBlock(state);
    final block = s0.dailyTap!;
    final cap = effectiveCap(s0);
    if (block.todayGained >= cap) {
      return (state: s0, allowedGain: 0);
    }
    final remaining = cap - block.todayGained;
    final allow = requestedGain.clamp(0.0, remaining.toDouble());
    final s1 = s0.copyWith(
      dailyTap: block.copyWith(todayGained: block.todayGained + allow.floor()),
    );
    return (state: s1, allowedGain: allow);
  }

  GameState setAdDoubled(GameState state, {required bool enabled}) {
    final s0 = ensureDailyBlock(state);
    final b0 = s0.dailyTap!;
    if (b0.adDoubledToday == enabled) return s0;
    return s0.copyWith(dailyTap: b0.copyWith(adDoubledToday: enabled));
  }

  Map<String, dynamic> getStats(GameState state) {
    final s = ensureDailyBlock(state);
    final b = s.dailyTap!;
    return {
      'date': b.date,
      'todayGained': b.todayGained,
      'adDoubledToday': b.adDoubledToday,
      'capBase': dailyCapBase,
      'adMultiplier': adMultiplier,
      'effectiveCap': effectiveCap(s),
    };
  }
}

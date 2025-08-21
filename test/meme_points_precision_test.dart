import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/daily_tap_service.dart';
import 'package:idle_hippo/services/decimal_utils.dart';

void main() {
  group('MemePoints decimal precision', () {
    test('tap_gain=0.2 twice accumulates to 0.1 exactly to 0.3 decimals', () {
      final svc = DailyTapService();
      var state = GameState.initial(1);

      // first tap
      final r1 = svc.applyTap(state, 0.2);
      state = r1.state.copyWith(
        memePoints: DecimalUtils.add(state.memePoints, r1.allowedGain),
      );

      // second tap
      final r2 = svc.applyTap(state, 0.1);
      state = r2.state.copyWith(
        memePoints: DecimalUtils.add(state.memePoints, r2.allowedGain),
      );

      expect(state.memePoints, 0.3);
    });
  });
}

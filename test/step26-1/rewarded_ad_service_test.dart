import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/rewarded_ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RewardedAdService.showAd 觀看完成會觸發 onAdWatched', (tester) async {
    int called = 0;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox()),
      ),
    );

    await RewardedAdService().showAd(
      context: tester.element(find.byType(SizedBox)),
      onAdWatched: () async {
        called++;
      },
      dialogTitle: 'Ad',
      rewardContent: const Text('ok'),
      showSuccessDialog: false, // avoid rendering dialog in test
      simulateDuration: Duration.zero,
    );

    expect(called, 1);
  });
}

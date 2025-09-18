import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/purchase_limit_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PurchaseLimitPolicy 限購規則', () {
    late SharedPreferences prefs;
    late PurchaseLimitPolicy policy;

    final storeConfig = <String, dynamic>{
      'limited_item': {
        'purchase_limit_type': 'limited',
        'purchase_max_count': 1,
      },
      'daily_item': {
        'purchase_limit_type': 'daily',
        'purchase_max_count': 3,
      },
      'monthly_item': {
        'purchase_limit_type': 'monthly',
      },
      'first7_item': {
        'purchase_limit_type': 'first7',
      },
    };

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      policy = PurchaseLimitPolicy.forTest(
        storeConfig: storeConfig,
        preferences: prefs,
      );
    });

    test('limited：第一次可購買，第二次不可', () {
      final now = DateTime.utc(2025, 9, 14, 10, 0, 0);

      expect(policy.canPurchase('limited_item', now), isTrue);
      expect(policy.remainingQuota('limited_item', now), equals(1));

      policy.recordPurchase('limited_item', now);

      expect(policy.canPurchase('limited_item', now), isFalse);
      expect(policy.remainingQuota('limited_item', now), equals(0));
    });

    test('daily：遵守 purchase_max_count，隔日會重置', () {
      final today = DateTime.utc(2025, 9, 14, 2, 0, 0);
      final tomorrow = DateTime.utc(2025, 9, 15, 2, 0, 0);

      expect(policy.canPurchase('daily_item', today), isTrue);
      expect(policy.remainingQuota('daily_item', today), equals(3));

      policy.recordPurchase('daily_item', today);
      expect(policy.canPurchase('daily_item', today), isTrue);
      expect(policy.remainingQuota('daily_item', today), equals(2));

      policy.recordPurchase('daily_item', today);
      expect(policy.canPurchase('daily_item', today), isTrue);
      expect(policy.remainingQuota('daily_item', today), equals(1));

      policy.recordPurchase('daily_item', today);
      expect(policy.canPurchase('daily_item', today), isFalse);
      expect(policy.remainingQuota('daily_item', today), equals(0));

      expect(policy.canPurchase('daily_item', tomorrow), isTrue);
      expect(policy.remainingQuota('daily_item', tomorrow), equals(3));
    });

    test('monthly：同月限購一次，跨月可重置', () {
      final september = DateTime.utc(2025, 9, 14, 8, 0, 0);
      final october = DateTime.utc(2025, 10, 1, 8, 0, 0);

      expect(policy.canPurchase('monthly_item', september), isTrue);
      policy.recordPurchase('monthly_item', september);

      expect(policy.canPurchase('monthly_item', september), isFalse);
      expect(policy.remainingQuota('monthly_item', september), equals(0));

      expect(policy.canPurchase('monthly_item', october), isTrue);
      expect(policy.remainingQuota('monthly_item', october), equals(1));
    });

    test('first7：超過第 7 天無法購買', () async {
      await prefs.setString(
        PurchaseLimitPolicy.firstLaunchKey,
        '2025-08-01',
      );

      final eighthDay = DateTime.utc(2025, 8, 8, 0, 0, 0);

      expect(policy.canPurchase('first7_item', eighthDay), isFalse);
      expect(policy.remainingQuota('first7_item', eighthDay), equals(0));
    });
  });
}

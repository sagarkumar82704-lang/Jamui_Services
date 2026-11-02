import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/subscription/data/models/subscription_plan_model.dart';

void main() {
  group('Provider Subscription & Payment Security Unit Tests', () {
    test('TEST A: SubscriptionPlan Model deserialization and properties matching', () {
      final map = {
        'name': 'Standard Pro',
        'price': 399.0,
        'durationDays': 30,
        'features': ['Unlimited Leads', 'High Search Rank', 'Verified Badge'],
        'isPopular': true,
      };

      final plan = SubscriptionPlanModel.fromMap(map, 'plan_popular');

      expect(plan.id, equals('plan_popular'));
      expect(plan.name, equals('Standard Pro'));
      expect(plan.price, equals(399.0));
      expect(plan.durationDays, equals(30));
      expect(plan.features.length, equals(3));
      expect(plan.isPopular, isTrue);
    });

    test('TEST B: SubscriptionPlan serialization to Map for caching', () {
      const plan = SubscriptionPlanModel(
        id: 'plan_monthly',
        name: 'Monthly Pro',
        price: 300.0,
        durationDays: 30,
        features: ['Lead Access'],
        isPopular: true,
      );

      final map = plan.toMap();
      expect(map['name'], equals('Monthly Pro'));
      expect(map['price'], equals(300.0));
      expect(map['durationDays'], equals(30));
      expect(map['isPopular'], isTrue);
    });

    test('TEST C: Malformed/Missing price & duration in plan document is flagged as invalid (No fake fallbacks)', () {
      final corruptMap = <String, dynamic>{
        'features': ['Direct Leads'],
      };

      final plan = SubscriptionPlanModel.fromMap(corruptMap, 'corrupt_plan');
      expect(plan.price, equals(0.0));
      expect(plan.durationDays, equals(0));
      expect(plan.isValid, isFalse, reason: 'Must not guess fake prices (299) or durations (30)');
    });

    test('TEST D: Live Firebase Basic plan (₹20, 30 days) deserializes with isValid=true', () {
      final liveFirebaseBasicMap = <String, dynamic>{
        'name': 'Basic',
        'price': 20,
        'durationDays': 30,
        'categoryLimit': 1,
        'targetAudience': 'new_provider',
        'isActive': true,
        'isPaymentMandatory': true,
        'features': ['100% Basic lead', 'call Sport'],
      };

      final plan = SubscriptionPlanModel.fromMap(liveFirebaseBasicMap, 'jP3p8pl3upBi7b8GShhw');
      expect(plan.id, equals('jP3p8pl3upBi7b8GShhw'));
      expect(plan.name, equals('Basic'));
      expect(plan.price, equals(20.0));
      expect(plan.durationDays, equals(30));
      expect(plan.categoryLimit, equals(1));
      expect(plan.isValid, isTrue);
    });
  });
}

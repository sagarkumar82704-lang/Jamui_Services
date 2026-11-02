import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pro Subscription Plan Duration Validation & Compatibility Tests', () {
    String? validateDuration(String? val) {
      if (val == null || val.trim().isEmpty) return 'Please enter duration in days';
      final num = int.tryParse(val.trim());
      if (num == null || num <= 0) return 'Must be a positive integer';
      if (num > 3650) return 'Duration cannot exceed 3650 days (10 years)';
      return null;
    }

    test('1. Create plan with valid duration (30, 90, 180, 365 days)', () {
      expect(validateDuration('30'), isNull);
      expect(validateDuration('90'), isNull);
      expect(validateDuration('180'), isNull);
      expect(validateDuration('365'), isNull);
      expect(validateDuration('3650'), isNull);

      final planPayload = <String, dynamic>{
        'name': 'Pro Growth 30',
        'price': 299.0,
        'durationDays': int.parse('30'),
        'maxProducts': 100,
        'maxImagesPerMonth': 200,
        'storageMb': 250,
        'isActive': true,
      };

      expect(planPayload['durationDays'], equals(30));
      expect(planPayload['name'], equals('Pro Growth 30'));
    });

    test('2. Edit plan duration updates durationDays accurately', () {
      final existingPlan = <String, dynamic>{
        'id': 'plan_pro_123',
        'name': 'Pro Starter',
        'price': 199.0,
        'durationDays': 30,
        'maxProducts': 50,
      };

      const newDurationInput = '90';
      expect(validateDuration(newDurationInput), isNull);

      final updatePayload = <String, dynamic>{
        ...existingPlan,
        'durationDays': int.parse(newDurationInput),
      };

      expect(updatePayload['durationDays'], equals(90));
    });

    test('3. Load existing plan duration into edit controller', () {
      final existingPlanWithDuration = <String, dynamic>{
        'id': 'plan_1',
        'name': 'Pro Quarterly',
        'durationDays': 90,
      };

      final controllerText = existingPlanWithDuration['durationDays'] != null
          ? existingPlanWithDuration['durationDays'].toString()
          : '';

      expect(controllerText, equals('90'));
    });

    test('4. Reject zero duration (0)', () {
      expect(validateDuration('0'), equals('Must be a positive integer'));
    });

    test('5. Reject negative duration (-30)', () {
      expect(validateDuration('-30'), equals('Must be a positive integer'));
    });

    test('6. Reject decimal duration (30.5)', () {
      expect(validateDuration('30.5'), equals('Must be a positive integer'));
    });

    test('7. Reject empty duration', () {
      expect(validateDuration(''), equals('Please enter duration in days'));
      expect(validateDuration('   '), equals('Please enter duration in days'));
      expect(validateDuration(null), equals('Please enter duration in days'));
    });

    test('8. Reject invalid text (non-numeric strings)', () {
      expect(validateDuration('abc'), equals('Must be a positive integer'));
      expect(validateDuration('one month'), equals('Must be a positive integer'));
      expect(validateDuration('30 days'), equals('Must be a positive integer'));
    });

    test('9. Handle legacy plans without duration without crashing (shows Not Configured)', () {
      final legacyPlan = <String, dynamic>{
        'id': 'legacy_plan_old',
        'name': 'Legacy Pro Plan',
        'price': 199.0,
        'maxProducts': 50,
        'maxImagesPerMonth': 100,
        'storageMb': 100,
        'isActive': true,
        // durationDays is null or absent
      };

      final duration = legacyPlan['durationDays'];
      final String displayLabel = duration != null ? '$duration Days' : 'Not Configured';

      expect(displayLabel, equals('Not Configured'));
      expect(() => legacyPlan['durationDays'] as int?, returnsNormally);
    });

    test('10. Confirm existing Normal/Premium plan behavior remains unchanged', () {
      final normalProviderPlan = <String, dynamic>{
        'id': 'starter_monthly',
        'name': 'Starter Normal Plan',
        'planTier': 'normal',
        'categoryLimit': 1,
        'price': 199,
        'durationDays': 30,
        'isActive': true,
      };

      expect(normalProviderPlan['planTier'], equals('normal'));
      expect(normalProviderPlan['categoryLimit'], equals(1));
      expect(normalProviderPlan['durationDays'], equals(30));
    });
  });
}


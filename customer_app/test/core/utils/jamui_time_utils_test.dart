import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/utils/jamui_time_utils.dart';

void main() {
  group('JamuiTimeUtils - parseTimeToMinutes', () {
    test('Parses 12-hour AM/PM formats correctly', () {
      expect(JamuiTimeUtils.parseTimeToMinutes('08:00 AM'), equals(480));
      expect(JamuiTimeUtils.parseTimeToMinutes('8:00 am'), equals(480));
      expect(JamuiTimeUtils.parseTimeToMinutes('12:00 PM'), equals(720));
      expect(JamuiTimeUtils.parseTimeToMinutes('12:00 AM'), equals(0));
      expect(JamuiTimeUtils.parseTimeToMinutes('09:30 PM'), equals(1290));
      expect(JamuiTimeUtils.parseTimeToMinutes('9:30pm'), equals(1290));
    });

    test('Parses 24-hour formats correctly', () {
      expect(JamuiTimeUtils.parseTimeToMinutes('18:00'), equals(1080));
      expect(JamuiTimeUtils.parseTimeToMinutes('02:00'), equals(120));
      expect(JamuiTimeUtils.parseTimeToMinutes('00:00'), equals(0));
      expect(JamuiTimeUtils.parseTimeToMinutes('23:59'), equals(1439));
    });

    test('Returns null for invalid, corrupt, or empty strings', () {
      expect(JamuiTimeUtils.parseTimeToMinutes(null), isNull);
      expect(JamuiTimeUtils.parseTimeToMinutes(''), isNull);
      expect(JamuiTimeUtils.parseTimeToMinutes('invalid_time'), isNull);
      expect(JamuiTimeUtils.parseTimeToMinutes('25:00'), isNull);
      expect(JamuiTimeUtils.parseTimeToMinutes('12:65'), isNull);
    });
  });

  group('JamuiTimeUtils - isOpenNow evaluation', () {
    test('Returns false immediately when isMasterOpen is false', () {
      final isOpen = JamuiTimeUtils.isOpenNow(
        isMasterOpen: false,
        legacyOpeningTime: '08:00 AM',
        legacyClosingTime: '09:00 PM',
        currentTimeIST: DateTime(2026, 11, 1, 12, 0), // 12:00 PM
      );
      expect(isOpen, isFalse);
    });

    test('Evaluates normal day shift correctly (08:00 AM to 09:00 PM)', () {
      // 10:00 AM -> Open
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: '08:00 AM',
          legacyClosingTime: '09:00 PM',
          currentTimeIST: DateTime(2026, 11, 1, 10, 0),
        ),
        isTrue,
      );

      // 07:00 AM -> Closed
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: '08:00 AM',
          legacyClosingTime: '09:00 PM',
          currentTimeIST: DateTime(2026, 11, 1, 7, 0),
        ),
        isFalse,
      );

      // 10:00 PM -> Closed
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: '08:00 AM',
          legacyClosingTime: '09:00 PM',
          currentTimeIST: DateTime(2026, 11, 1, 22, 0),
        ),
        isFalse,
      );
    });

    test('Evaluates midnight crossover shift correctly (18:00 to 02:00)', () {
      // 20:00 (Evening) -> Open
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: '18:00',
          legacyClosingTime: '02:00',
          currentTimeIST: DateTime(2026, 11, 1, 20, 0),
        ),
        isTrue,
      );

      // 01:00 (Post-midnight) -> Open
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: '18:00',
          legacyClosingTime: '02:00',
          currentTimeIST: DateTime(2026, 11, 1, 1, 0),
        ),
        isTrue,
      );

      // 03:00 (Late night closed) -> Closed
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: '18:00',
          legacyClosingTime: '02:00',
          currentTimeIST: DateTime(2026, 11, 1, 3, 0),
        ),
        isFalse,
      );

      // 12:00 PM (Noon closed) -> Closed
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: '18:00',
          legacyClosingTime: '02:00',
          currentTimeIST: DateTime(2026, 11, 1, 12, 0),
        ),
        isFalse,
      );
    });

    test('Evaluates 7-day weekly schedule with day off', () {
      // 2026-11-01 is a Sunday
      final sundaySchedule = {
        'sunday': {
          'isOpen': false,
          'openTime': '09:00 AM',
          'closeTime': '08:00 PM',
        },
        'monday': {
          'isOpen': true,
          'openTime': '09:00 AM',
          'closeTime': '08:00 PM',
        },
      };

      // Sunday -> Closed due to day off
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          weeklySchedule: sundaySchedule,
          currentTimeIST: DateTime(2026, 11, 1, 12, 0), // Sunday
        ),
        isFalse,
      );

      // Monday (2026-11-02) -> Open
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          weeklySchedule: sundaySchedule,
          currentTimeIST: DateTime(2026, 11, 2, 12, 0), // Monday
        ),
        isTrue,
      );
    });

    test('Fails closed on missing or corrupt schedule hours', () {
      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: null,
          legacyClosingTime: null,
          currentTimeIST: DateTime(2026, 11, 1, 12, 0),
        ),
        isFalse,
      );

      expect(
        JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          legacyOpeningTime: 'bad_time',
          legacyClosingTime: 'corrupt',
          currentTimeIST: DateTime(2026, 11, 1, 12, 0),
        ),
        isFalse,
      );
    });
  });
}


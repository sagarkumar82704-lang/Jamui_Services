import 'package:intl/intl.dart';

/// Production Real-Time Schedule & Timezone Engine for Jamui Services.
///
/// Enforces:
/// 1. Strict `Asia/Kolkata` (IST = UTC+5:30) evaluation regardless of device locale.
/// 2. 7-Day weekly schedule with day-off detection.
/// 3. Midnight crossover shift evaluation (e.g., 18:00 to 02:00).
/// 4. Fail-closed behavior for missing, null, or corrupted operational hours.
class JamuiTimeUtils {
  const JamuiTimeUtils._();

  static const List<String> dayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// Returns current time in Asia/Kolkata (IST = UTC + 5 hours 30 minutes).
  static DateTime getNowInKolkata([DateTime? customUtc]) {
    final utc = (customUtc ?? DateTime.now()).toUtc();
    return utc.add(const Duration(hours: 5, minutes: 30));
  }

  /// Parses a 12-hour or 24-hour time string into minutes since midnight [0..1439].
  ///
  /// Examples:
  /// - "08:00 AM" -> 480
  /// - "8:00 AM"  -> 480
  /// - "09:30 PM" -> 1290
  /// - "18:00"    -> 1080
  /// - "02:00"    -> 120
  ///
  /// Returns `null` if the string cannot be parsed.
  static int? parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final clean = timeStr.trim().toUpperCase();

    // Try 12-hour AM/PM formats first
    if (clean.contains('AM') || clean.contains('PM')) {
      final formats = [
        DateFormat('hh:mm a'),
        DateFormat('h:mm a'),
        DateFormat('hh:mma'),
        DateFormat('h:mma'),
      ];
      for (final format in formats) {
        try {
          final dt = format.parseLoose(clean);
          return dt.hour * 60 + dt.minute;
        } catch (_) {}
      }
    }

    // Try 24-hour formats
    final formats24 = [
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
    ];
    for (final format in formats24) {
      try {
        final dt = format.parseLoose(clean);
        return dt.hour * 60 + dt.minute;
      } catch (_) {}
    }

    // Manual fallback for "HH:MM"
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0].trim());
      final minutePart = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
      final minute = int.tryParse(minutePart);
      if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return hour * 60 + minute;
      }
    }

    return null;
  }

  /// Evaluates whether a shop is currently open based on master toggle,
  /// 7-day schedule, and operational hours in Asia/Kolkata timezone.
  static bool isOpenNow({
    required bool isMasterOpen,
    Map<String, dynamic>? weeklySchedule,
    String? legacyOpeningTime,
    String? legacyClosingTime,
    DateTime? currentTimeIST,
  }) {
    // 1. Master manual toggle check
    if (!isMasterOpen) return false;

    // 2. Compute current IST time
    final nowIst = currentTimeIST ?? getNowInKolkata();
    final dayIndex = (nowIst.weekday - 1).clamp(0, 6);
    final todayName = dayNames[dayIndex];

    String? openTimeStr;
    String? closeTimeStr;

    // 3. Inspect weekly schedule
    if (weeklySchedule != null && weeklySchedule.isNotEmpty) {
      // Find today's entry (case-insensitive)
      dynamic dayEntry;
      for (final entry in weeklySchedule.entries) {
        if (entry.key.toLowerCase().trim() == todayName) {
          dayEntry = entry.value;
          break;
        }
      }

      if (dayEntry is Map) {
        // Weekly day off check
        final isOpenToday = dayEntry['isOpen'] as bool? ??
            !(dayEntry['isClosed'] as bool? ?? false);
        if (!isOpenToday) {
          return false; // Day off
        }

        openTimeStr = dayEntry['openTime']?.toString() ??
            dayEntry['openingTime']?.toString();
        closeTimeStr = dayEntry['closeTime']?.toString() ??
            dayEntry['closingTime']?.toString();
      }
    }

    // 4. Fallback to top-level legacy times if weekly schedule missing
    openTimeStr ??= legacyOpeningTime;
    closeTimeStr ??= legacyClosingTime;

    // 5. Fail-closed if no verifiable hours
    final openMinutes = parseTimeToMinutes(openTimeStr);
    final closeMinutes = parseTimeToMinutes(closeTimeStr);
    if (openMinutes == null || closeMinutes == null) {
      return false;
    }

    final currentMinutes = nowIst.hour * 60 + nowIst.minute;

    // 6. Midnight crossover handling (e.g. 18:00 [1080] to 02:00 [120])
    if (closeMinutes < openMinutes) {
      return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
    }

    // Normal day shift (e.g. 08:00 [480] to 21:00 [1260])
    return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
  }
}


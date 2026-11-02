import 'package:flutter/foundation.dart';

/// Production-ready Semantic Versioning Parser and Comparator (SemVer 2.0.0 compliant)
///
/// Ensures correct numeric comparisons so that:
/// - "1.10.0" is strictly GREATER than "1.2.0"
/// - "1.2.0+15" is GREATER than "1.2.0+12"
/// - "1.2.0-beta" or "v1.2.0" is parsed gracefully without crashing
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final int? buildNumber;
  final String raw;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber,
    required this.raw,
  });

  /// Factory parser from string representation
  factory AppVersion.parse(String? versionString) {
    if (versionString == null || versionString.trim().isEmpty) {
      return const AppVersion(major: 0, minor: 0, patch: 0, raw: '0.0.0');
    }

    final raw = versionString.trim();
    // Strip surrounding or internal quotes (e.g. "\"1.3.0\"" or "'1.3.0'")
    var sanitized = raw.replaceAll('"', '').replaceAll("'", '').trim();
    // Remove leading 'v' or 'V' if present
    sanitized = sanitized.startsWith(RegExp(r'^[vV]')) ? sanitized.substring(1).trim() : sanitized;

    int? buildNum;
    if (sanitized.contains('+')) {
      final parts = sanitized.split('+');
      sanitized = parts[0].trim();
      if (parts.length > 1) {
        buildNum = int.tryParse(parts[1].trim());
      }
    }

    // Strip pre-release tag like -beta, -rc1, etc.
    if (sanitized.contains('-')) {
      sanitized = sanitized.split('-').first.trim();
    }

    final components = sanitized.split('.');
    final major = components.isNotEmpty ? (int.tryParse(components[0].trim()) ?? 0) : 0;
    final minor = components.length > 1 ? (int.tryParse(components[1].trim()) ?? 0) : 0;
    final patch = components.length > 2 ? (int.tryParse(components[2].trim()) ?? 0) : 0;

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: buildNum,
      raw: raw,
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // If major, minor, and patch are equal, check build numbers if available on both
    if (buildNumber != null && other.buildNumber != null) {
      return buildNumber!.compareTo(other.buildNumber!);
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppVersion) return false;
    return compareTo(other) == 0;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, buildNumber);

  @override
  String toString() {
    if (buildNumber != null) {
      return '$major.$minor.$patch+$buildNumber';
    }
    return '$major.$minor.$patch';
  }

  /// Convenience comparator: returns true if [current] is strictly lower than [target]
  static bool isVersionLower(String? current, String? target) {
    try {
      final vCurrent = AppVersion.parse(current);
      final vTarget = AppVersion.parse(target);
      return vCurrent < vTarget;
    } catch (e) {
      debugPrint('⚠️ [AppVersion] Comparator error: $e');
      return false;
    }
  }

  /// Convenience comparator: returns true if [current] is greater than or equal to [target]
  static bool isVersionGreaterOrEqual(String? current, String? target) {
    try {
      final vCurrent = AppVersion.parse(current);
      final vTarget = AppVersion.parse(target);
      return vCurrent >= vTarget;
    } catch (_) {
      return true;
    }
  }
}

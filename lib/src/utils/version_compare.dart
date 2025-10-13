import '../enums/update_type.dart';

/// Utility for comparing versions and determining update type
class VersionCompare {
  static UpdateType getUpdateType(
      String current, String minRequired, String latest) {
    if (_compareVersions(current, minRequired) < 0) {
      return UpdateType.force;
    } else if (_compareVersions(current, latest) < 0) {
      return UpdateType.optional;
    }
    return UpdateType.none;
  }

  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(BigInt.parse).toList();
    final v2Parts = v2.split('.').map(BigInt.parse).toList();
    final maxLength =
        v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : BigInt.zero;
      final v2Part = i < v2Parts.length ? v2Parts[i] : BigInt.zero;
      if (v1Part > v2Part) return 1;
      if (v1Part < v2Part) return -1;
    }
    return 0;
  }
}

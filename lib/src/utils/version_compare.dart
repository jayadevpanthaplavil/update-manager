
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
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < v1Parts.length; i++) {
      if (i >= v2Parts.length) return 1;
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    return 0;
  }
}

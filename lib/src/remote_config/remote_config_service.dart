import 'dart:convert';
import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:update_manager/src/shorebird/shorebird_service.dart';
import '../enums/update_source.dart';
import '../update_manager.dart';
import '../enums/update_type.dart';
import '../utils/version_compare.dart';
import 'remote_config_variables.dart';

class RemoteConfigService {
  static RemoteConfigService? _instance;

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  late final PackageInfo _packageInfo;
  UpdateManagerCallback? onUpdate;
  ShorebirdService? shorebirdService;
  UpdateTrackType _currentTrack = UpdateTrackType.stable;

  UpdateType _lastUpdateType = UpdateType.none;
  UpdateType get updateTypeStatus => _lastUpdateType;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Private constructor
  RemoteConfigService._();

  // Factory constructor to return singleton instance
  factory RemoteConfigService() {
    _instance ??= RemoteConfigService._();
    return _instance!;
  }

  // Static getter for easy access
  static RemoteConfigService get instance => RemoteConfigService();

  // Initialize method (must be called before use)
  Future<void> initialize({
    required PackageInfo packageInfo,
    UpdateManagerCallback? onUpdate,
    ShorebirdService? shorebirdService,
  }) async {
    if (_isInitialized) {
      debugPrint("RemoteConfigService already initialized");
      return;
    }

    _packageInfo = packageInfo;
    this.onUpdate = onUpdate;
    this.shorebirdService = shorebirdService;
    _isInitialized = true;
  }

  Future<void> initialiseAndCheck(
      {UpdateTrackType track = UpdateTrackType.stable}) async {
    if (!_isInitialized) {
      throw StateError(
          "RemoteConfigService must be initialized before calling initialiseAndCheck");
    }

    _currentTrack = track;

    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero,
      ));

      await _remoteConfig.setDefaults({
        RemoteConfigVariables.minRequiredVersion: _packageInfo.version,
        RemoteConfigVariables.latestVersion: _packageInfo.version,
        RemoteConfigVariables.patchEnabled: false,
        RemoteConfigVariables.patchInfo: '{}',
        RemoteConfigVariables.redirectUrl: jsonEncode({
          "android": {
            "stable": "",
            "beta": "",
            "staging": "",
          },
          "ios": {
            "stable": "",
            "beta": "",
            "staging": "",
          },
        }),
      });

      await _remoteConfig.fetchAndActivate();

      _remoteConfig.onConfigUpdated.listen((_) async {
        await _remoteConfig.fetchAndActivate();
        await handleUpdateCheck();
      });

      await handleUpdateCheck();
    } catch (e) {
      debugPrint("RemoteConfigService init error: $e");
    }
  }

  Future<void> handleUpdateCheck() async {
    final currentVersion = _packageInfo.version;

    // Get track-specific versions
    final minRequired = _getVersionForTrack(
      RemoteConfigVariables.minRequiredVersion,
      _currentTrack,
    );
    final latest = _getVersionForTrack(
      RemoteConfigVariables.latestVersion,
      _currentTrack,
    );

    debugPrint("Track: ${_currentTrack.name}");
    debugPrint(
        "Current: $currentVersion, MinRequired: $minRequired, Latest: $latest");

    final patchEnabled =
        _remoteConfig.getBool(RemoteConfigVariables.patchEnabled);
    final patchesJson =
        _remoteConfig.getString(RemoteConfigVariables.patchInfo);

    final updateType =
        VersionCompare.getUpdateType(currentVersion, minRequired, latest);

    UpdateSource source = UpdateSource.release;
    int? patchNumber;
    int? currentPatchNumber;

    if (patchEnabled && shorebirdService != null && patchesJson.isNotEmpty) {
      patchNumber = _getPatchNumberFromJson(
          patchesJson, currentVersion, _currentTrack.toShorebirdUpdateTrack());
      currentPatchNumber = await shorebirdService?.readCurrentPatch();

      if (patchNumber != null &&
          patchNumber > 0 &&
          patchNumber != currentPatchNumber) {
        source = UpdateSource.patch;
      }
    }

    _lastUpdateType = updateType;

    if (onUpdate != null) {
      await onUpdate!(
        type: updateType,
        source: source,
        patchNumber: patchNumber,
      );
    }
  }

  /// Gets version string for the current track from Remote Config
  /// Supports both simple string format and track-specific JSON format
  String _getVersionForTrack(String configKey, UpdateTrackType track) {
    final configValue = _remoteConfig.getString(configKey);

    if (configValue.isEmpty) {
      return _packageInfo.version;
    }

    // Try to parse as JSON first
    try {
      final dynamic parsed = jsonDecode(configValue);

      // If it's a Map, look for track-specific version
      if (parsed is Map<String, dynamic>) {
        final trackVersion = parsed[track.name];

        if (trackVersion != null && trackVersion is String) {
          return trackVersion;
        }

        // Fallback to 'stable' if current track not found
        final stableVersion = parsed['stable'];
        if (stableVersion != null && stableVersion is String) {
          debugPrint(
              "Track '${track.name}' not found in $configKey, using stable");
          return stableVersion;
        }
      }

      // If parsed but not the expected format, treat as simple string
      return configValue;
    } catch (e) {
      // Not JSON, treat as simple version string
      return configValue;
    }
  }

  int? _getPatchNumberFromJson(
      String? patchesJson, String currentVersion, UpdateTrack track) {
    if (patchesJson == null || patchesJson.isEmpty) return null;

    try {
      final Map<String, dynamic> versionMap = jsonDecode(patchesJson);
      debugPrint("Patch map: $versionMap");

      final versionData = versionMap[currentVersion];
      if (versionData == null) return null;

      if (versionData is Map<String, dynamic>) {
        final trackPatch = versionData[track.name];
        if (trackPatch != null) {
          return trackPatch as int;
        }

        // Fallback to stable if track not found
        debugPrint(
            "Track '${track.name}' not found for version $currentVersion, checking stable");
        return versionData['stable'] as int?;
      }

      // Legacy format: direct integer
      return versionData as int?;
    } catch (e) {
      debugPrint("Patch parse error: $e");
      return null;
    }
  }

  /// Get redirection URL for the current or specified track, platform-specific only
  String getRedirectUrl({UpdateTrackType? track}) {
    final configValue =
        _remoteConfig.getString(RemoteConfigVariables.redirectUrl);

    if (configValue.isEmpty) {
      debugPrint("Redirect URL not found in Remote Config. Using default.");
      return "";
    }

    try {
      final dynamic parsed = jsonDecode(configValue);
      final currentTrack = track ?? _currentTrack;

      if (parsed is! Map<String, dynamic>) {
        return "";
      }

      // Determine platform
      final platformKey = Platform.isAndroid ? 'android' : 'ios';
      final platformUrls = parsed[platformKey];

      if (platformUrls is Map<String, dynamic>) {
        final trackUrl = platformUrls[currentTrack.name];
        if (trackUrl != null && trackUrl is String && trackUrl.isNotEmpty) {
          return trackUrl;
        } else {
          // Platform exists but track URL not found
          debugPrint(
              "Track '${currentTrack.name}' not found for platform '$platformKey'");
          return "";
        }
      }

      // Platform not found
      debugPrint("Platform '$platformKey' not found in redirect_url");
      return "";
    } catch (e) {
      debugPrint("Redirect URL parse error: $e");
      return "";
    }
  }
}

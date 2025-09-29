

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:update_manager/src/remote_config/remote_config_variables.dart';

import '../enums/update_type.dart';
import '../utils/version_compare.dart';

typedef UpdateCallback = Future<void> Function(UpdateType type);

/// Service that handles update checks via Firebase Remote Config
class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final PackageInfo _packageInfo;
  final UpdateCallback? onUpdate;


  UpdateType _lastUpdateType = UpdateType.none;
  UpdateType get updateTypeStatus => _lastUpdateType;

  RemoteConfigService({
    required PackageInfo packageInfo,
    this.onUpdate,
  }) : _packageInfo = packageInfo;

  /// Initialize Remote Config and perform the first update check
  Future<void> initialiseAndCheck() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero,
      ));

      await _remoteConfig.setDefaults({
        RemoteConfigVariables.minRequiredVersion: _packageInfo.version,
        RemoteConfigVariables.latestVersion: _packageInfo.version,
      });

      // Fetch + activate
      await _remoteConfig.fetchAndActivate();

      // Listen for remote config changes
      _remoteConfig.onConfigUpdated.listen((_) async {
        await _remoteConfig.fetchAndActivate();
        await _handleUpdateCheck();
      });

      // Initial check
      await _handleUpdateCheck();
    } catch (e) {
      debugPrint("RemoteConfig error: $e");
    }
  }

  /// Handles update checking logic
  Future<void> _handleUpdateCheck() async {
    final currentVersion = _packageInfo.version;
    final minRequired =
    _remoteConfig.getString(RemoteConfigVariables.minRequiredVersion);
    final latest =
    _remoteConfig.getString(RemoteConfigVariables.latestVersion);

    debugPrint(
        "AppVersionCheck → current: $currentVersion, minRequired: $minRequired, latest: $latest");

    final updateType =
    VersionCompare.getUpdateType(currentVersion, minRequired, latest);

    // Store the status
    _lastUpdateType = updateType;

    if (onUpdate != null) {
      await onUpdate!(updateType);
    }
  }
}

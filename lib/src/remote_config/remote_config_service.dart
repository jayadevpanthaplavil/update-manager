import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:update_manager/src/shorebird/shorebird_service.dart';
import '../enums/update_source.dart';
import '../update_manager.dart';
import '../enums/update_type.dart';
import '../utils/version_compare.dart';
import 'remote_config_variables.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final PackageInfo _packageInfo;
  final UpdateManagerCallback? onUpdate;
  final ShorebirdService? shorebirdService;

  UpdateType _lastUpdateType = UpdateType.none;
  UpdateType get updateTypeStatus => _lastUpdateType;

  RemoteConfigService({
    required PackageInfo packageInfo,
    this.onUpdate,
    this.shorebirdService
  }) : _packageInfo = packageInfo;

  Future<void> initialiseAndCheck() async {
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
      });

      await _remoteConfig.fetchAndActivate();

      _remoteConfig.onConfigUpdated.listen((_) async {
        await _remoteConfig.fetchAndActivate();
        await _handleUpdateCheck();
      });

      await _handleUpdateCheck();
    } catch (e) {
      debugPrint("RemoteConfigService init error: $e");
    }
  }

  Future<void> _handleUpdateCheck() async {
    final currentVersion = _packageInfo.version;
    final minRequired =
    _remoteConfig.getString(RemoteConfigVariables.minRequiredVersion);
    final latest =
    _remoteConfig.getString(RemoteConfigVariables.latestVersion);
    final patchEnabled =
    _remoteConfig.getBool(RemoteConfigVariables.patchEnabled);
    final patchesJson = _remoteConfig.getString(RemoteConfigVariables.patchInfo);

    final updateType =
    VersionCompare.getUpdateType(currentVersion, minRequired, latest);

    UpdateSource source = UpdateSource.release;
    int? patchNumber;
    int? currentPatchNumber;

    if (patchEnabled && patchesJson != null && patchesJson.isNotEmpty) {
      patchNumber = _getPatchNumberFromJson(patchesJson, currentVersion);
      currentPatchNumber = await shorebirdService?.readCurrentPatch();
      if (patchNumber != null && patchNumber > 0 && patchNumber != currentPatchNumber) {
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

  int? _getPatchNumberFromJson(String? patchesJson, String currentVersion) {
    if (patchesJson == null || patchesJson.isEmpty) return null;

    try {
      // Direct decode since Firebase returns JSON correctly
      final Map<String, dynamic> versionMap = jsonDecode(patchesJson);
      debugPrint("Patch map: $versionMap");

      return versionMap[currentVersion] as int?;
    } catch (e) {
      debugPrint("Patch parse error: $e");
      return null;
    }
  }

}

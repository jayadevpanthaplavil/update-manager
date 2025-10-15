import 'dart:convert';
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
  UpdateTrack _currentTrack = UpdateTrack.stable;

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
      {UpdateTrack track = UpdateTrack.stable}) async {
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
    final minRequired =
        _remoteConfig.getString(RemoteConfigVariables.minRequiredVersion);
    final latest = _remoteConfig.getString(RemoteConfigVariables.latestVersion);
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
      patchNumber =
          _getPatchNumberFromJson(patchesJson, currentVersion, _currentTrack);
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

  int? _getPatchNumberFromJson(
      String? patchesJson, String currentVersion, UpdateTrack track) {
    if (patchesJson == null || patchesJson.isEmpty) return null;

    try {
      final Map<String, dynamic> versionMap = jsonDecode(patchesJson);
      debugPrint("Patch map: $versionMap");

      final versionData = versionMap[currentVersion];
      if (versionData == null) return null;

      if (versionData is Map<String, dynamic>) {
        return versionData[track.name] as int?;
      }

      return versionData as int?;
    } catch (e) {
      debugPrint("Patch parse error: $e");
      return null;
    }
  }
}

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'remote_config/remote_config_service.dart';
import 'shorebird/shorebird_service.dart';
import 'enums/update_type.dart';
import 'enums/update_source.dart';

typedef UpdateManagerCallback = Future<void> Function({
required UpdateType type,
required UpdateSource source,
int? patchNumber,
});

class UpdateManager {
  final PackageInfo _packageInfo;
  final bool enableShorebird;
  final UpdateManagerCallback? onUpdate;

  late final RemoteConfigService _remoteConfigService;
  final ShorebirdService? _shorebirdService;

  UpdateType _lastUpdateType = UpdateType.none;
  UpdateType get updateTypeStatus => _lastUpdateType;

  UpdateManager({
    required PackageInfo packageInfo,
    this.enableShorebird = false,
    this.onUpdate,
  })  : _packageInfo = packageInfo,
        _shorebirdService = enableShorebird ? ShorebirdService() : null {
    _remoteConfigService = RemoteConfigService(
      packageInfo: _packageInfo,
      onUpdate: _handleUpdateCallback,
    );
  }

  /// Entry point: initialise Remote Config + Shorebird
  Future<void> initialise({UpdateTrack shorebirdTrack = UpdateTrack.stable}) async {
    // 1. Remote Config updates
    await _remoteConfigService.initialiseAndCheck();

    // 2. Shorebird patch updates
    if (_shorebirdService != null && _shorebirdService!.isAvailable) {
      await checkShorebirdPatch(track: shorebirdTrack);
    }
  }

  /// Check Shorebird patch updates manually
  Future<void> checkShorebirdPatch({UpdateTrack track = UpdateTrack.stable}) async {
    if (_shorebirdService == null || !_shorebirdService!.isAvailable) return;
    await _shorebirdService!.checkForUpdate(
      track: track,
      onUpdate: _handleUpdateCallback,
    );
  }

  /// Central callback handler for both Remote Config & Shorebird
  Future<void> _handleUpdateCallback({
    required UpdateType type,
    UpdateSource source = UpdateSource.release,
    int? patchNumber,
  }) async {
    _lastUpdateType = type;

    if (onUpdate != null) {
      await onUpdate!(
        type: type,
        source: source,
        patchNumber: patchNumber,
      );
    }
  }
}

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'remote_config/remote_config_service.dart';
import 'shorebird/shorebird_service.dart';
import 'enums/update_type.dart';
import 'enums/update_source.dart';
import 'enums/shorebird_update_status.dart';

typedef UpdateManagerCallback = Future<void> Function({
required UpdateType type,
required UpdateSource source,
int? patchNumber,
});

typedef ShorebirdStatusCallback = Future<void> Function({
required ShorebirdUpdateStatus status,
UpdateType? type,
int? patchNumber,
String? errorMessage,
});

class UpdateManager {
  final PackageInfo _packageInfo;
  final bool enableShorebird;
  final UpdateManagerCallback? onUpdate;
  final ShorebirdStatusCallback? onShorebirdStatusChange;

  late final RemoteConfigService _remoteConfigService;
  final ShorebirdService? _shorebirdService;

  UpdateType _lastUpdateType = UpdateType.none;
  UpdateType get updateTypeStatus => _lastUpdateType;

  ShorebirdUpdateStatus _shorebirdStatus = ShorebirdUpdateStatus.idle;
  ShorebirdUpdateStatus get shorebirdStatus => _shorebirdStatus;

  // Expose shorebirdService for direct access if needed
  ShorebirdService? get shorebirdService => _shorebirdService;

  UpdateManager({
    required PackageInfo packageInfo,
    this.enableShorebird = false,
    this.onUpdate,
    this.onShorebirdStatusChange,
  })  : _packageInfo = packageInfo,
        _shorebirdService = enableShorebird ? ShorebirdService() : null {
    _remoteConfigService = RemoteConfigService(
      packageInfo: _packageInfo,
      onUpdate: _handleUpdateCallback,
      shorebirdService: _shorebirdService,
    );
  }

  /// Entry point: initialise Remote Config + Shorebird
  Future<void> initialise(
      {UpdateTrack shorebirdTrack = UpdateTrack.stable}) async {
    // 1. Remote Config updates
    await _remoteConfigService.initialiseAndCheck();

    // 2. Shorebird patch updates (only if no patch detected by Remote Config)
    if (_shorebirdService != null && _shorebirdService!.isAvailable) {
      // Only check Shorebird directly if Remote Config didn't already detect a patch
      if (_lastUpdateType == UpdateType.none) {
        await checkShorebirdPatch(track: shorebirdTrack);
      }
    }
  }

  /// Check Shorebird patch updates manually
  Future<void> checkShorebirdPatch(
      {UpdateTrack track = UpdateTrack.stable}) async {
    if (_shorebirdService == null || !_shorebirdService!.isAvailable) {
      await _handleShorebirdStatusChange(
        status: ShorebirdUpdateStatus.unavailable,
      );
      return;
    }

    await _shorebirdService!.checkForUpdate(
      track: track,
      onStatusChange: _handleShorebirdStatusChange,
    );
  }

  /// Download Shorebird patch
  Future<void> downloadShorebirdPatch(
      {UpdateTrack track = UpdateTrack.stable}) async {
    if (_shorebirdService == null || !_shorebirdService!.isAvailable) {
      await _handleShorebirdStatusChange(
        status: ShorebirdUpdateStatus.unavailable,
      );
      return;
    }

    await _shorebirdService!.downloadPatch(
      track: track,
      onStatusChange: _handleShorebirdStatusChange,
    );
  }

  /// Central callback handler for both Remote Config & Shorebird
  Future<void> _handleUpdateCallback({
    required UpdateType type,
    UpdateSource source = UpdateSource.release,
    int? patchNumber,
  }) async {
    _lastUpdateType = type;

    // If Remote Config detected a patch, notify directly without rechecking
    if (source == UpdateSource.patch && patchNumber != null) {
      // Directly notify that an update is available
      await _handleShorebirdStatusChange(
        status: ShorebirdUpdateStatus.updateAvailable,
        type: type,
        patchNumber: patchNumber,
      );
    }

    if (onUpdate != null) {
      await onUpdate!(
        type: type,
        source: source,
        patchNumber: patchNumber,
      );
    }
  }

  /// Handle Shorebird status changes
  Future<void> _handleShorebirdStatusChange({
    required ShorebirdUpdateStatus status,
    UpdateType? type,
    int? patchNumber,
    String? errorMessage,
  }) async {
    _shorebirdStatus = status;

    if (onShorebirdStatusChange != null) {
      await onShorebirdStatusChange!(
        status: status,
        type: type,
        patchNumber: patchNumber,
        errorMessage: errorMessage,
      );
    }
  }
}
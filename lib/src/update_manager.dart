import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:update_manager/src/ui/ui_handler/ui_handler.dart';

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
  final UpdateUIConfig? uiConfig;
  final BuildContext? context;

  // No longer creating a new instance - using singleton
  RemoteConfigService get _remoteConfigService => RemoteConfigService.instance;

  final ShorebirdService? _shorebirdService;
  UpdateUIHandler? _uiHandler;

  UpdateTrackType currentTrackType = UpdateTrackType.stable;
  UpdateType _lastUpdateType = UpdateType.none;

  // Get update status from RemoteConfigService singleton
  UpdateType get updateTypeStatus => _remoteConfigService.isInitialized
      ? _remoteConfigService.updateTypeStatus
      : _lastUpdateType;

  ShorebirdUpdateStatus _shorebirdStatus = ShorebirdUpdateStatus.idle;
  ShorebirdUpdateStatus get shorebirdStatus => _shorebirdStatus;

  ShorebirdService? get shorebirdService => _shorebirdService;

  UpdateManager({
    required PackageInfo packageInfo,
    this.enableShorebird = false,
    this.onUpdate,
    this.onShorebirdStatusChange,
    this.uiConfig,
    this.context,
  })  : _packageInfo = packageInfo,
        _shorebirdService = enableShorebird ? ShorebirdService() : null {
    // Initialize the singleton RemoteConfigService
    _initializeRemoteConfig();

    if (context != null && uiConfig != null) {
      _uiHandler = UpdateUIHandler(
        context: context!,
        config: uiConfig!,
        onDownloadPatch: _handleDownloadFromUI,
      );
    }
  }

  Future<void> _initializeRemoteConfig() async {
    if (!_remoteConfigService.isInitialized) {
      await _remoteConfigService.initialize(
        packageInfo: _packageInfo,
        onUpdate: _handleUpdateCallback,
        shorebirdService: _shorebirdService,
      );
    } else {
      // If already initialized, just update the callback
      _remoteConfigService.onUpdate = _handleUpdateCallback;
      _remoteConfigService.shorebirdService = _shorebirdService;
    }
  }

  Future<void> initialise(
      {UpdateTrackType updateTrackType = UpdateTrackType.stable}) async {
    currentTrackType = updateTrackType;

    // Ensure RemoteConfigService is initialized
    await _initializeRemoteConfig();

    await _remoteConfigService.initialiseAndCheck(track: currentTrackType);
    // Remote config will trigger Shorebird check if patch update is available
  }

  Future<void> checkShorebirdPatch(
      {UpdateTrackType track = UpdateTrackType.stable}) async {
    if (!enableShorebird ||
        _shorebirdService == null ||
        !_shorebirdService!.isAvailable) {
      await _handleShorebirdStatusChange(
          status: ShorebirdUpdateStatus.unavailable);
      return;
    }

    await _shorebirdService!.checkForUpdate(
      track: track.toShorebirdUpdateTrack(),
      onStatusChange: _handleShorebirdStatusChange,
    );
  }

  Future<void> downloadShorebirdPatch(
      {UpdateTrackType track = UpdateTrackType.stable}) async {
    if (!enableShorebird ||
        _shorebirdService == null ||
        !_shorebirdService!.isAvailable) {
      await _handleShorebirdStatusChange(
          status: ShorebirdUpdateStatus.unavailable);
      return;
    }

    await _shorebirdService!.downloadPatch(
      track: track.toShorebirdUpdateTrack(),
      onStatusChange: _handleShorebirdStatusChange,
    );
  }

  Future<void> _handleDownloadFromUI() async {
    await downloadShorebirdPatch(track: currentTrackType);
  }

  Future<void> _handleUpdateCallback({
    required UpdateType type,
    UpdateSource source = UpdateSource.release,
    int? patchNumber,
  }) async {
    if (_lastUpdateType != UpdateType.none && type == UpdateType.none) {
      dismissStoreUpdateUI();
    }

    _lastUpdateType = type;

    // --- Step 1: Handle store (release) updates first ---
    if (type != UpdateType.none) {
      if (onUpdate == null && _uiHandler != null) {
        await _uiHandler!
            .handleStoreUpdate(type: type, source: UpdateSource.release);
      }

      if (onUpdate != null) {
        await onUpdate!(
            type: type, source: UpdateSource.release, patchNumber: patchNumber);
      }

      // If it's a forced update, stop further checks (don’t continue to Shorebird)
      if (type == UpdateType.force) return;
    }

    // --- Step 2: Only check Shorebird patch updates after handling store updates ---
    if (enableShorebird &&
        source == UpdateSource.patch &&
        patchNumber != null &&
        _shorebirdService != null &&
        _shorebirdService!.isAvailable) {
      await checkShorebirdPatch(track: currentTrackType);
      return; // Don't show store UI for patch updates
    }
  }

  Future<void> _handleShorebirdStatusChange({
    required ShorebirdUpdateStatus status,
    UpdateType? type,
    int? patchNumber,
    String? errorMessage,
  }) async {
    final previousStatus = _shorebirdStatus;
    _shorebirdStatus = status;

    debugPrint('UpdateManager: Shorebird status: $previousStatus → $status');

    // Dismiss UI when transitioning to idle
    if (previousStatus != ShorebirdUpdateStatus.idle &&
        status == ShorebirdUpdateStatus.idle) {
      dismissPatchUI();
    }

    // Show UI for all non-idle statuses
    if (status != ShorebirdUpdateStatus.idle) {
      if (onShorebirdStatusChange == null && _uiHandler != null) {
        await _uiHandler!.handlePatchUpdate(
          status: status,
          patchNumber: patchNumber,
          errorMessage: errorMessage,
        );
      }
    }

    // Always call custom callback
    if (onShorebirdStatusChange != null) {
      await onShorebirdStatusChange!(
        status: status,
        type: type,
        patchNumber: patchNumber,
        errorMessage: errorMessage,
      );
    }
  }

  void dismissAllUpdateUI() {
    _uiHandler?.dismissAllUpdateUI();
  }

  void dismissStoreUpdateUI() {
    _uiHandler?.dismissStoreUpdateUI();
  }

  void dismissPatchUI() {
    _uiHandler?.dismissPatchUI();
  }

  bool get hasActiveUI => _uiHandler?.hasActiveUI ?? false;

  void handleUpdateReverted() {
    debugPrint('UpdateManager: Update reverted, dismissing UI');
    dismissAllUpdateUI();
    _lastUpdateType = UpdateType.none;
    _shorebirdStatus = ShorebirdUpdateStatus.idle;
  }
}

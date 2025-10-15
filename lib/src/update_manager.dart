import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
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

  late final RemoteConfigService _remoteConfigService;
  final ShorebirdService? _shorebirdService;
  UpdateUIHandler? _uiHandler;

  UpdateTrack _currentTrack = UpdateTrack.stable;
  UpdateType _lastUpdateType = UpdateType.none;
  UpdateType get updateTypeStatus => _lastUpdateType;

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
    _remoteConfigService = RemoteConfigService(
      packageInfo: _packageInfo,
      onUpdate: _handleUpdateCallback,
      shorebirdService: _shorebirdService,
    );

    if (context != null && uiConfig != null) {
      _uiHandler = UpdateUIHandler(
        context: context!,
        config: uiConfig!,
        onDownloadPatch: _handleDownloadFromUI,
      );
    }
  }

  Future<void> initialise(
      {UpdateTrack shorebirdTrack = UpdateTrack.stable}) async {
    _currentTrack = shorebirdTrack;
    await _remoteConfigService.initialiseAndCheck(track: _currentTrack);
    // Remote config will trigger Shorebird check if patch update is available
  }

  Future<void> checkShorebirdPatch(
      {UpdateTrack track = UpdateTrack.stable}) async {
    if (!enableShorebird ||
        _shorebirdService == null ||
        !_shorebirdService!.isAvailable) {
      await _handleShorebirdStatusChange(
          status: ShorebirdUpdateStatus.unavailable);
      return;
    }

    await _shorebirdService!.checkForUpdate(
      track: track,
      onStatusChange: _handleShorebirdStatusChange,
    );
  }

  Future<void> downloadShorebirdPatch(
      {UpdateTrack track = UpdateTrack.stable}) async {
    if (!enableShorebird ||
        _shorebirdService == null ||
        !_shorebirdService!.isAvailable) {
      await _handleShorebirdStatusChange(
          status: ShorebirdUpdateStatus.unavailable);
      return;
    }

    await _shorebirdService!.downloadPatch(
      track: track,
      onStatusChange: _handleShorebirdStatusChange,
    );
  }

  Future<void> _handleDownloadFromUI() async {
    await downloadShorebirdPatch(track: _currentTrack);
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

    // Only trigger Shorebird check if patch source
    if (source == UpdateSource.patch && patchNumber != null) {
      if (enableShorebird &&
          _shorebirdService != null &&
          _shorebirdService!.isAvailable) {
        await checkShorebirdPatch(track: _currentTrack);
        return; // Don't show store UI for patch updates
      }
    }

    // Show store update UI
    if (type != UpdateType.none) {
      if (onUpdate == null && _uiHandler != null) {
        await _uiHandler!.handleStoreUpdate(type: type, source: source);
      }

      if (onUpdate != null) {
        await onUpdate!(type: type, source: source, patchNumber: patchNumber);
      }
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

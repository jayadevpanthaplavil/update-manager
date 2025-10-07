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

  UpdateTrack _currentTrack = UpdateTrack.stable;
  UpdateType _lastUpdateType = UpdateType.none;
  UpdateType get updateTypeStatus => _lastUpdateType;

  ShorebirdUpdateStatus _shorebirdStatus = ShorebirdUpdateStatus.idle;
  ShorebirdUpdateStatus get shorebirdStatus => _shorebirdStatus;

  ShorebirdService? get shorebirdService => _shorebirdService;

  // Add concurrency control at UpdateManager level
  bool _isCheckingShorebird = false;

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

  Future<void> initialise(
      {UpdateTrack shorebirdTrack = UpdateTrack.stable}) async {
    _currentTrack = shorebirdTrack;
    await _remoteConfigService.initialiseAndCheck(track: _currentTrack);

    if (enableShorebird &&
        _shorebirdService != null &&
        _shorebirdService!.isAvailable) {
      if (_lastUpdateType == UpdateType.none) {
        await checkShorebirdPatch(track: shorebirdTrack);
      }
    }
  }

  Future<void> checkShorebirdPatch(
      {UpdateTrack track = UpdateTrack.stable}) async {
    // Prevent concurrent checks at UpdateManager level
    if (_isCheckingShorebird) {
      debugPrint(
          'UpdateManager: Shorebird check already in progress, ignoring request');
      return;
    }

    if (!enableShorebird ||
        _shorebirdService == null ||
        !_shorebirdService!.isAvailable) {
      await _handleShorebirdStatusChange(
        status: ShorebirdUpdateStatus.unavailable,
      );
      return;
    }

    _isCheckingShorebird = true;

    try {
      await _shorebirdService!.checkForUpdate(
        track: track,
        onStatusChange: _handleShorebirdStatusChange,
      );
    } finally {
      _isCheckingShorebird = false;
    }
  }

  Future<void> downloadShorebirdPatch(
      {UpdateTrack track = UpdateTrack.stable}) async {
    if (!enableShorebird ||
        _shorebirdService == null ||
        !_shorebirdService!.isAvailable) {
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

  Future<void> _handleUpdateCallback({
    required UpdateType type,
    UpdateSource source = UpdateSource.release,
    int? patchNumber,
  }) async {
    _lastUpdateType = type;

    if (source == UpdateSource.patch && patchNumber != null) {
      if (enableShorebird &&
          _shorebirdService != null &&
          _shorebirdService!.isAvailable) {
        await _handleShorebirdStatusChange(
          status: ShorebirdUpdateStatus.idle,
          type: type,
          patchNumber: patchNumber,
        );
        await checkShorebirdPatch(track: _currentTrack);
      }
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

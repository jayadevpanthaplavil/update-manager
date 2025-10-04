import 'package:flutter/cupertino.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../enums/shorebird_update_status.dart';
import '../update_manager.dart';
import '../enums/update_source.dart';
import '../enums/update_type.dart';

typedef ShorebirdStatusCallback = Future<void> Function({
  required ShorebirdUpdateStatus status,
  UpdateType? type,
  int? patchNumber,
  String? errorMessage,
});

class ShorebirdService {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  bool get isAvailable => _updater.isAvailable;

  Future<int?> readCurrentPatch() async {
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  /// Check for updates with granular status callback
  Future<void> checkForUpdate({
    required UpdateTrack track,
    required ShorebirdStatusCallback onStatusChange,
  }) async {
    try {
      await onStatusChange(status: ShorebirdUpdateStatus.checking);

      final status = await _updater.checkForUpdate(track: track);
      debugPrint("Shorebird checkForUpdate: $status");

      switch (status) {
        case UpdateStatus.outdated:
          await onStatusChange(
            status: ShorebirdUpdateStatus.updateAvailable,
            type: UpdateType.optional,
          );
          break;
        case UpdateStatus.upToDate:
          await onStatusChange(
            status: ShorebirdUpdateStatus.upToDate,
            type: UpdateType.none,
          );
          break;
        case UpdateStatus.restartRequired:
          final patchNumber = await readCurrentPatch();
          await onStatusChange(
            status: ShorebirdUpdateStatus.restartRequired,
            type: UpdateType.optional,
            patchNumber: patchNumber,
          );
          break;
        case UpdateStatus.unavailable:
          await onStatusChange(
            status: ShorebirdUpdateStatus.unavailable,
            type: UpdateType.none,
          );
          break;
      }
    } catch (e) {
      debugPrint("Shorebird checkForUpdate failed: $e");
      await onStatusChange(
        status: ShorebirdUpdateStatus.error,
        type: UpdateType.none,
        errorMessage: e.toString(),
      );
    }
  }

  /// Download patch with progress tracking
  Future<void> downloadPatch({
    required UpdateTrack track,
    required ShorebirdStatusCallback onStatusChange,
  }) async {
    try {
      await onStatusChange(status: ShorebirdUpdateStatus.downloading);

      await _updater.update(track: track);

      final patchNumber = await readCurrentPatch();
      await onStatusChange(
        status: ShorebirdUpdateStatus.restartRequired,
        type: UpdateType.optional,
        patchNumber: patchNumber,
      );
    } on UpdateException catch (e) {
      debugPrint('Patch download failed: ${e.message}');
      await onStatusChange(
        status: ShorebirdUpdateStatus.error,
        type: UpdateType.none,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('Patch download failed: $e');
      await onStatusChange(
        status: ShorebirdUpdateStatus.error,
        type: UpdateType.none,
        errorMessage: e.toString(),
      );
    }
  }
}

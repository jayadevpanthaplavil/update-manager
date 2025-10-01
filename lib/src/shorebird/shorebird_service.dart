import 'package:flutter/cupertino.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../update_manager.dart';
import '../enums/update_source.dart';
import '../enums/update_type.dart';

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

  Future<void> checkForUpdate({
    required UpdateTrack track,
    required UpdateManagerCallback onUpdate,
  }) async {
    try {
      final status = await _updater.checkForUpdate(track: track);

      switch (status) {
        case UpdateStatus.outdated:
          await _downloadPatch(track: track, onUpdate: onUpdate);
          break;
        case UpdateStatus.upToDate:
        case UpdateStatus.restartRequired:
        case UpdateStatus.unavailable:
          await onUpdate(type: UpdateType.none, source: UpdateSource.patch);
          break;
      }
    } catch (e) {
      debugPrint("Shorebird checkForUpdate failed: $e");
      await onUpdate(type: UpdateType.none, source: UpdateSource.patch);
    }
  }

  Future<void> _downloadPatch({
    required UpdateTrack track,
    required UpdateManagerCallback onUpdate,
  }) async {
    try {
      // Notify patch download started
      await onUpdate(type: UpdateType.optional, source: UpdateSource.patch);

      await _updater.update(track: track);

      final patchNumber = await readCurrentPatch();
      await onUpdate(
        type: UpdateType.optional,
        source: UpdateSource.patch,
        patchNumber: patchNumber,
      );
    } catch (e) {
      debugPrint('Patch download failed: $e');
    }
  }
}

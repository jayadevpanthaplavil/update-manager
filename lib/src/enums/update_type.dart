import '../../update_manager.dart';

/// Update Type
enum UpdateType { none, optional, force }

/// Update Track Type
enum UpdateTrackType { stable, beta, staging }

/// Extension to map enum to UpdateTrack
extension UpdateTrackTypeExtension on UpdateTrackType {
  UpdateTrack toShorebirdUpdateTrack() {
    switch (this) {
      case UpdateTrackType.stable:
        return UpdateTrack.stable;
      case UpdateTrackType.beta:
        return UpdateTrack.beta;
      case UpdateTrackType.staging:
        return UpdateTrack.staging;
    }
  }
}

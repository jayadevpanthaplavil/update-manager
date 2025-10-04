/// Status of Shorebird patch updates
enum ShorebirdUpdateStatus {
  /// Initial state or no update needed
  idle,

  /// Checking for updates
  checking,

  /// Update is available for download
  updateAvailable,

  /// Downloading the patch
  downloading,

  /// Download complete, restart required
  restartRequired,

  /// No update available, app is up to date
  upToDate,

  /// Shorebird is not available
  unavailable,

  /// Error occurred during check or download
  error,
}
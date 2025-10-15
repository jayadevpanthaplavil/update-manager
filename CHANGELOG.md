# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2025-10-15
### Added
- Default UI for app update and patch prompts.
  - You can now use the built-in update dialog and patch ui with minimal configuration.
  - To enable store navigation from the default UI:
      - Add the required intent filters in the **AndroidManifest.xml**.
      - Include the corresponding URL scheme configuration in **iOS Info.plist**.
      - For reference, see [URL Launcher Documentation](https://github.com/flutter/plugins/tree/master_archive/packages/url_launcher/url_launcher#android).
### Fixed
- Support `BigInt` handling for version comparison to ensure accurate comparison across extended version formats.

## [1.1.1] - 2025-10-09
### Fixed
- Improved version comparison logic to correctly handle variable-length semantic version formats (e.g., 1.2 vs 1.2.0).

## [1.1.0] - 2025-10-07
### Added
- Shorebird patch update functionality integrated alongside Firebase Remote Config.
- Support for specifying Shorebird update tracks.
- Improved update handling combining both Remote Config and Shorebird services.

### Changed
- Updated Remote Config template to include Shorebird-related parameters.
- Enhanced internal flow for checking updates from multiple sources.

## [1.0.0] - 2025-09-30
### Added
- Initial release of `update_manager`.
- Firebase Remote Config integration.
- UpdateType handling: force, optional, none.
- Example implementation included.

### Planned
- Future integration with Shorebird for patch updates.

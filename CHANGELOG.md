# Changelog

All notable changes to this project will be documented in this file.

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

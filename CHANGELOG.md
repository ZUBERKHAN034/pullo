# Changelog

All notable changes to DevNotch are listed here, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

### Added
- Drag a pull request out of the panel to drop its link into Slack, an email or anywhere else.

## [0.4.0] - 2026-10-20

### Added
- A glass look for the panel and alerts on macOS 26 and later, with or without a dark top behind the notch. Pick it in Settings → General. It follows your Liquid Glass setting and stays solid when Reduce transparency is on.

## [0.3.1] - 2026-10-20

### Added
- Portuguese (Brazil) and Spanish, following your system language.
- Alerts wait while a Focus, like Do Not Disturb, is on. DevNotch asks for permission the first time.
- VoiceOver support in the panel.

### Changed
- A new app icon.
- The download is less than half the size, now 1.4 MB. DevNotch runs on Apple silicon only.

## [0.3.0] - 2026-10-20

### Added
- Alerts when your pull request is merged or closed.
- Alerts for every new reviewer.
- Hovering over an icon explains what it means.

### Changed
- Comment alerts say who commented.
- Settings has its own window, with pages for general options, accounts, alerts, shortcuts, updates and about. Accounts are managed there.
- Alerts that arrive together list each update, most important first.
- A calmer list: one status icon per row, clearer text and simpler tags.
- Search is a field at the top of the panel, and `#123` finds that exact number.
- DevNotch asks before removing an account.

### Fixed
- Your own new pull requests no longer show up as unread.

## [0.2.1] - 2026-10-19

### Changed
- The download is a signed and notarized disk image.

## [0.2.0] - 2026-10-19

### Added
- DevNotch updates itself when a new version is out.
- Alerts can play a sound.
- Support for external displays. The notch stays on the built-in screen.
- An app icon.

### Changed
- An alert stays open while the pointer is over it.
- Clicks only land on the visible part of the notch. Everywhere else they go to the app behind it.

[unreleased]: https://github.com/jordan-cod/devnotch/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/jordan-cod/devnotch/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/jordan-cod/devnotch/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/jordan-cod/devnotch/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/jordan-cod/devnotch/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/jordan-cod/devnotch/releases/tag/v0.2.0

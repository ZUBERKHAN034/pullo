# Changelog

All notable changes to Pullo are listed here, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

### Removed
- Pullo no longer counts how many Macs check for updates. It checks GitHub for updates again, like before 0.10.1, and nothing about your Mac is kept anywhere.

## [0.10.1] - 2026-10-22

### Changed
- Pullo now checks for updates at pullo.jrdan.dev, which counts how many Macs check each day so we know how many people use Pullo. It keeps only the day, the app version and the country. Turn off automatic update checks in Settings → Updates to be left out.

## [0.10.0] - 2026-10-22

### Added
- Each pull request tab can sort by last update or newest first (Settings → Tabs → Edit → Sort by).

### Changed
- Editing a pull request tab is now a set of menus (author, repository, review, checks, state and label) instead of a search you have to type. The GitHub search is still there for anything else.

### Fixed
- ⌘A, ⌘C, ⌘V, ⌘X and ⌘Z now work in text fields, like the tab editor in Settings, and ⌘W closes the Settings window.

## [0.9.0] - 2026-10-21

### Changed
- With more than one account, everything now shows up together: pull requests and runs from all your accounts are in the same tabs, each with the account's avatar, so there's no account to switch anymore. Tabs are shared by every account, and a tab can stick to one account if you want (Settings → Tabs → Account). Tabs you had per account are kept: the ones every account had become one, and the rest stay tied to their account.
- ⌘1 to ⌘9 now jump to a tab, on both the Pull requests and Actions sides.

## [0.8.1] - 2026-10-21

### Fixed
- When GitHub has a hiccup, like error 502 or a slow answer, Pullo tries again by itself before giving up. If your lists are too big for GitHub to answer in time, it switches to a lighter request that asks for fewer pull requests at once.
- A short hiccup no longer shows an error. Pullo keeps your list and only warns you if the problem lasts more than a minute and a half, telling you what's wrong (offline, GitHub not responding, request limit reached or sign-in) and when the list was last updated. The warning's button tries again, and only opens Accounts when the problem is signing in.
- On the Actions side, Pullo now tells you when it can't load runs, instead of quietly showing an old or empty list.

## [0.8.0] - 2026-10-21

### Added
- A new Actions side in the panel shows your GitHub Actions runs: what's running, waiting for approval or just finished, with job progress. Switch to it with the pill under the open notch, or ⌘← and ⌘→. It looks at the repositories you pushed to recently and the ones with your open pull requests, and filters by Mine, Everyone or Deploys.
- Click a run in Actions to see its jobs, with failures first, matrix jobs grouped and the step that failed. From there you can re-run the failed jobs, cancel a run that's still going (click twice to confirm) or open it on GitHub. Esc goes back to the list.
- Make your own tabs for the Actions side in Settings → Tabs, per account: pick who started the run, the repository, part of the workflow name, the branch (`release/*` matches the start), the event and the status. Mine, Everyone and Deploys become regular tabs you can edit, reorder or remove, and there are ready-made ones like Production deploys or Failing on main. The slider button next to the tabs opens the settings.
- The run detail lists every step of each job, like GitHub does, with its status and how long it took. The job that's running or failed opens by itself, the others open with a click, and clicking a step opens its log on GitHub right at that step.

### Changed
- DevNotch is now called Pullo. Nothing else changes: your accounts, tabs and settings stay as they are, and updates keep coming the same way.
- The closed notch now also shows workflow runs you started, like a deploy, with the workflow's name. The ring turns red as soon as a job fails, and the notch flashes the result when the run finishes.
- With the Glass panel style, the tabs, filters, account, search, buttons, the Pull requests / Actions pill and the toasts use macOS Liquid Glass and react to the pointer, instead of flat shapes drawn by the app. The Solid style looks the same as before.

### Fixed
- The pill under the open notch follows the panel style, so it's glass when the panel is, instead of always black.
- Tooltips show up next to the pointer, under the thing you hover (or above it when there's no room), and always inside the panel. Before, some were cut off by the panel edge, hidden behind other parts of the list, or showed up on the wrong side.
- The count on a tab with unread pull requests stays white like the others, with a small blue dot, instead of turning the whole number blue.

## [0.8.0-beta.5] - 2026-10-21

### Added
- A new Actions side in the panel shows your GitHub Actions runs: what's running, waiting for approval or just finished, with job progress. Switch to it with the pill under the open notch, or ⌘← and ⌘→. It looks at the repositories you pushed to recently and the ones with your open pull requests, and filters by Mine, Everyone or Deploys.
- Click a run in Actions to see its jobs, with failures first, matrix jobs grouped and the step that failed. From there you can re-run the failed jobs, cancel a run that's still going (click twice to confirm) or open it on GitHub. Esc goes back to the list.
- Make your own tabs for the Actions side in Settings → Tabs, per account: pick who started the run, the repository, part of the workflow name, the branch (`release/*` matches the start), the event and the status. Mine, Everyone and Deploys become regular tabs you can edit, reorder or remove, and there are ready-made ones like Production deploys or Failing on main. The slider button next to the tabs opens the settings.
- The run detail lists every step of each job, like GitHub does, with its status and how long it took. The job that's running or failed opens by itself, the others open with a click, and clicking a step opens its log on GitHub right at that step.

### Changed
- The closed notch now also shows workflow runs you started, like a deploy, with the workflow's name. The ring turns red as soon as a job fails, and the notch flashes the result when the run finishes.
- With the Glass panel style, the tabs, filters, account, search, buttons, the Pull requests / Actions pill and the toasts use macOS Liquid Glass and react to the pointer, instead of flat shapes drawn by the app. The Solid style looks the same as before.

### Fixed
- The pill under the open notch follows the panel style, so it's glass when the panel is, instead of always black.
- Tooltips show up next to the pointer, under the thing you hover (or above it when there's no room), and always inside the panel. Before, some were cut off by the panel edge, hidden behind other parts of the list, or showed up on the wrong side.
- The count on a tab with unread pull requests stays white like the others, with a small blue dot, instead of turning the whole number blue.

## [0.8.0-beta.4] - 2026-10-21

### Added
- A new Actions side in the panel shows your GitHub Actions runs: what's running, waiting for approval or just finished, with job progress. Switch to it with the pill under the open notch, or ⌘← and ⌘→. It looks at the repositories you pushed to recently and the ones with your open pull requests, and filters by Mine, Everyone or Deploys.
- Click a run in Actions to see its jobs, with failures first, matrix jobs grouped and the step that failed. From there you can re-run the failed jobs, cancel a run that's still going (click twice to confirm) or open it on GitHub. Esc goes back to the list.
- Make your own tabs for the Actions side in Settings → Tabs, per account: pick who started the run, the repository, part of the workflow name, the branch (`release/*` matches the start), the event and the status. Mine, Everyone and Deploys become regular tabs you can edit, reorder or remove, and there are ready-made ones like Production deploys or Failing on main. The slider button next to the tabs opens the settings.

### Changed
- The closed notch now also shows workflow runs you started, like a deploy, with the workflow's name. The ring turns red as soon as a job fails, and the notch flashes the result when the run finishes.
- With the Glass panel style, the tabs, filters, account, search, buttons, the Pull requests / Actions pill and the toasts use macOS Liquid Glass and react to the pointer, instead of flat shapes drawn by the app. The Solid style looks the same as before.

### Fixed
- The pill under the open notch follows the panel style, so it's glass when the panel is, instead of always black.
- Tooltips show up next to the pointer, under the thing you hover (or above it when there's no room), and always inside the panel. Before, some were cut off by the panel edge, hidden behind other parts of the list, or showed up on the wrong side.
- The count on a tab with unread pull requests stays white like the others, with a small blue dot, instead of turning the whole number blue.

## [0.8.0-beta.3] - 2026-10-21

### Added
- A new Actions side in the panel shows your GitHub Actions runs: what's running, waiting for approval or just finished, with job progress. Switch to it with the pill under the open notch, or ⌘← and ⌘→. It looks at the repositories you pushed to recently and the ones with your open pull requests, and filters by Mine, Everyone or Deploys.
- Click a run in Actions to see its jobs, with failures first, matrix jobs grouped and the step that failed. From there you can re-run the failed jobs, cancel a run that's still going (click twice to confirm) or open it on GitHub. Esc goes back to the list.

### Changed
- The closed notch now also shows workflow runs you started, like a deploy, with the workflow's name. The ring turns red as soon as a job fails, and the notch flashes the result when the run finishes.
- With the Glass panel style, the tabs, filters, account, search, buttons, the Pull requests / Actions pill and the toasts use macOS Liquid Glass and react to the pointer, instead of flat shapes drawn by the app. The Solid style looks the same as before.

### Fixed
- The pill under the open notch follows the panel style, so it's glass when the panel is, instead of always black.

## [0.8.0-beta.2] - 2026-10-21

### Added
- A new Actions side in the panel shows your GitHub Actions runs: what's running, waiting for approval or just finished, with job progress. Switch to it with the pill under the open notch, or ⌘← and ⌘→. It looks at the repositories you pushed to recently and the ones with your open pull requests, and filters by Mine, Everyone or Deploys.
- Click a run in Actions to see its jobs, with failures first, matrix jobs grouped and the step that failed. From there you can re-run the failed jobs, cancel a run that's still going (click twice to confirm) or open it on GitHub. Esc goes back to the list.

### Changed
- The closed notch now also shows workflow runs you started, like a deploy, with the workflow's name. The ring turns red as soon as a job fails, and the notch flashes the result when the run finishes.

### Fixed
- The pill under the open notch follows the panel style, so it's glass when the panel is, instead of always black.

## [0.8.0-beta.1] - 2026-10-21

### Added
- A new Actions side in the panel shows your GitHub Actions runs: what's running, waiting for approval or just finished, with job progress. Switch to it with the pill under the open notch, or ⌘← and ⌘→. It looks at the repositories you pushed to recently and the ones with your open pull requests, and filters by Mine, Everyone or Deploys.

## [0.7.0] - 2026-10-21

### Added
- Ready-made searches to start a tab from, like Ready to merge, Failing checks or Mentions me, in Settings → Tabs → Add tab and in the tab editor.
- Choose the panel's tabs for each account in Settings → Tabs. My PRs and To review are now regular tabs you can rename, edit, reorder or remove, and you can add your own, written like a GitHub search (for example `repo:acme/api label:bug`). Alerts keep following your PRs and review requests, whatever tabs you keep.

### Changed
- The quick search in the panel (⌘F) is now called Search, and it looks through every tab.
- The left arrow goes to the previous tab, and Tab or the right arrow to the next one.
- Settings → Appearance shows a preview of each panel style, so you can see what you pick.
- While checks run, the notch shows the PR number by default. In Settings → Appearance you can switch to the checks done, or both.

## [0.7.0-beta.3] - 2026-10-21

### Added
- Ready-made searches to start a tab from, like Ready to merge, Failing checks or Mentions me, in Settings → Tabs → Add tab and in the tab editor.

### Changed
- Settings → Appearance shows a preview of each panel style, so you can see what you pick.
- While checks run, the notch shows the PR number by default. In Settings → Appearance you can switch to the checks done, or both.

## [0.7.0-beta.2] - 2026-10-21

### Fixed
- The glass panel stays dark and readable when your Mac uses Light mode.

## [0.6.2] - 2026-10-21

### Fixed
- The glass panel stays dark and readable when your Mac uses Light mode.

## [0.6.1] - 2026-10-21

### Fixed
- DevNotch looks for updates at a new address, so beta versions reach people who turned them on again.

## [0.7.0-beta.1] - 2026-10-20

### Added
- Choose the panel's tabs for each account in Settings → Tabs. My PRs and To review are now regular tabs you can rename, edit, reorder or remove, and you can add your own, written like a GitHub search (for example `repo:acme/api label:bug`). Alerts keep following your PRs and review requests, whatever tabs you keep.

### Changed
- The quick search in the panel (⌘F) is now called Search, and it looks through every tab.
- The left arrow goes to the previous tab, and Tab or the right arrow to the next one.

## [0.6.0] - 2026-10-20

### Added
- Each kind of alert can play its own sound, so you can tell a failed CI from an approval without looking. Set it in Settings → Alerts.
- Alerts that arrive during a Focus are no longer lost. When the Focus ends, DevNotch shows them together in one alert.
- Drag a pull request out of the panel to drop its link into Slack, an email or anywhere else.
- While checks run on your pull requests, the closed notch widens to show how many are done, with a +1 when more than one is running. It turns green or red when they finish, right before the alert. Turn it off in Settings → Appearance.

### Changed
- The glass style moved from General to a new Appearance page in Settings.
- DevNotch checks GitHub every 30 seconds while checks are running, and every minute otherwise.

## [0.6.0-beta.2] - 2026-10-20

### Added
- While checks run on your pull requests, the closed notch widens to show how many are done, with a +1 when more than one is running. It turns green or red when they finish, right before the alert. Turn it off in Settings → Appearance.

### Changed
- The glass style moved from General to a new Appearance page in Settings.
- DevNotch checks GitHub every 30 seconds while checks are running, and every minute otherwise.

### Fixed
- Dragging a pull request into another app works. The link goes out as both a URL and plain text, and the panel stays open until you drop it.

## [0.6.0-beta.1] - 2026-10-20

### Added
- Each kind of alert can play its own sound, so you can tell a failed CI from an approval without looking. Set it in Settings → Alerts.
- Alerts that arrive during a Focus are no longer lost. When the Focus ends, DevNotch shows them together in one alert.
- Drag a pull request out of the panel to drop its link into Slack, an email or anywhere else.

## [0.5.0] - 2026-10-20

### Added
- Each pull request shows how many lines it adds and removes. Hover over it to see how many files changed.
- Get beta versions: turn it on in Settings → Updates to try new features before everyone else.

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

[unreleased]: https://github.com/jordan-cod/pullo/compare/v0.10.1...HEAD
[0.10.1]: https://github.com/jordan-cod/pullo/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/jordan-cod/pullo/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/jordan-cod/pullo/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/jordan-cod/pullo/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/jordan-cod/pullo/compare/v0.7.0...v0.8.0
[0.8.0-beta.5]: https://github.com/jordan-cod/pullo/compare/v0.8.0-beta.4...v0.8.0-beta.5
[0.8.0-beta.4]: https://github.com/jordan-cod/pullo/compare/v0.8.0-beta.3...v0.8.0-beta.4
[0.8.0-beta.3]: https://github.com/jordan-cod/pullo/compare/v0.8.0-beta.2...v0.8.0-beta.3
[0.8.0-beta.2]: https://github.com/jordan-cod/pullo/compare/v0.8.0-beta.1...v0.8.0-beta.2
[0.8.0-beta.1]: https://github.com/jordan-cod/pullo/compare/v0.7.0...v0.8.0-beta.1
[0.7.0]: https://github.com/jordan-cod/pullo/compare/v0.6.2...v0.7.0
[0.7.0-beta.3]: https://github.com/jordan-cod/pullo/compare/v0.7.0-beta.2...v0.7.0-beta.3
[0.7.0-beta.2]: https://github.com/jordan-cod/pullo/compare/v0.7.0-beta.1...v0.7.0-beta.2
[0.6.2]: https://github.com/jordan-cod/pullo/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/jordan-cod/pullo/compare/v0.6.0...v0.6.1
[0.7.0-beta.1]: https://github.com/jordan-cod/pullo/compare/v0.6.0...v0.7.0-beta.1
[0.6.0]: https://github.com/jordan-cod/pullo/compare/v0.5.0...v0.6.0
[0.6.0-beta.2]: https://github.com/jordan-cod/pullo/compare/v0.6.0-beta.1...v0.6.0-beta.2
[0.6.0-beta.1]: https://github.com/jordan-cod/pullo/compare/v0.5.0...v0.6.0-beta.1
[0.5.0]: https://github.com/jordan-cod/pullo/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/jordan-cod/pullo/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/jordan-cod/pullo/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/jordan-cod/pullo/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/jordan-cod/pullo/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/jordan-cod/pullo/releases/tag/v0.2.0

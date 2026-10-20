# DevNotch

DevNotch is a macOS app that puts your GitHub pull requests in the notch. It lets you know when CI fails, when someone approves or comments, and when your review is requested.

<img src="docs/media/demo.gif" alt="DevNotch showing an alert and the list of pull requests" width="720">

Requires a Mac with Apple silicon running macOS 14 or later, and the [GitHub CLI](https://cli.github.com). Available in English, Portuguese (Brazil) and Spanish.

## Features

- Your pull requests and review requests in one list
- Review requests split between direct and team requests
- Alerts for CI, approvals, requested changes, comments and review requests
- Unread marker on each pull request, with what changed
- Failed checks with a link to the logs
- Multiple GitHub accounts, each with its own list
- Search by title, repo, number, branch or author
- Global shortcut and keyboard navigation
- Solid or Liquid Glass look on macOS 26 and later
- Updates itself when a new version is out
- Read-only: it doesn't approve, merge or store tokens

## Installation

1. Download [`DevNotch.dmg`](https://github.com/jordan-cod/devnotch/releases/latest/download/DevNotch.dmg) from the latest release.
2. Open it and drag DevNotch to your Applications folder.
3. If you don't have the GitHub CLI yet, install it and log in:

   ```sh
   brew install gh
   gh auth login
   ```

## Usage

1. Open DevNotch and hover over the notch.
2. Pick which `gh` accounts to add.
3. Hover over the notch to see your pull requests, or press <kbd>⌥</kbd> <kbd>⌘</kbd> <kbd>P</kbd> from any app.
4. Click a pull request to open it in your browser. Opening it marks it as read.
5. Drag a pull request out of the panel to drop its link into Slack, an email or anywhere else.
6. Click the gear to change alerts, the alert sound, trackpad feedback and "Open at login".

| Shortcut | Action |
|---|---|
| <kbd>⌥</kbd> <kbd>⌘</kbd> <kbd>P</kbd> | Open or close the panel |
| <kbd>⌘</kbd> <kbd>F</kbd> | Search |
| <kbd>↑</kbd> <kbd>↓</kbd> | Move through the list |
| <kbd>↩</kbd> | Open the pull request |
| <kbd>C</kbd> | Copy the branch name |
| <kbd>R</kbd> | Mark as read |
| <kbd>⇥</kbd> | Switch tabs |
| <kbd>⌘</kbd> <kbd>1</kbd>…<kbd>9</kbd> | Switch accounts |
| <kbd>esc</kbd> | Close search or the panel |

## Screenshots

#### Alerts that arrive together are grouped

<img src="docs/media/screenshots/01-alerts.png" alt="Alert with 4 updates" width="470">

#### Your pull requests, with what changed since you last looked

<img src="docs/media/screenshots/02-my-prs.png" alt="List of pull requests" width="630">

#### Direct and team review requests

<img src="docs/media/screenshots/03-to-review.png" alt="To review tab" width="630">

#### One list per account

<img src="docs/media/screenshots/04-accounts.png" alt="Personal account selected" width="630">

#### Search

<img src="docs/media/screenshots/05-search.png" alt="Searching for pay" width="630">

## FAQ

### Can I try new features early?

Turn on **Get beta versions** in Settings → Updates. Betas may have bugs. If you turn it off again, you keep the beta you have until a newer stable version is out.

### Why does it need the GitHub CLI?

So it never has to store a token. DevNotch asks `gh` for a token on each refresh and keeps it in memory only. There's no server and no sign-up: the app talks to the GitHub API directly.

### How do I add another account?

Run `gh auth login` with the other account, then add it in Settings › Accounts.

### Does it work with external displays or Macs without a notch?

DevNotch stays on your Mac's built-in screen, under the notch, even with other displays plugged in. On a Mac without a notch, or with the lid closed, it moves to the main display: hover over the top center of the menu bar.

### How often does it refresh?

Every minute, and right after your Mac wakes up. There's also a refresh button in the panel.

### What counts as an update?

Comments, reviews, changes to CI or the review decision, and new commits on other people's pull requests. Your own activity and bot activity don't count. Read state is stored only on your Mac.

## License

[MIT](LICENSE)

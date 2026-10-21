# AGENTS

## Changelog
- Every pull request that changes something a user can notice adds a line under `## [Unreleased]` in `CHANGELOG.md`, in the same pull request.
- Use the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) categories: Added, Changed, Deprecated, Removed, Fixed, Security. Skip empty ones.
- Write for people who use the app, not for people who read the code: what changed for them, in one short sentence. Leave out refactors, tests, CI and build changes unless the user feels them, like a smaller download.
- To release, rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, add a new empty `## [Unreleased]` above it, update the links at the bottom, merge, then push the `vX.Y.Z` tag. The release workflow publishes that section on GitHub and in the update window, and fails if it's missing.

## Betas
- A beta is tagged `vX.Y.Z-beta.N` and gets its own `## [X.Y.Z-beta.N] - YYYY-MM-DD` section, listing what changed since the previous beta or stable release. Leave `[Unreleased]` alone until the stable release.
- The workflow publishes it as a GitHub pre-release on Sparkle's `beta` channel, so only people who turned on "Get beta versions" get it. The download links keep pointing to the latest stable release.

## Update feed
- The app reads its Sparkle feed from GitHub Pages, at `https://jordan-cod.github.io/devnotch/appcast.xml`, served from the `gh-pages` branch.
- Releases are immutable, so the feed never lives only inside a release. Every release workflow starts from the published feed, adds the new version, pushes it to `gh-pages` and waits until Pages serves it.
- A copy is still attached to each release for installs older than 0.6.1, which read it from the latest release.
- The stable `X.Y.Z` release lists everything since the previous stable release, betas included.

## Code
- No comments in code, except `// MARK:`.
- Commit messages and pull requests in English.
- Every pull request that changes the UI shows before and after screenshots in its description.

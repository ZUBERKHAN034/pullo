# AGENTS

## Changelog
- Every pull request that changes something a user can notice adds a line under `## [Unreleased]` in `CHANGELOG.md`, in the same pull request.
- Use the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) categories: Added, Changed, Deprecated, Removed, Fixed, Security. Skip empty ones.
- Write for people who use the app, not for people who read the code: what changed for them, in one short sentence. Leave out refactors, tests, CI and build changes unless the user feels them, like a smaller download.
- To release, rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, add a new empty `## [Unreleased]` above it, update the links at the bottom, merge, then push the `vX.Y.Z` tag. The release workflow publishes that section on GitHub and in the update window, and fails if it's missing.

## Code
- No comments in code, except `// MARK:`.
- Commit messages and pull requests in English.
- Every pull request that changes the UI shows before and after screenshots in its description.

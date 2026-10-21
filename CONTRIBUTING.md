# Contributing to Pullo

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Reporting a bug

[Open a bug report](https://github.com/jordan-cod/pullo/issues/new?template=bug_report.yml) and fill in the form. The Pullo version (Settings › About), your macOS version and whether your Mac has a notch help a lot. Screenshots or a short screen recording help even more.

Found a security problem? Don't open an issue, follow [SECURITY.md](SECURITY.md).

## Suggesting a feature

[Open a feature request](https://github.com/jordan-cod/pullo/issues/new?template=feature_request.yml) that starts from the problem you have, not only the solution. Pullo tries to stay small, so not every idea will land, but every one is read.

## Working on the code

You need macOS 14 or later, Xcode 26 and the [GitHub CLI](https://cli.github.com) logged in with `gh auth login`.

```sh
swift test               # run the tests
./scripts/run.sh         # build the app and open it
swiftformat --lint .     # check formatting (swiftformat . to fix it)
swiftlint lint --strict  # lint
```

CI runs the same checks on every pull request.

### Conventions

- No comments in code, except `// MARK:`.
- Commit messages, pull requests and code in English. The app itself is translated in `Sources/Pullo/Resources/Localizable.xcstrings`.
- If people using the app will notice the change, add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md), written for them, not for people who read the code. See [AGENTS.md](AGENTS.md) for the details.
- Pull requests that change the UI show before and after screenshots. Use made-up data, not your real repositories.

## Pull requests

1. For anything bigger than a small fix, open an issue first so we can agree on the approach.
2. Fork, create a branch, make the change with tests where it makes sense.
3. Open the pull request and fill in the template.

By contributing you agree that your work is released under the [MIT License](LICENSE), and to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

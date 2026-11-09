# Contributing to Hermes

Thanks for your interest in Hermes. Bug reports, ideas and pull requests are all welcome.

Before starting on a larger change, open an issue first so we can agree on the approach. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md), and report security issues privately as described in [SECURITY.md](SECURITY.md).

## Requirements

- macOS 15 or later to run Hermes
- Xcode 27 or later to build
- [SwiftLint](https://github.com/realm/SwiftLint) for linting (`brew install swiftlint`)

The only dependency is [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), fetched by Swift Package Manager on the first build. No accounts or tokens are needed.

## Building from source

```sh
git clone https://github.com/DouweBos/Hermes.git
cd Hermes/app/Hermes
xcodebuild -project Hermes.xcodeproj -scheme Hermes -derivedDataPath build -destination 'platform=macOS,arch=arm64' build
open build/Build/Products/Debug/Hermes.app --args -HermesStorage /tmp/hermes-dev
```

Or open `app/Hermes/Hermes.xcodeproj` in Xcode and run the Hermes scheme.

Useful launch flags:

- `-HermesStorage <path>` keeps the shelf and history somewhere other than Application Support, so your real shelf is left alone. Use `/tmp/hermes-dev` when testing.
- `-HermesOpenShelf shelf|clipboard|handle` shows the shelf on launch.
- `-HermesOpenSettings YES` opens Settings.

### Signing

The project is set up with the maintainer's development team, so you need to sign with your own. Hermes isn't sandboxed and uses no entitlements that require a paid Apple Developer account, so any of these work:

- **Xcode**: select the Hermes target, open Signing & Capabilities, and pick your own team (a free Personal Team is fine). Do the same for HermesTests.
- **Command line, with your team**: append `DEVELOPMENT_TEAM=<your team id>` to the `xcodebuild` command.
- **Command line, ad-hoc**: append `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=` to sign without any Apple account.

Don't commit a changed `DEVELOPMENT_TEAM`. Revert `project.pbxproj` before committing, or stick to the command-line overrides.

Each time a differently signed copy runs, macOS may ask again for folder access, since it sees a new app.

## Tests and linting

```sh
cd app/Hermes
xcodebuild -project Hermes.xcodeproj -scheme Hermes -derivedDataPath build -destination 'platform=macOS,arch=arm64' test -only-testing:HermesTests
swiftlint lint --quiet
```

Both need to pass before a pull request is merged. Add tests for behavior you change where it's practical.

## Conventions

Read [CLAUDE.md](CLAUDE.md) for the architecture notes and the design system rules. In short:

- Colors come from `Theme`, icons are SF Symbols, and reusable components live in `DesignSystem/` with a `#Preview`.
- Keep files under 500 lines and views under 300.
- Comments explain why, in 1–2 lines.
- One logical change per commit, with its tests and docs in the same commit.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org): `type(scope): subject`, one short lowercase subject. For example `fix(drag): notice drags that start in the dock`.

The app icon is generated: edit `scripts/render-icon.swift` and run `swift scripts/render-icon.swift` instead of editing the icon by hand.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make your change, with tests where they make sense.
3. Run the tests and SwiftLint.
4. Open a pull request and fill in the template. Screenshots or a short recording help for anything visible.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).

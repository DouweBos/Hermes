# Hermes

A free, open source drag-and-drop shelf for macOS: a menu bar app with a floating panel at the screen edge. Its design language follows Grove (`../Grove`).

## Development Guidelines

- This is not a production app. Never plan or implement data migrations — just refactor directly.
- Never name or compare Hermes to other shelf apps anywhere in the repository: code, docs, commit messages.
- The shelf is an `NSPanel` (`ShelfPanel`) hosting SwiftUI. Drags in and out go through AppKit (`DropTargetView`, `ItemDragSourceView`), not SwiftUI's `onDrop`/`onDrag`, which can't drag several files or report where a drag ended.
- `ShelfController` owns the panel and its modes (hidden, handle, open); views call functions on it rather than mutating stores directly.
- Settings keys live in `SettingKey`; views bind with `@AppStorage`, services read `Preferences` at the moment they need a value.
- Entries are either referenced files or content Hermes owns under `Data/<id>/`. Only owned files are ever deleted (`ItemStorage.owns`).

## Design system

1. All colors come from `Theme` (asset catalog tokens, light and dark). No `Color.red`, `Color(red:)`, hex, or `Color(nsColor:)` in views.
2. The shelf sits on `.shelfSurface()`.
3. SF Symbols only, no emoji.
4. Reusable components live in `DesignSystem/`, each with a `#Preview`. Check there before building a one-off.

## Build and test

```sh
cd app/Hermes
xcodebuild -project Hermes.xcodeproj -scheme Hermes -derivedDataPath build -destination 'platform=macOS,arch=arm64' build
xcodebuild -project Hermes.xcodeproj -scheme Hermes -derivedDataPath build -destination 'platform=macOS,arch=arm64' test -only-testing:HermesTests
swiftlint lint --quiet
```

Dev launch flags: `-HermesStorage <path>` keeps the shelf and history somewhere other than Application Support (use `/tmp/hermes-dev` when testing), `-HermesOpenShelf shelf|clipboard|handle` shows the shelf on launch.

The app icon is generated: edit `scripts/render-icon.swift` and run `swift scripts/render-icon.swift`.

## Conventions

- Files under 500 lines, views under 300; split when approaching that.
- Commit when a thing is done. Every feature, fix or refactor gets its own commit the moment it works, with its tests and docs in it. Committing is not pushing: push only when asked.
- Commit messages: Conventional Commits, `type(scope): subject`, one short lowercase subject.
- Comments explain why, in 1–2 lines, describing the code as it stands.

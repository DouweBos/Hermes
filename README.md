# Hermes

A free, open source drag-and-drop shelf for macOS.

Start dragging a file, some text, a link or an image and a shelf slides in at the edge of the screen. Drop things on it, switch apps or Spaces, then drag them back out wherever they need to go.

## Features

- **Shelf on drag**: shows up when you start dragging, when you shake the pointer, or when you drag to the screen edge. You pick which.
- **Anything you can drag**: files and folders, plain and rich text, links, images, and files apps hand over as promises (Mail attachments, Photos).
- **Stacks**: things dropped together stay together and drag out as one. Split them, or combine items into a stack.
- **Drag out anywhere**: files behave as they do in Finder; text, links and images go in as content or as a file, whichever the target takes. Items leave the shelf once dragged out, unless you pin them with Keep on Shelf or hold Option.
- **Edge handle**: the shelf collapses to a slim tab while it holds items; hover or drag over it to open it.
- **Clipboard history**: recent copies in a second tab. Click to copy again, drag out, or move to the shelf. Passwords and other content apps mark as private are skipped.
- **Screenshots**: optionally put new screenshots on the shelf as you take them.
- **Quick Look, Share, Show in Finder, Open** from the context menu or the keyboard.
- **Global shortcuts** for the shelf, the clipboard history and pasting to the shelf, all changeable in Settings.
- Survives restarts, follows files when they're moved or renamed, works on every Space and over full-screen apps, and can open at login.

## Keyboard

| Shortcut | Action |
|---|---|
| ⌃⌥H | Show or hide the shelf |
| ⌃⌥V | Show clipboard history |
| ⌃⌥C | Paste the clipboard to the shelf |
| Space | Quick Look the selection |
| Return | Open the selection |
| Delete | Remove the selection |
| ⌘C / ⌘V / ⌘A | Copy, paste to the shelf, select all |
| Escape | Collapse the shelf |

## Requirements

- macOS 15 or later
- Xcode 27 to build

## Building

```sh
cd app/Hermes
xcodebuild -project Hermes.xcodeproj -scheme Hermes -derivedDataPath build -destination 'platform=macOS,arch=arm64' build
open build/Build/Products/Debug/Hermes.app
```

Tests:

```sh
xcodebuild -project Hermes.xcodeproj -scheme Hermes -derivedDataPath build -destination 'platform=macOS,arch=arm64' test -only-testing:HermesTests
```

To build with your own Apple ID, change the development team in the project's Signing & Capabilities.

## Project structure

```
app/Hermes/Hermes/
  App/            Entry point, app delegate, menu bar menu
  Shelf/          Panel, controller, drag and drop, tiles, context menus, Quick Look
  Clipboard/      Clipboard history model and tab
  Monitors/       Drag detection, shake detection, clipboard polling, screenshots
  Pasteboard/     Reading drops and the clipboard, writing items back out
  Storage/        On-disk lists and stored copies
  Models/         Items, entries, settings
  Settings/       Settings window
  DesignSystem/   Theme and shared components
scripts/          App icon renderer
```

Data lives in `~/Library/Application Support/Hermes`.

## License

MIT

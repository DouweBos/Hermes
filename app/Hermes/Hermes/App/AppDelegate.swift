// App/AppDelegate.swift
// Hermes
//
// Builds the shelf and connects it to the drag, clipboard and screenshot monitors and the shortcuts.

import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: ShelfStore
    let history: ClipboardHistory
    let controller: ShelfController
    let launchAtLogin = LaunchAtLogin()

    private let dragMonitor = DragMonitor()
    private let clipboardMonitor = ClipboardMonitor()
    private let screenshotWatcher = ScreenshotWatcher()
    private var defaultsObserver: NSObjectProtocol?

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    override init() {
        Preferences.registerDefaults()
        store = ShelfStore(storage: .live)
        history = ClipboardHistory(storage: .live)
        controller = ShelfController(store: store, history: history)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        dragMonitor.onBegan = { [weak self] point in self?.controller.externalDragBegan(at: point) }
        dragMonitor.onMoved = { [weak self] point in self?.controller.externalDragMoved(to: point) }
        dragMonitor.onEnded = { [weak self] in self?.controller.externalDragEnded() }
        dragMonitor.start()

        clipboardMonitor.onChange = { [weak self] pasteboard in self?.recordClipboard(pasteboard) }
        controller.onWroteClipboard = { [weak self] in self?.clipboardMonitor.skipCurrentContents() }
        screenshotWatcher.onScreenshot = { [weak self] url in self?.controller.addScreenshot(url) }

        KeyboardShortcuts.onKeyUp(for: .toggleShelf) { [weak self] in self?.controller.toggle(tab: .shelf) }
        KeyboardShortcuts.onKeyUp(for: .showClipboard) { [weak self] in self?.controller.toggle(tab: .clipboard) }
        KeyboardShortcuts.onKeyUp(for: .pasteToShelf) { [weak self] in self?.controller.pasteFromClipboard() }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPreferences() }
        }
        applyPreferences()

        switch UserDefaults.standard.string(forKey: "HermesOpenShelf") {
        case "clipboard": controller.open(tab: .clipboard)
        case "handle": controller.collapse()
        case .some: controller.open(tab: .shelf)
        case nil: break
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor.stop()
        clipboardMonitor.stop()
        screenshotWatcher.stop()
    }

    /// Starts or stops the optional monitors and moves the shelf when its edge changes.
    private func applyPreferences() {
        if Preferences.clipboardHistory, !clipboardMonitor.isRunning {
            clipboardMonitor.start()
        } else if !Preferences.clipboardHistory, clipboardMonitor.isRunning {
            clipboardMonitor.stop()
        }
        history.trim(to: Preferences.clipboardLimit)

        if Preferences.captureScreenshots, !screenshotWatcher.isRunning {
            screenshotWatcher.start()
        } else if !Preferences.captureScreenshots, screenshotWatcher.isRunning {
            screenshotWatcher.stop()
        }
        controller.refreshPlacement()
    }

    private func recordClipboard(_ pasteboard: NSPasteboard) {
        let entries = controller.reader.entries(from: pasteboard, prefer: .text)
        history.record(entries, limit: Preferences.clipboardLimit)
    }
}

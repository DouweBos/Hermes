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
    private lazy var settingsWindow = SettingsWindowController(launchAtLogin: launchAtLogin)
    private var statusItem: StatusItemController?

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

        statusItem = StatusItemController(controller: controller) { [weak self] in self?.settingsWindow.show() }
        controller.onShowSettings = { [weak self] in self?.settingsWindow.show() }

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
            // Frameworks write defaults mid-layout (text measurement does); moving the panel then crashes SwiftUI.
            DispatchQueue.main.async { self?.preferencesMayHaveChanged() }
        }
        preferencesMayHaveChanged()

        if UserDefaults.standard.bool(forKey: "HermesOpenSettings") { settingsWindow.show() }
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

    private var appliedPreferences: [String] = []

    private func preferencesMayHaveChanged() {
        let current = [SettingKey.edge, SettingKey.position, SettingKey.size, SettingKey.keepHandle,
                       SettingKey.clipboardHistory, SettingKey.clipboardLimit, SettingKey.captureScreenshots]
            .map { "\(Preferences.defaults.object(forKey: $0) ?? "")" }
        guard current != appliedPreferences else { return }
        appliedPreferences = current
        applyPreferences()
    }

    /// Starts or stops the optional monitors and moves the shelf when its edge changes.
    private func applyPreferences() {
        // Clipboard screenshots come through the clipboard monitor too.
        let watchClipboard = Preferences.clipboardHistory || Preferences.captureScreenshots
        if watchClipboard, !clipboardMonitor.isRunning {
            clipboardMonitor.start()
        } else if !watchClipboard, clipboardMonitor.isRunning {
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
        if Preferences.captureScreenshots, PasteboardReader.isLikelyScreenshot(pasteboard) {
            controller.addClipboardScreenshot(pasteboard)
        }
        guard Preferences.clipboardHistory else { return }
        let entries = controller.reader.entries(from: pasteboard, prefer: .text)
        history.record(entries, limit: Preferences.clipboardLimit)
    }
}

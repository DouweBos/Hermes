// App/SettingsWindowController.swift
// Hermes
//
// The Settings window, hosted by hand since Hermes has no SwiftUI scenes.

import AppKit
import SwiftUI

final class SettingsWindowController {
    private let launchAtLogin: LaunchAtLogin
    private var window: NSWindow?

    init(launchAtLogin: LaunchAtLogin) {
        self.launchAtLogin = launchAtLogin
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(launchAtLogin: launchAtLogin)))
        window.title = "Hermes Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

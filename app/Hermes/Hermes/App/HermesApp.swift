// App/HermesApp.swift
// Hermes
//
// Application entry point: a menu bar extra and the Settings window. The shelf is its own panel.

import KeyboardShortcuts
import SwiftUI

@main
struct HermesApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: appDelegate.controller)
        } label: {
            Image(systemName: appDelegate.store.isEmpty ? "tray" : "tray.full")
                .accessibilityLabel("Hermes")
        }

        Settings {
            SettingsView(launchAtLogin: appDelegate.launchAtLogin)
        }
    }
}

struct MenuBarContent: View {
    let controller: ShelfController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(controller.mode == .open && controller.tab == .shelf ? "Hide Shelf" : "Show Shelf") {
            controller.toggle(tab: .shelf)
        }
        .globalKeyboardShortcut(.toggleShelf)
        Button("Clipboard History") {
            controller.toggle(tab: .clipboard)
        }
        .globalKeyboardShortcut(.showClipboard)
        Button("Paste to Shelf") {
            controller.pasteFromClipboard()
        }
        .globalKeyboardShortcut(.pasteToShelf)
        Divider()
        Button(controller.store.isEmpty ? "Shelf Is Empty" : "Clear Shelf (\(controller.store.items.count))") {
            controller.clearShelf()
        }
        .disabled(controller.store.items.allSatisfy(\.isPinned))
        Divider()
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("About Hermes") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        }
        Divider()
        Button("Quit Hermes") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

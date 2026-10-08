// Settings/SettingsView.swift
// Hermes
//
// The Settings window: when the shelf appears, how it behaves, the clipboard history and shortcuts.

import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettings(launchAtLogin: launchAtLogin)
            }
            Tab("Clipboard", systemImage: "doc.on.clipboard") {
                ClipboardSettings()
            }
            Tab("Shortcuts", systemImage: "keyboard") {
                ShortcutSettings()
            }
        }
        .frame(width: 460)
        .scenePadding()
    }
}

private struct GeneralSettings: View {
    let launchAtLogin: LaunchAtLogin

    @AppStorage(SettingKey.trigger) private var trigger = ShelfTrigger.anyDrag
    @AppStorage(SettingKey.edge) private var edge = ShelfEdge.right
    @AppStorage(SettingKey.position) private var position = ShelfPosition.center
    @AppStorage(SettingKey.size) private var size = ShelfSize.standard
    @AppStorage(SettingKey.keepHandle) private var keepHandle = true
    @AppStorage(SettingKey.removeAfterDragOut) private var removeAfterDragOut = true
    @AppStorage(SettingKey.stackDrops) private var stackDrops = true
    @AppStorage(SettingKey.captureScreenshots) private var captureScreenshots = false

    var body: some View {
        Form {
            Section {
                Picker("Show the shelf", selection: $trigger) {
                    ForEach(ShelfTrigger.allCases) { Text($0.title).tag($0) }
                }
                Picker("Screen edge", selection: $edge) {
                    ForEach(ShelfEdge.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Position on edge", selection: $position) {
                    ForEach(ShelfPosition.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Size", selection: $size) {
                    ForEach(ShelfSize.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Keep a handle at the edge while items are on the shelf", isOn: $keepHandle)
            }
            Section {
                Toggle("Remove items after dragging them out", isOn: $removeAfterDragOut)
                Text("Hold Option while dropping to keep an item, or pin it with Keep on Shelf.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Toggle("Group items dropped together into a stack", isOn: $stackDrops)
                Toggle("Add new screenshots to the shelf", isOn: $captureScreenshots)
            }
            Section {
                Toggle("Open at login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: launchAtLogin.set))
                if let error = launchAtLogin.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ClipboardSettings: View {
    @AppStorage(SettingKey.clipboardHistory) private var isEnabled = true
    @AppStorage(SettingKey.clipboardLimit) private var limit = 50

    var body: some View {
        Form {
            Section {
                Toggle("Keep a clipboard history", isOn: $isEnabled)
                Picker("Remember", selection: $limit) {
                    ForEach([20, 50, 100, 200], id: \.self) { Text("\($0) items").tag($0) }
                }
                .disabled(!isEnabled)
            } footer: {
                Text("Passwords and other content that apps mark as private are never recorded.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutSettings: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Show or hide the shelf", name: .toggleShelf)
            KeyboardShortcuts.Recorder("Show clipboard history", name: .showClipboard)
            KeyboardShortcuts.Recorder("Paste clipboard to the shelf", name: .pasteToShelf)
            Section("On the shelf") {
                LabeledContent("Quick Look", value: "Space")
                LabeledContent("Open", value: "Return")
                LabeledContent("Remove", value: "Delete")
                LabeledContent("Copy, Paste, Select All", value: "⌘C, ⌘V, ⌘A")
                LabeledContent("Collapse", value: "Escape")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView(launchAtLogin: LaunchAtLogin())
}

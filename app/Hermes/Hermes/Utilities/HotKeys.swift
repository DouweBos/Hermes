// Utilities/HotKeys.swift
// Hermes
//
// Global shortcuts, recorded in Settings.

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleShelf = Self("toggleShelf", initial: .init(.h, modifiers: [.control, .option]))
    static let showClipboard = Self("showClipboardHistory", initial: .init(.v, modifiers: [.control, .option]))
    static let pasteToShelf = Self("pasteToShelf", initial: .init(.c, modifiers: [.control, .option]))
}

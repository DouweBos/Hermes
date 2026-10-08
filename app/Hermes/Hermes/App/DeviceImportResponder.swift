// App/DeviceImportResponder.swift
// Hermes
//
// Continuity Camera looks for a requestor through the key window's responder chain, and a menu bar app
// has no key window. While the menu is open, a transparent window offscreen holds this view as first responder.

import AppKit

final class DeviceImportResponder: NSView, NSServicesMenuRequestor {
    var onImport: ((NSPasteboard) -> Bool)?
    private lazy var panel: NSPanel = {
        let panel = KeyablePanel(contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = self
        return panel
    }()

    override var acceptsFirstResponder: Bool { true }

    func becomeKey() {
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(self)
    }

    func resign() {
        panel.orderOut(nil)
    }

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?,
                                 returnType: NSPasteboard.PasteboardType?) -> Any? {
        if sendType == nil, let returnType, ([.pdf] + PasteboardReader.imageTypes).contains(returnType) {
            return self
        }
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }

    func readSelection(from pasteboard: NSPasteboard) -> Bool {
        onImport?(pasteboard) ?? false
    }

    func writeSelection(to pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool { false }
}

/// Borderless panels refuse key status unless asked.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

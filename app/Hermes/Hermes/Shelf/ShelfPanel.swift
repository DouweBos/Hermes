// Shelf/ShelfPanel.swift
// Hermes
//
// A borderless floating panel that shows on every Space and over full-screen apps without activating Hermes.

import AppKit
import Quartz

final class ShelfPanel: NSPanel {
    private weak var controller: ShelfController?

    init(controller: ShelfController) {
        self.controller = controller
        super.init(contentRect: NSRect(x: 0, y: 0, width: ShelfLayout.width, height: ShelfLayout.height(rows: 3)),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        controller?.panelResignedKey()
    }

    // MARK: - Quick Look

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        controller?.quickLook.attach(to: panel)
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        controller?.quickLook.detach(from: panel)
    }
}

// Shelf/ShelfController.swift
// Hermes
//
// Owns the shelf panel and decides when it opens, collapses to its handle or hides.

import AppKit
import Observation
import SwiftUI

enum ShelfMode {
    case hidden
    /// A slim tab at the screen edge, while there are items.
    case handle
    case open
}

enum ShelfTab: Hashable {
    case shelf
    case clipboard
}

/// What a drag out of the shelf carries.
enum DragPayload: Equatable {
    case items(Set<UUID>)
    case entry(item: UUID, entry: UUID)
    case clipboard(UUID)
}

@Observable
final class ShelfController {
    let store: ShelfStore
    let history: ClipboardHistory
    let reader: PasteboardReader

    private(set) var mode: ShelfMode = .hidden
    var tab: ShelfTab = .shelf
    var isDropTargeted = false
    var hoveredID: UUID?
    var expandedStackID: UUID?
    /// Briefly marks the history item just copied.
    var copiedID: UUID?

    /// Called after Hermes writes to the clipboard, so the history doesn't record its own copies.
    @ObservationIgnored var onWroteClipboard: (() -> Void)?
    @ObservationIgnored var onShowSettings: (() -> Void)?

    @ObservationIgnored private(set) var panel: ShelfPanel?
    @ObservationIgnored let quickLook = QuickLookSource()
    @ObservationIgnored private var collapseTask: Task<Void, Never>?
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var pointerTimer: Timer?
    @ObservationIgnored var keyMonitor: Any?
    @ObservationIgnored private var shake = ShakeDetector()
    @ObservationIgnored private(set) var isPointerInside = false
    @ObservationIgnored private var isExternalDragActive = false
    @ObservationIgnored var isInternalDragActive = false
    @ObservationIgnored private var screen: NSScreen?
    @ObservationIgnored var promiseStackID: UUID?

    init(store: ShelfStore, history: ClipboardHistory) {
        self.store = store
        self.history = history
        reader = PasteboardReader(storage: store.storage)
        observeContent()
    }

    // MARK: - Panel

    private func makePanel() -> ShelfPanel {
        if let panel { return panel }
        let panel = ShelfPanel(controller: self)
        // The panel decides its own size; letting SwiftUI size the window feeds back into layout.
        let hosting = ShelfHostingView(controller: self)
        hosting.sizingOptions = []
        panel.contentView = hosting
        self.panel = panel
        installKeyMonitor()
        return panel
    }

    private func openHeight(in visible: NSRect) -> CGFloat {
        let content = switch tab {
        case .shelf:
            ShelfLayout.contentHeight(tiles: store.items.count,
                                      expandedEntries: expandedStackID.flatMap(store.item)?.entries.count ?? 0)
        case .clipboard:
            ShelfLayout.clipboardContentHeight(rows: history.items.count)
        }
        return ShelfLayout.height(for: Preferences.size, contentHeight: content,
                                  maxHeight: visible.height - 2 * ShelfLayout.edgeInset)
    }

    /// Keeps the panel in step with what it shows: resizes automatic shelves, shows or hides the handle.
    private func observeContent() {
        withObservationTracking {
            _ = store.items
            _ = history.items
            _ = expandedStackID
            _ = tab
        } onChange: { [weak self] in
            guard let self else { return }
            // Fires before the change lands, so react on the next turn.
            Task { @MainActor in
                self.contentChanged()
                self.observeContent()
            }
        }
    }

    private func contentChanged() {
        switch mode {
        case .open:
            if Preferences.size.isAutomatic { apply(.open) }
        case .handle:
            if store.isEmpty || !Preferences.keepHandle { apply(.hidden) }
        case .hidden:
            if !store.isEmpty, Preferences.keepHandle { apply(.handle) }
        }
    }

    private func apply(_ newMode: ShelfMode) {
        let panel = makePanel()
        let changed = newMode != mode
        mode = newMode
        updatePointerPolling()
        guard newMode != .hidden else {
            panel.orderOut(nil)
            return
        }
        let screen = screen ?? Self.screenWithPointer()
        let visible = screen.visibleFrame
        let frame = ShelfLayout.frame(for: newMode, edge: Preferences.edge, position: Preferences.position,
                                      height: openHeight(in: visible), in: visible)
        if !panel.isVisible {
            panel.setFrame(frame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
        } else if changed || panel.frame != frame {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        }
    }

    static func screenWithPointer() -> NSScreen {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    // MARK: - Showing and hiding

    func open(tab: ShelfTab? = nil, focus: Bool = false) {
        cancelCollapse()
        if let tab { self.tab = tab }
        if mode == .hidden { screen = Self.screenWithPointer() }
        apply(.open)
        if focus { panel?.makeKey() }
    }

    /// Down to the handle, or away entirely when there's nothing to come back to.
    func collapse() {
        cancelCollapse()
        guard !isInternalDragActive else { return }
        expandedStackID = nil
        isDropTargeted = false
        if store.isEmpty || !Preferences.keepHandle {
            apply(.hidden)
        } else {
            apply(.handle)
        }
    }

    func toggle(tab: ShelfTab = .shelf) {
        if mode == .open, self.tab == tab {
            collapse()
        } else {
            open(tab: tab, focus: true)
        }
    }

    /// Re-applies the current mode after settings or the shelf contents change.
    func refreshPlacement() {
        switch mode {
        case .hidden:
            if !store.isEmpty, Preferences.keepHandle { apply(.handle) }
        case .handle:
            collapse()
        case .open:
            apply(.open)
        }
    }

    func scheduleCollapse(after delay: TimeInterval = 0.8) {
        cancelCollapse()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, !self.isPointerInside, !self.isExternalDragActive,
                  !self.isInternalDragActive, !self.quickLook.isVisible else { return }
            self.collapse()
        }
    }

    private func cancelCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    /// Polled rather than tracked: tracking areas miss enter and exit while a drag is in flight.
    private func updatePointerPolling() {
        guard mode != .hidden else {
            pointerTimer?.invalidate()
            pointerTimer = nil
            isPointerInside = false
            return
        }
        guard pointerTimer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPointer() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
    }

    private func pollPointer() {
        guard let panel, panel.isVisible else { return }
        let inside = NSMouseInRect(NSEvent.mouseLocation, panel.frame.insetBy(dx: -2, dy: -2), false)
        guard inside != isPointerInside else { return }
        if inside {
            pointerEntered()
        } else {
            pointerExited()
        }
    }

    private func pointerEntered() {
        isPointerInside = true
        cancelCollapse()
        guard mode == .handle else { return }
        hoverTask?.cancel()
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled, self.isPointerInside else { return }
            self.open()
        }
    }

    private func pointerExited() {
        isPointerInside = false
        hoverTask?.cancel()
        hoveredID = nil
        if mode == .open, panel?.isKeyWindow != true { scheduleCollapse() }
    }

    func panelResignedKey() {
        guard mode == .open, !isPointerInside, !quickLook.isVisible else { return }
        scheduleCollapse(after: 0.2)
    }

    // MARK: - Drags in other apps

    func externalDragBegan(at point: NSPoint) {
        isExternalDragActive = true
        shake.reset()
        if Preferences.trigger == .anyDrag, mode != .open {
            screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            open(tab: .shelf)
        }
    }

    func externalDragMoved(to point: NSPoint) {
        guard mode != .open else { return }
        switch Preferences.trigger {
        case .shake:
            if shake.add(x: point.x, at: ProcessInfo.processInfo.systemUptime) {
                screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
                open(tab: .shelf)
            }
        case .edge:
            guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else { return }
            let atEdge = Preferences.edge == .right ? point.x >= screen.frame.maxX - 4 : point.x <= screen.frame.minX + 4
            if atEdge {
                self.screen = screen
                open(tab: .shelf)
            }
        case .anyDrag, .manual:
            break
        }
    }

    func externalDragEnded() {
        isExternalDragActive = false
        isDropTargeted = false
        if mode == .open, !isPointerInside { scheduleCollapse(after: 0.3) }
    }
}

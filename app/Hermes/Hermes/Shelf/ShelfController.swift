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
    }

    // MARK: - Panel

    private func makePanel() -> ShelfPanel {
        if let panel { return panel }
        let panel = ShelfPanel(controller: self)
        let container = DropTargetView(controller: self)
        let hosting = NSHostingView(rootView: ShelfRootView(controller: self))
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        panel.contentView = container
        self.panel = panel
        installKeyMonitor()
        return panel
    }

    static let openSize = CGSize(width: 184, height: 520)
    static let handleSize = CGSize(width: 22, height: 88)
    static let edgeInset: CGFloat = 8

    /// Where the panel sits for a mode, against the visible area of its screen.
    static func frame(for mode: ShelfMode, edge: ShelfEdge, in visible: NSRect) -> NSRect {
        let size = mode == .handle ? handleSize : CGSize(width: openSize.width,
                                                         height: min(openSize.height, visible.height - 2 * edgeInset))
        let inset = mode == .handle ? 0 : edgeInset
        let x = edge == .right ? visible.maxX - size.width - inset : visible.minX + inset
        return NSRect(x: x, y: (visible.midY - size.height / 2).rounded(), width: size.width, height: size.height)
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
        let frame = Self.frame(for: newMode, edge: Preferences.edge, in: screen.visibleFrame)
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

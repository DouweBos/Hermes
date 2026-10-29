// Monitors/DragMonitor.swift
// Hermes
//
// Notices drags in other apps. A drag-and-drop writes to the drag pasteboard, so a change in its count
// while the button is held tells it apart from moving a window or selecting text.
// Global event monitors never see mouse events in the Dock, so the button state is also polled.

import AppKit

final class DragMonitor {
    var onBegan: ((NSPoint) -> Void)?
    var onMoved: ((NSPoint) -> Void)?
    var onEnded: (() -> Void)?

    private(set) var isDragging = false
    private var monitors: [Any] = []
    private var timer: Timer?
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var changeCountAtRelease = 0
    private var isPressed = false
    /// Presses that start in Hermes are its own drags, which the shelf handles itself.
    private var pressedInHermes = false
    private var lastLocation: NSPoint?

    func start() {
        guard monitors.isEmpty else { return }
        changeCountAtRelease = dragPasteboard.changeCount
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] _ in
            self?.update()
        }
        if let global { monitors.append(global) }
        let local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.pressedInHermes = true
            return event
        }
        if let local { monitors.append(local) }
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.update() }
        timer.tolerance = 0.01
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        timer?.invalidate()
        timer = nil
        isDragging = false
    }

    private func update() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            released()
            return
        }
        isPressed = true
        guard !pressedInHermes else { return }
        let location = NSEvent.mouseLocation
        if isDragging {
            if location != lastLocation { onMoved?(location) }
        } else if dragPasteboard.changeCount != changeCountAtRelease {
            isDragging = true
            onBegan?(location)
        }
        lastLocation = location
    }

    private func released() {
        pressedInHermes = false
        guard isPressed else { return }
        isPressed = false
        lastLocation = nil
        changeCountAtRelease = dragPasteboard.changeCount
        if isDragging {
            isDragging = false
            onEnded?()
        }
    }
}

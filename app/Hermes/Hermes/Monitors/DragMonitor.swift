// Monitors/DragMonitor.swift
// Hermes
//
// Notices drags in other apps. A drag-and-drop writes to the drag pasteboard, so a change in its count
// between mouse down and the first drag event tells it apart from moving a window or selecting text.

import AppKit

final class DragMonitor {
    var onBegan: ((NSPoint) -> Void)?
    var onMoved: ((NSPoint) -> Void)?
    var onEnded: (() -> Void)?

    private(set) var isDragging = false
    private var monitors: [Any] = []
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var changeCountAtMouseDown = 0

    func start() {
        guard monitors.isEmpty else { return }
        changeCountAtMouseDown = dragPasteboard.changeCount
        let events: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        let global = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            self?.handle(event)
        }
        if let global { monitors.append(global) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        isDragging = false
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            changeCountAtMouseDown = dragPasteboard.changeCount
        case .leftMouseDragged:
            if isDragging {
                onMoved?(NSEvent.mouseLocation)
            } else if dragPasteboard.changeCount != changeCountAtMouseDown {
                isDragging = true
                onBegan?(NSEvent.mouseLocation)
            }
        case .leftMouseUp:
            changeCountAtMouseDown = dragPasteboard.changeCount
            if isDragging {
                isDragging = false
                onEnded?()
            }
        default:
            break
        }
    }
}

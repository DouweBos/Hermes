// Shelf/ItemDragSourceView.swift
// Hermes
//
// Clicks, drags and context menus for a tile. AppKit rather than SwiftUI's onDrag, which can't drag
// several files at once or tell where a drag ended.

import AppKit
import SwiftUI

enum InteractionTarget: Equatable {
    case item(UUID)
    case entry(item: UUID, entry: UUID)
    case clipboard(UUID)

    var hoverID: UUID {
        switch self {
        case .item(let id), .clipboard(let id): id
        case .entry(_, let entry): entry
        }
    }
}

struct ItemInteraction: NSViewRepresentable {
    let controller: ShelfController
    let target: InteractionTarget

    func makeNSView(context: Context) -> ItemDragSourceView {
        ItemDragSourceView(controller: controller, target: target)
    }

    func updateNSView(_ view: ItemDragSourceView, context: Context) {
        view.target = target
    }
}

final class ItemDragSourceView: NSView, NSDraggingSource {
    var target: InteractionTarget
    private weak var controller: ShelfController?
    private var mouseDownEvent: NSEvent?
    private var selectOnMouseUp = false
    private var payload: DragPayload?

    init(controller: ShelfController, target: InteractionTarget) {
        self.controller = controller
        self.target = target
        super.init(frame: .zero)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseEntered(with event: NSEvent) {
        controller?.hoveredID = target.hoverID
    }

    override func mouseExited(with event: NSEvent) {
        if controller?.hoveredID == target.hoverID { controller?.hoveredID = nil }
    }

    // MARK: - Clicks

    override func mouseDown(with event: NSEvent) {
        guard let controller else { return }
        mouseDownEvent = event
        selectOnMouseUp = false
        if event.clickCount == 2 {
            doubleClick(controller)
            return
        }
        guard case .item(let id) = target else { return }
        let modifiers = event.modifierFlags.intersection([.command, .shift])
        if !modifiers.isEmpty || !controller.store.selection.contains(id) {
            controller.click(id, modifiers: modifiers)
        } else {
            // Keep a multiple selection intact in case this turns into a drag.
            selectOnMouseUp = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownEvent = nil }
        guard let controller, mouseDownEvent != nil, event.clickCount < 2 else { return }
        switch target {
        case .item(let id):
            if selectOnMouseUp { controller.click(id, modifiers: []) }
        case .clipboard(let id):
            controller.copyHistoryItem(id)
        case .entry:
            break
        }
    }

    private func doubleClick(_ controller: ShelfController) {
        switch target {
        case .item(let id):
            controller.open(controller.store.entries(for: [id]))
        case .entry:
            controller.open(entries(controller))
        case .clipboard:
            break
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let controller else { return nil }
        if case .item(let id) = target, !controller.store.selection.contains(id) {
            controller.click(id, modifiers: [])
        }
        return controller.menu(for: target)
    }

    // MARK: - Dragging

    override func mouseDragged(with event: NSEvent) {
        guard let controller, let down = mouseDownEvent, payload == nil else { return }
        let start = down.locationInWindow, now = event.locationInWindow
        guard hypot(now.x - start.x, now.y - start.y) >= 4 else { return }

        let payload: DragPayload = switch target {
        case .item(let id): controller.dragPayload(startingAt: id)
        case .entry(let item, let entry): .entry(item: item, entry: entry)
        case .clipboard(let id): .clipboard(id)
        }
        let entries = controller.entries(for: payload)
        guard !entries.isEmpty else { return }

        let local = convert(down.locationInWindow, from: nil)
        let items = entries.enumerated().map { index, entry in
            let item = NSDraggingItem(pasteboardWriter: PasteboardWriter.item(for: entry))
            let offset = CGFloat(min(index, 4)) * 6
            let frame = NSRect(x: local.x - 32 + offset, y: local.y - 32 - offset, width: 64, height: 64)
            item.setDraggingFrame(frame, contents: Thumbnails.shared.immediateImage(for: entry, size: 64))
            return item
        }
        self.payload = payload
        selectOnMouseUp = false
        mouseDownEvent = nil
        controller.dragBegan(payload)
        let session = beginDraggingSession(with: items, event: down, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }

    private func entries(_ controller: ShelfController) -> [ShelfEntry] {
        switch target {
        case .item(let id): controller.store.entries(for: [id])
        case .entry(let item, let entry): controller.entries(for: .entry(item: item, entry: entry))
        case .clipboard(let id): controller.entries(for: .clipboard(id))
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        guard context == .outsideApplication, let controller, let payload else { return [] }
        let entries = controller.entries(for: payload)
        // Hermes' own copies of text and images can only be copied; referenced files behave as in Finder.
        let referencesOnly = entries.allSatisfy { $0.kind == .file && !controller.store.storage.owns($0) }
        if referencesOnly, case .clipboard = payload {
            return [.copy, .link, .generic]
        }
        return referencesOnly ? [.copy, .move, .link, .generic, .delete] : [.copy, .generic, .delete]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard let payload else { return }
        self.payload = nil
        controller?.dragEnded(payload, operation: operation)
    }
}

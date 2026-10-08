// Shelf/DropTargetView.swift
// Hermes
//
// The panel's content view: takes drops anywhere on the shelf.

import AppKit

final class DropTargetView: NSView {
    private weak var controller: ShelfController?

    init(controller: ShelfController) {
        self.controller = controller
        super.init(frame: .zero)
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes([.fileURL, .URL, .string, .rtf, .png, .tiff] + PasteboardReader.imageTypes + promiseTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - NSDraggingDestination

    /// Drags that started on the shelf itself aren't drops.
    private func isOwnDrag(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingSource is ItemDragSourceView
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !isOwnDrag(sender) else { return [] }
        controller?.dropEntered()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        isOwnDrag(sender) ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        controller?.dropExited()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !isOwnDrag(sender) else { return false }
        return controller?.performDrop(sender.draggingPasteboard) ?? false
    }
}

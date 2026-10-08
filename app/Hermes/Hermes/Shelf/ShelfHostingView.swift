// Shelf/ShelfHostingView.swift
// Hermes
//
// The panel's content view: hosts the SwiftUI shelf and takes drops anywhere on it.

import AppKit
import SwiftUI

final class ShelfHostingView: NSHostingView<ShelfRootView> {
    private weak var controller: ShelfController?

    init(controller: ShelfController) {
        self.controller = controller
        super.init(rootView: ShelfRootView(controller: controller))
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes([.fileURL, .URL, .string, .rtf, .png, .tiff] + PasteboardReader.imageTypes + promiseTypes)
    }

    @available(*, unavailable)
    required init(rootView: ShelfRootView) { fatalError("init(rootView:) has not been implemented") }

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

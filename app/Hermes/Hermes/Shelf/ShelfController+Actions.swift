// Shelf/ShelfController+Actions.swift
// Hermes
//
// What the shelf does with drops, clicks, keys and menu commands.

import AppKit

extension ShelfController {
    // MARK: - Dropping in

    func dropEntered() {
        isDropTargeted = true
        tab = .shelf
        if mode != .open { open() }
    }

    func dropExited() {
        isDropTargeted = false
    }

    func performDrop(_ pasteboard: NSPasteboard) -> Bool {
        isDropTargeted = false
        let hasFiles = pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
        if !hasFiles, !promises.isEmpty {
            receive(promises)
            return true
        }
        let entries = reader.entries(from: pasteboard, prefer: .images)
        guard !entries.isEmpty else { return false }
        add(entries, source: .drop)
        return true
    }

    /// Files apps hand over only as promises (Mail attachments, Photos) arrive one by one into one stack.
    private func receive(_ promises: [NSFilePromiseReceiver]) {
        promiseStackID = nil
        for promise in promises {
            guard let folder = store.storage.makePromiseDirectory() else { continue }
            promise.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: .main) { [weak self] url, error in
                guard error == nil else { return }
                MainActor.assumeIsolated { self?.receivedPromisedFile(url) }
            }
        }
    }

    private func receivedPromisedFile(_ url: URL) {
        let entry = store.storage.fileEntry(for: url)
        if Preferences.stackDrops, let id = promiseStackID, store.item(id) != nil {
            store.append([entry], to: id)
        } else {
            promiseStackID = store.add([entry], source: .drop).first?.id
        }
        refreshPlacement()
    }

    func add(_ entries: [ShelfEntry], source: ItemSource) {
        store.add(entries, source: source, stacked: Preferences.stackDrops)
        expandedStackID = nil
        refreshPlacement()
    }

    func pasteFromClipboard() {
        let entries = reader.entries(from: .general, prefer: .text)
        guard !entries.isEmpty else {
            NSSound.beep()
            return
        }
        add(entries, source: .paste)
        open(tab: .shelf)
    }

    func addScreenshot(_ url: URL) {
        add([store.storage.fileEntry(for: url)], source: .screenshot)
        open(tab: .shelf)
        if !isPointerInside { scheduleCollapse(after: 3) }
    }

    // MARK: - Dragging out

    func entries(for payload: DragPayload) -> [ShelfEntry] {
        switch payload {
        case .items(let ids):
            return store.entries(for: ids)
        case .entry(let itemID, let entryID):
            return store.item(itemID)?.entries.filter { $0.id == entryID } ?? []
        case .clipboard(let id):
            return history.item(id)?.entries ?? []
        }
    }

    /// The items a drag starting on this one should carry: the whole selection when it's part of it.
    func dragPayload(startingAt id: UUID) -> DragPayload {
        if !store.selection.contains(id) { store.selection = [id] }
        return .items(store.selection)
    }

    func dragBegan(_ payload: DragPayload) {
        isInternalDragActive = true
    }

    func dragEnded(_ payload: DragPayload, operation: NSDragOperation) {
        isInternalDragActive = false
        if !operation.isEmpty {
            let keep = NSEvent.modifierFlags.contains(.option) && !operation.contains(.delete)
            let remove = operation.contains(.delete) || (Preferences.removeAfterDragOut && !keep)
            switch payload {
            case .items(let ids):
                store.didDragOut(ids, removeAfterDragOut: remove)
            case .entry(let itemID, let entryID):
                store.didDragOutEntry(entryID, from: itemID, removeAfterDragOut: remove)
            case .clipboard:
                break
            }
        }
        if store.isEmpty, tab == .shelf, !isPointerInside {
            collapse()
        } else if !isPointerInside {
            scheduleCollapse()
        }
    }

    // MARK: - Items

    func click(_ id: UUID, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            store.selection.formSymmetricDifference([id])
        } else if modifiers.contains(.shift), let anchor = store.items.firstIndex(where: { store.selection.contains($0.id) }),
                  let target = store.items.firstIndex(where: { $0.id == id }) {
            store.selection = Set(store.items[min(anchor, target)...max(anchor, target)].map(\.id))
        } else {
            store.selection = [id]
        }
    }

    func toggleExpanded(_ id: UUID) {
        expandedStackID = expandedStackID == id ? nil : id
    }

    func open(_ entries: [ShelfEntry]) {
        for entry in entries {
            NSWorkspace.shared.open(entry.linkURL ?? entry.url)
        }
    }

    func reveal(_ entries: [ShelfEntry]) {
        NSWorkspace.shared.activateFileViewerSelecting(entries.map(\.url))
    }

    func copy(_ entries: [ShelfEntry]) {
        PasteboardWriter.copy(entries)
        onWroteClipboard?()
    }

    func remove(_ ids: Set<UUID>) {
        store.remove(ids)
        if store.isEmpty, mode == .handle { collapse() }
    }

    func clearShelf() {
        store.clear()
        if store.isEmpty, mode != .open { collapse() }
    }

    func showQuickLook(_ entries: [ShelfEntry]) {
        guard !entries.isEmpty else { return }
        quickLook.show(entries.map(\.url), from: panel)
    }

    func toggleQuickLook(_ entries: [ShelfEntry]) {
        if quickLook.isVisible {
            quickLook.close()
        } else {
            showQuickLook(entries)
        }
    }

    // MARK: - Clipboard history

    func copyHistoryItem(_ id: UUID) {
        guard let item = history.item(id) else { return }
        copy(item.entries)
        history.promote(id)
        copiedID = id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            if self?.copiedID == id { self?.copiedID = nil }
        }
    }

    func addHistoryItemToShelf(_ id: UUID) {
        guard let item = history.item(id) else { return }
        let entries = item.entries.compactMap(store.storage.duplicate)
        add(entries, source: .clipboard)
    }

    // MARK: - Keys

    func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel, self.handleKey(event) else { return event }
            return nil
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        let selected = store.entries(for: store.selection)
        switch (event.keyCode, command, event.charactersIgnoringModifiers) {
        case (53, _, _): collapse()
        case (49, false, _): toggleQuickLook(selected)
        case (51, _, _), (117, _, _): remove(store.selection)
        case (36, _, _): open(selected)
        case (126, false, _): store.selectNeighbor(-1)
        case (125, false, _): store.selectNeighbor(1)
        case (_, true, "a"): store.selectAll()
        case (_, true, "c"): copy(selected)
        case (_, true, "v"): pasteFromClipboard()
        default: return false
        }
        return true
    }
}

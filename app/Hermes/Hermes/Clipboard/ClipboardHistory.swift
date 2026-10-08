// Clipboard/ClipboardHistory.swift
// Hermes
//
// Recent clipboard contents, newest first. Copying something again moves it back to the top.

import Foundation
import Observation

@Observable
final class ClipboardHistory {
    private(set) var items: [ShelfItem] = []

    let storage: ItemStorage
    private let fileName: String

    init(storage: ItemStorage, fileName: String = "clipboard.json") {
        self.storage = storage
        self.fileName = fileName
        items = (storage.load([ShelfItem].self, from: fileName) ?? []).filter { item in
            item.entries.allSatisfy(storage.exists)
        }
    }

    func item(_ id: UUID) -> ShelfItem? {
        items.first { $0.id == id }
    }

    func contains(fingerprint: String) -> Bool {
        items.contains { $0.fingerprint == fingerprint }
    }

    /// Records a clipboard change. Returns false when it was already the newest entry.
    @discardableResult
    func record(_ entries: [ShelfEntry], limit: Int) -> Bool {
        guard !entries.isEmpty else { return false }
        let item = ShelfItem(entries: entries, source: .clipboard)
        if items.first?.fingerprint == item.fingerprint {
            storage.deleteOwnedFiles(of: entries)
            return false
        }
        if let existing = items.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
            // Keep the older copy's files; the new ones are duplicates.
            let moved = items.remove(at: existing)
            storage.deleteOwnedFiles(of: entries)
            items.insert(moved, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        trim(to: limit)
        save()
        return true
    }

    /// Moves an item to the top, as the clipboard now holds it.
    func promote(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }), index > 0 else { return }
        items.insert(items.remove(at: index), at: 0)
        save()
    }

    func remove(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        storage.deleteOwnedFiles(of: items.remove(at: index).entries)
        save()
    }

    func clear() {
        storage.deleteOwnedFiles(of: items.flatMap(\.entries))
        items.removeAll()
        save()
    }

    func trim(to limit: Int) {
        guard items.count > limit else { return }
        storage.deleteOwnedFiles(of: items[limit...].flatMap(\.entries))
        items.removeSubrange(limit...)
        save()
    }

    private func save() {
        storage.save(items, to: fileName)
    }
}

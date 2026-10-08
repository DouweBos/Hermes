// Shelf/ShelfStore.swift
// Hermes
//
// The items on the shelf, newest first, saved after every change.

import Foundation
import Observation

@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []
    /// The last batch removed, kept with its files so it can be brought back.
    private(set) var recentlyRemoved: [ShelfItem] = []
    var selection: Set<UUID> = []

    let storage: ItemStorage
    private let fileName: String
    private let removedFileName: String

    init(storage: ItemStorage, fileName: String = "shelf.json", removedFileName: String = "removed.json") {
        self.storage = storage
        self.fileName = fileName
        self.removedFileName = removedFileName
        items = storage.load([ShelfItem].self, from: fileName) ?? []
        recentlyRemoved = storage.load([ShelfItem].self, from: removedFileName) ?? []
        refresh()
    }

    var isEmpty: Bool { items.isEmpty }

    func item(_ id: UUID) -> ShelfItem? {
        items.first { $0.id == id }
    }

    /// Entries for a drag or copy, in shelf order.
    func entries(for ids: Set<UUID>) -> [ShelfEntry] {
        items.filter { ids.contains($0.id) }.flatMap(\.entries)
    }

    var selectedItems: [ShelfItem] {
        items.filter { selection.contains($0.id) }
    }

    // MARK: - Adding

    /// Adds entries as one stack, or one item each when `stacked` is off.
    @discardableResult
    func add(_ entries: [ShelfEntry], source: ItemSource, stacked: Bool = true) -> [ShelfItem] {
        guard !entries.isEmpty else { return [] }
        let added = stacked
            ? [ShelfItem(entries: entries, source: source)]
            : entries.map { ShelfItem(entries: [$0], source: source) }
        items.insert(contentsOf: added, at: 0)
        selection = Set(added.map(\.id))
        save()
        return added
    }

    /// Adds entries to an existing item, turning it into a stack.
    func append(_ entries: [ShelfEntry], to id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].entries.append(contentsOf: entries)
        save()
    }

    // MARK: - Removing

    func remove(_ ids: Set<UUID>) {
        let removed = items.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        replaceRecentlyRemoved(with: removed)
        save()
    }

    func removeEntry(_ entryID: UUID, from itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              let entry = items[index].entries.first(where: { $0.id == entryID }) else { return }
        if items[index].entries.count == 1 {
            remove([itemID])
            return
        }
        let item = items[index]
        items[index].entries.removeAll { $0.id == entryID }
        replaceRecentlyRemoved(with: [ShelfItem(entries: [entry], source: item.source)])
        save()
    }

    var canRestore: Bool { !recentlyRemoved.isEmpty }

    /// Puts the last removed items back on top, minus any whose files have since gone.
    func restoreRemoved() {
        let restored = recentlyRemoved.compactMap { item -> ShelfItem? in
            var item = item
            item.entries = item.entries.map(storage.resolve).filter(storage.exists)
            return item.entries.isEmpty ? nil : item
        }
        recentlyRemoved = []
        storage.save(recentlyRemoved, to: removedFileName)
        guard !restored.isEmpty else { return }
        items.insert(contentsOf: restored, at: 0)
        selection = Set(restored.map(\.id))
        save()
    }

    /// Only one batch is kept; the previous one's stored content goes for good.
    private func replaceRecentlyRemoved(with removed: [ShelfItem]) {
        storage.deleteOwnedFiles(of: recentlyRemoved.flatMap(\.entries))
        recentlyRemoved = removed
        storage.save(recentlyRemoved, to: removedFileName)
    }

    /// Clears everything except pinned items.
    func clear() {
        remove(Set(items.filter { !$0.isPinned }.map(\.id)))
    }

    /// After a drag to another app: the items leave the shelf unless they're pinned or the user asked to keep them.
    func didDragOut(_ ids: Set<UUID>, removeAfterDragOut: Bool) {
        guard removeAfterDragOut else {
            refresh()
            return
        }
        remove(Set(items.filter { ids.contains($0.id) && !$0.isPinned }.map(\.id)))
        refresh()
    }

    func didDragOutEntry(_ entryID: UUID, from itemID: UUID, removeAfterDragOut: Bool) {
        if removeAfterDragOut, item(itemID)?.isPinned == false {
            removeEntry(entryID, from: itemID)
        }
        refresh()
    }

    // MARK: - Arranging

    func togglePin(_ ids: Set<UUID>) {
        let pin = items.contains { ids.contains($0.id) && !$0.isPinned }
        for index in items.indices where ids.contains(items[index].id) {
            items[index].isPinned = pin
        }
        save()
    }

    /// Breaks a stack into one item per entry, in place.
    func split(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].isStack else { return }
        let stack = items[index]
        let parts = stack.entries.map {
            ShelfItem(entries: [$0], addedAt: stack.addedAt, source: stack.source, isPinned: stack.isPinned)
        }
        items.replaceSubrange(index...index, with: parts)
        selection = Set(parts.map(\.id))
        save()
    }

    /// Combines items into one stack at the position of the first.
    func combine(_ ids: Set<UUID>) {
        let parts = items.filter { ids.contains($0.id) }
        guard parts.count > 1, let index = items.firstIndex(where: { ids.contains($0.id) }) else { return }
        let stack = ShelfItem(entries: parts.flatMap(\.entries), source: parts[0].source,
                              isPinned: parts.contains(where: \.isPinned))
        items.removeAll { ids.contains($0.id) }
        items.insert(stack, at: min(index, items.count))
        selection = [stack.id]
        save()
    }

    func move(_ id: UUID, by offset: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let target = max(0, min(items.count - 1, index + offset))
        guard target != index else { return }
        items.insert(items.remove(at: index), at: target)
        save()
    }

    // MARK: - Selection

    func selectAll() {
        selection = Set(items.map(\.id))
    }

    /// Moves the selection up or down one item.
    func selectNeighbor(_ offset: Int) {
        guard !items.isEmpty else { return }
        let current = items.firstIndex { selection.contains($0.id) }
        let next = current.map { max(0, min(items.count - 1, $0 + offset)) } ?? (offset > 0 ? 0 : items.count - 1)
        selection = [items[next].id]
    }

    // MARK: - Upkeep

    /// Follows moved files and drops entries whose file is gone.
    func refresh() {
        var changed = false
        var refreshed: [ShelfItem] = []
        for var item in items {
            let entries = item.entries.map(storage.resolve).filter(storage.exists)
            if entries != item.entries {
                changed = true
                item.entries = entries
            }
            if !entries.isEmpty { refreshed.append(item) }
        }
        guard changed else { return }
        items = refreshed
        selection.formIntersection(Set(items.map(\.id)))
        save()
    }

    private func save() {
        storage.save(items, to: fileName)
    }
}

// ShelfStoreTests.swift
// HermesTests
//
// Adding, stacking, pinning and removing items, and that it all survives a relaunch.

import Foundation
import Testing
@testable import Hermes

@MainActor
struct ShelfStoreTests {
    private let storage = makeStorage()

    private func entries(_ count: Int) -> [ShelfEntry] {
        (0..<count).map { storage.fileEntry(for: makeFile(named: "File \($0).txt")) }
    }

    @Test func dropsTogetherFormOneStack() {
        let store = ShelfStore(storage: storage)
        store.add(entries(3), source: .drop)
        #expect(store.items.count == 1)
        #expect(store.items[0].isStack)
        #expect(store.items[0].title == "3 Items")
    }

    @Test func unstackedDropsAreSeparateItems() {
        let store = ShelfStore(storage: storage)
        store.add(entries(3), source: .drop, stacked: false)
        #expect(store.items.count == 3)
    }

    @Test func newestComesFirstAndIsSelected() {
        let store = ShelfStore(storage: storage)
        store.add(entries(1), source: .drop)
        let added = store.add(entries(1), source: .paste)
        #expect(store.items.first?.id == added.first?.id)
        #expect(store.selection == Set(added.map(\.id)))
    }

    @Test func itemsSurviveARelaunch() {
        let store = ShelfStore(storage: storage)
        store.add(entries(2), source: .drop)
        store.togglePin([store.items[0].id])
        let reopened = ShelfStore(storage: storage)
        #expect(reopened.items == store.items)
        #expect(reopened.items[0].isPinned)
    }

    @Test func splitAndCombineRoundTrip() {
        let store = ShelfStore(storage: storage)
        store.add(entries(3), source: .drop)
        store.split(store.items[0].id)
        #expect(store.items.count == 3)
        store.combine(Set(store.items.map(\.id)))
        #expect(store.items.count == 1)
        #expect(store.items[0].entries.count == 3)
    }

    @Test func draggingOutRemovesUnlessPinned() {
        let store = ShelfStore(storage: storage)
        store.add(entries(1), source: .drop)
        store.add(entries(1), source: .drop)
        let pinned = store.items[0].id, loose = store.items[1].id
        store.togglePin([pinned])
        store.didDragOut([pinned, loose], removeAfterDragOut: true)
        #expect(store.items.map(\.id) == [pinned])
    }

    @Test func draggingOutKeepsItemsWhenTurnedOff() {
        let store = ShelfStore(storage: storage)
        store.add(entries(1), source: .drop)
        store.didDragOut([store.items[0].id], removeAfterDragOut: false)
        #expect(store.items.count == 1)
    }

    @Test func clearKeepsPinnedItems() {
        let store = ShelfStore(storage: storage)
        store.add(entries(1), source: .drop)
        store.add(entries(1), source: .drop)
        store.togglePin([store.items[1].id])
        store.clear()
        #expect(store.items.count == 1)
        #expect(store.items[0].isPinned)
    }

    @Test func removingTheLastEntryOfAStackRemovesIt() {
        let store = ShelfStore(storage: storage)
        store.add(entries(2), source: .drop)
        let item = store.items[0]
        store.removeEntry(item.entries[0].id, from: item.id)
        #expect(store.items[0].entries.count == 1)
        store.removeEntry(item.entries[1].id, from: item.id)
        #expect(store.isEmpty)
    }

    @Test func removingDeletesStoredContent() throws {
        let store = ShelfStore(storage: storage)
        let text = try #require(storage.textEntry("note"))
        store.add([text], source: .paste)
        store.remove([store.items[0].id])
        #expect(!FileManager.default.fileExists(atPath: text.path))
    }

    @Test func entriesWhoseFileIsGoneDropOff() throws {
        let store = ShelfStore(storage: storage)
        let file = makeFile()
        store.add([storage.fileEntry(for: file)], source: .drop)
        try FileManager.default.removeItem(at: file)
        store.refresh()
        #expect(store.isEmpty)
    }

    @Test func selectingNeighborsStaysInBounds() {
        let store = ShelfStore(storage: storage)
        store.add(entries(3), source: .drop, stacked: false)
        store.selection = [store.items[0].id]
        store.selectNeighbor(-1)
        #expect(store.selection == [store.items[0].id])
        store.selectNeighbor(1)
        #expect(store.selection == [store.items[1].id])
    }
}

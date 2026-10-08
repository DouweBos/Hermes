// ClipboardHistoryTests.swift
// HermesTests
//
// Recording, de-duplicating and trimming the clipboard history.

import Foundation
import Testing
@testable import Hermes

@MainActor
struct ClipboardHistoryTests {
    private let storage = makeStorage()

    private func text(_ string: String) throws -> [ShelfEntry] {
        [try #require(storage.textEntry(string))]
    }

    @Test func recordsNewestFirst() throws {
        let history = ClipboardHistory(storage: storage)
        history.record(try text("one"), limit: 10)
        history.record(try text("two"), limit: 10)
        #expect(history.items.map { $0.entries[0].text } == ["two", "one"])
    }

    @Test func copyingTheSameThingTwiceKeepsOneEntry() throws {
        let history = ClipboardHistory(storage: storage)
        history.record(try text("same"), limit: 10)
        let duplicate = try text("same")
        #expect(!history.record(duplicate, limit: 10))
        #expect(history.items.count == 1)
        #expect(!FileManager.default.fileExists(atPath: duplicate[0].path))
    }

    @Test func copyingAnOlderThingMovesItUp() throws {
        let history = ClipboardHistory(storage: storage)
        history.record(try text("a"), limit: 10)
        history.record(try text("b"), limit: 10)
        history.record(try text("a"), limit: 10)
        #expect(history.items.map { $0.entries[0].text } == ["a", "b"])
    }

    @Test func trimsToTheLimitAndDeletesWhatFallsOff() throws {
        let history = ClipboardHistory(storage: storage)
        let oldest = try text("0")
        history.record(oldest, limit: 3)
        for index in 1...3 { history.record(try text("\(index)"), limit: 3) }
        #expect(history.items.count == 3)
        #expect(!FileManager.default.fileExists(atPath: oldest[0].path))
    }

    @Test func survivesARelaunch() throws {
        let history = ClipboardHistory(storage: storage)
        history.record(try text("kept"), limit: 10)
        #expect(ClipboardHistory(storage: storage).items == history.items)
    }
}

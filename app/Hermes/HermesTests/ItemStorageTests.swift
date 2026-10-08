// ItemStorageTests.swift
// HermesTests
//
// Stored copies, names and following moved files.

import Foundation
import Testing
@testable import Hermes

struct ItemStorageTests {
    @Test func textIsStoredAsAFileNamedAfterItsFirstLine() throws {
        let storage = makeStorage()
        let entry = try #require(storage.textEntry("Shopping list\nmilk\neggs"))
        #expect(entry.kind == .text)
        #expect(entry.url.lastPathComponent == "Shopping list.txt")
        #expect(try String(contentsOf: entry.url, encoding: .utf8) == "Shopping list\nmilk\neggs")
        #expect(storage.owns(entry))
    }

    @Test func fileNamesDropSlashesAndStayShort() {
        #expect(ItemStorage.sanitized("a/b:c") == "a-b-c")
        let long = String(repeating: "word ", count: 20)
        #expect(ItemStorage.fileName(summarizing: long).count <= 41)
    }

    @Test func linksBecomeWeblocFiles() throws {
        let storage = makeStorage()
        let url = try #require(URL(string: "https://example.com/page"))
        let entry = try #require(storage.linkEntry(url, title: "Example"))
        #expect(entry.url.pathExtension == "webloc")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: entry.url), format: nil) as? [String: String]
        #expect(plist?["URL"] == "https://example.com/page")
        #expect(entry.linkURL == url)
    }

    @Test func referencedFilesAreNotOwned() {
        let storage = makeStorage()
        let entry = storage.fileEntry(for: makeFile())
        #expect(entry.kind == .file)
        #expect(!storage.owns(entry))
    }

    @Test func resolvingFollowsAMovedFile() throws {
        let storage = makeStorage()
        let original = makeFile(named: "Draft.txt")
        let entry = storage.fileEntry(for: original)
        let moved = original.deletingLastPathComponent().appendingPathComponent("Final.txt")
        try FileManager.default.moveItem(at: original, to: moved)

        let resolved = storage.resolve(entry)
        #expect(resolved.path == moved.resolvingSymlinksInPath().path)
        #expect(resolved.name == "Final.txt")
    }

    @Test func deletingRemovesOnlyOwnedFiles() throws {
        let storage = makeStorage()
        let text = try #require(storage.textEntry("hello"))
        let file = makeFile()
        storage.deleteOwnedFiles(of: [text, storage.fileEntry(for: file)])
        #expect(!FileManager.default.fileExists(atPath: text.path))
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func duplicatesGetTheirOwnFiles() throws {
        let storage = makeStorage()
        let text = try #require(storage.textEntry("hello"))
        let copy = try #require(storage.duplicate(text))
        #expect(copy.path != text.path)
        storage.deleteOwnedFiles(of: [text])
        #expect(FileManager.default.fileExists(atPath: copy.path))
    }
}

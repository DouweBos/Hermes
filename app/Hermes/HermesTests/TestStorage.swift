// TestStorage.swift
// HermesTests
//
// A throwaway storage root per test.

import Foundation
@testable import Hermes

func makeStorage() -> ItemStorage {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("HermesTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return ItemStorage(root: root)
}

/// A real file outside the storage root, for reference entries.
func makeFile(named name: String = "Report.pdf", contents: String = "data") -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("HermesFiles-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent(name)
    try? Data(contents.utf8).write(to: url)
    return url
}

// Models/ShelfItem.swift
// Hermes
//
// A tile on the shelf. Several entries dropped together form a stack that moves as one.

import Foundation

enum ItemSource: String, Codable, Hashable {
    case drop
    case paste
    case clipboard
    case screenshot
}

struct ShelfItem: Identifiable, Codable, Hashable {
    let id: UUID
    var entries: [ShelfEntry]
    var addedAt: Date
    var source: ItemSource
    /// Pinned items stay when dragged out and survive Clear.
    var isPinned: Bool

    init(id: UUID = UUID(), entries: [ShelfEntry], addedAt: Date = .now,
         source: ItemSource = .drop, isPinned: Bool = false) {
        self.id = id
        self.entries = entries
        self.addedAt = addedAt
        self.source = source
        self.isPinned = isPinned
    }

    var isStack: Bool { entries.count > 1 }

    var title: String {
        guard isStack else { return entries.first?.name ?? "" }
        return "\(entries.count) Items"
    }

    var fingerprint: String {
        entries.map(\.fingerprint).joined(separator: "\n")
    }
}

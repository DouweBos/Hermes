// Models/ShelfEntry.swift
// Hermes
//
// One thing on the shelf: a referenced file, or text, a link or an image that Hermes keeps a copy of.

import Foundation
import UniformTypeIdentifiers

enum EntryKind: String, Codable, Hashable {
    case file
    case text
    case richText
    case link
    case image
}

struct ShelfEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: EntryKind
    var name: String
    /// The referenced file, or the copy in Hermes' data directory for everything else.
    var path: String
    /// Follows a referenced file when it's moved or renamed.
    var bookmark: Data?
    /// Plain text body, or the address of a link.
    var text: String?
    /// Identifies the content, so the clipboard history can skip what it already has.
    var fingerprint: String

    init(id: UUID = UUID(), kind: EntryKind, name: String, path: String,
         bookmark: Data? = nil, text: String? = nil, fingerprint: String) {
        self.id = id
        self.kind = kind
        self.name = name
        self.path = path
        self.bookmark = bookmark
        self.text = text
        self.fingerprint = fingerprint
    }

    var url: URL { URL(fileURLWithPath: path) }

    var linkURL: URL? {
        guard kind == .link, let text else { return nil }
        return URL(string: text)
    }

    var contentType: UTType? {
        UTType(filenameExtension: url.pathExtension)
    }

    var isImage: Bool {
        kind == .image || contentType?.conforms(to: .image) == true
    }
}

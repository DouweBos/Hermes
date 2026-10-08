// Storage/ItemStorage.swift
// Hermes
//
// Where the shelf lives on disk: the item lists as JSON, and a folder per entry for content Hermes owns.

import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct ItemStorage {
    let root: URL

    static let live = ItemStorage(root: defaultRoot)

    private static var defaultRoot: URL {
        if let override = UserDefaults.standard.string(forKey: "HermesStorage") {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Hermes", isDirectory: true)
    }

    var dataDirectory: URL { root.appendingPathComponent("Data", isDirectory: true) }

    // MARK: - Lists

    func load<Value: Decodable>(_ type: Value.Type, from name: String) -> Value? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func save(_ value: some Encodable, to name: String) {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: root.appendingPathComponent(name), options: .atomic)
        } catch {
            NSLog("Hermes: couldn't save \(name): \(error)")
        }
    }

    // MARK: - Making entries

    func fileEntry(for url: URL) -> ShelfEntry {
        // Canonical, so the path matches what resolving the bookmark later returns.
        let url = url.standardizedFileURL.resolvingSymlinksInPath()
        return ShelfEntry(kind: .file, name: FileManager.default.displayName(atPath: url.path), path: url.path,
                          bookmark: try? url.bookmarkData(), fingerprint: "file:" + url.path)
    }

    func textEntry(_ text: String, rtf: Data? = nil) -> ShelfEntry? {
        let id = UUID()
        let base = Self.fileName(summarizing: text)
        let entry: ShelfEntry
        if let rtf {
            guard let url = write(rtf, id: id, name: base + ".rtf") else { return nil }
            entry = ShelfEntry(id: id, kind: .richText, name: base, path: url.path, text: text,
                               fingerprint: "text:" + text)
        } else {
            guard let url = write(Data(text.utf8), id: id, name: base + ".txt") else { return nil }
            entry = ShelfEntry(id: id, kind: .text, name: base, path: url.path, text: text,
                               fingerprint: "text:" + text)
        }
        return entry
    }

    func linkEntry(_ link: URL, title: String? = nil) -> ShelfEntry? {
        let id = UUID()
        let name = title.flatMap { $0.isEmpty ? nil : $0 } ?? link.host() ?? link.absoluteString
        let plist = ["URL": link.absoluteString]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
              let url = write(data, id: id, name: Self.sanitized(name) + ".webloc") else { return nil }
        return ShelfEntry(id: id, kind: .link, name: name, path: url.path, text: link.absoluteString,
                          fingerprint: "link:" + link.absoluteString)
    }

    /// Stores the image as PNG unless it already is a compact format.
    func imageEntry(_ data: Data, type: UTType, name: String? = nil) -> ShelfEntry? {
        let id = UUID()
        var data = data
        var ext = type.preferredFilenameExtension ?? "png"
        if ![UTType.png, .jpeg, .gif, .heic].contains(type) {
            guard let rep = NSBitmapImageRep(data: data),
                  let png = rep.representation(using: .png, properties: [:]) else { return nil }
            data = png
            ext = "png"
        }
        let base = name.map { Self.sanitized($0) } ?? "Image \(Self.timestamp())"
        guard let url = write(data, id: id, name: base + "." + ext) else { return nil }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return ShelfEntry(id: id, kind: .image, name: base, path: url.path, fingerprint: "image:" + digest)
    }

    /// A folder for receiving files that apps hand over as promises.
    func makePromiseDirectory() -> URL? {
        let url = dataDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)) == nil ? nil : url
    }

    /// A copy whose stored files are independent, for moving entries between the shelf and the clipboard history.
    func duplicate(_ entry: ShelfEntry) -> ShelfEntry? {
        guard owns(entry) else { return ShelfEntry(kind: entry.kind, name: entry.name, path: entry.path,
                                                   bookmark: entry.bookmark, text: entry.text,
                                                   fingerprint: entry.fingerprint) }
        let id = UUID()
        let folder = dataDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        let target = folder.appendingPathComponent(entry.url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: entry.url, to: target)
        } catch {
            return nil
        }
        return ShelfEntry(id: id, kind: entry.kind, name: entry.name, path: target.path, text: entry.text,
                          fingerprint: entry.fingerprint)
    }

    // MARK: - Resolving and cleanup

    /// The entry's current location; a referenced file that moved gets its new path.
    func resolve(_ entry: ShelfEntry) -> ShelfEntry {
        guard entry.kind == .file, let bookmark = entry.bookmark else { return entry }
        var stale = false
        guard let url = (try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale))?.resolvingSymlinksInPath(),
              url.path != entry.path || stale else { return entry }
        var resolved = entry
        resolved.path = url.path
        resolved.name = FileManager.default.displayName(atPath: url.path)
        if stale { resolved.bookmark = try? url.bookmarkData() }
        return resolved
    }

    func exists(_ entry: ShelfEntry) -> Bool {
        FileManager.default.fileExists(atPath: entry.path)
    }

    /// Content Hermes made itself, as opposed to files it only points at.
    func owns(_ entry: ShelfEntry) -> Bool {
        entry.url.resolvingSymlinksInPath().path.hasPrefix(dataDirectory.resolvingSymlinksInPath().path + "/")
    }

    func deleteOwnedFiles(of entries: [ShelfEntry]) {
        for entry in entries where owns(entry) {
            let folder = entry.url.deletingLastPathComponent()
            let isEntryFolder = folder.deletingLastPathComponent().resolvingSymlinksInPath().path
                == dataDirectory.resolvingSymlinksInPath().path
            let target = isEntryFolder ? folder : entry.url
            try? FileManager.default.removeItem(at: target)
        }
    }

    // MARK: - Helpers

    private func write(_ data: Data, id: UUID, name: String) -> URL? {
        let folder = dataDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        let url = folder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            NSLog("Hermes: couldn't write \(name): \(error)")
            return nil
        }
    }

    /// The first line, short enough for a file name.
    static func fileName(summarizing text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let short = trimmed.count > 40 ? String(trimmed.prefix(40)).trimmingCharacters(in: .whitespaces) + "…" : trimmed
        let name = sanitized(short)
        return name.isEmpty ? "Text \(timestamp())" : name
    }

    static func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        return name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespaces))
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: .now)
    }
}

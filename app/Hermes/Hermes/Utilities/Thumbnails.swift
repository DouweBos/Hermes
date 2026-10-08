// Utilities/Thumbnails.swift
// Hermes
//
// Quick Look thumbnails for entries, cached, with the Finder icon as a fallback.

import AppKit
import QuickLookThumbnailing

final class Thumbnails {
    static let shared = Thumbnails()

    private let cache = NSCache<NSString, NSImage>()

    /// Whatever is ready now: a cached thumbnail or the file's icon. Used for drag images.
    func immediateImage(for entry: ShelfEntry, size: CGFloat) -> NSImage {
        if let cached = cache.object(forKey: key(entry, size)) { return cached }
        return icon(for: entry)
    }

    func image(for entry: ShelfEntry, size: CGFloat) async -> NSImage {
        let key = key(entry, size)
        if let cached = cache.object(forKey: key) { return cached }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: entry.url, size: CGSize(width: size, height: size),
                                                   scale: scale, representationTypes: .thumbnail)
        let image: NSImage
        if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            image = representation.nsImage
        } else {
            image = icon(for: entry)
        }
        cache.setObject(image, forKey: key)
        return image
    }

    func icon(for entry: ShelfEntry) -> NSImage {
        NSWorkspace.shared.icon(forFile: entry.path)
    }

    private func key(_ entry: ShelfEntry, _ size: CGFloat) -> NSString {
        "\(entry.path)#\(Int(size))" as NSString
    }
}

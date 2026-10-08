// Pasteboard/PasteboardWriter.swift
// Hermes
//
// Puts entries back on a pasteboard for dragging out or copying. Each one carries its file as well as
// its text, link or image, so Finder gets a file and an editor gets the content.

import AppKit
import UniformTypeIdentifiers

enum PasteboardWriter {
    static func item(for entry: ShelfEntry) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        switch entry.kind {
        case .file:
            break
        case .text:
            item.setString(entry.text ?? "", forType: .string)
        case .richText:
            if let rtf = try? Data(contentsOf: entry.url) {
                item.setData(rtf, forType: .rtf)
            }
            item.setString(entry.text ?? "", forType: .string)
        case .link:
            if let link = entry.linkURL {
                item.setString(link.absoluteString, forType: .URL)
                item.setString(link.absoluteString, forType: .string)
                item.setString(entry.name, forType: .init("public.url-name"))
            }
        case .image:
            if let data = try? Data(contentsOf: entry.url) {
                let type = NSPasteboard.PasteboardType(entry.contentType?.identifier ?? "public.png")
                item.setData(data, forType: type)
                if type != .tiff, let tiff = NSImage(data: data)?.tiffRepresentation {
                    item.setData(tiff, forType: .tiff)
                }
            }
        }
        item.setString(entry.url.absoluteString, forType: .fileURL)
        return item
    }

    static func copy(_ entries: [ShelfEntry], to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.writeObjects(entries.map { item(for: $0) })
    }
}

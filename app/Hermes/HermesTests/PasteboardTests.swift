// PasteboardTests.swift
// HermesTests
//
// Reading drops and the clipboard into entries, and writing entries back out.

import AppKit
import Testing
@testable import Hermes

@MainActor
struct PasteboardTests {
    private let storage = makeStorage()
    private var reader: PasteboardReader { PasteboardReader(storage: storage) }

    private func pasteboard(_ write: (NSPasteboard) -> Void) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: .init("HermesTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        write(pasteboard)
        return pasteboard
    }

    @Test func filesWinOverEverythingElse() {
        let file = makeFile()
        let board = pasteboard { $0.writeObjects([file as NSURL]) }
        let entries = reader.entries(from: board, prefer: .text)
        #expect(entries.map(\.kind) == [.file])
        #expect(entries.first?.path == file.resolvingSymlinksInPath().path)
    }

    @Test func aBareAddressIsALink() {
        let board = pasteboard { $0.setString("  https://example.com/a  ", forType: .string) }
        let entries = reader.entries(from: board, prefer: .text)
        #expect(entries.map(\.kind) == [.link])
        #expect(entries.first?.text == "https://example.com/a")
    }

    @Test func sentencesWithAddressesAreText() {
        let board = pasteboard { $0.setString("see https://example.com", forType: .string) }
        #expect(reader.entries(from: board, prefer: .text).map(\.kind) == [.text])
    }

    @Test func richTextKeepsItsFormatting() throws {
        let attributed = NSAttributedString(string: "Bold", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)])
        let rtf = try attributed.data(from: NSRange(location: 0, length: 4),
                                      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let board = pasteboard {
            $0.declareTypes([.rtf, .string], owner: nil)
            $0.setData(rtf, forType: .rtf)
            $0.setString("Bold", forType: .string)
        }
        let entry = try #require(reader.entries(from: board, prefer: .text).first)
        #expect(entry.kind == .richText)
        #expect(entry.url.pathExtension == "rtf")
    }

    @Test func dropsPreferImagesOverText() throws {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let tiff = try #require(image.tiffRepresentation)
        let board = pasteboard {
            $0.declareTypes([.tiff, .string], owner: nil)
            $0.setData(tiff, forType: .tiff)
            $0.setString("caption", forType: .string)
        }
        #expect(reader.entries(from: board, prefer: .images).first?.kind == .image)
        #expect(reader.entries(from: board, prefer: .text).first?.kind == .text)
    }

    @Test func barePNGLooksLikeAScreenshot() throws {
        let png = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
                                                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)?
            .representation(using: .png, properties: [:]))
        let screenshot = pasteboard { $0.setData(png, forType: .png) }
        #expect(PasteboardReader.isLikelyScreenshot(screenshot))
        let copiedImage = pasteboard {
            $0.declareTypes([.png, .tiff], owner: nil)
            $0.setData(png, forType: .png)
            $0.setData(png, forType: .tiff)
        }
        #expect(!PasteboardReader.isLikelyScreenshot(copiedImage))
        let text = pasteboard { $0.setString("hi", forType: .string) }
        #expect(!PasteboardReader.isLikelyScreenshot(text))
    }

    @Test func concealedContentIsRecognized() {
        let board = pasteboard {
            $0.declareTypes([.string, .init("org.nspasteboard.ConcealedType")], owner: nil)
            $0.setString("hunter2", forType: .string)
        }
        #expect(PasteboardReader.isConcealed(board))
    }

    @Test func writtenTextCarriesItsFileToo() throws {
        let entry = try #require(storage.textEntry("hello"))
        let item = PasteboardWriter.item(for: entry)
        #expect(item.string(forType: .string) == "hello")
        #expect(item.string(forType: .fileURL) == entry.url.absoluteString)
    }

    @Test func writtenLinksCarryTheirAddress() throws {
        let url = try #require(URL(string: "https://example.com"))
        let entry = try #require(storage.linkEntry(url))
        let item = PasteboardWriter.item(for: entry)
        #expect(item.string(forType: .URL) == "https://example.com")
    }
}

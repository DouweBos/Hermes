// App/ExternalRequest.swift
// Hermes
//
// What another app or the `hermes` command asks for: files opened with Hermes, or a `hermes://` URL.

import Foundation

enum ExternalRequest: Equatable {
    enum Content: Equatable {
        case file(URL)
        case text(String)
        case link(URL)
    }

    /// `hermes://add?path=…&text=…&url=…`, in the order given.
    case add([Content])
    /// `hermes://show?tab=shelf|clipboard`
    case show(ShelfTab)

    static let scheme = "hermes"

    /// Files opened with Hermes add to the shelf; `hermes://` URLs are parsed; anything else is ignored.
    static func requests(for urls: [URL]) -> [ExternalRequest] {
        let files = urls.filter(\.isFileURL)
        let commands = urls.filter { $0.scheme?.lowercased() == scheme }.compactMap(ExternalRequest.init)
        return (files.isEmpty ? [] : [.add(files.map(Content.file))]) + commands
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []
        switch components.host?.lowercased() {
        case "add":
            let contents = items.compactMap(Self.content)
            guard !contents.isEmpty else { return nil }
            self = .add(contents)
        case "show":
            let tab = items.first { $0.name == "tab" }?.value
            self = .show(tab == "clipboard" ? .clipboard : .shelf)
        default:
            return nil
        }
    }

    private static func content(_ item: URLQueryItem) -> Content? {
        guard let value = item.value, !value.isEmpty else { return nil }
        switch item.name {
        case "path":
            return .file(URL(fileURLWithPath: (value as NSString).expandingTildeInPath))
        case "url":
            return PasteboardReader.webURL(value).map(Content.link)
        case "text":
            // A lone address piped in is a link, as when pasting it.
            if let link = PasteboardReader.webURL(value) { return .link(link) }
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .text(value)
        default:
            return nil
        }
    }
}

// Monitors/ScreenshotWatcher.swift
// Hermes
//
// Reports screenshots taken after it starts, wherever they're saved, through Spotlight's screen capture flag.

import Foundation

final class ScreenshotWatcher {
    var onScreenshot: ((URL) -> Void)?

    private var query: NSMetadataQuery?
    private var known: Set<String> = []
    private var observers: [NSObjectProtocol] = []

    var isRunning: Bool { query != nil }

    func start() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture = 1")
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.gathered() }
            },
            center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] note in
                let added = note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
                let paths = added.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
                MainActor.assumeIsolated { self?.added(paths) }
            }
        ]
        self.query = query
        query.start()
    }

    func stop() {
        query?.stop()
        query = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        known.removeAll()
    }

    private func gathered() {
        guard let query else { return }
        query.disableUpdates()
        for index in 0..<query.resultCount {
            if let item = query.result(at: index) as? NSMetadataItem,
               let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                known.insert(path)
            }
        }
        query.enableUpdates()
    }

    private func added(_ paths: [String]) {
        for path in paths where !known.contains(path) {
            known.insert(path)
            onScreenshot?(URL(fileURLWithPath: path))
        }
    }
}

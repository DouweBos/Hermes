// ScreenshotWatcherTests.swift
// HermesTests
//
// The Spotlight query has to parse, or the watcher silently finds nothing.

import Foundation
import Testing
@testable import Hermes

@MainActor
struct ScreenshotWatcherTests {
    @Test func queryParsesAndCoversRecordings() throws {
        let predicate = try #require(ScreenshotWatcher.predicate)
        #expect(predicate.predicateFormat.contains("kMDItemIsScreenCapture"))
        #expect(predicate.predicateFormat.contains("Screen Recording"))
    }
}

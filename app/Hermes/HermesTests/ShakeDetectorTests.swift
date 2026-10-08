// ShakeDetectorTests.swift
// HermesTests
//
// Telling a shake apart from ordinary dragging.

import Foundation
import Testing
@testable import Hermes

struct ShakeDetectorTests {
    @Test func quickBackAndForthIsAShake() {
        var detector = ShakeDetector()
        let xs: [CGFloat] = [500, 560, 500, 560, 500]
        let results = xs.enumerated().map { index, x in detector.add(x: x, at: Double(index) * 0.1) }
        #expect(results.last == true)
    }

    @Test func steadyDragIsNot() {
        var detector = ShakeDetector()
        let results = stride(from: 0, to: 800, by: 20).enumerated().map { index, x in
            detector.add(x: CGFloat(x), at: Double(index) * 0.02)
        }
        #expect(!results.contains(true))
    }

    @Test func slowSwingsAreNot() {
        var detector = ShakeDetector()
        let xs: [CGFloat] = [500, 560, 500, 560, 500]
        let results = xs.enumerated().map { index, x in detector.add(x: x, at: Double(index) * 0.5) }
        #expect(!results.contains(true))
    }

    @Test func smallJitterIsNot() {
        var detector = ShakeDetector()
        let xs: [CGFloat] = [500, 510, 500, 510, 500, 510, 500]
        let results = xs.enumerated().map { index, x in detector.add(x: x, at: Double(index) * 0.05) }
        #expect(!results.contains(true))
    }
}

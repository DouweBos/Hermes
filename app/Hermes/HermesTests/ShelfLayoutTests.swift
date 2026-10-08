// ShelfLayoutTests.swift
// HermesTests
//
// Where the panel sits on screen.

import AppKit
import Testing
@testable import Hermes

@MainActor
struct ShelfLayoutTests {
    private let visible = NSRect(x: 0, y: 0, width: 1440, height: 875)

    @Test func openShelfHugsTheRightEdge() {
        let frame = ShelfController.frame(for: .open, edge: .right, in: visible)
        #expect(frame.maxX == visible.maxX - ShelfController.edgeInset)
        #expect(abs(frame.midY - visible.midY) <= 1)
    }

    @Test func handleSitsFlushOnTheLeftEdge() {
        let frame = ShelfController.frame(for: .handle, edge: .left, in: visible)
        #expect(frame.minX == visible.minX)
        #expect(frame.size == ShelfController.handleSize)
    }

    @Test func shortScreensShrinkTheShelf() {
        let short = NSRect(x: 0, y: 0, width: 1024, height: 400)
        let frame = ShelfController.frame(for: .open, edge: .right, in: short)
        #expect(frame.height == 400 - 2 * ShelfController.edgeInset)
    }

    @Test func secondScreensUseTheirOwnOrigin() {
        let second = NSRect(x: 1440, y: 200, width: 1920, height: 1055)
        let frame = ShelfController.frame(for: .open, edge: .left, in: second)
        #expect(frame.minX == second.minX + ShelfController.edgeInset)
        #expect(second.contains(frame))
    }
}

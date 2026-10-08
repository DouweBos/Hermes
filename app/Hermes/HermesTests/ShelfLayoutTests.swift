// ShelfLayoutTests.swift
// HermesTests
//
// Where the panel sits on screen and how tall it gets.

import AppKit
import Testing
@testable import Hermes

@MainActor
struct ShelfLayoutTests {
    private let visible = NSRect(x: 0, y: 0, width: 1440, height: 875)
    private var maxHeight: CGFloat { visible.height - 2 * ShelfLayout.edgeInset }

    private func frame(_ mode: ShelfMode = .open, edge: ShelfEdge = .right, position: ShelfPosition = .center,
                       height: CGFloat = 400, in rect: NSRect? = nil) -> NSRect {
        ShelfLayout.frame(for: mode, edge: edge, position: position, height: height, in: rect ?? visible)
    }

    @Test func openShelfHugsTheRightEdge() {
        let frame = frame()
        #expect(frame.maxX == visible.maxX - ShelfLayout.edgeInset)
        #expect(abs(frame.midY - visible.midY) <= 1)
    }

    @Test func handleSitsFlushOnTheLeftEdge() {
        let frame = frame(.handle, edge: .left)
        #expect(frame.minX == visible.minX)
        #expect(frame.size == ShelfLayout.handleSize)
    }

    @Test func topAndBottomKeepTheInset() {
        #expect(frame(position: .top).maxY == visible.maxY - ShelfLayout.edgeInset)
        #expect(frame(position: .bottom).minY == visible.minY + ShelfLayout.edgeInset)
    }

    @Test func neverTallerThanTheScreen() {
        let short = NSRect(x: 0, y: 0, width: 1024, height: 400)
        #expect(frame(height: 2000, in: short).height == 400 - 2 * ShelfLayout.edgeInset)
    }

    @Test func secondScreensUseTheirOwnOrigin() {
        let second = NSRect(x: 1440, y: 200, width: 1920, height: 1055)
        let frame = frame(edge: .left, in: second)
        #expect(frame.minX == second.minX + ShelfLayout.edgeInset)
        #expect(second.contains(frame))
    }

    @Test func fixedSizesIgnoreTheContent() {
        let lots = ShelfLayout.contentHeight(tiles: 20, expandedEntries: 0)
        #expect(ShelfLayout.height(for: .standard, contentHeight: lots, maxHeight: maxHeight) == ShelfLayout.height(rows: 3))
        #expect(ShelfLayout.height(for: .smallest, contentHeight: lots, maxHeight: maxHeight) == ShelfLayout.height(rows: 1))
        #expect(ShelfLayout.height(for: .largest, contentHeight: 0, maxHeight: maxHeight) == maxHeight)
    }

    @Test func automaticGrowsFromItsMinimumToTheScreen() {
        let two = ShelfLayout.contentHeight(tiles: 2, expandedEntries: 0)
        let four = ShelfLayout.contentHeight(tiles: 4, expandedEntries: 0)
        let many = ShelfLayout.contentHeight(tiles: 40, expandedEntries: 0)
        #expect(ShelfLayout.height(for: .automatic, contentHeight: two, maxHeight: maxHeight) == ShelfLayout.height(rows: 3))
        #expect(ShelfLayout.height(for: .automatic, contentHeight: four, maxHeight: maxHeight) == ShelfLayout.height(rows: 4))
        #expect(ShelfLayout.height(for: .automaticSmallest, contentHeight: two, maxHeight: maxHeight) == two)
        #expect(ShelfLayout.height(for: .automatic, contentHeight: many, maxHeight: maxHeight) == maxHeight)
    }

    @Test func expandedStacksAddRows() {
        #expect(ShelfLayout.contentHeight(tiles: 1, expandedEntries: 3) > ShelfLayout.contentHeight(tiles: 1, expandedEntries: 0))
    }
}

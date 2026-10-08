// Shelf/ShelfLayout.swift
// Hermes
//
// Panel sizes and placement. Tiles have a fixed height so the shelf can be sized to a number of items.

import AppKit

enum ShelfLayout {
    static let width: CGFloat = 184
    static let handleSize = CGSize(width: 22, height: 88)
    static let edgeInset: CGFloat = 8
    static let headerHeight: CGFloat = 35
    static let listPadding: CGFloat = 8
    static let tileHeight: CGFloat = 124
    static let tileSpacing: CGFloat = 4
    static let entryRowHeight: CGFloat = 30
    static let clipboardRowHeight: CGFloat = 56

    /// Height that fits exactly `rows` tiles.
    static func height(rows: Int) -> CGFloat {
        let rows = CGFloat(max(1, rows))
        return headerHeight + 2 * listPadding + rows * tileHeight + (rows - 1) * tileSpacing
    }

    /// Height of the shelf tab's content: its tiles plus the rows of an expanded stack.
    static func contentHeight(tiles: Int, expandedEntries: Int) -> CGFloat {
        guard tiles > 0 else { return 0 }
        let rows = CGFloat(tiles + expandedEntries)
        return headerHeight + 2 * listPadding + CGFloat(tiles) * tileHeight
            + CGFloat(expandedEntries) * entryRowHeight + (rows - 1) * tileSpacing
    }

    static func clipboardContentHeight(rows: Int) -> CGFloat {
        guard rows > 0 else { return 0 }
        return headerHeight + 12 + CGFloat(rows) * clipboardRowHeight + CGFloat(rows - 1) * 2
    }

    static func height(for size: ShelfSize, contentHeight: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let height = switch size {
        case .standard: Self.height(rows: 3)
        case .smallest: Self.height(rows: 1)
        case .largest: maxHeight
        case .automatic: max(contentHeight, Self.height(rows: 3))
        case .automaticSmallest: max(contentHeight, Self.height(rows: 1))
        }
        return min(height, maxHeight)
    }

    /// Where the panel sits for a mode, against the visible area of its screen.
    static func frame(for mode: ShelfMode, edge: ShelfEdge, position: ShelfPosition,
                      height: CGFloat, in visible: NSRect) -> NSRect {
        let size = mode == .handle ? handleSize : CGSize(width: width, height: min(height, visible.height - 2 * edgeInset))
        let inset = mode == .handle ? 0 : edgeInset
        let x = edge == .right ? visible.maxX - size.width - inset : visible.minX + inset
        let y = switch position {
        case .top: visible.maxY - size.height - edgeInset
        case .center: (visible.midY - size.height / 2).rounded()
        case .bottom: visible.minY + edgeInset
        }
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

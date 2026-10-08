// Models/Preferences.swift
// Hermes
//
// User settings. Views bind through @AppStorage with these keys; services read the current values on use.

import Foundation

enum ShelfEdge: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }
    var title: String { self == .left ? "Left" : "Right" }
}

enum ShelfPosition: String, CaseIterable, Identifiable {
    case top
    case center
    case bottom

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ShelfSize: String, CaseIterable, Identifiable {
    case standard
    case largest
    case smallest
    /// Grows with the items, from room for three up to the screen height.
    case automatic
    /// Grows with the items, from room for one.
    case automaticSmallest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Default (3 Items)"
        case .largest: "Biggest"
        case .smallest: "Smallest"
        case .automatic: "Adjust Automatically (3 Items)"
        case .automaticSmallest: "Adjust Automatically (Smallest)"
        }
    }

    var isAutomatic: Bool { self == .automatic || self == .automaticSmallest }
}

enum ShelfTrigger: String, CaseIterable, Identifiable {
    /// Any drag of files, text or images.
    case anyDrag
    /// Shaking the pointer side to side while dragging.
    case shake
    /// Dragging to the edge of the screen the shelf sits on.
    case edge
    /// Only the shortcut and the menu bar.
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anyDrag: "When You Start Dragging"
        case .shake: "When You Shake While Dragging"
        case .edge: "When You Drag to the Screen Edge"
        case .manual: "Only from the Shortcut or Menu Bar"
        }
    }
}

enum SettingKey {
    static let edge = "shelfEdge"
    static let position = "shelfPosition"
    static let size = "shelfSize"
    static let trigger = "shelfTrigger"
    static let keepHandle = "keepHandleVisible"
    static let removeAfterDragOut = "removeAfterDragOut"
    static let stackDrops = "stackMultipleItems"
    static let clipboardHistory = "clipboardHistoryEnabled"
    static let clipboardLimit = "clipboardHistoryLimit"
    static let captureScreenshots = "captureScreenshots"
}

enum Preferences {
    static var defaults: UserDefaults = .standard

    static func registerDefaults() {
        defaults.register(defaults: [
            SettingKey.edge: ShelfEdge.right.rawValue,
            SettingKey.position: ShelfPosition.center.rawValue,
            SettingKey.size: ShelfSize.standard.rawValue,
            SettingKey.trigger: ShelfTrigger.anyDrag.rawValue,
            SettingKey.keepHandle: true,
            SettingKey.removeAfterDragOut: true,
            SettingKey.stackDrops: true,
            SettingKey.clipboardHistory: true,
            SettingKey.clipboardLimit: 50,
            SettingKey.captureScreenshots: false
        ])
    }

    static var edge: ShelfEdge {
        ShelfEdge(rawValue: defaults.string(forKey: SettingKey.edge) ?? "") ?? .right
    }

    static var position: ShelfPosition {
        ShelfPosition(rawValue: defaults.string(forKey: SettingKey.position) ?? "") ?? .center
    }

    static var size: ShelfSize {
        ShelfSize(rawValue: defaults.string(forKey: SettingKey.size) ?? "") ?? .standard
    }

    static var trigger: ShelfTrigger {
        ShelfTrigger(rawValue: defaults.string(forKey: SettingKey.trigger) ?? "") ?? .anyDrag
    }

    static var keepHandle: Bool { defaults.bool(forKey: SettingKey.keepHandle) }
    static var removeAfterDragOut: Bool { defaults.bool(forKey: SettingKey.removeAfterDragOut) }
    static var stackDrops: Bool { defaults.bool(forKey: SettingKey.stackDrops) }
    static var clipboardHistory: Bool { defaults.bool(forKey: SettingKey.clipboardHistory) }
    static var clipboardLimit: Int { max(5, defaults.integer(forKey: SettingKey.clipboardLimit)) }
    static var captureScreenshots: Bool { defaults.bool(forKey: SettingKey.captureScreenshots) }
}

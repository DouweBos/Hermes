// DesignSystem/Theme.swift
// Hermes
//
// Every color the UI uses. Values live in the asset catalog with light and dark variants.

import SwiftUI

enum Theme {
    static let background = Color(.background)
    static let surface = Color(.surface)
    static let surfaceRaised = Color(.surfaceRaised)
    static let border = Color(.border)
    static let textPrimary = Color(.textPrimary)
    static let textSecondary = Color(.textSecondary)
    static let accent = Color.accentColor
    static let success = Color(.success)
    static let warning = Color(.warning)
    static let danger = Color(.danger)

    static let selectionFill = accent.opacity(0.2)
    static let hoverFill = textSecondary.opacity(0.1)
    static let subtleFill = textSecondary.opacity(0.12)
    static let dropFill = accent.opacity(0.12)

    enum Radius {
        static let shelf: CGFloat = 18
        static let tile: CGFloat = 10
        static let thumbnail: CGFloat = 6
        static let pill: CGFloat = 20
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

extension Font {
    static let tileTitle = Font.system(size: 11, weight: .medium)
    static let tileCaption = Font.system(size: 10, weight: .regular)
    static let sectionLabel = Font.system(size: 12, weight: .semibold)
    static let badge = Font.system(size: 10, weight: .bold, design: .rounded)
    static let monoCaption = Font.system(size: 11, weight: .regular, design: .monospaced)
}

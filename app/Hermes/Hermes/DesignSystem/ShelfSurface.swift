// DesignSystem/ShelfSurface.swift
// Hermes
//
// The floating glass the shelf and its handle sit on.

import SwiftUI

struct ShelfSurface: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.shelf
    var highlighted = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.regularMaterial, in: shape)
            .background(highlighted ? Theme.dropFill : .clear, in: shape)
            .overlay(shape.strokeBorder(highlighted ? Theme.accent : Theme.border, lineWidth: highlighted ? 2 : 0.5))
            .clipShape(shape)
    }
}

extension View {
    func shelfSurface(cornerRadius: CGFloat = Theme.Radius.shelf, highlighted: Bool = false) -> some View {
        modifier(ShelfSurface(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}

#Preview {
    Text("Shelf")
        .frame(width: 160, height: 200)
        .shelfSurface(highlighted: true)
        .padding()
}

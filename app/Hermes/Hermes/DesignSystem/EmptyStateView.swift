// DesignSystem/EmptyStateView.swift
// Hermes
//
// Centered placeholder for an empty shelf or history.

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 48, height: 48)
                .background(Theme.subtleFill, in: Circle())
            Text(title)
                .font(.sectionLabel)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.tileCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(systemImage: "tray.and.arrow.down", title: "Drop Here", subtitle: "Files, text, links and images")
        .frame(width: 160, height: 260)
}

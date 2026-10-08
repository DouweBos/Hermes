// DesignSystem/CountBadge.swift
// Hermes
//
// Small accent pill with a number, for stacks and the handle.

import SwiftUI

struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.badge)
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Theme.accent, in: Capsule())
    }
}

#Preview {
    HStack { CountBadge(count: 3); CountBadge(count: 128) }.padding()
}

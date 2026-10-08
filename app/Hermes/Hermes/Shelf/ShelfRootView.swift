// Shelf/ShelfRootView.swift
// Hermes
//
// The panel's SwiftUI content: the edge handle, or the open shelf with its tabs.

import SwiftUI

struct ShelfRootView: View {
    let controller: ShelfController

    var body: some View {
        Group {
            if controller.mode == .handle {
                HandleView(count: controller.store.items.count)
            } else {
                ShelfView(controller: controller)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HandleView: View {
    let count: Int
    @AppStorage(SettingKey.edge) private var edge = ShelfEdge.right

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: edge == .right ? "chevron.compact.left" : "chevron.compact.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("\(count)")
                .font(.badge)
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shelfSurface(cornerRadius: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shelf, \(count) items")
    }
}

struct ShelfView: View {
    let controller: ShelfController

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.border).frame(height: 0.5)
            switch controller.tab {
            case .shelf: ShelfItemsView(controller: controller)
            case .clipboard: ClipboardListView(controller: controller)
            }
        }
        .shelfSurface(highlighted: controller.isDropTargeted)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs) {
            tabButton(.shelf, symbol: "tray.full", label: "Shelf")
            tabButton(.clipboard, symbol: "doc.on.clipboard", label: "Clipboard History")
            Spacer(minLength: 0)
            Menu {
                if controller.tab == .shelf {
                    Button("Paste to Shelf") { controller.pasteFromClipboard() }
                    Button("Clear Shelf") { controller.clearShelf() }
                        .disabled(controller.store.items.allSatisfy(\.isPinned))
                } else {
                    Button("Clear History") { controller.history.clear() }
                        .disabled(controller.history.items.isEmpty)
                }
                Divider()
                Button("Settings…") { controller.onShowSettings?() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
    }

    private func tabButton(_ tab: ShelfTab, symbol: String, label: String) -> some View {
        let selected = controller.tab == tab
        return Button {
            controller.tab = tab
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                .frame(width: 28, height: 22)
                .background(selected ? Theme.selectionFill : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Clipboard/ClipboardListView.swift
// Hermes
//
// The clipboard tab: click a row to copy it again, or drag it out.

import SwiftUI

struct ClipboardListView: View {
    let controller: ShelfController
    @AppStorage(SettingKey.clipboardHistory) private var isEnabled = true

    var body: some View {
        if controller.history.items.isEmpty {
            EmptyStateView(systemImage: "doc.on.clipboard", title: "Nothing Copied Yet",
                           subtitle: isEnabled ? "Text, links and images you copy show up here."
                                               : "Clipboard history is off in Settings.")
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(controller.history.items) { item in
                        ClipboardRow(controller: controller, item: item)
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.never)
        }
    }
}

struct ClipboardRow: View {
    let controller: ShelfController
    let item: ShelfItem

    private var isCopied: Bool { controller.copiedID == item.id }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if let entry = item.entries.first {
                EntryThumbnail(entry: entry, size: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(preview)
                    .font(.tileTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(3)
                Text(isCopied ? "Copied" : item.addedAt.formatted(.relative(presentation: .named)))
                    .font(.tileCaption)
                    .foregroundStyle(isCopied ? Theme.accent : Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.thumbnail, style: .continuous))
        .overlay(ItemInteraction(controller: controller, target: .clipboard(item.id)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preview)
        .accessibilityHint("Copies to the clipboard")
    }

    private var preview: String {
        guard !item.isStack, let entry = item.entries.first else { return item.title }
        let text = entry.kind == .file ? entry.name : entry.text ?? entry.name
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var fill: Color {
        isCopied ? Theme.selectionFill : controller.hoveredID == item.id ? Theme.hoverFill : .clear
    }
}

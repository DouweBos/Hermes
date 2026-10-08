// Shelf/ShelfItemsView.swift
// Hermes
//
// The shelf tab: one tile per item, with a stack's entries listed underneath when expanded.

import SwiftUI

struct ShelfItemsView: View {
    let controller: ShelfController

    var body: some View {
        if controller.store.items.isEmpty {
            EmptyStateView(systemImage: "tray.and.arrow.down", title: "Drop Here",
                           subtitle: "Files, text, links and images stay here until you drag them out.")
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.xs) {
                    ForEach(controller.store.items) { item in
                        ItemTile(controller: controller, item: item)
                        if controller.expandedStackID == item.id {
                            ForEach(item.entries) { entry in
                                StackEntryRow(controller: controller, itemID: item.id, entry: entry)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.sm)
            }
            .scrollIndicators(.never)
        }
    }
}

struct ItemTile: View {
    let controller: ShelfController
    let item: ShelfItem

    private var isSelected: Bool { controller.store.selection.contains(item.id) }
    private var isHovered: Bool { controller.hoveredID == item.id }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                StackThumbnail(item: item, size: 76)
                    .frame(maxWidth: .infinity)
                if item.isStack {
                    CountBadge(count: item.entries.count)
                        .offset(x: -18, y: -4)
                }
            }
            Text(item.title)
                .font(.tileTitle)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .overlay(ItemInteraction(controller: controller, target: .item(item.id)))
        .overlay(alignment: .topLeading) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if item.isStack, isHovered || controller.expandedStackID == item.id {
                Button {
                    controller.toggleExpanded(item.id)
                } label: {
                    Image(systemName: controller.expandedStackID == item.id ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(4)
                .help(controller.expandedStackID == item.id ? "Collapse Stack" : "Show Stack Items")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fill: Color {
        isSelected ? Theme.selectionFill : isHovered ? Theme.hoverFill : .clear
    }
}

struct StackEntryRow: View {
    let controller: ShelfController
    let itemID: UUID
    let entry: ShelfEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            EntryThumbnail(entry: entry, size: 24)
            Text(entry.name)
                .font(.tileCaption)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .padding(.leading, Theme.Spacing.sm)
        .background(controller.hoveredID == entry.id ? Theme.hoverFill : .clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.thumbnail, style: .continuous))
        .overlay(ItemInteraction(controller: controller, target: .entry(item: itemID, entry: entry.id)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.name)
    }
}

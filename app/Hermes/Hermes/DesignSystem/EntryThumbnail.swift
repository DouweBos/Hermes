// DesignSystem/EntryThumbnail.swift
// Hermes
//
// A square preview of an entry: the text itself for snippets, the host for links, a Quick Look thumbnail otherwise.

import SwiftUI

struct EntryThumbnail: View {
    let entry: ShelfEntry
    let size: CGFloat

    @State private var image: NSImage?

    var body: some View {
        Group {
            switch entry.kind {
            case .text, .richText:
                textPreview
            case .link:
                linkPreview
            case .file, .image:
                Image(nsImage: image ?? Thumbnails.shared.immediateImage(for: entry, size: size))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .task(id: entry.path) {
                        image = await Thumbnails.shared.image(for: entry, size: size)
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(entry.name)
    }

    private var textPreview: some View {
        Text(entry.text ?? entry.name)
            .font(.system(size: max(6, size / 10)))
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.leading)
            .padding(size / 12)
            .frame(width: size * 0.8, height: size, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.thumbnail, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.thumbnail, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 0.5))
            .clipped()
    }

    private var linkPreview: some View {
        VStack(spacing: size / 16) {
            Image(systemName: "link")
                .font(.system(size: size / 3, weight: .medium))
                .foregroundStyle(Theme.accent)
            if size >= 48 {
                Text(entry.linkURL?.host() ?? entry.name)
                    .font(.monoCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.thumbnail, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.thumbnail, style: .continuous)
            .strokeBorder(Theme.border, lineWidth: 0.5))
    }
}

/// Up to three entries fanned out, for stacks.
struct StackThumbnail: View {
    let item: ShelfItem
    let size: CGFloat

    var body: some View {
        let shown = Array(item.entries.prefix(3))
        ZStack {
            ForEach(Array(shown.enumerated().reversed()), id: \.element.id) { index, entry in
                EntryThumbnail(entry: entry, size: size * (shown.count > 1 ? 0.86 : 1))
                    .rotationEffect(.degrees(shown.count > 1 ? Double(index - 1) * -6 : 0))
                    .offset(x: CGFloat(index) * 3, y: CGFloat(index) * -2)
                    .shadow(color: .black.opacity(shown.count > 1 ? 0.15 : 0), radius: 2, y: 1)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    let text = ShelfEntry(kind: .text, name: "Notes", path: "/tmp/notes.txt",
                          text: "Remember to send the slides before Friday", fingerprint: "a")
    let link = ShelfEntry(kind: .link, name: "Apple", path: "/tmp/a.webloc", text: "https://apple.com", fingerprint: "b")
    HStack {
        EntryThumbnail(entry: text, size: 72)
        EntryThumbnail(entry: link, size: 72)
        StackThumbnail(item: ShelfItem(entries: [text, link]), size: 72)
    }
    .padding()
}

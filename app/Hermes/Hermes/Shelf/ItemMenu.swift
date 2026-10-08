// Shelf/ItemMenu.swift
// Hermes
//
// Context menus for tiles, stack entries and clipboard history.

import AppKit

/// A menu item that runs a closure.
final class ActionMenuItem: NSMenuItem, NSMenuItemValidation {
    private let handler: () -> Void
    /// Menus enable items through validation, so this stands in for `isEnabled`.
    var isAvailable = true

    init(_ title: String, symbol: String? = nil, state: NSControl.StateValue = .off, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        self.state = state
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func run() { handler() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { isAvailable }
}

extension ShelfController {
    func menu(for target: InteractionTarget) -> NSMenu {
        let menu = NSMenu()
        switch target {
        case .item:
            buildItemMenu(menu)
        case .entry(let itemID, let entryID):
            buildEntryMenu(menu, itemID: itemID, entryID: entryID)
        case .clipboard(let id):
            buildClipboardMenu(menu, id: id)
        }
        return menu
    }

    private func buildItemMenu(_ menu: NSMenu) {
        let ids = store.selection
        let items = store.selectedItems
        let entries = store.entries(for: ids)
        addCommonItems(to: menu, entries: entries)
        menu.addItem(.separator())
        let pinned = !items.isEmpty && items.allSatisfy(\.isPinned)
        menu.addItem(ActionMenuItem("Keep on Shelf", symbol: "pin", state: pinned ? .on : .off) { [weak self] in
            self?.store.togglePin(ids)
        })
        if items.count == 1, let stack = items.first, stack.isStack {
            menu.addItem(ActionMenuItem("Split Stack", symbol: "square.split.2x1") { [weak self] in
                self?.store.split(stack.id)
            })
        } else if items.count > 1 {
            menu.addItem(ActionMenuItem("Combine into Stack", symbol: "square.stack") { [weak self] in
                self?.store.combine(ids)
            })
        }
        menu.addItem(.separator())
        let title = items.count > 1 ? "Remove \(items.count) Items" : "Remove"
        menu.addItem(ActionMenuItem(title, symbol: "xmark") { [weak self] in
            self?.remove(ids)
        })
    }

    private func buildEntryMenu(_ menu: NSMenu, itemID: UUID, entryID: UUID) {
        addCommonItems(to: menu, entries: entries(for: .entry(item: itemID, entry: entryID)))
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Remove from Stack", symbol: "xmark") { [weak self] in
            self?.store.removeEntry(entryID, from: itemID)
        })
    }

    private func buildClipboardMenu(_ menu: NSMenu, id: UUID) {
        let entries = entries(for: .clipboard(id))
        menu.addItem(ActionMenuItem("Copy", symbol: "doc.on.doc") { [weak self] in
            self?.copyHistoryItem(id)
        })
        menu.addItem(ActionMenuItem("Add to Shelf", symbol: "tray.and.arrow.down") { [weak self] in
            self?.addHistoryItemToShelf(id)
        })
        menu.addItem(ActionMenuItem("Quick Look", symbol: "eye") { [weak self] in
            self?.showQuickLook(entries)
        })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Remove from History", symbol: "xmark") { [weak self] in
            self?.history.remove(id)
        })
    }

    private func addCommonItems(to menu: NSMenu, entries: [ShelfEntry]) {
        let title = entries.count > 1 ? "Open \(entries.count) Items" : "Open"
        menu.addItem(ActionMenuItem(title, symbol: "arrow.up.forward.app") { [weak self] in
            self?.open(entries)
        })
        menu.addItem(ActionMenuItem("Quick Look", symbol: "eye") { [weak self] in
            self?.showQuickLook(entries)
        })
        let files = entries.filter { $0.kind == .file }
        if !files.isEmpty {
            menu.addItem(ActionMenuItem("Show in Finder", symbol: "folder") { [weak self] in
                self?.reveal(files)
            })
        }
        menu.addItem(ActionMenuItem("Copy", symbol: "doc.on.doc") { [weak self] in
            self?.copy(entries)
        })
        let share = NSSharingServicePicker(items: entries.map(\.url)).standardShareMenuItem
        menu.addItem(share)
    }
}

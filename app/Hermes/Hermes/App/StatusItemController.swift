// App/StatusItemController.swift
// Hermes
//
// The menu bar item and its menu. AppKit rather than MenuBarExtra for Continuity Camera import and
// section headers in submenus.

import AppKit
import KeyboardShortcuts

final class StatusItemController: NSObject, NSMenuDelegate {
    private let controller: ShelfController
    private let showSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(controller: ShelfController, showSettings: @escaping () -> Void) {
        self.controller = controller
        self.showSettings = showSettings
        super.init()
        importResponder.onImport = { [controller] pasteboard in controller.importFromDevice(pasteboard) }
        let image = NSImage(resource: .menuBarIcon)
        image.isTemplate = true
        image.accessibilityDescription = "Hermes"
        statusItem.button?.image = image
        let menu = NSMenu()
        menu.delegate = self
        buildMenu(menu)
        statusItem.menu = menu
    }

    private let importResponder = DeviceImportResponder()
    private var restoreItem: ActionMenuItem?
    private var clearItem: ActionMenuItem?
    private var showItem: ActionMenuItem?
    private var positionMenu = NSMenu()
    private var sizeMenu = NSMenu()

    /// Built once: Continuity Camera only fills in an import item that's already in the menu.
    private func buildMenu(_ menu: NSMenu) {
        let restore = ActionMenuItem("Bring Back Last Removed Files", symbol: "arrow.uturn.backward") { [controller] in
            controller.restoreRemoved()
        }
        menu.addItem(restore)
        restoreItem = restore
        let paste = ActionMenuItem("Add Clipboard Contents to Hermes", symbol: "doc.on.clipboard") { [controller] in
            controller.pasteFromClipboard()
        }
        paste.setShortcut(for: .pasteToShelf)
        menu.addItem(paste)
        let importItem = NSMenuItem(title: "Import from iPhone or iPad", action: nil, keyEquivalent: "")
        importItem.identifier = NSMenuItem.importFromDeviceIdentifier
        importItem.image = NSImage(systemSymbolName: "laptopcomputer.and.iphone", accessibilityDescription: nil)
        menu.addItem(importItem)
        let clear = ActionMenuItem("Clear Shelf", symbol: "trash") { [controller] in
            controller.clearShelf()
        }
        menu.addItem(clear)
        clearItem = clear

        menu.addItem(.separator())
        menu.addItem(submenuItem("Window Position", positionMenu))
        menu.addItem(submenuItem("Window Size", sizeMenu))
        let show = ActionMenuItem("Show Hermes", symbol: "square") { [controller] in
            controller.toggle(tab: .shelf)
        }
        show.setShortcut(for: .toggleShelf)
        menu.addItem(show)
        showItem = show
        let history = ActionMenuItem("Clipboard History", symbol: "list.clipboard") { [controller] in
            controller.toggle(tab: .clipboard)
        }
        history.setShortcut(for: .showClipboard)
        menu.addItem(history)

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("About Hermes", symbol: "info.circle") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(ActionMenuItem("Settings…", symbol: "gearshape") { [showSettings] in
            showSettings()
        })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Quit Hermes", symbol: "xmark.square") {
            NSApp.terminate(nil)
        })
    }

    func menuDidClose(_ menu: NSMenu) {
        importResponder.resign()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        importResponder.becomeKey()
        let store = controller.store
        restoreItem?.isAvailable = store.canRestore
        clearItem?.isAvailable = store.items.contains { !$0.isPinned }
        showItem?.state = controller.mode == .open && controller.tab == .shelf ? .on : .off
        fillPositionMenu()
        fillSizeMenu()
    }

    private func submenuItem(_ title: String, _ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func fillPositionMenu() {
        let submenu = positionMenu
        submenu.removeAllItems()
        for edge in ShelfEdge.allCases {
            if edge == .right { submenu.addItem(.separator()) }
            submenu.addItem(.sectionHeader(title: "\(edge.title) Edge of Screen"))
            for position in ShelfPosition.allCases {
                let selected = Preferences.edge == edge && Preferences.position == position
                submenu.addItem(ActionMenuItem("\(edge.title) Edge, \(position.title)", state: selected ? .on : .off) {
                    Preferences.defaults.set(edge.rawValue, forKey: SettingKey.edge)
                    Preferences.defaults.set(position.rawValue, forKey: SettingKey.position)
                })
            }
        }
    }

    private func fillSizeMenu() {
        let submenu = sizeMenu
        submenu.removeAllItems()
        for size in ShelfSize.allCases {
            if size == .automatic { submenu.addItem(.separator()) }
            submenu.addItem(ActionMenuItem(size.title, state: Preferences.size == size ? .on : .off) {
                Preferences.defaults.set(size.rawValue, forKey: SettingKey.size)
            })
        }
    }
}

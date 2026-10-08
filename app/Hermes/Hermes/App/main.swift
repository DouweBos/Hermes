// App/main.swift
// Hermes
//
// Application entry point. Plain AppKit: the menu bar item, shelf panel and Settings window are all managed by hand.

import AppKit

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
}

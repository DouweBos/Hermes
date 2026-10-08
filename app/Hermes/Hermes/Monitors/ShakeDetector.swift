// Monitors/ShakeDetector.swift
// Hermes
//
// Recognizes a quick side-to-side shake of the pointer from its positions over time.

import Foundation

struct ShakeDetector {
    /// Horizontal travel that counts as one swing.
    var minimumSwing: CGFloat = 40
    /// Direction changes needed within the window.
    var requiredReversals = 3
    var window: TimeInterval = 0.8

    private var anchorX: CGFloat?
    private var direction: CGFloat = 0
    private var reversals: [TimeInterval] = []

    /// Feeds a pointer position; true once the movement adds up to a shake.
    mutating func add(x: CGFloat, at time: TimeInterval) -> Bool {
        guard let anchor = anchorX else {
            anchorX = x
            return false
        }
        let delta = x - anchor
        guard abs(delta) >= minimumSwing else {
            // Keep the anchor at the turning point while still moving the same way.
            if direction != 0, delta * direction > 0 { anchorX = x }
            return false
        }
        let newDirection: CGFloat = delta > 0 ? 1 : -1
        if direction != 0, newDirection != direction {
            reversals.append(time)
        }
        direction = newDirection
        anchorX = x
        reversals.removeAll { time - $0 > window }
        if reversals.count >= requiredReversals {
            reset()
            return true
        }
        return false
    }

    mutating func reset() {
        anchorX = nil
        direction = 0
        reversals.removeAll()
    }
}

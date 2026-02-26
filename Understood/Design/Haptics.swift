//
//  Haptics.swift
//  Understood
//
//  Haptic feedback utility
//

import UIKit

enum Haptics {
    /// Light tap — for card taps, selections
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium tap — for button presses, swipe actions
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Success — for "This Landed", save complete
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Error — for failures, delete confirmations
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Warning — for destructive action confirmations
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Selection tick — for pill/chip taps
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

//
//  AppNavigationState.swift
//  Understood
//
//  Global navigation state for menu-driven navigation
//

import SwiftUI

@Observable
class AppNavigationState {
    /// Active section: "story", "note", "action", "connection", "extraction", "timeline"
    var currentSection: String = "story"

    /// Life area filter: "all", "business", "finance", "health", "fitness", "spiritual", "fun", "social", "romance"
    var currentFilter: String = "all"

    /// Overlay states
    var showMenu: Bool = false
    var showCapture: Bool = false

    /// All available life areas
    static let lifeAreas = [
        "all", "business", "finance", "health",
        "fitness", "spiritual", "fun", "social", "romance"
    ]

    /// All navigable sections
    static let sections: [(id: String, label: String, icon: String)] = [
        ("story", "Stories", "book.pages"),
        ("note", "Notes", "note.text"),
        ("action", "Actions", "checkmark.circle"),
        ("connection", "Connections", "brain.head.profile"),
        ("extraction", "Extractions", "sparkle.magnifyingglass")
    ]

    /// Navigate to a section and dismiss the menu
    func navigate(to section: String) {
        currentSection = section
        showMenu = false
    }

    /// Set filter and dismiss the menu
    func setFilter(_ filter: String) {
        currentFilter = filter
    }
}

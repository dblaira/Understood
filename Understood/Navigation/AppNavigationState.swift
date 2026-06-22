//
//  AppNavigationState.swift
//  Understood
//
//  Global navigation state for menu-driven navigation
//

import SwiftUI

@Observable
class AppNavigationState {
    enum CaptureKind: String, CaseIterable, Identifiable {
        case reminder
        case action
        case event

        var id: String { rawValue }
    }

    /// Shared navigation stack for the app shell. Section changes reset this so
    /// detail pages cannot trap the user above the home surface.
    var navigationPath = NavigationPath()

    /// Active section: "story", "connection", "extraction", "timeline".
    /// Legacy "note" and "action" routes remain in code, but are no longer user-facing.
    var currentSection: String = "story"

    /// Pattern step filter: "all" or lowercased Adam Pattern step name
    var currentFilter: String = "all"

    /// Overlay states
    var showMenu: Bool = false
    var isRadialMenuPresented: Bool = false
    var highlightedCaptureKind: CaptureKind? = nil
    var captureKind: CaptureKind = .reminder
    var showCapture: Bool = false {
        didSet {
            if showCapture && !oldValue {
                captureSessionID = UUID()
                isRadialMenuPresented = false
            }
        }
    }
    var showSettings: Bool = false
    var captureSessionID = UUID()

    /// Adam Pattern filter options (replaces life areas)
    static let patternFilters = AdamPattern.filterOptions

    /// Primary sections shown in the app navigation.
    static let sections: [(id: String, label: String, icon: String)] = [
        ("story", "Now", "house"),
        ("connection", "Reminders", "bell"),
        ("extraction", "Actions", "bolt"),
        ("timeline", "Calendar", "calendar")
    ]

    /// Navigate to a section and dismiss the menu
    func navigate(to section: String) {
        navigationPath = NavigationPath()
        currentSection = section
        showMenu = false
        isRadialMenuPresented = false
    }

    /// Return to the app's home surface from any sheet or pushed detail.
    func returnHome() {
        navigationPath = NavigationPath()
        currentSection = "story"
        currentFilter = "all"
        showMenu = false
        showSettings = false
        isRadialMenuPresented = false
        showCapture = false
    }

    /// Set pattern filter and dismiss the menu
    func setFilter(_ filter: String) {
        currentFilter = filter
    }

    func toggleRadialMenu() {
        isRadialMenuPresented.toggle()
        if !isRadialMenuPresented {
            highlightedCaptureKind = nil
        }
    }

    func dismissRadialMenu() {
        isRadialMenuPresented = false
        highlightedCaptureKind = nil
    }

    func openComposer(kind: CaptureKind) {
        captureKind = kind
        highlightedCaptureKind = nil
        isRadialMenuPresented = false
        showCapture = true
    }
}

//
//  MainTabView.swift
//  Understood
//
//  Bottom navigation with centered capture
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(AppNavigationState.self) private var nav
    @EnvironmentObject private var reminderStore: ReminderStore
    let supabase = SupabaseService.shared

    @State private var editingReminder: Reminder?
    @State private var pendingSeed: Reminder?

    var body: some View {
        @Bindable var nav = nav

        ZStack(alignment: .bottom) {
            NavigationStack(path: $nav.navigationPath) {
                ZStack {
                    Color.understoodCream
                        .ignoresSafeArea()

                    switch nav.currentSection {
                    case "story":
                        ContentView(patternFilter: nav.currentFilter)
                    case "connection":
                        RemindersHomeView(onOpen: openReminder)
                    case "extraction":
                        RecallActionsHomeView(onOpen: openReminder)
                    case "timeline":
                        RecallCalendarView(onOpen: openReminder)
                    case "note":
                        BeliefLibraryView(patternFilter: nav.currentFilter)
                    case "action":
                        ActionsView(patternFilter: nav.currentFilter)
                    default:
                        ContentView(patternFilter: nav.currentFilter)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
            }

            if nav.isRadialMenuPresented {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { closeFabMenu() }
                    .transition(.opacity)
            }

            BottomNavigationBar(
                onSelectKind: startEntry,
                onCloseMenu: closeFabMenu
            )
        }
        .fullScreenCover(isPresented: $nav.showMenu) {
            FullScreenMenuView(onSignOut: {
                Task {
                    try? await supabase.signOut()
                }
            })
            .environment(nav)
        }
        .sheet(isPresented: $nav.showCapture, onDismiss: {
            editingReminder = nil
            pendingSeed = nil
        }) {
            EntryComposerView(
                initialKind: nav.captureKind.reminderKind,
                existing: editingReminder ?? pendingSeed,
                existingTags: knownTags
            ) { reminderStore.save($0) }
            .id(nav.captureSessionID)
        }
        .sheet(isPresented: $nav.showSettings) {
            SettingsView(onSignOut: {
                Task {
                    try? await supabase.signOut()
                }
            })
        }
    }

    private var knownTags: [String] {
        let counts = Dictionary(
            reminderStore.reminders.flatMap(\.tags).map { ($0, 1) },
            uniquingKeysWith: +
        )
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }

    private func startEntry(_ kind: AppNavigationState.CaptureKind) {
        editingReminder = nil
        pendingSeed = nil
        nav.openComposer(kind: kind)
    }

    private func openReminder(_ reminder: Reminder) {
        editingReminder = reminder
        pendingSeed = nil
        nav.captureKind = switch reminder.kind {
        case .reminder: .reminder
        case .action: .action
        case .event: .event
        }
        nav.captureSessionID = UUID()
        nav.showCapture = true
    }

    private func closeFabMenu() {
        FabHaptics.menuClose()
        withAnimation(FabMenuMotion.close) {
            nav.dismissRadialMenu()
        }
    }

    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        EmptyStateView(icon: icon, title: title, subtitle: subtitle)
    }
}

#Preview {
    MainTabView()
        .environment(AppNavigationState())
        .environmentObject(ReminderStore())
}

private struct BottomNavigationBar: View {
    @Environment(AppNavigationState.self) private var nav
    @State private var draggingFab = false
    @State private var menuWasOpenAtStart = false

    let onSelectKind: (AppNavigationState.CaptureKind) -> Void
    let onCloseMenu: () -> Void

    private let barBackground = Color.sandyBrown
    private let inactiveColor = Color(red: 0.34, green: 0.27, blue: 0.21).opacity(0.68)
    private let fabSize: CGFloat = 64

    private var leadingSections: [(id: String, label: String, icon: String)] {
        Array(AppNavigationState.sections.prefix(2))
    }

    private var trailingSections: [(id: String, label: String, icon: String)] {
        Array(AppNavigationState.sections.suffix(2))
    }

    var body: some View {
        ZStack(alignment: .top) {
            barBackground

            HStack(alignment: .center, spacing: 0) {
                ForEach(leadingSections, id: \.id) { section in
                    navButton(section)
                }

                Spacer()
                    .frame(maxWidth: .infinity)

                ForEach(trailingSections, id: \.id) { section in
                    navButton(section)
                }
            }
            .padding(.horizontal, 12)
            .offset(y: 12)

            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(height: 1)

            ZStack {
                if nav.isRadialMenuPresented {
                    fabOption(.reminder, icon: "clock").offset(x: -76, y: -40)
                    fabOption(.action, icon: "bolt.fill").offset(x: 0, y: -116)
                    fabOption(.event, icon: "calendar").offset(x: 76, y: -40)
                }

                fab
                    .offset(y: -22)
            }
        }
        .frame(height: 48)
        .background(barBackground.ignoresSafeArea(edges: .bottom))
    }

    private func navButton(_ section: (id: String, label: String, icon: String)) -> some View {
        Button {
            Haptics.selection()
            nav.navigate(to: section.id)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: section.icon)
                    .font(.system(size: 22, weight: nav.currentSection == section.id ? .semibold : .regular))

                Text(section.label)
                    .font(Typography.chipLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(nav.currentSection == section.id ? .understoodCrimson : inactiveColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.label)
    }

    private var fab: some View {
        borderedSymbol(nav.isRadialMenuPresented ? "xmark" : "bolt.fill")
            .frame(width: fabSize, height: fabSize)
            .background(Color.understoodCrimson)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !draggingFab {
                            draggingFab = true
                            menuWasOpenAtStart = nav.isRadialMenuPresented
                            if !nav.isRadialMenuPresented {
                                FabHaptics.menuOpen()
                                withAnimation(FabMenuMotion.open) {
                                    nav.isRadialMenuPresented = true
                                }
                            }
                        }

                        let target = targetKind(for: value.translation)
                        if target != nav.highlightedCaptureKind {
                            nav.highlightedCaptureKind = target
                            if target != nil {
                                FabHaptics.selection()
                            }
                        }
                    }
                    .onEnded { _ in
                        if let selected = nav.highlightedCaptureKind {
                            FabHaptics.primaryImpact()
                            withAnimation(FabMenuMotion.close) {
                                nav.dismissRadialMenu()
                            }
                            onSelectKind(selected)
                        } else if menuWasOpenAtStart {
                            onCloseMenu()
                        }

                        draggingFab = false
                        nav.highlightedCaptureKind = nil
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(nav.isRadialMenuPresented ? "Close menu" : "New entry")
            .accessibilityIdentifier("chargeFab")
            .accessibilityAddTraits(.isButton)
    }

    private func borderedSymbol(_ name: String) -> some View {
        ZStack {
            Image(systemName: name)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
            Image(systemName: name)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func fabOption(_ kind: AppNavigationState.CaptureKind, icon: String) -> some View {
        let active = nav.highlightedCaptureKind == kind
        return Button {
            FabHaptics.primaryImpact()
            withAnimation(FabMenuMotion.close) {
                nav.dismissRadialMenu()
            }
            onSelectKind(kind)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(active ? Color.understoodCrimson : Color.recallNearBlack, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(active ? 0.9 : 0.15), lineWidth: 1.5)
                    )
                    .scaleEffect(active ? 1.15 : 1)
                Text(kind.label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.understoodCrimson)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func targetKind(for translation: CGSize) -> AppNavigationState.CaptureKind? {
        guard hypot(translation.width, translation.height) > 30 else { return nil }
        let angle = atan2(-translation.height, translation.width) * 180 / .pi
        if angle >= 45 && angle < 135 { return .action }
        if angle >= -45 && angle < 45 { return .event }
        if angle >= 135 || angle < -135 { return .reminder }
        return nil
    }
}

private enum FabMenuMotion {
    static let open = Animation.spring(response: 0.34, dampingFraction: 0.72)
    static let close = Animation.spring(response: 0.3, dampingFraction: 0.8)
}

private enum FabHaptics {
    @MainActor
    static func primaryImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    @MainActor
    static func menuOpen() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    @MainActor
    static func menuClose() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    @MainActor
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

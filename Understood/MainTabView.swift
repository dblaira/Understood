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
    let supabase = SupabaseService.shared

    var body: some View {
        @Bindable var nav = nav

        ZStack(alignment: .bottom) {
            NavigationStack(path: $nav.navigationPath) {
                ZStack {
                    Color.understoodCream
                        .ignoresSafeArea()

                    // Route to active section
                    switch nav.currentSection {
                    case "story":
                        ContentView(patternFilter: nav.currentFilter)
                    case "connection":
                        BeliefLibraryView(patternFilter: nav.currentFilter)
                    case "extraction":
                        ExtractionsView()
                    case "timeline":
                        placeholderView(
                            icon: "chart.xyaxis.line",
                            title: "Patterns",
                            subtitle: "Deterministic readouts and inference layers will live here."
                        )
                    case "note":
                        placeholderView(
                            icon: "note.text",
                            title: "Notes",
                            subtitle: "Coming soon — category-styled note cards"
                        )
                    case "action":
                        ActionsView(patternFilter: nav.currentFilter)
                    default:
                        ContentView(patternFilter: nav.currentFilter)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
            }

            RadialFabMenu(
                isPresented: nav.isRadialMenuPresented,
                highlightedKind: nav.highlightedCaptureKind,
                onDismiss: { nav.dismissRadialMenu() },
                onSelect: { kind in nav.openComposer(kind: kind) }
            )

            BottomNavigationBar()
        }
        .fullScreenCover(isPresented: $nav.showMenu) {
            FullScreenMenuView(onSignOut: {
                Task {
                    try? await supabase.signOut()
                }
            })
            .environment(nav)
        }
        .fullScreenCover(isPresented: $nav.showCapture) {
            EntryComposerView(initialKind: composerKind(for: nav.captureKind), onSaved: {
                // Views will refresh via their own .task modifiers
            })
            .id(nav.captureSessionID)
            .environment(nav)
        }
        .sheet(isPresented: $nav.showSettings) {
            SettingsView(onSignOut: {
                Task {
                    try? await supabase.signOut()
                }
            })
        }
    }

    /// Placeholder for sections not yet built
    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        EmptyStateView(
            icon: icon,
            title: title,
            subtitle: subtitle
        )
    }

    private func composerKind(for kind: AppNavigationState.CaptureKind) -> EntryComposerKind {
        switch kind {
        case .reminder:
            return .reminder
        case .action:
            return .action
        case .event:
            return .event
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppNavigationState())
}

private struct BottomNavigationBar: View {
    @Environment(AppNavigationState.self) private var nav
    @State private var draggingFab = false
    @State private var menuWasOpenAtStart = false
    private let barBackground = Color(red: 0.80, green: 0.70, blue: 0.58)
    private let inactiveColor = Color(red: 0.34, green: 0.27, blue: 0.21).opacity(0.68)
    private let fabSize: CGFloat = 70

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
                if !nav.isRadialMenuPresented {
                    // Slightly larger red underlay creates a thin visible outline.
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.understoodCrimson)
                }
                Image(systemName: nav.isRadialMenuPresented ? "xmark" : "bolt.fill")
                    .font(.system(size: nav.isRadialMenuPresented ? 32 : 30, weight: .heavy))
                    .foregroundStyle(.white)
            }
                .frame(width: fabSize, height: fabSize)
                .background(Color.textPrimary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
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
                                    nav.openComposer(kind: selected)
                                }
                            } else if menuWasOpenAtStart {
                                FabHaptics.menuClose()
                                withAnimation(FabMenuMotion.close) {
                                    nav.dismissRadialMenu()
                                }
                            }

                            draggingFab = false
                            nav.highlightedCaptureKind = nil
                        }
                )
            .accessibilityLabel(nav.isRadialMenuPresented ? "Close quick capture menu" : "Open quick capture menu")
            // Center the FAB on the white/brown seam.
            .offset(y: -(fabSize / 2))
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

    private func targetKind(for translation: CGSize) -> AppNavigationState.CaptureKind? {
        guard hypot(translation.width, translation.height) > 30 else { return nil }
        let angle = atan2(-translation.height, translation.width) * 180 / .pi
        if angle >= 45 && angle < 135 { return .action }     // up
        if angle >= -45 && angle < 45 { return .event }      // right
        if angle >= 135 || angle < -135 { return .reminder } // left
        return nil
    }
}

private struct RadialFabMenu: View {
    let isPresented: Bool
    let highlightedKind: AppNavigationState.CaptureKind?
    let onDismiss: () -> Void
    let onSelect: (AppNavigationState.CaptureKind) -> Void

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        FabHaptics.menuClose()
                        withAnimation(FabMenuMotion.close) {
                            onDismiss()
                        }
                    }
                    .transition(.opacity)

                ZStack {
                    radialButton(kind: .reminder, icon: "bell.fill", x: -118, y: 0)
                    radialButton(kind: .action, icon: "bolt.fill", x: 0, y: -118)
                    radialButton(kind: .event, icon: "calendar", x: 118, y: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                // Anchor the radial hub to the FAB center so swipe directions are cardinal.
                .padding(.bottom, 48)
                .transition(.scale(scale: 0.78, anchor: .bottom).combined(with: .opacity))
            }
        }
    }

    private func radialButton(
        kind: AppNavigationState.CaptureKind,
        icon: String,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        let isHighlighted = highlightedKind == kind
        return Button {
            FabHaptics.primaryImpact()
            withAnimation(FabMenuMotion.close) {
                onSelect(kind)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(Color.understoodCrimson, in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(isHighlighted ? 0.95 : 0.35), lineWidth: isHighlighted ? 3 : 1.5)
                )
                .scaleEffect(isHighlighted ? 1.14 : 1.0)
                .shadow(color: Color.black.opacity(0.22), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .offset(x: x, y: y)
        .accessibilityLabel(kind.rawValue.capitalized)
    }
}

private enum FabMenuMotion {
    // Snappier reveal when opening, smoother collapse when closing.
    static let open = Animation.spring(response: 0.24, dampingFraction: 0.76)
    static let close = Animation.spring(response: 0.42, dampingFraction: 0.82)
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

private struct AppMenuButton: View {
    @Environment(AppNavigationState.self) private var nav

    var body: some View {
        VStack {
            HStack {
                Spacer()

                Button {
                    Haptics.light()
                    nav.showMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.78))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open menu")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer()
        }
    }
}

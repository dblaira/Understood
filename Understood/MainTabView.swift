//
//  MainTabView.swift
//  Understood
//
//  Bottom navigation with centered capture
//

import SwiftUI

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
            CaptureView(onSaved: {
                // Views will refresh via their own .task modifiers
            })
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
}

#Preview {
    MainTabView()
        .environment(AppNavigationState())
}

private struct BottomNavigationBar: View {
    @Environment(AppNavigationState.self) private var nav
    private let barBackground = Color(red: 0.80, green: 0.70, blue: 0.58)
    private let inactiveColor = Color(red: 0.34, green: 0.27, blue: 0.21).opacity(0.68)

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

            Button {
                Haptics.medium()
                nav.showCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.textPrimary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Capture")
            .offset(y: -12)
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

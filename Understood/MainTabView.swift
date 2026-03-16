//
//  MainTabView.swift
//  Understood
//
//  Menu-driven navigation: hamburger → full-page menu
//

import SwiftUI

struct MainTabView: View {
    @Environment(AppNavigationState.self) private var nav
    let supabase = SupabaseService.shared

    var body: some View {
        @Bindable var nav = nav

        ZStack(alignment: .bottom) {
            NavigationStack {
                ZStack {
                    Color.understoodCream
                        .ignoresSafeArea()

                    // Route to active section
                    switch nav.currentSection {
                    case "story":
                        ContentView(lifeAreaFilter: nav.currentFilter)
                    case "connection":
                        BeliefLibraryView(lifeAreaFilter: nav.currentFilter)
                    case "extraction":
                        ExtractionsView()
                    case "timeline":
                        // Phase 3 — placeholder until TimelineView is built
                        placeholderView(
                            icon: "clock.arrow.circlepath",
                            title: "Timeline",
                            subtitle: "Coming soon — chronological archive of all entries"
                        )
                    case "note":
                        // Phase 2 — placeholder until NotesView is built
                        placeholderView(
                            icon: "note.text",
                            title: "Notes",
                            subtitle: "Coming soon — category-styled note cards"
                        )
                    case "action":
                        ActionsView(lifeAreaFilter: nav.currentFilter)
                    default:
                        ContentView(lifeAreaFilter: nav.currentFilter)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(navTitle)
                            .font(Typography.uiMedium)
                            .fontWeight(.semibold)
                            .foregroundStyle(.textPrimary)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Haptics.light()
                            nav.showMenu = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.textPrimary)
                        }
                    }

                    // Filter indicator
                    if nav.currentFilter != "all" {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                nav.currentFilter = "all"
                                Haptics.selection()
                            } label: {
                                HStack(spacing: 4) {
                                    Text(nav.currentFilter.capitalized)
                                        .font(Typography.chipLabel)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundStyle(.understoodCrimson)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.understoodCrimson.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            // Floating capture button
            Button {
                Haptics.medium()
                nav.showCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.textPrimary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .padding(.bottom, 16)
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
    }

    /// Dynamic nav title based on current section
    private var navTitle: String {
        switch nav.currentSection {
        case "story": return "Understood"
        case "note": return "Notes"
        case "action": return "Actions"
        case "connection": return "Beliefs"
        case "extraction": return "Understood"
        case "timeline": return "Timeline"
        default: return "Understood"
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

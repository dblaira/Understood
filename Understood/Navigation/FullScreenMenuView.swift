//
//  FullScreenMenuView.swift
//  Understood
//
//  Full-page black overlay menu matching the web's mobile-menu.tsx
//

import SwiftUI

struct FullScreenMenuView: View {
    @Environment(AppNavigationState.self) private var nav
    let onSignOut: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Close button
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                nav.showMenu = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("CLOSE")
                                    .font(Typography.sectionHeader)
                                    .tracking(2)
                            }
                            .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)

                    // MARK: - Section Navigation
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(AppNavigationState.sections, id: \.id) { section in
                            sectionButton(
                                label: section.label.uppercased(),
                                isActive: nav.currentSection == section.id
                            ) {
                                Haptics.light()
                                nav.navigate(to: section.id)
                            }
                        }

                    }
                    .padding(.horizontal, 24)

                    // MARK: - Life Areas
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LIFE AREAS")
                            .font(Typography.sectionHeader)
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.4))

                        FlowLayout(spacing: 10) {
                            ForEach(AppNavigationState.lifeAreas, id: \.self) { area in
                                Button {
                                    Haptics.selection()
                                    nav.setFilter(area)
                                } label: {
                                    Text(area == "all" ? "All" : area.capitalized)
                                        .font(Typography.uiMedium)
                                        .foregroundStyle(nav.currentFilter == area ? .black : .white.opacity(0.7))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            nav.currentFilter == area
                                                ? Color.white
                                                : Color.white.opacity(0.08)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)

                    // MARK: - Compose Button
                    Button {
                        Haptics.medium()
                        nav.showMenu = false
                        // Small delay so menu dismisses before capture appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            nav.showCapture = true
                        }
                    } label: {
                        Text("COMPOSE")
                            .font(Typography.uiMedium)
                            .tracking(2)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.understoodCrimson)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)

                    // MARK: - Bottom Actions
                    HStack(spacing: 32) {
                        Button {
                            Haptics.light()
                            nav.showMenu = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                nav.showSettings = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 14))
                                Text("Settings")
                                    .font(Typography.subtitle)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        }

                        Button {
                            Haptics.warning()
                            nav.showMenu = false
                            onSignOut()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 14))
                                Text("Sign Out")
                                    .font(Typography.subtitle)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Section Button

    private func sectionButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isActive {
                    Circle()
                        .fill(Color.understoodCrimson)
                        .frame(width: 8, height: 8)
                }

                Text(label)
                    .font(.custom("PlayfairDisplay-Regular", size: 30))
                    .tracking(2)
                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))

                Spacer()
            }
            .padding(.vertical, 10)
        }
    }
}

#Preview {
    FullScreenMenuView(onSignOut: {})
        .environment(AppNavigationState())
}

//
//  UnderstoodApp.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import SwiftUI

// MARK: - App Entry Point

@main
struct UnderstoodApp: App {
    @State private var supabase = SupabaseService.shared
    @State private var nav = AppNavigationState()
    @StateObject private var reminderStore = ReminderStore()
    @State private var appliedUITestLaunchState = false

    /// DEBUG-only simulator verification door: skips the login gate (local store only, no
    /// Supabase writes) so UI can be exercised and screenshotted without credentials.
    /// Compiled out of release builds entirely.
    private var uiTestBypassAuth: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uitestBypassAuth")
        #else
        return false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if uiTestBypassAuth {
                    MainTabView()
                        .environment(nav)
                        .environmentObject(reminderStore)
                        .onAppear { applyUITestLaunchState() }
                } else if !supabase.hasCheckedInitialSession {
                    LaunchAuthCheckView()
                } else if supabase.isAuthenticated {
                    MainTabView()
                        .environment(nav)
                        .environmentObject(reminderStore)
                        .onAppear { applyUITestLaunchState() }
                        .task {
                            await reminderStore.bootstrap()
                        }
                } else {
                    LoginView()
                }
            }
            .background(Color.understoodCream)
            .task {
                #if DEBUG
                if PhotoUploadVerifier.isEnabled {
                    await PhotoUploadVerifier.runIfNeeded()
                    await MainActor.run {
                        supabase.hasCheckedInitialSession = true
                    }
                    return
                }
                #endif

                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await supabase.checkSession()
                    }
                    group.addTask {
                        try? await Task.sleep(for: .seconds(4))
                        await MainActor.run {
                            if !supabase.hasCheckedInitialSession {
                                supabase.hasCheckedInitialSession = true
                            }
                        }
                    }
                    _ = await group.next()
                    group.cancelAll()
                }
            }
        }
    }

    /// DEBUG launch controls also support inspecting the signed-in physical app without reset:
    /// "-uitestComposer <kind>" opens the real entry sheet; "-uitestSection <id>" opens a tab.
    /// "-uitestSeed" is reserved for isolated simulator data.
    private func applyUITestLaunchState() {
        #if DEBUG
        guard !appliedUITestLaunchState else { return }
        appliedUITestLaunchState = true
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-uitestSection"), args.indices.contains(idx + 1) {
            nav.currentSection = args[idx + 1]
        }
        if let idx = args.firstIndex(of: "-uitestComposer"), args.indices.contains(idx + 1),
           let kind = AppNavigationState.CaptureKind(rawValue: args[idx + 1]) {
            nav.openComposer(kind: kind)
        }
        if args.contains("-uitestSeed"), reminderStore.reminders.isEmpty {
            var first = Reminder(); first.kind = .reminder; first.title = "Sim check one"
            var second = Reminder(); second.kind = .reminder; second.title = "Sim check two"
            var third = Reminder(); third.kind = .action; third.title = "Sim action"
            var fourth = Reminder(); fourth.kind = .event; fourth.title = "Sim event today"
            fourth.dueDate = Date()
            [first, second, third, fourth].forEach { reminderStore.save($0) }
        }
        #endif
    }
}

private struct LaunchAuthCheckView: View {
    var body: some View {
        ZStack {
            Color.understoodCream
                .ignoresSafeArea()

            ProgressView()
                .tint(.textPrimary)
        }
    }
}

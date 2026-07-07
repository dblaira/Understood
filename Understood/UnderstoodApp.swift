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

    /// Optional launch arguments consumed with the bypass: "-uitestSection <id>" opens a tab,
    /// "-uitestSeed" plants sample reminders/actions/events in the local store.
    private func applyUITestLaunchState() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-uitestSection"), args.indices.contains(idx + 1) {
            nav.currentSection = args[idx + 1]
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

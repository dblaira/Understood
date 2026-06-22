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

    var body: some Scene {
        WindowGroup {
            Group {
                if !supabase.hasCheckedInitialSession {
                    LaunchAuthCheckView()
                } else if supabase.isAuthenticated {
                    MainTabView()
                        .environment(nav)
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

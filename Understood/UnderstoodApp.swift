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
            if supabase.isAuthenticated {
                MainTabView()
                    .environment(nav)
            } else {
                LoginView()
            }
        }
    }
}

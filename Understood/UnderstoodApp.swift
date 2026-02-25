//
//  UnderstoodApp.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import SwiftUI

@main
struct UnderstoodApp: App {
    @State private var supabase = SupabaseService.shared
    
    var body: some Scene {
        WindowGroup {
            if supabase.isAuthenticated {
                ContentView()
            } else {
                LoginView()
            }
        }
    }
}

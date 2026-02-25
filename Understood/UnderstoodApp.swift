//
//  UnderstoodApp.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import SwiftUI
import UserNotifications

// MARK: - AppDelegate (Push Notification Bridge)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationService.shared.handleRegistrationError(error)
    }
}

// MARK: - App Entry Point

@main
struct UnderstoodApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var supabase = SupabaseService.shared
    @State private var showNotificationPrompt = false

    var body: some Scene {
        WindowGroup {
            if supabase.isAuthenticated {
                MainTabView()
                    .task {
                        await NotificationService.shared.checkPermission()
                        if !NotificationService.shared.hasAskedPermission {
                            showNotificationPrompt = true
                        }
                    }
                    .sheet(isPresented: $showNotificationPrompt) {
                        NotificationPromptView()
                    }
            } else {
                LoginView()
            }
        }
    }
}

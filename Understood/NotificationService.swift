//
//  NotificationService.swift
//  Understood
//
//  Phase 5: Push Notifications via APNs
//

import Foundation
import UserNotifications
import UIKit

@Observable
class NotificationService: NSObject {
    static let shared = NotificationService()

    var isPermissionGranted = false
    var deviceToken: String?
    var hasAskedPermission = false

    private let supabase = SupabaseService.shared

    private override init() {
        super.init()
        registerCategories()
    }

    // MARK: - Permission

    func checkPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            isPermissionGranted = settings.authorizationStatus == .authorized
            hasAskedPermission = settings.authorizationStatus != .notDetermined
        }
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                isPermissionGranted = granted
                hasAskedPermission = true
            }
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    // MARK: - Device Token

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02x", $0) }.joined()
        deviceToken = tokenString
        print("APNs device token: \(tokenString)")

        Task {
            await registerTokenWithServer(tokenString)
        }
    }

    func handleRegistrationError(_ error: Error) {
        print("APNs registration failed: \(error)")
    }

    private func registerTokenWithServer(_ token: String) async {
        guard let userId = supabase.currentSession?.user.id else {
            print("Cannot register push token: not authenticated")
            return
        }

        guard let url = URL(string: "\(SupabaseService.apiBaseURL)/api/push/register-ios") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken = supabase.currentSession?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "user_id": userId.uuidString,
            "device_token": token,
            "device_name": UIDevice.current.name,
            "timezone": TimeZone.current.identifier
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("iOS push token registered successfully")
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("Push token registration failed: status \(statusCode)")
            }
        } catch {
            print("Push token registration error: \(error)")
        }
    }

    // MARK: - Re-register on Login

    /// Call after authentication to ensure the token is registered for the current user
    func registerIfNeeded() async {
        await checkPermission()
        if isPermissionGranted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Notification Categories

    private func registerCategories() {
        let landedAction = UNNotificationAction(
            identifier: "LANDED",
            title: "This Landed",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Not Now",
            options: []
        )

        let connectionCategory = UNNotificationCategory(
            identifier: "CONNECTION",
            actions: [landedAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([connectionCategory])
    }

    // MARK: - Handle Notification Response

    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let connectionId = userInfo["connectionId"] as? String else { return }

        let action: String
        switch response.actionIdentifier {
        case "LANDED":
            action = "landed"
        case "SNOOZE":
            action = "snooze"
        case UNNotificationDefaultActionIdentifier:
            action = "opened"
        default:
            return
        }

        guard let url = URL(string: "\(SupabaseService.apiBaseURL)/api/notifications/response") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "connectionId": connectionId,
            "action": action
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            print("Notification response error: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handleNotificationResponse(response)
    }
}

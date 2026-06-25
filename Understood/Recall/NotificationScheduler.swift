import Foundation
import UserNotifications

enum NotificationScheduler {
    static func schedule(_ reminder: Reminder) {
        cancel(reminder)
        guard reminder.status == .active, let base = reminder.fireDate else { return }
        let fire = base.addingTimeInterval(-reminder.earlyReminder.lead)

        Task {
            guard await ensureAuthorized() else { return }
            scheduleAuthorized(reminder, fire: fire)
        }
    }

    static func cancel(_ reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids(reminder))
    }

    private static func ensureAuthorized() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static func scheduleAuthorized(_ reminder: Reminder, fire: Date) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title.isEmpty ? "Reminder" : reminder.title
        if !reminder.notes.isEmpty { content.body = reminder.notes }
        content.sound = .default
        if reminder.urgent { content.interruptionLevel = .timeSensitive }

        let cal = Calendar.current
        let repeats = reminder.repeatRule != .none
        if reminder.repeatRule == .weekdays {
            let time = cal.dateComponents([.hour, .minute], from: fire)
            for weekday in 2...6 {
                var comps = DateComponents()
                comps.weekday = weekday
                comps.hour = time.hour
                comps.minute = time.minute
                addRequest(identifier: id(reminder, suffix: "\(weekday)"), content: content, components: comps, repeats: true)
            }
            return
        }

        let comps: DateComponents
        switch reminder.repeatRule {
        case .none:
            comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        case .daily:
            comps = cal.dateComponents([.hour, .minute], from: fire)
        case .weekly:
            comps = cal.dateComponents([.weekday, .hour, .minute], from: fire)
        case .weekdays:
            return
        case .monthly:
            comps = cal.dateComponents([.day, .hour, .minute], from: fire)
        case .yearly:
            comps = cal.dateComponents([.month, .day, .hour, .minute], from: fire)
        }

        addRequest(identifier: id(reminder), content: content, components: comps, repeats: repeats)
    }

    private static func id(_ reminder: Reminder) -> String { "recall.reminder.\(reminder.id.uuidString)" }
    private static func id(_ reminder: Reminder, suffix: String) -> String { "\(id(reminder)).\(suffix)" }
    private static func ids(_ reminder: Reminder) -> [String] {
        [id(reminder)] + (2...6).map { id(reminder, suffix: "\($0)") }
    }

    private static func addRequest(
        identifier: String,
        content: UNNotificationContent,
        components: DateComponents,
        repeats: Bool
    ) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
